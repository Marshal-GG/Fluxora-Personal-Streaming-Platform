package dev.marshalx.fluxora_mobile.exo

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackGroup
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import io.flutter.view.TextureRegistry
import java.io.IOException

/**
 * Plan 24 M4 — per-player wrapper around a single Media3 [ExoPlayer].
 *
 * One instance owns:
 *   - the [ExoPlayer] itself,
 *   - the Flutter [TextureRegistry.SurfaceProducer] it renders into,
 *   - the [Player.Listener] that emits events back to the [plugin],
 *   - the ~250 ms position ticker that self-rearms while playing.
 *
 * Multiple instances are managed by [ExoPlayerPlugin]'s player map; they
 * share the plugin's single EventChannel and demultiplex on the
 * `playerId` field every payload carries.
 */
internal class FluxoraExoPlayer(
    private val playerId: Int,
    context: Context,
    private val surfaceProducer: TextureRegistry.SurfaceProducer,
    private val plugin: ExoPlayerPlugin,
) {

    companion object {
        private const val TAG = "FluxoraExoPlayer"
        private const val POSITION_TICK_MS = 250L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private val player: ExoPlayer = ExoPlayer.Builder(context.applicationContext)
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
        }

    /** Mapping populated from the most-recent `onTracksChanged`.
     *  source-stream index → (audio TrackGroup, formatIndex within it). */
    private var audioTrackMap: Map<Int, AudioTrackHandle> = emptyMap()

    private var lastEmittedDurationMs: Long = C.TIME_UNSET
    private var lastEmittedIsPlaying: Boolean? = null
    private var lastEmittedState: Int = -1
    private var released: Boolean = false

    /** Position-tick runnable.  Self-rearming via [mainHandler] while
     *  [Player.isPlaying] reports true; cancelled on pause/stop/release. */
    private val positionTicker: Runnable = object : Runnable {
        override fun run() {
            if (released) return
            if (player.isPlaying) {
                emitPosition()
                mainHandler.postDelayed(this, POSITION_TICK_MS)
            }
        }
    }

    init {
        player.addListener(EngineListener())
        // SurfaceProducer can recreate its underlying Surface across the
        // app lifecycle — Flutter releases native surfaces when the
        // engine is detached or trimmed (rotation, PIP entry/exit,
        // backgrounding past Android's trim threshold).  Bind to
        // ExoPlayer on every (re-)creation; clear it on destruction so
        // the player doesn't keep a stale Surface reference.
        surfaceProducer.setCallback(
            object : TextureRegistry.SurfaceProducer.Callback {
                override fun onSurfaceCreated() {
                    if (released) return
                    Log.d(TAG, "playerId=$playerId onSurfaceCreated — binding to player")
                    try {
                        player.setVideoSurface(surfaceProducer.surface)
                    } catch (t: Throwable) {
                        Log.w(TAG, "playerId=$playerId onSurfaceCreated — setVideoSurface threw", t)
                    }
                }

                override fun onSurfaceDestroyed() {
                    if (released) return
                    Log.d(TAG, "playerId=$playerId onSurfaceDestroyed — clearing surface")
                    try {
                        player.clearVideoSurface()
                    } catch (t: Throwable) {
                        Log.w(TAG, "playerId=$playerId onSurfaceDestroyed — clearVideoSurface threw", t)
                    }
                }
            },
        )
        // Bind the initial surface if it's already available — the M1
        // spike confirmed this is the common case at construction time.
        val initialSurface = surfaceProducer.surface
        if (initialSurface != null) {
            try {
                player.setVideoSurface(initialSurface)
            } catch (t: Throwable) {
                Log.w(TAG, "playerId=$playerId init — initial setVideoSurface threw", t)
            }
        }
    }

    // ── Commands ─────────────────────────────────────────────────────────────

    fun open(url: String, headers: Map<String, String>?, play: Boolean, startPositionMs: Long) {
        ensureAlive()
        // Header keys only — values may contain Authorization: Bearer
        // tokens which must never reach logcat (Hard Prohibition #8).
        val headerKeys = headers?.keys?.toString() ?: "<none>"
        Log.i(
            TAG,
            "playerId=$playerId open — startPositionMs=$startPositionMs play=$play " +
                "headerKeys=$headerKeys",
        )

        val httpFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
        if (!headers.isNullOrEmpty()) {
            httpFactory.setDefaultRequestProperties(headers)
        }

        val mediaSource = HlsMediaSource.Factory(httpFactory)
            .createMediaSource(MediaItem.fromUri(Uri.parse(url)))

        mainHandler.post {
            if (released) return@post
            try {
                player.stop()
                player.clearMediaItems()
                player.setMediaSource(mediaSource)
                player.prepare()
                if (startPositionMs > 0L) {
                    player.seekTo(startPositionMs)
                }
                player.playWhenReady = play
            } catch (t: Throwable) {
                Log.e(TAG, "playerId=$playerId open — failed to start playback", t)
                plugin.sendEvent(
                    mapOf(
                        "playerId" to playerId,
                        "type" to "playerError",
                        "errorCode" to "unknown",
                        "message" to (t.message ?: t::class.java.simpleName),
                    ),
                )
            }
        }
    }

    fun play() {
        ensureAlive()
        mainHandler.post {
            if (released) return@post
            player.playWhenReady = true
            player.play()
        }
    }

    fun pause() {
        ensureAlive()
        mainHandler.post {
            if (released) return@post
            player.pause()
        }
    }

    fun seek(positionMs: Long) {
        ensureAlive()
        mainHandler.post {
            if (released) return@post
            try {
                player.seekTo(positionMs)
            } catch (t: Throwable) {
                Log.w(TAG, "playerId=$playerId seek — seekTo threw", t)
            }
        }
    }

    /**
     * Switch audio rendition by source-stream index, where `sourceIndex`
     * comes from the FFmpeg stream ordering the rest of the codebase
     * uses.  The mapping was populated by the most recent
     * `onTracksChanged` callback.
     */
    fun setAudioTrack(sourceIndex: Int) {
        ensureAlive()
        val handle = audioTrackMap[sourceIndex]
        if (handle == null) {
            Log.w(
                TAG,
                "playerId=$playerId setAudioTrack — unknown sourceIndex=$sourceIndex " +
                    "known=${audioTrackMap.keys}",
            )
            return
        }
        mainHandler.post {
            if (released) return@post
            try {
                val override = TrackSelectionOverride(handle.group, handle.formatIndex)
                player.trackSelectionParameters = player.trackSelectionParameters
                    .buildUpon()
                    .setOverrideForType(override)
                    .build()
                Log.i(
                    TAG,
                    "playerId=$playerId setAudioTrack — applied sourceIndex=$sourceIndex " +
                        "formatIndex=${handle.formatIndex}",
                )
            } catch (t: Throwable) {
                Log.w(TAG, "playerId=$playerId setAudioTrack — failed", t)
            }
        }
    }

    fun setRate(rate: Double) {
        ensureAlive()
        val safeRate = rate.coerceIn(0.25, 4.0).toFloat()
        mainHandler.post {
            if (released) return@post
            try {
                player.playbackParameters = PlaybackParameters(safeRate)
            } catch (t: Throwable) {
                Log.w(TAG, "playerId=$playerId setRate — failed rate=$rate", t)
            }
        }
    }

    fun setVolume(volume0to1: Double) {
        ensureAlive()
        val safe = volume0to1.coerceIn(0.0, 1.0).toFloat()
        mainHandler.post {
            if (released) return@post
            try {
                player.volume = safe
            } catch (t: Throwable) {
                Log.w(TAG, "playerId=$playerId setVolume — failed volume=$volume0to1", t)
            }
        }
    }

    fun release() {
        if (released) return
        released = true
        Log.i(TAG, "playerId=$playerId release — tearing down")
        mainHandler.removeCallbacks(positionTicker)
        try {
            player.release()
        } catch (t: Throwable) {
            Log.e(TAG, "playerId=$playerId release — ExoPlayer.release threw", t)
        }
        try {
            surfaceProducer.release()
        } catch (t: Throwable) {
            Log.e(TAG, "playerId=$playerId release — SurfaceProducer.release threw", t)
        }
    }

    private fun ensureAlive() {
        if (released) {
            throw IllegalStateException("Player $playerId has been disposed")
        }
    }

    // ── Listener + emission helpers ──────────────────────────────────────────

    private inner class EngineListener : Player.Listener {

        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == lastEmittedState) return
            lastEmittedState = playbackState
            val name = when (playbackState) {
                Player.STATE_IDLE -> "idle"
                Player.STATE_BUFFERING -> "buffering"
                Player.STATE_READY -> "ready"
                Player.STATE_ENDED -> "ended"
                else -> "idle"
            }
            Log.d(TAG, "playerId=$playerId onPlaybackStateChanged state=$name")
            plugin.sendEvent(
                mapOf(
                    "playerId" to playerId,
                    "type" to "playbackStateChanged",
                    "state" to name,
                ),
            )

            // Duration becomes valid once the player reaches READY.
            if (playbackState == Player.STATE_READY) {
                val dur = player.duration
                if (dur != C.TIME_UNSET && dur != lastEmittedDurationMs) {
                    lastEmittedDurationMs = dur
                    plugin.sendEvent(
                        mapOf(
                            "playerId" to playerId,
                            "type" to "durationChanged",
                            "durationMs" to dur,
                        ),
                    )
                }
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (lastEmittedIsPlaying == isPlaying) return
            lastEmittedIsPlaying = isPlaying
            Log.d(TAG, "playerId=$playerId onIsPlayingChanged isPlaying=$isPlaying")
            plugin.sendEvent(
                mapOf(
                    "playerId" to playerId,
                    "type" to "isPlayingChanged",
                    "isPlaying" to isPlaying,
                ),
            )

            mainHandler.removeCallbacks(positionTicker)
            if (isPlaying) {
                // Emit one now, then self-rearm every 250 ms.
                emitPosition()
                mainHandler.postDelayed(positionTicker, POSITION_TICK_MS)
            }
        }

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            Log.d(
                TAG,
                "playerId=$playerId onPositionDiscontinuity reason=$reason " +
                    "old=${oldPosition.positionMs}ms new=${newPosition.positionMs}ms",
            )
            // Emit a one-shot position so the scrubber jumps immediately
            // rather than waiting for the next 250 ms tick.
            plugin.sendEvent(
                mapOf(
                    "playerId" to playerId,
                    "type" to "positionChanged",
                    "positionMs" to newPosition.positionMs,
                ),
            )
        }

        override fun onTracksChanged(tracks: Tracks) {
            val mapping = buildAudioTrackMapping(tracks)
            audioTrackMap = mapping.handles
            Log.i(
                TAG,
                "playerId=$playerId onTracksChanged — audioTracks=${mapping.descriptors.size} " +
                    "selected=${mapping.selectedSourceIndex}",
            )
            plugin.sendEvent(
                mapOf(
                    "playerId" to playerId,
                    "type" to "tracksChanged",
                    "audioTracks" to mapping.descriptors,
                    "selectedAudioSourceIndex" to mapping.selectedSourceIndex,
                ),
            )
        }

        override fun onPlayerError(error: PlaybackException) {
            val errorCode = mapPlayerErrorCode(error)
            Log.e(
                TAG,
                "playerId=$playerId onPlayerError mappedCode=$errorCode " +
                    "exoCode=${error.errorCodeName} exoMessage=${error.message}",
                error,
            )
            plugin.sendEvent(
                mapOf(
                    "playerId" to playerId,
                    "type" to "playerError",
                    "errorCode" to errorCode,
                    "message" to (error.message ?: error.errorCodeName),
                ),
            )
        }
    }

    private fun emitPosition() {
        val pos = try {
            player.currentPosition
        } catch (t: Throwable) {
            Log.w(TAG, "playerId=$playerId emitPosition — currentPosition threw", t)
            return
        }
        plugin.sendEvent(
            mapOf(
                "playerId" to playerId,
                "type" to "positionChanged",
                "positionMs" to pos,
            ),
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure helpers — exposed at the package level so JUnit can hit them without
// instantiating a full ExoPlayer (Media3 instances aren't constructible in a
// host-JVM unit test).
// ─────────────────────────────────────────────────────────────────────────────

/** Lookup record into the audio-track tables built from [Tracks]. */
internal data class AudioTrackHandle(val group: TrackGroup, val formatIndex: Int)

/**
 * Result of [buildAudioTrackMapping]:
 *  - [descriptors]: serialisable maps emitted on the `tracksChanged`
 *    event; one per audio [Format] across every audio [TrackGroup].
 *  - [handles]: source-index → ([TrackGroup], formatIndex) lookup the
 *    `setAudioTrack` command uses to build a [TrackSelectionOverride].
 *  - [selectedSourceIndex]: source-stream index of the currently
 *    selected audio track, or `null` if no audio track is selected.
 */
internal data class AudioMappingResult(
    val descriptors: List<Map<String, Any?>>,
    val handles: Map<Int, AudioTrackHandle>,
    val selectedSourceIndex: Int?,
)

/**
 * Walk a [Tracks] tree, pick out every audio [Format] across every
 * audio [TrackGroup], and assign each a source-stream index using
 * either the `Format.label` (if it parses as a non-negative integer
 * ordinal — that's how plan 22's server-side multiplexing labels its
 * audio tracks) or a positional fallback across all audio groups.
 *
 * Pure function so it's unit-testable on the host JVM without a real
 * ExoPlayer.  See `FluxoraExoPlayerTest`.
 */
internal fun buildAudioTrackMapping(tracks: Tracks): AudioMappingResult {
    val descriptors = mutableListOf<Map<String, Any?>>()
    val handles = mutableMapOf<Int, AudioTrackHandle>()
    var selectedSourceIndex: Int? = null
    var positionalFallback = 0

    for (group in tracks.groups) {
        if (group.type != C.TRACK_TYPE_AUDIO) continue
        for (formatIndex in 0 until group.length) {
            val format = group.getTrackFormat(formatIndex)
            val sourceIndex = parseSourceIndex(format.label) ?: positionalFallback
            positionalFallback++

            val codec = format.codecs ?: format.sampleMimeType
            val descriptor = mapOf(
                "sourceIndex" to sourceIndex,
                "language" to format.language,
                "label" to format.label,
                "channels" to format.channelCount.takeIf { it != Format.NO_VALUE },
                "codec" to codec,
            )
            descriptors.add(descriptor)
            handles[sourceIndex] = AudioTrackHandle(group.mediaTrackGroup, formatIndex)

            if (group.isTrackSelected(formatIndex)) {
                selectedSourceIndex = sourceIndex
            }
        }
    }

    return AudioMappingResult(
        descriptors = descriptors,
        handles = handles,
        selectedSourceIndex = selectedSourceIndex,
    )
}

/**
 * The server tags multiplexed audio renditions with a `LABEL` that's
 * either the literal stream-source index (`"0"`, `"1"`, …) or a human
 * name.  Try to parse the integer form; fall back to positional
 * ordering otherwise.
 */
internal fun parseSourceIndex(label: String?): Int? {
    if (label.isNullOrBlank()) return null
    return label.trim().toIntOrNull()?.takeIf { it >= 0 }
}

/**
 * Map a Media3 [PlaybackException] to one of the documented engine
 * error codes the Dart side expects:
 *
 *   "auth_failed", "network_error", "decoder_failed",
 *   "format_unsupported", "unknown"
 */
internal fun mapPlayerErrorCode(error: PlaybackException): String {
    val cause = error.cause
    if (cause is HttpDataSource.InvalidResponseCodeException) {
        return if (cause.responseCode == 401 || cause.responseCode == 403) {
            "auth_failed"
        } else {
            "network_error"
        }
    }
    if (cause is HttpDataSource.HttpDataSourceException || cause is IOException) {
        return "network_error"
    }
    return when (error.errorCode) {
        PlaybackException.ERROR_CODE_DECODER_INIT_FAILED,
        PlaybackException.ERROR_CODE_DECODER_QUERY_FAILED,
        PlaybackException.ERROR_CODE_DECODING_FAILED,
        PlaybackException.ERROR_CODE_DECODING_FORMAT_EXCEEDS_CAPABILITIES,
        PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED,
        -> "decoder_failed"

        PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED,
        PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED,
        PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED,
        PlaybackException.ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED,
        PlaybackException.ERROR_CODE_UNSPECIFIED,
        -> "format_unsupported"

        PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS,
        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT,
        PlaybackException.ERROR_CODE_IO_UNSPECIFIED,
        // DNS-failure codepoint was introduced in a later Media3
        // release; DNS errors land in NETWORK_CONNECTION_FAILED on
        // 1.10.1 so they still map to "network_error" via the line
        // above.
        -> "network_error"

        else -> "unknown"
    }
}
