package dev.marshalx.fluxora_mobile.exo

import android.content.Context
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.util.Log
import androidx.media3.common.Format
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer
import androidx.media3.exoplayer.video.VideoRendererEventListener

/**
 * Custom renderers factory that swaps Media3's stock
 * [MediaCodecVideoRenderer] for [TonemappingVideoRenderer], which asks
 * the decoder to tone-map HDR (HDR10 / HLG / DolbyVision) frames down
 * to SDR before they reach the Flutter texture surface.
 *
 * Why: a bare Flutter `SurfaceProducer` texture is SDR.  HDR-encoded
 * frames rendered onto it without tone-mapping look washed out /
 * desaturated.  Requesting tone-mapping at the codec level is
 * hardware-accelerated on Android 13+ (API 33) devices that support
 * it — zero CPU cost, no FFmpeg server transcode required.
 *
 * On Android <13 or codecs that don't support tone-mapping, the
 * request is silently ignored; HDR content will still look washed
 * out and operators can fall back to the server-side `?tonemap=true`
 * path via the 3-dot menu's "Tone-map HDR to SDR" toggle.
 */
@UnstableApi
internal class TonemappingRenderersFactory(
    context: Context,
) : DefaultRenderersFactory(context) {

    override fun buildVideoRenderers(
        context: Context,
        extensionRendererMode: Int,
        mediaCodecSelector: MediaCodecSelector,
        enableDecoderFallback: Boolean,
        eventHandler: Handler,
        eventListener: VideoRendererEventListener,
        allowedVideoJoiningTimeMs: Long,
        out: ArrayList<Renderer>,
    ) {
        out.add(
            TonemappingVideoRenderer(
                context,
                codecAdapterFactory,
                mediaCodecSelector,
                allowedVideoJoiningTimeMs,
                enableDecoderFallback,
                eventHandler,
                eventListener,
            ),
        )
    }
}

@UnstableApi
internal class TonemappingVideoRenderer(
    context: Context,
    codecAdapterFactory: MediaCodecAdapter.Factory,
    mediaCodecSelector: MediaCodecSelector,
    allowedJoiningTimeMs: Long,
    enableDecoderFallback: Boolean,
    eventHandler: Handler,
    eventListener: VideoRendererEventListener,
) : MediaCodecVideoRenderer(
    context,
    codecAdapterFactory,
    mediaCodecSelector,
    allowedJoiningTimeMs,
    enableDecoderFallback,
    eventHandler,
    eventListener,
    MAX_DROPPED_VIDEO_FRAME_COUNT_TO_NOTIFY,
) {

    companion object {
        private const val TAG = "FluxoraTonemap"

        /** Default value Media3 uses for its standard renderer factory. */
        private const val MAX_DROPPED_VIDEO_FRAME_COUNT_TO_NOTIFY = 50
    }

    override fun getMediaFormat(
        format: Format,
        codecMimeType: String,
        codecMaxValues: CodecMaxValues,
        codecOperatingRate: Float,
        deviceNeedsNoPostProcessWorkaround: Boolean,
        tunnelingAudioSessionId: Int,
    ): MediaFormat {
        val mediaFormat = super.getMediaFormat(
            format,
            codecMimeType,
            codecMaxValues,
            codecOperatingRate,
            deviceNeedsNoPostProcessWorkaround,
            tunnelingAudioSessionId,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // KEY_COLOR_TRANSFER_REQUEST = "color-transfer-request"
            // COLOR_TRANSFER_SDR_VIDEO  = 3 (SMPTE 170M / BT.709 SDR)
            // Both constants are public on MediaFormat from API 33; we
            // use string + int literals here so the build compiles
            // against older compileSdk too.
            mediaFormat.setInteger("color-transfer-request", 3)
            Log.d(
                TAG,
                "Requested SDR tone-mapping at codec for mime=$codecMimeType " +
                    "colorInfo=${format.colorInfo}",
            )
        }
        return mediaFormat
    }
}
