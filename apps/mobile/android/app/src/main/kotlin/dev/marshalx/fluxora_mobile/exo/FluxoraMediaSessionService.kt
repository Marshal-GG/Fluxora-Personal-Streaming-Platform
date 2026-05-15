package dev.marshalx.fluxora_mobile.exo

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Media3 [MediaSessionService] that owns the OS-facing [MediaSession]
 * for the Android-ExoPlayer playback path.
 *
 * Replaces the Dart-side `FluxoraAudioHandler` binding when
 * [FluxoraExoPlayer] (Media3) is the engine.  The `audio_service` Dart
 * plugin stays in the codebase because the desktop / iOS / Android
 * rollback (`_kForceMediaKitOnAndroid = true`) paths still drive playback
 * via libmpv-`media_kit` and rely on the Dart-side bridge.  See the
 * `engine is MediaKitEngine` guard in `player_cubit.dart`.
 *
 * ## Lifecycle
 *
 * Driven by [bind] / [unbind] in the companion object, both called from
 * [FluxoraExoPlayer]:
 *
 *  - On `open()`-after-`prepare()` the plugin calls [bind] to attach the
 *    OS MediaSession to the active [ExoPlayer].  First [bind] starts the
 *    service via `startService(..)`; subsequent [bind] calls on a running
 *    service swap the session's player in-place.
 *  - On per-player `release()` the plugin calls [unbind] which releases
 *    the [MediaSession] (NOT the underlying [ExoPlayer] — that belongs
 *    to the plugin).
 *
 * Media3 owns notification + foreground-service handling automatically
 * once a session is built; we never post a notification ourselves.
 *
 * ## Threading
 *
 * Every interaction with [MediaSession] / [ExoPlayer] happens on the
 * main thread — [FluxoraExoPlayer] already routes commands through a
 * main-looper [android.os.Handler], and Service lifecycle callbacks
 * (`onCreate`, `onDestroy`, `onTaskRemoved`) run on the main thread
 * as well.  The companion uses [LOCK] to serialise reads / writes of
 * the shared `activeService` + `pendingPlayer` references across the
 * brief window between [bind]'s static record and [onCreate]'s pickup.
 */
