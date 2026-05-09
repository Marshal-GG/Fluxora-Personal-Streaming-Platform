-- Plan 19 §M7 — Streaming mode toggle (docs/10_planning/19_library_transcode_followups.md).
-- Switches between client-side decoding (server stream-copies the source
-- codec straight to the client; modern devices hardware-decode AV1/VP9)
-- and server-side transcoding (legacy live-transcode-to-H.264 pipeline,
-- the previous default).
--
-- Default `client-decode` matches v1 launch intent: server CPU near zero,
-- modern phones / tablets / desktops play sources directly.  Operators
-- with mixed device pools (anything pre-2021) flip the toggle to
-- `server-transcode` to restore the legacy live-transcode behaviour from
-- plan 18.  Sidecar pickup (plan 18, migration 027) wins regardless of
-- mode — already-transcoded files keep stream-copying the H.264 sidecar.

ALTER TABLE user_settings ADD COLUMN
    streaming_mode TEXT NOT NULL DEFAULT 'client-decode'
    CHECK(streaming_mode IN ('client-decode', 'server-transcode'));
