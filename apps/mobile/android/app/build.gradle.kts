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

// Media3 ExoPlayer — Google's first-party HLS engine; the Android
// default playback backend.  Desktop + iOS stay on `media_kit`
// (libmpv / AVPlayer).  Version skew within the media3 family is
// unsafe (shared internal AIDL), so every media3 artefact is pinned
// to the same version.
//
// Artefacts:
//   - media3-exoplayer        — core Player + DefaultRenderersFactory
//   - media3-exoplayer-hls    — HlsMediaSource + HLS playlist parser
//   - media3-ui               — PlayerView (kept for future subtitle
//                                rendering on the Kotlin side)
//   - media3-session          — MediaSession + MediaSessionService for
//                                lockscreen / notification / Bluetooth-
//                                headset transport.  Replaces the
//                                audio_service Dart-side binding when
//                                the ExoPlayerEngine owns playback.
dependencies {
    val media3Version = "1.10.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-ui:$media3Version")
    implementation("androidx.media3:media3-session:$media3Version")

    // JUnit unit tests for the rendition→source-index mapping helper
    // in FluxoraExoPlayer.  Host-JVM only; we don't mock the full
    // ExoPlayer — the tests exercise pure helper functions over
    // Media3's public Format/TrackGroup/Tracks types which are
    // already on the implementation classpath.
    testImplementation("junit:junit:4.13.2")
}
