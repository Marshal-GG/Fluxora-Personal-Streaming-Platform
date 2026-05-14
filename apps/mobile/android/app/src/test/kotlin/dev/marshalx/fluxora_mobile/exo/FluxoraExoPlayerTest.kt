package dev.marshalx.fluxora_mobile.exo

import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.TrackGroup
import androidx.media3.common.Tracks
import com.google.common.collect.ImmutableList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Plan 24 M4 — host-JVM unit tests for the pure helpers extracted from
 * [FluxoraExoPlayer].  Media3's [Tracks]/[TrackGroup]/[Format] types are
 * data-classes-with-a-builder; constructing them in a test is the same
 * pattern Media3's own `*Test` files use.
 */
class FluxoraExoPlayerTest {

    private fun audioFormat(
        id: String,
        label: String?,
        language: String?,
        channels: Int,
        codec: String,
    ): Format = Format.Builder()
        .setId(id)
        .setLabel(label)
        .setLanguage(language)
        .setChannelCount(channels)
        .setSampleMimeType(MimeTypes.AUDIO_AAC)
        .setCodecs(codec)
        .build()

    private fun audioTrackGroup(vararg formats: Format): TrackGroup = TrackGroup(*formats)

    private fun tracksWithAudioGroup(
        group: TrackGroup,
        selectedFormatIndex: Int? = null,
    ): Tracks {
        val trackSupport = IntArray(group.length) { C.FORMAT_HANDLED }
        val trackSelected = BooleanArray(group.length) {
            selectedFormatIndex != null && it == selectedFormatIndex
        }
        val tracksGroup = Tracks.Group(
            group,
            /* adaptiveSupported = */ false,
            trackSupport,
            trackSelected,
        )
        return Tracks(ImmutableList.of(tracksGroup))
    }

    // ── parseSourceIndex ─────────────────────────────────────────────────────

    @Test
    fun `parseSourceIndex returns integer for numeric label`() {
        assertEquals(0, parseSourceIndex("0"))
        assertEquals(7, parseSourceIndex("7"))
        assertEquals(42, parseSourceIndex(" 42 "))
    }

    @Test
    fun `parseSourceIndex returns null for non-numeric or empty label`() {
        assertNull(parseSourceIndex(null))
        assertNull(parseSourceIndex(""))
        assertNull(parseSourceIndex("   "))
        assertNull(parseSourceIndex("English"))
        assertNull(parseSourceIndex("Hindi 5.1"))
        assertNull(parseSourceIndex("-3"))
    }

    // ── buildAudioTrackMapping ───────────────────────────────────────────────

    @Test
    fun `buildAudioTrackMapping uses numeric label as source index`() {
        val group = audioTrackGroup(
            audioFormat(id = "a0", label = "0", language = "eng", channels = 2, codec = "mp4a.40.2"),
            audioFormat(id = "a1", label = "1", language = "hin", channels = 6, codec = "ac-3"),
        )
        val tracks = tracksWithAudioGroup(group, selectedFormatIndex = 1)

        val result = buildAudioTrackMapping(tracks)

        assertEquals(2, result.descriptors.size)
        assertEquals(0, result.descriptors[0]["sourceIndex"])
        assertEquals(1, result.descriptors[1]["sourceIndex"])
        assertEquals("eng", result.descriptors[0]["language"])
        assertEquals(6, result.descriptors[1]["channels"])
        assertEquals(1, result.selectedSourceIndex)

        // Handle table must cover every source index and point at the
        // correct (group, formatIndex) pair so setAudioTrack can build
        // a TrackSelectionOverride directly.
        assertNotNull(result.handles[0])
        assertNotNull(result.handles[1])
        assertEquals(0, result.handles[0]!!.formatIndex)
        assertEquals(1, result.handles[1]!!.formatIndex)
        assertEquals(group, result.handles[0]!!.group)
    }

    @Test
    fun `buildAudioTrackMapping falls back to positional index when label is not numeric`() {
        val group = audioTrackGroup(
            audioFormat(id = "a0", label = null, language = "eng", channels = 2, codec = "mp4a.40.2"),
            audioFormat(id = "a1", label = "English (Director's Commentary)", language = "eng", channels = 2, codec = "mp4a.40.2"),
            audioFormat(id = "a2", label = "Hindi", language = "hin", channels = 6, codec = "ac-3"),
        )
        val tracks = tracksWithAudioGroup(group, selectedFormatIndex = 0)

        val result = buildAudioTrackMapping(tracks)

        assertEquals(3, result.descriptors.size)
        assertEquals(0, result.descriptors[0]["sourceIndex"])
        assertEquals(1, result.descriptors[1]["sourceIndex"])
        assertEquals(2, result.descriptors[2]["sourceIndex"])
        assertEquals(0, result.selectedSourceIndex)
    }

