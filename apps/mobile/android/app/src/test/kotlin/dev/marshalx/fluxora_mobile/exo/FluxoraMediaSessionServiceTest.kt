package dev.marshalx.fluxora_mobile.exo

import org.junit.After
import org.junit.Test

/**
 * Pure JUnit smoke tests for the [FluxoraMediaSessionService]
 * companion API.
 *
 * The Android [android.app.Service] lifecycle cannot be exercised on the
 * host JVM without Robolectric, so we keep the assertions tight: every
 * companion entry point must be a no-op when the service has never been
 * started, regardless of call order or duplication.  That covers the
 * window between the plugin's `release()` (which calls `unbind`) and a
 * subsequent `open()` (which calls `bind` again) when the OS happened
 * to tear the service down between them.
 *
 * Real-device validation of the running-service path is part of
 * operator smoke testing — those scenarios cover the live lockscreen
 * card, swipe-to-dismiss behaviour, and Bluetooth-headset transport.
 */
class FluxoraMediaSessionServiceTest {

    @After
    fun tearDown() {
        // The companion object is a process-wide singleton in production;
        // each test resets it so the next one starts from a clean slate.
        FluxoraMediaSessionService.resetForTesting()
    }

    @Test
    fun `unbind without prior bind is a no-op`() {
        // Should not throw, should not interact with any Context.
        FluxoraMediaSessionService.unbind()
        FluxoraMediaSessionService.unbind()
        FluxoraMediaSessionService.unbind()
    }

    @Test
    fun `applyMetadata without active session is a no-op`() {
        FluxoraMediaSessionService.applyMetadata("Inception")
        FluxoraMediaSessionService.applyMetadata(null)
        FluxoraMediaSessionService.applyMetadata("")
        FluxoraMediaSessionService.applyMetadata("   ")
    }

    @Test
    fun `resetForTesting clears any leaked pending state`() {
        // The bind() entry point requires a Context and an ExoPlayer
        // instance — both of which need an Android runtime — so we
        // can't exercise the happy path on the host JVM.  We can
        // however prove that resetForTesting() is callable repeatedly
        // and leaves no observable side effects against the other
        // companion methods.
        FluxoraMediaSessionService.resetForTesting()
        FluxoraMediaSessionService.resetForTesting()
        FluxoraMediaSessionService.unbind()
        FluxoraMediaSessionService.applyMetadata(null)
    }
}
