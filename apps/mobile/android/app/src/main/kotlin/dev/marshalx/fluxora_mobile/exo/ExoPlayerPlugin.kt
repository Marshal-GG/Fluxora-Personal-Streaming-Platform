package dev.marshalx.fluxora_mobile.exo

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Android ExoPlayer plugin entry point.
 *
 * Owns a [Map] of player ids to [FluxoraExoPlayer] instances and routes
 * every Dart→Kotlin command on the `dev.marshalx.fluxora/exo_player`
 * MethodChannel to the right wrapper.  Per-player events (position,
 * tracks, errors, …) flow back to Dart over a single EventChannel
 * `dev.marshalx.fluxora/exo_player_events` — each event payload carries
 * `playerId` as the first field so the Dart side can demultiplex.
 *
 * The plugin attaches either:
 *   1. Automatically via [FlutterPlugin.onAttachedToEngine] when added to
 *      a [io.flutter.embedding.engine.FlutterEngine] via
 *      `engine.plugins.add(ExoPlayerPlugin())`, or
 *   2. Manually via [attachToEngine] for callers that don't go through
 *      the standard FlutterPlugin lifecycle.
 *
 * Channel contract (locked between this plugin and the Dart
 * `ExoPlayerEngine`):
 *
 *   create               → {playerId, textureId}
 *   open                 → {playerId, url, headers?, play, startPositionMs}
 *   play, pause, seek    → {playerId, …}
 *   setAudioTrack        → {playerId, sourceIndex}
 *   setRate, setVolume   → {playerId, …}
 *   dispose              → {playerId}
 *
 * After `dispose`, any subsequent method on the same playerId throws
 * `IllegalStateException` rather than silently no-op'ing.
 */
class ExoPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "FluxoraExoPlugin"
        private const val METHOD_CHANNEL_NAME = "dev.marshalx.fluxora/exo_player"
        private const val EVENT_CHANNEL_NAME = "dev.marshalx.fluxora/exo_player_events"

        /**
         * Process-global handle to the currently-active plugin
         * instance.  The [FluxoraMediaSessionService] runs in a
         * separate Android component and needs to reach across to the
         * Flutter-attached plugin to read the current player.  A weak
         * static handle is the simplest robust shape (the AOSP
         * [androidx.media3.session.MediaSessionService] sample uses
         * the same pattern).  Cleared in [onDetachedFromEngine] so a
         * relaunch can't leak across engine teardown.
         */
        @JvmStatic
        @Volatile
        internal var activeInstance: ExoPlayerPlugin? = null
            private set
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private var applicationContext: Context? = null
    private var textureRegistry: TextureRegistry? = null

    private val players: MutableMap<Int, FluxoraExoPlayer> = HashMap()
    /** Tracks ids that were created and then explicitly disposed — calls
     *  against them must throw, not silently no-op. */
    private val disposedIds: MutableSet<Int> = HashSet()
    private var nextPlayerId: Int = 0

    /**
     * Id of the most-recently-`create`d player.  Drives the
     * [FluxoraMediaSessionService]'s "current session" selection: when
     * the user has multiple Flutter player widgets alive simultaneously
     * (mini-player + fullscreen player) only the most recent one owns
     * the OS media session.  Stays set across `dispose` if the operator
     * tears down a player without creating a new one — in that case the
     * service binds to nothing and the lockscreen card stays idle, which
     * matches the audio_service detach semantics on the MediaKitEngine
     * path.
     */
    @Volatile
    private var currentSessionPlayerId: Int? = null

    // ── FlutterPlugin lifecycle ──────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.i(TAG, "onAttachedToEngine — registering channels")
        applicationContext = binding.applicationContext
        textureRegistry = binding.textureRegistry
        registerChannels(binding.binaryMessenger)
        activeInstance = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.i(TAG, "onDetachedFromEngine — releasing ${players.size} player(s)")
        releaseAllPlayers()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        eventSink = null
        applicationContext = null
        textureRegistry = null
        currentSessionPlayerId = null
        // Clear the static handle only if it still points at *this*
        // instance — defensive against an out-of-order re-attach.
        if (activeInstance === this) {
            activeInstance = null
        }
    }

    /**
     * Returns the [FluxoraExoPlayer] the [FluxoraMediaSessionService]
     * should bind to right now, or `null` when there's no active
     * player.  Reading [currentSessionPlayerId] preserves the
     * "most-recently-created wins" rule.
     */
    internal fun activeSessionPlayer(): FluxoraExoPlayer? {
        val id = currentSessionPlayerId ?: return null
        return players[id]
    }

    /**
     * Manual attachment used by callers that don't go through the
     * standard FlutterPlugin lifecycle.  The plugin behaves
     * identically to the auto-registered path; both code paths funnel
     * through [registerChannels].
     */
    fun attachToEngine(
        context: Context,
        messenger: BinaryMessenger,
        registry: TextureRegistry,
    ) {
        Log.i(TAG, "attachToEngine — manual registration")
        applicationContext = context
        textureRegistry = registry
        registerChannels(messenger)
    }

    private fun registerChannels(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME).apply {
            setMethodCallHandler(this@ExoPlayerPlugin)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME).apply {
            setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        Log.i(TAG, "EventChannel.onListen — sink attached")
                        eventSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        Log.i(TAG, "EventChannel.onCancel — sink detached")
                        eventSink = null
                    }
                },
            )
        }
    }

    // ── Event emission ───────────────────────────────────────────────────────

    /**
     * Push an event payload to the Dart side.  Every payload must carry
     * `playerId` so the Dart listener can demultiplex.  Posts to the
     * Flutter UI thread because [EventChannel.EventSink] is not
     * thread-safe.
     */
    internal fun sendEvent(payload: Map<String, Any?>) {
        val sink = eventSink ?: run {
            // Common during early teardown — listener has detached but
            // a Player.Listener callback fired one last time.  Don't
            // spam logcat on every position tick.
            return
        }
        try {
            sink.success(payload)
        } catch (t: Throwable) {
            Log.w(TAG, "sendEvent — failed to push payload type=${payload["type"]}", t)
        }
    }

    // ── MethodChannel dispatcher ─────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Log only the method + playerId; never log argument values which
        // may contain bearer tokens (Hard Prohibition #8 in CLAUDE.md).
        val pid = call.argument<Int>("playerId")
        Log.d(TAG, "onMethodCall method=${call.method} playerId=$pid")

        try {
            when (call.method) {
                "create" -> handleCreate(result)
                "open" -> handleOpen(call, result)
                "play" -> handlePlay(call, result)
                "pause" -> handlePause(call, result)
                "seek" -> handleSeek(call, result)
                "setAudioTrack" -> handleSetAudioTrack(call, result)
                "setRate" -> handleSetRate(call, result)
                "setVolume" -> handleSetVolume(call, result)
                "setMetadata" -> handleSetMetadata(call, result)
                "dispose" -> handleDispose(call, result)
                else -> {
                    Log.w(TAG, "onMethodCall — unimplemented method=${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: IllegalStateException) {
            Log.w(TAG, "onMethodCall — illegal state for method=${call.method}", e)
            result.error("ILLEGAL_STATE", e.message, null)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "onMethodCall — bad args for method=${call.method}", e)
            result.error("BAD_ARGS", e.message, null)
        } catch (t: Throwable) {
            Log.e(TAG, "onMethodCall — unexpected failure for method=${call.method}", t)
            result.error("UNEXPECTED", t.message, null)
        }
    }

    // ── Method handlers ──────────────────────────────────────────────────────

    private fun handleCreate(result: MethodChannel.Result) {
        val context = applicationContext
            ?: throw IllegalStateException("Plugin not attached: applicationContext == null")
        val registry = textureRegistry
            ?: throw IllegalStateException("Plugin not attached: textureRegistry == null")

        val playerId = nextPlayerId++
        val producer = registry.createSurfaceProducer()
        val textureId = producer.id()

        val player = FluxoraExoPlayer(
            playerId = playerId,
            context = context,
            surfaceProducer = producer,
            plugin = this,
        )
        players[playerId] = player
        // Newest player wins the MediaSession slot.  The actual bind
        // to the MediaSession happens later, after the player has
        // called prepare() (see FluxoraExoPlayer.open) — at this
        // point there's no MediaItem yet, so attaching a session
        // would produce a notification with no title.  We just record
        // the id so [activeSessionPlayer] can look the player up if
        // the service needs it.
        currentSessionPlayerId = playerId

        Log.i(TAG, "create — playerId=$playerId textureId=$textureId")
        result.success(
            mapOf(
                "playerId" to playerId,
                "textureId" to textureId.toInt(),
            ),
        )
    }

    private fun handleOpen(call: MethodCall, result: MethodChannel.Result) {
        val player = requirePlayer(call)
        val url = call.argument<String>("url")
            ?: throw IllegalArgumentException("Missing 'url' argument")
        @Suppress("UNCHECKED_CAST")
        val headers = call.argument<Map<String, String>>("headers")
        val play = call.argument<Boolean>("play") ?: true
        val startPositionMs = (call.argument<Number>("startPositionMs") ?: 0).toLong()

        player.open(url = url, headers = headers, play = play, startPositionMs = startPositionMs)
        result.success(emptyMap<String, Any>())
    }

    private fun handlePlay(call: MethodCall, result: MethodChannel.Result) {
        requirePlayer(call).play()
        result.success(emptyMap<String, Any>())
    }

    private fun handlePause(call: MethodCall, result: MethodChannel.Result) {
        requirePlayer(call).pause()
        result.success(emptyMap<String, Any>())
    }

    private fun handleSeek(call: MethodCall, result: MethodChannel.Result) {
        val positionMs = (call.argument<Number>("positionMs")
            ?: throw IllegalArgumentException("Missing 'positionMs' argument")).toLong()
        requirePlayer(call).seek(positionMs)
        result.success(emptyMap<String, Any>())
    }

    private fun handleSetAudioTrack(call: MethodCall, result: MethodChannel.Result) {
        val sourceIndex = call.argument<Int>("sourceIndex")
            ?: throw IllegalArgumentException("Missing 'sourceIndex' argument")
        requirePlayer(call).setAudioTrack(sourceIndex)
        result.success(emptyMap<String, Any>())
    }

    private fun handleSetRate(call: MethodCall, result: MethodChannel.Result) {
        val rate = (call.argument<Number>("rate")
            ?: throw IllegalArgumentException("Missing 'rate' argument")).toDouble()
        requirePlayer(call).setRate(rate)
        result.success(emptyMap<String, Any>())
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        val volume = (call.argument<Number>("volume0to1")
            ?: throw IllegalArgumentException("Missing 'volume0to1' argument")).toDouble()
        requirePlayer(call).setVolume(volume)
        result.success(emptyMap<String, Any>())
    }

    private fun handleSetMetadata(call: MethodCall, result: MethodChannel.Result) {
        // title is optional — null clears back to the default ("Fluxora").
        val title = call.argument<String?>("title")
        requirePlayer(call).setMetadata(title)
        result.success(emptyMap<String, Any>())
    }

    private fun handleDispose(call: MethodCall, result: MethodChannel.Result) {
        val playerId = call.argument<Int>("playerId")
            ?: throw IllegalArgumentException("Missing 'playerId' argument")
        val player = players.remove(playerId)
        if (player == null) {
            if (disposedIds.contains(playerId)) {
                throw IllegalStateException("Player $playerId has been disposed")
            }
            throw IllegalStateException("Player $playerId does not exist")
        }
        try {
            player.release()
        } catch (t: Throwable) {
            Log.e(TAG, "dispose — release threw for playerId=$playerId", t)
        }
        disposedIds.add(playerId)
        // Clear the slot if the disposed player was the active one.
        // [FluxoraExoPlayer.release] above already called
        // [FluxoraMediaSessionService.unbind] so the OS session is
        // gone; we just track the bookkeeping locally.
        if (currentSessionPlayerId == playerId) {
            currentSessionPlayerId = null
        }
        Log.i(TAG, "dispose — playerId=$playerId released")
        result.success(emptyMap<String, Any>())
    }

    /**
     * Look up the [FluxoraExoPlayer] for the playerId in [call] or throw.
     * Already-disposed ids throw with a clear message (per channel
     * contract).
     */
    private fun requirePlayer(call: MethodCall): FluxoraExoPlayer {
        val playerId = call.argument<Int>("playerId")
            ?: throw IllegalArgumentException("Missing 'playerId' argument")
        val player = players[playerId]
        if (player != null) return player
        if (disposedIds.contains(playerId)) {
            throw IllegalStateException("Player $playerId has been disposed")
        }
        throw IllegalStateException("Player $playerId does not exist; call create() first")
    }

    private fun releaseAllPlayers() {
        val snapshot = players.values.toList()
        players.clear()
        for (p in snapshot) {
            try {
                p.release()
            } catch (t: Throwable) {
                Log.e(TAG, "releaseAllPlayers — release threw", t)
            }
        }
    }
}