    @Test
    fun `buildAudioTrackMapping mixes labelled and unlabelled tracks safely`() {
        val group = audioTrackGroup(
            audioFormat(id = "a0", label = "5", language = "eng", channels = 2, codec = "mp4a.40.2"),
            audioFormat(id = "a1", label = null, language = "hin", channels = 6, codec = "ac-3"),
        )
        val tracks = tracksWithAudioGroup(group)

        val result = buildAudioTrackMapping(tracks)

        // First format takes its numeric label 5, second falls back to
        // its positional index (1 after the first slot has been
        // consumed).
        assertEquals(5, result.descriptors[0]["sourceIndex"])
        assertEquals(1, result.descriptors[1]["sourceIndex"])
        assertNotNull(result.handles[5])
        assertNotNull(result.handles[1])
        assertNull(result.selectedSourceIndex)
    }

    @Test
    fun `buildAudioTrackMapping ignores non-audio track groups`() {
        val videoGroup = TrackGroup(
            Format.Builder()
                .setId("v0")
                .setSampleMimeType(MimeTypes.VIDEO_H264)
                .setWidth(1920)
                .setHeight(1080)
                .build(),
        )
        val audioGroup = audioTrackGroup(
            audioFormat(id = "a0", label = "0", language = "eng", channels = 2, codec = "mp4a.40.2"),
        )
        val tracks = Tracks(
            ImmutableList.of(
                Tracks.Group(videoGroup, false, intArrayOf(C.FORMAT_HANDLED), booleanArrayOf(true)),
                Tracks.Group(audioGroup, false, intArrayOf(C.FORMAT_HANDLED), booleanArrayOf(false)),
            ),
        )

        val result = buildAudioTrackMapping(tracks)

        assertEquals(1, result.descriptors.size)
        assertEquals(0, result.descriptors[0]["sourceIndex"])
        assertNull(result.selectedSourceIndex)
    }

    @Test
    fun `buildAudioTrackMapping handles empty track list`() {
        val tracks = Tracks(ImmutableList.of())
        val result = buildAudioTrackMapping(tracks)
        assertTrue(result.descriptors.isEmpty())
        assertTrue(result.handles.isEmpty())
        assertNull(result.selectedSourceIndex)
    }

    // ── mapPlayerErrorCode ───────────────────────────────────────────────────
    //
    // Note: tests that need to construct an HttpDataSource.InvalidResponseCodeException
    // require an android.net.Uri-backed DataSpec, which throws "Stub!" on
    // the host JVM unless we add Robolectric.  We exercise the network/io
    // branches via raw IOException causes instead, and rely on real-device
    // smoke testing in M5+ for the 401/403 → auth_failed mapping.

    @Test
    fun `mapPlayerErrorCode reports network_error for raw IOException cause`() {
        val ex = PlaybackException(
            "Network",
            IOException("connection reset"),
            PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
        )
        assertEquals("network_error", mapPlayerErrorCode(ex))
    }

    @Test
    fun `mapPlayerErrorCode reports network_error for io error without IOException cause`() {
        val ex = PlaybackException(
            "Bad HTTP status",
            null,
            PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS,
        )
        assertEquals("network_error", mapPlayerErrorCode(ex))
    }

    @Test
    fun `mapPlayerErrorCode reports decoder_failed for decoder init error`() {
        val ex = PlaybackException(
            "Decoder init",
            null,
            PlaybackException.ERROR_CODE_DECODER_INIT_FAILED,
        )
        assertEquals("decoder_failed", mapPlayerErrorCode(ex))
    }

    @Test
    fun `mapPlayerErrorCode reports decoder_failed for decoding format unsupported`() {
        val ex = PlaybackException(
            "Format unsupported by decoder",
            null,
            PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED,
        )
        assertEquals("decoder_failed", mapPlayerErrorCode(ex))
    }

    @Test
    fun `mapPlayerErrorCode reports format_unsupported for malformed manifest`() {
        val ex = PlaybackException(
            "Malformed",
            null,
            PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED,
        )
        assertEquals("format_unsupported", mapPlayerErrorCode(ex))
    }

    @Test
    fun `mapPlayerErrorCode reports format_unsupported for unspecified error code`() {
        val ex = PlaybackException(
            "Unspecified",
            null,
            PlaybackException.ERROR_CODE_UNSPECIFIED,
        )
        assertEquals("format_unsupported", mapPlayerErrorCode(ex))
    }

    @Test
    fun `mapPlayerErrorCode reports unknown for unmapped error code`() {
        val ex = PlaybackException(
            "Remote",
            null,
            PlaybackException.ERROR_CODE_REMOTE_ERROR,
        )
        assertEquals("unknown", mapPlayerErrorCode(ex))
    }
}
