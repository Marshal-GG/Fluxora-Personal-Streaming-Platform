plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.marshalx.fluxora_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.marshalx.fluxora_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Plan 24 — Android playback migration to Media3 ExoPlayer.
//
// `media_kit` (libmpv-on-Android) shipped two unfixable defects on real
// devices: mid-stream `setAudioTrack` hung the player when the HLS fmp4
// init/segment contract changed, and HDR multi-audio sources played
// silent.  Media3 is Google's first-party HLS engine (the one Plex,
// Jellyfin, Netflix, YouTube and every modern Android video product
// ships) and replaces the libmpv path on Android only — desktop + iOS
// stay on media_kit per Plan 24 §D1.  Version pinned to the latest
// stable at the time of M1 (1.10.1, released 2026-05-12) per
// developer.android.com/jetpack/androidx/releases/media3.
//
// Three artefacts are required for M1's HLS playback spike:
//   - media3-exoplayer        — core Player + DefaultRenderersFactory
//   - media3-exoplayer-hls    — HlsMediaSource + HLS playlist parser
//   - media3-ui               — PlayerView (kept for future surface +
//                                subtitle rendering — see Plan 24 M9
//                                open-question on Kotlin-side subtitles)
dependencies {
    val media3Version = "1.10.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-ui:$media3Version")
}
