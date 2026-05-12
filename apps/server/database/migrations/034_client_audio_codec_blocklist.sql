-- Plan 21 — per-(client, source audio codec) blocklist for transparent
-- audio-only transcode fallback.  Mirrors plan 20's
-- `client_codec_blocklist` (which covers video) but is kept as a
-- separate table because audio decode failure is independent of video
-- decode failure: a device that can decode AV1 video may still choke on
-- an Opus or AC3 audio track, and we don't want the video blocklist
-- forcing a full transcode when only the audio needs help.
--
-- Populated when a client reports a player audio decode error within
-- the first 6 s of playback on the 'auto' streaming mode.  Looked up
-- at `/start` time: a hit sets `_session_force_audio_transcode` for
-- the new session so the audio path re-encodes while video continues
-- to stream-copy.  Strict `client-decode` and legacy
-- `server-transcode` modes ignore the table.
--
-- (client_id, audio_codec) is the composite primary key so a single
-- device can be blocked on multiple audio codecs (Opus + FLAC, say)
-- but never duplicates a (client, codec) pair.  `INSERT OR IGNORE`
-- from the service layer leans on this for idempotency under
-- double-error bursts.
--
-- FK to clients(id) ON DELETE CASCADE: when an operator unpairs a
-- client, the blocklist rows go with it.  No dangling state.

CREATE TABLE client_audio_codec_blocklist (
    client_id    TEXT NOT NULL,
    audio_codec  TEXT NOT NULL,
    reason       TEXT,
    created_at   TEXT NOT NULL,
    PRIMARY KEY (client_id, audio_codec),
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);
