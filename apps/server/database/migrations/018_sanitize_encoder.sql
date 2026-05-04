-- Migration 018: Sanitise stale transcoding_encoder values.
--
-- The TranscodingEncoder Literal in models/settings.py was updated to remove
-- 'h264_amf' and add six new hardware-accelerated variants.  Any row that
-- still stores an encoder ID that is not in the current allowed set would
-- cause a 422 Unprocessable Entity on the next PATCH /api/v1/settings call.
-- Reset those rows to the safe software fallback 'libx264'.

UPDATE user_settings
SET transcoding_encoder = 'libx264'
WHERE transcoding_encoder NOT IN (
    'libx264',
    'libx265',
    'h264_nvenc',
    'hevc_nvenc',
    'h264_qsv',
    'hevc_qsv',
    'h264_vaapi',
    'hevc_vaapi',
    'h264_videotoolbox',
    'hevc_videotoolbox'
);
