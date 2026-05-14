package dev.marshalx.fluxora_mobile.exo

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Plan 24 M1 — Android ExoPlayer spike plugin.
 *
 * Owns a single Media3 [ExoPlayer] instance and bridges it to Dart via a
 * [MethodChannel] on `dev.marshalx.fluxora/exo_player`.  The full M4
 * module will:
 *   - move to a per-player id map (multiple Flutter players),
 *   - add an EventChannel for state/position/track events,
 *   - implement seek + audio-track selection + volume,
 *   - inject the bearer-token Authorization header on segment fetches.
 *
 * For M1 the surface we want to validate is:
 *   1. `androidx.media3:media3-exoplayer-hls` resolves and compiles.
 *   2. Flutter's [TextureRegistry.SurfaceProducer] hands ExoPlayer a
 *      Surface that the engine actually renders into.
 *   3. The texture id round-trips back to Dart so `Texture(textureId:)`
 *      shows the frame.
 *
 * Logging tag is `FluxoraExoSpike` so the operator can `adb logcat -s
 * FluxoraExoSpike` and isolate the spike from production playback logs.
 */
class ExoPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "FluxoraExoSpike"
        private const val CHANNEL_NAME = "dev.marshalx.fluxora/exo_player"
    }

    private var methodChannel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var textureRegistry: TextureRegistry? = null

    // M1: single player only.  M4 replaces this with a Map<Int, FluxoraExoPlayer>.
    private var player: ExoPlayer? = null
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── FlutterPlugin lifecycle ──────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.i(TAG, "onAttachedToEngine — registering channel $CHANNEL_NAME")
        applicationContext = binding.applicationContext
        textureRegistry = binding.textureRegistry
        registerChannel(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.i(TAG, "onDetachedFromEngine — tearing down player + channel")
        disposeInternal()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        applicationContext = null
        textureRegistry = null
    }

    /**
     * Public entry point used by `MainActivity.configureFlutterEngine`
     * when the plugin is wired manually instead of via plugin auto-
     * registration.  Kept as a separate method so the same code path
     * survives the move to a proper FlutterPlugin auto-register flow
     * in M4.
     */
    fun attachToEngine(
        context: Context,
        messenger: BinaryMessenger,
        registry: TextureRegistry,
    ) {
        Log.i(TAG, "attachToEngine — manual registration on $CHANNEL_NAME")
        applicationContext = context
        textureRegistry = registry
        registerChannel(messenger)
    }

    private fun registerChannel(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, CHANNEL_NAME).apply {
            setMethodCallHandler(this@ExoPlayerPlugin)
        }
    }

    // ── MethodChannel handler ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.i(TAG, "onMethodCall method=${call.method}")
        when (call.method) {
            "open" -> handleOpen(call, result)
            "play" -> handlePlay(result)
            "pause" -> handlePause(result)
            "dispose" -> handleDispose(result)
            else -> {
                Log.w(TAG, "onMethodCall — unimplemented method=${call.method}")
                result.notImplemented()
            }
        }
    }

    private fun handleOpen(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        @Suppress("UNCHECKED_CAST")
        val headers = call.argument<Map<String, String>>("headers")

        if (url.isNullOrBlank()) {
            Log.e(TAG, "open — missing 'url' arg")
            result.error("BAD_ARGS", "Missing 'url' argument", null)
            return
        }

        val context = applicationContext
        val registry = textureRegistry
        if (context == null || registry == null) {
            Log.e(TAG, "open — plugin not attached to an engine")
            result.error(
                "NOT_ATTACHED",
                "Plugin is not attached to a Flutter engine",
                null,
            )
            return
        }

        try {
            // M1: a second `open` on the same plugin throws away the
            // previous player + surface.  M4 will track multiple ids.
            disposeInternal()

            val producer = registry.createSurfaceProducer().also {
                surfaceProducer = it
            }
            val producerSurface = producer.surface
            if (producerSurface == null) {
                Log.e(TAG, "open — SurfaceProducer returned a null Surface")
                disposeInternal()
                result.error(
                    "NO_SURFACE",
                    "Flutter SurfaceProducer returned a null Surface",
                    null,
                )
                return
            }
            Log.i(TAG, "open — created SurfaceProducer id=${producer.id()}")

            val httpFactory = DefaultHttpDataSource.Factory()
                .setAllowCrossProtocolRedirects(true)
            if (!headers.isNullOrEmpty()) {
                Log.i(TAG, "open — applying ${headers.size} HTTP header(s)")
                httpFactory.setDefaultRequestProperties(headers)
            }

            val mediaSource = HlsMediaSource.Factory(httpFactory)
                .createMediaSource(MediaItem.fromUri(Uri.parse(url)))

            val newPlayer = ExoPlayer.Builder(context)
                .build()
                .apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                            .setUsage(C.USAGE_MEDIA)
                            .build(),
                        /* handleAudioFocus = */ true,
                    )
                    setHandleAudioBecomingNoisy(true)
                    setVideoSurface(producerSurface)
                    addListener(SpikeListener())
                    setMediaSource(mediaSource)
                    prepare()
                    playWhenReady = true
                }
            player = newPlayer

            Log.i(TAG, "open — ExoPlayer prepared, returning textureId=${producer.id()}")
            result.success(producer.id())
        } catch (t: Throwable) {
            Log.e(TAG, "open — failed to start playback", t)
            disposeInternal()
            result.error("OPEN_FAILED", t.message, null)
        }
    }

    private fun handlePlay(result: MethodChannel.Result) {
        val p = player
        if (p == null) {
            Log.w(TAG, "play — no active player")
            result.error("NO_PLAYER", "No active ExoPlayer; call open() first", null)
            return
        }
        // Player methods are not thread-safe; route through the main
        // handler.  We're already on the main thread for method calls
        // but this future-proofs the spike against a worker isolate.
        mainHandler.post {
            p.playWhenReady = true
            p.play()
        }
        result.success(null)
    }

    private fun handlePause(result: MethodChannel.Result) {
        val p = player
        if (p == null) {
            Log.w(TAG, "pause — no active player")
            result.error("NO_PLAYER", "No active ExoPlayer; call open() first", null)
            return
        }
        mainHandler.post {
            p.pause()
        }
        result.success(null)
    }

    private fun handleDispose(result: MethodChannel.Result) {
        disposeInternal()
        result.success(null)
    }

    private fun disposeInternal() {
        player?.let {
            Log.i(TAG, "dispose — releasing ExoPlayer")
            try {
                it.release()
            } catch (t: Throwable) {
                Log.e(TAG, "dispose — ExoPlayer.release threw", t)
            }
        }
        player = null

        surfaceProducer?.let {
            Log.i(TAG, "dispose — releasing SurfaceProducer id=${it.id()}")
            try {
                it.release()
            } catch (t: Throwable) {
                Log.e(TAG, "dispose — SurfaceProducer.release threw", t)
            }
        }
        surfaceProducer = null
    }

    // ── Listener (logging only for M1) ───────────────────────────────────────

    private inner class SpikeListener : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            Log.i(TAG, "listener — onPlaybackStateChanged state=${stateName(playbackState)}")
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            Log.i(TAG, "listener — onIsPlayingChanged isPlaying=$isPlaying")
        }

        override fun onPlayerError(error: PlaybackException) {
            Log.e(
                TAG,
                "listener — onPlayerError codeName=${error.errorCodeName} " +
                    "code=${error.errorCode} message=${error.message}",
                error,
            )
        }

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            Log.i(
                TAG,
                "listener — onPositionDiscontinuity reason=$reason " +
                    "old=${oldPosition.positionMs}ms new=${newPosition.positionMs}ms",
            )
        }

        override fun onTracksChanged(tracks: androidx.media3.common.Tracks) {
            Log.i(TAG, "listener — onTracksChanged groups=${tracks.groups.size}")
        }
    }

    private fun stateName(state: Int): String = when (state) {
        Player.STATE_IDLE -> "IDLE"
        Player.STATE_BUFFERING -> "BUFFERING"
        Player.STATE_READY -> "READY"
        Player.STATE_ENDED -> "ENDED"
        else -> "UNKNOWN($state)"
    }
}