class FluxoraMediaSessionService : MediaSessionService() {

    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate — service spinning up")
        synchronized(LOCK) {
            activeService = this
            val pending = pendingPlayer
            pendingPlayer = null
            if (pending != null) {
                attachSessionLocked(pending)
            } else {
                Log.w(
                    TAG,
                    "onCreate — no pending player; session will attach on next bind()",
                )
            }
        }
    }

    /**
     * Build and store a fresh [MediaSession] over the given player.
     * Releases any previously attached session first so the OS sees a
     * clean handoff.  Caller must hold [LOCK].
     */
    private fun attachSessionLocked(player: ExoPlayer) {
        releaseSessionLocked()
        try {
            val builder = MediaSession.Builder(this, player)
            val sessionActivity = buildSessionActivityIntent()
            if (sessionActivity != null) {
                builder.setSessionActivity(sessionActivity)
            }
            mediaSession = builder.build()
            Log.i(TAG, "attachSession — session attached to player=${player.hashCode()}")
        } catch (t: Throwable) {
            Log.e(TAG, "attachSession — MediaSession.Builder threw", t)
        }
    }

    private fun releaseSessionLocked() {
        mediaSession?.let { session ->
            try {
                session.release()
            } catch (t: Throwable) {
                Log.w(TAG, "releaseSession — MediaSession.release threw", t)
            }
        }
        mediaSession = null
    }

    /**
     * Tapping the lockscreen / notification card should bring the
     * Fluxora player screen forward.  We can't reach Flutter routes
     * from a service, but resolving the LAUNCHER intent for our own
     * package brings the user back to the already-running MainActivity
     * (`launchMode="singleTop"`).
     */
    private fun buildSessionActivityIntent(): PendingIntent? {
        return try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                Log.w(TAG, "buildSessionActivityIntent — no LAUNCHER for $packageName")
                return null
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
            PendingIntent.getActivity(
                this,
                /* requestCode = */ 0,
                launchIntent,
                flags,
            )
        } catch (e: PackageManager.NameNotFoundException) {
            Log.w(TAG, "buildSessionActivityIntent — package not found", e)
            null
        } catch (t: Throwable) {
            Log.w(TAG, "buildSessionActivityIntent — failed", t)
            null
        }
    }

    /**
     * Swap the session's underlying player.  Used when a second
     * [FluxoraExoPlayer] binds (operator navigated to a new file while
     * a previous session was still alive).  The previous session is
     * released; the previous [ExoPlayer] is NOT released — that's the
     * plugin's job.
     */
    internal fun swapPlayer(player: ExoPlayer) {
        synchronized(LOCK) {
            attachSessionLocked(player)
        }
    }

    /**
     * Drop the current session without stopping the service.  Media3
     * removes the lockscreen card on its own once `onGetSession` starts
     * returning null.
     */
    internal fun detachSession() {
        synchronized(LOCK) {
            releaseSessionLocked()
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // AOSP guidance for `MediaSessionService`: if the operator swipes
        // the app from recents and nothing is actively playing, drop the
        // service so the foreground notification clears.  See
        // developer.android.com/media/media3/session/background-playback.
        val player = mediaSession?.player
        if (player == null || !player.playWhenReady || player.mediaItemCount == 0) {
            stopSelf()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy — releasing session (player owned by plugin)")
        synchronized(LOCK) {
            releaseSessionLocked()
            if (activeService === this) {
                activeService = null
            }
            pendingPlayer = null
        }
        super.onDestroy()
    }

    companion object {
        private const val TAG = "FluxoraMediaSession"

        /** Tracks the live service instance.  Guarded by [LOCK]. */
        @Volatile
        private var activeService: FluxoraMediaSessionService? = null

        /**
         * Player handed in via [bind] BEFORE the service finished
         * spinning up.  Consumed by [onCreate].  Cleared once attached
         * or once the service tears down.  Guarded by [LOCK].
         */
        @Volatile
        private var pendingPlayer: ExoPlayer? = null

        private val LOCK = Any()

        /**
         * Attach a freshly-prepared [ExoPlayer] to the OS [MediaSession].
         *
         * Called from [FluxoraExoPlayer.open] right after `prepare()`.
         *
         * Idempotent across:
         *  - first call (starts the service, queues the player, attaches
         *    in `onCreate`).
         *  - subsequent call with same player (no-op).
         *  - subsequent call with different player (swaps in place; no
         *    second service started).
         *  - calls preceded by [unbind] (re-attaches cleanly).
         */
        @JvmStatic
        fun bind(context: Context, player: ExoPlayer) {
            val needsStart: Boolean
            synchronized(LOCK) {
                val service = activeService
                if (service != null) {
                    if (service.mediaSession?.player === player) {
                        Log.d(TAG, "bind — same player already attached; no-op")
                        return
                    }
                    Log.i(TAG, "bind — swapping player on running service")
                    service.swapPlayer(player)
                    return
                }
                Log.i(TAG, "bind — queueing player for service onCreate")
                pendingPlayer = player
                needsStart = true
            }
            if (needsStart) {
                try {
                    val intent = Intent(
                        context.applicationContext,
                        FluxoraMediaSessionService::class.java,
                    )
                    context.applicationContext.startService(intent)
                } catch (t: Throwable) {
                    Log.e(TAG, "bind — startService threw", t)
                    synchronized(LOCK) {
                        pendingPlayer = null
                    }
                }
            }
        }

        /**
         * Detach the current session.  Safe to call when no session is
         * bound — every step is null-guarded.  Does NOT release the
         * underlying [ExoPlayer]; the plugin's `release()` owns that.
         */
        @JvmStatic
        fun unbind() {
            synchronized(LOCK) {
                pendingPlayer = null
                val service = activeService
                if (service == null) {
                    Log.d(TAG, "unbind — no active service; no-op")
                    return
                }
                service.detachSession()
            }
        }

        /**
         * Apply lightweight [MediaMetadata] to the active session so the
         * lockscreen / notification show something recognisable.  Called
         * from [FluxoraExoPlayer.open] after the player has the title.
         *
         * Empty / null title falls back to "Fluxora" — the OS rejects
         * an empty title outright and we'd rather show the app name
         * than a blank card.
         *
         * NEVER include the playlist URL or any HTTP header value here:
         * URLs embed bearer-tokenised query paths on some code paths,
         * and Hard Prohibition #8 forbids logging or exposing those
         * values.
         */
        @JvmStatic
        fun applyMetadata(title: String?) {
            val safeTitle = title?.trim().orEmpty().ifEmpty { "Fluxora" }
            synchronized(LOCK) {
                val session = activeService?.mediaSession
                if (session == null) {
                    Log.d(TAG, "applyMetadata — no active session; skipping")
                    return
                }
                val player = session.player
                val metadata = MediaMetadata.Builder()
                    .setTitle(safeTitle)
                    .setArtist("Fluxora")
                    .build()
                try {
                    val currentItem: MediaItem? = player.currentMediaItem
                    val rebuilt: MediaItem? = currentItem
                        ?.buildUpon()
                        ?.setMediaMetadata(metadata)
                        ?.build()
                    if (rebuilt != null) {
                        player.replaceMediaItem(
                            player.currentMediaItemIndex,
                            rebuilt,
                        )
                    } else {
                        Log.d(
                            TAG,
                            "applyMetadata — player has no current MediaItem yet; skipping",
                        )
                    }
                } catch (t: Throwable) {
                    Log.w(TAG, "applyMetadata — replaceMediaItem threw", t)
                }
            }
        }

        /**
         * Test-only: clear the static state so JUnit tests don't leak
         * state across runs.  Production code never calls this.
         */
        @JvmStatic
        internal fun resetForTesting() {
            synchronized(LOCK) {
                pendingPlayer = null
                activeService = null
            }
        }
    }
}
