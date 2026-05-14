package dev.marshalx.fluxora_mobile

import android.app.PictureInPictureParams
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServicePlugin
import dev.marshalx.fluxora_mobile.exo.ExoPlayerPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Player polish round (2026-05-04):
// - `FlutterFragmentActivity` (vs `FlutterActivity`) gives us fragment
//   hosting if any future plugin needs it.  Drop-in replacement otherwise.
// - `provideFlutterEngine` is overridden to return the engine cached by
//   `AudioServicePlugin` (`AudioService.getFlutterEngine`).  The plugin's
//   foreground service spins up its own engine on background-restart and
//   needs the activity to share the same instance — without this override,
//   `AudioService.init` throws
//   "The Activity class declared in your AndroidManifest.xml is wrong or
//    has not provided the correct FlutterEngine" at app start.  This is the
//   same hook `AudioServiceActivity` (provided by the package) installs;
//   inlining it here keeps us extending FlutterFragmentActivity directly.
class MainActivity : FlutterFragmentActivity() {

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }


    private var multicastLock: WifiManager.MulticastLock? = null

    // Plan 24 M1 — ExoPlayer spike plugin held for lifecycle parity with
    // the Activity.  Attached during configureFlutterEngine so it owns
    // its MethodChannel before any Dart code can call it; detached in
    // onDestroy so the SurfaceProducer + ExoPlayer release cleanly when
    // the Activity tears down (e.g. user backgrounds for long enough to
    // hit Android's process trim).  M4 moves this to plugin auto-
    // registration once we add the standard FlutterPlugin entry point.
    private var exoPlayerPlugin: ExoPlayerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── ExoPlayer spike (Plan 24 M1) ─────────────────────────────────────
        // Manual registration so the plugin can read the engine's
        // BinaryMessenger + TextureRegistry without us spinning up the
        // full FlutterPlugin auto-discovery path (which would require
        // an entry under META-INF or a plugin manifest).  Same approach
        // the multicast + PIP channels above use.
        exoPlayerPlugin = ExoPlayerPlugin().also {
            it.attachToEngine(
                applicationContext,
                flutterEngine.dartExecutor.binaryMessenger,
                flutterEngine.renderer,
            )
        }

        // ── mDNS multicast lock ─────────────────────────────────────────────
        // Phase 1 server-discovery support (existing).  ConnectCubit acquires
        // before scanning, releases on close — Android 12+ silently drops
        // multicast packets without WifiManager.MulticastLock.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.marshalx.fluxora/multicast",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    val wifiManager =
                        applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                    multicastLock =
                        wifiManager.createMulticastLock("fluxora_mdns").also {
                            it.setReferenceCounted(true)
                            it.acquire()
                        }
                    result.success(null)
                }
                "release" -> {
                    multicastLock?.takeIf { it.isHeld }?.release()
                    multicastLock = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Picture-in-Picture ──────────────────────────────────────────────
        // Player polish round (2026-05-04).  Dart side posts the source
        // video's intrinsic width/height — we wrap that in a Rational and
        // hand it to the system's PIP API.  Aspect ratios outside Android's
        // accepted range (≈[0.4, 2.4]) are clamped to a safe value so the
        // call never throws.  Pre-Android 8.0 has no PIP at all; we report
        // unsupported so the Dart layer can hide the button.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.marshalx.fluxora/pip",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> {
                    result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(
                                android.content.pm.PackageManager
                                    .FEATURE_PICTURE_IN_PICTURE,
                            ),
                    )
                }
                "enter" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.error(
                            "UNSUPPORTED",
                            "Picture-in-Picture requires Android 8.0+",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    val width = (call.argument<Int>("width") ?: 16).coerceAtLeast(1)
                    val height = (call.argument<Int>("height") ?: 9).coerceAtLeast(1)
                    val ratio = clampPipAspect(width, height)
                    val params = PictureInPictureParams.Builder()
                        .setAspectRatio(ratio)
                        .build()
                    val ok = enterPictureInPictureMode(params)
                    result.success(ok)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Android rejects PIP aspect ratios outside roughly [1:2.39, 2.39:1].
     * Source video can be much wider (anamorphic 21:9) or taller (mobile
     * portrait 9:16) than that.  Clamp before calling the system API.
     */
    private fun clampPipAspect(width: Int, height: Int): Rational {
        val raw = width.toDouble() / height.toDouble()
        // Android 11+ accepts up to 2.39:1; older versions are stricter.
        // Use the safer bounds so the same code works back to API 26.
        val min = 1.0 / 2.39
        val max = 2.39
        val clamped = raw.coerceIn(min, max)
        // Convert back to a small Rational — large numerator/denominator
        // values trigger ArithmeticException in Rational.parseRational,
        // and the system rounds anyway.
        val num = (clamped * 1000).toInt().coerceAtLeast(1)
        val den = 1000
        return Rational(num, den)
    }

    override fun onDestroy() {
        multicastLock?.takeIf { it.isHeld }?.release()
        // Plan 24 M1 — release ExoPlayer + SurfaceProducer when the
        // Activity is destroyed so the Surface doesn't outlive the
        // engine's renderer.  Without this the spike can leak a
        // MediaCodec instance after every player exit on debug builds.
        exoPlayerPlugin?.let {
            try {
                it.onMethodCall(
                    io.flutter.plugin.common.MethodCall("dispose", null),
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {}
                        override fun error(code: String, message: String?, details: Any?) {}
                        override fun notImplemented() {}
                    },
                )
            } catch (_: Throwable) {
                // Best-effort teardown — the Activity is going away.
            }
        }
        exoPlayerPlugin = null
        super.onDestroy()
    }
}
