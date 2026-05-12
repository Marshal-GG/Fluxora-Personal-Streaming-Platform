-- Plan 20 — per-(client, source codec) blocklist for transparent
-- transcode fallback.  Populated when a client reports a player decode
-- error within the first 6 s of playback on the 'auto' streaming
-- mode.  Looked up at `/start` time: a hit forces the new session into
-- server-side transcode regardless of the global setting or the
-- per-library override, so the device that couldn't decode AV1 last
-- time doesn't waste another session probing the same codec.
--
-- (client_id, source_codec) is the composite primary key so a single
-- device can be blocked on multiple codecs (HEVC + AV1, say) but never
-- duplicates a (client, codec) pair.  `INSERT OR IGNORE` from the
-- service layer leans on this for idempotency under double-error
-- bursts.
--
-- FK to clients(id) ON DELETE CASCADE: when an operator unpairs a
-- client, the blocklist rows go with it.  No dangling state.

CREATE TABLE client_codec_blocklist (
    client_id    TEXT NOT NULL,
    source_codec TEXT NOT NULL,
    reason       TEXT,
    created_at   TEXT NOT NULL,
    PRIMARY KEY (client_id, source_codec),
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);
