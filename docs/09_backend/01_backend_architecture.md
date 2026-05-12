# Backend Architecture

> **Category:** Backend  
> **Status:** Active - Updated 2026-05-12 (plan 20 — `streaming_mode='auto'` third mode + per-client codec blocklist + `POST /fallback-transcode` endpoint + `stream_decision` diagnostic log; migrations 032 + 033; new `services/client_codec_service.py`; server suite at **792 passing**.) Earlier 2026-05-09 (deep audit sync — server suite at **695 passing**; benchmark service + history persistence + transcoding `/benchmark*` routes documented; `services/ffmpeg_capabilities.py` + `-readrate` capability gating + `support_bundle_service` reflected in services map; `POST /stream/{id}/seek` + `applied_seek_sec` scrubber-offset patch documented; per-session `_applied_seek_sec` registry; mobile-side `/auth/clients/me/visible-libraries` + `/clients/me/continue-watching` + `/clients/me/stats` routes documented).  Earlier 2026-05-08 (mobile redesign audit §17.3 #3 closed: new `DELETE /api/v1/auth/clients/me` self-revoke route — bearer-validated, runs same teardown as the operator-driven `/auth/revoke/{id}`, records a `client.revoke` activity event with `actor_kind='client'`; +4 tests in test_auth.py.  Earlier 2026-05-08: streaming pipeline §4.5 closed: new `_finalize_vod_playlist` + `_finalize_vod_playlist_on_exit` watcher in `ffmpeg_service.py` replace the spawn-time over-promised static playlist with FFmpeg's accurate one on natural exit — fixes 5–15 % tail-segment 404s on stream-copy HEVC; new `_finalize_watchers` registry; `_terminate_ffmpeg` cancels watcher on stop/restart paths; +11 tests in test_stream.py.  Earlier 2026-05-08: new `POST /api/v1/files/{id}/reset-progress` for the "Start over" UI affordance — visibility-checked like `get_file` (404 not 403 on miss to prevent enumeration); HLS segment-wait loop tightened from 5 s to 2 s in `serve_hls` since the seek-restart pipeline shrinks the realistic gap to sub-second.  test_files.py +4 cases: 6 → 21.  Server suite **637 → 641 → 652 → 656 passing**.) Earlier 2026-05-04 (**Phase 6 follow-ups:** `ffmpeg_service` — `_CUVID_FAILURE_MARKERS` widened with `"hwaccel initialisation returned error"` / `"doesn't support hardware accelerated"` / `"hardware is lacking required capabilities"` to cover Turing GPUs (RTX 20-series) that lack AV1 NVDEC entirely; `use_cuvid` flag renamed `use_gpu_input`; retry path now drops both `-hwaccel cuda` AND `-c:v *_cuvid` so the GPU input pipeline is fully disabled for the fallback attempt; tonemap forces `use_gpu_input=False` from the first attempt. New helpers: `_resolve_source_metadata(db, file_path) -> (codec, hdr_format)` (back-compat `_resolve_source_codec` wrapper retained); `_HDR_TO_SDR_VF` constant (zscale+Hable BT.2020 PQ → BT.709 SDR); `_ensure_fmp4_init_segment()` (one-shot `ffmpeg -t 0.04` writes `init.mp4` if FFmpeg skipped it); `_write_static_vod_playlist()` (pre-emits VOD playlist, FFmpeg's incremental playlist moved to `_ff_playlist.m3u8`); `start_stream` gains `tonemap_hdr: bool = False`; `_build_ffmpeg_cmd` gains `apply_hdr_tonemap` param. `routers/stream.py` — `POST /stream/start` gained `tonemap: bool = False` query param; `StreamStartResponse` model gains `hdr_format: str | None` and `tonemapped: bool`; HLS router waits up to 5 s for not-yet-written segments (seek-ahead-of-encode); `.m4s` + `.mp4` served as `video/mp4` (was `video/MP2T`). Server suite 336 → 351. **GPU UX Slice C — multi-encoder priority chain + fallback orchestration:** new `services/session_router.py` walks the operator's `transcoding_chain` (JSON-encoded TEXT in `user_settings`, migration 020) on every transcode session start; `pick_encoder(chain, session_id, *, default_encoder)` returns `(encoder, reason)` where reason ∈ {`configured`, `gpu_session_cap_hit`, `all_encoders_saturated`, `encoder_unknown`}; `release_session` frees the cap slot in `stop_stream`; 50-entry FIFO ring buffer of routing decisions exposed via `GET /api/v1/transcoding/fallback-history`. `EncoderMeta` gained `concurrent_session_cap: int | None` (NVENC = 3 on consumer cards; software / QSV / VAAPI / VideoToolbox = None / unlimited). `start_stream` consults the router for transcode mode (stream-copy bypasses entirely); default chain when null is `[transcoding_encoder, "libx264"]` for back-compat. `stream_sessions.encoder_used TEXT` (migration 021) records the picked encoder per session; `_list_active_sessions` propagates it to the API. `UpdateSettingsBody.transcoding_chain: list[str] | None` validation rejects unknown encoders + all-duplicate chains; empty list → NULL → use default chain. Server suite 312 → 336. **GPU UX Slice B:** new `services/hardware_probe.py` enumerates CPU + GPU per-OS (lspci / wmic / system_profiler + nvidia-smi); `GET /api/v1/transcoding/devices` endpoint + lifetime cache. GPU UX Slice A + stream pipeline robustness: new `services/encoder_advisor.py` pure-function recommendation engine + `GET /api/v1/transcoding/advisor`; `test_encoder` returns `tuple[bool, str | None]`; `EncoderTestResult` dataclass (`passed`, `error`, `tested_at`); `_TEST_RESULTS` keyed to `EncoderTestResult`; `EncoderLoad` gains `encoder_test_error` + `encoder_tested_at`; NVIDIA cuvid input-decoder hint via `_NVIDIA_CUVID_BY_CODEC` + `_input_decoder_args`; cuvid auto-fallback retry (`_is_cuvid_failure` + `_build_ffmpeg_cmd` + `_spawn_ffmpeg_attempt` refactor); `independent_segments` dropped + `hls_time=10` for stream-copy long-GOP; migration 019 sanitises stale license keys; settings router `_log_validation_error` now delegates to FastAPI's default handler; stream/start 503 detail surfaces FFmpeg stderr tail. Earlier 2026-05-04: Player polish round: ffmpeg stream-copy pipeline for h264/hevc sources [`-c:v copy`, ~95% CPU drop], hevc → fMP4 segments, lazy `probe_video()` at stream-start back-fills `codec_name` for pre-migration-016 rows, per-session ffmpeg stderr captured to temp file + tail logged on premature exit / timeout. Phase A backfill (migration 016 + `probe_video` + `/files/recent` + `/auth/clients/me` + same-`client_id` re-pair fix); Phase B backfill (`/files/search` + `/me/continue-watching` + `/me/stats`). 2026-05-02: orders router, transcoding settings DB-driven, hardware encoding, logs endpoint, live system stats + storage breakdown, info actions, conditional Sentry init, `/healthz` + `remote_url` on `/info`, CF Tunnel real-IP / HLS-block / admin-hardening middlewares for public routing; legacy 4-part license keys removed; Groups CRUD + stream-gate; Profile endpoints; Notifications (REST + WS + in-process pub/sub); Activity event log; §7.8 transcoding status endpoint + transcoding_service + models/transcoding.py; §7.9 structured JSON logs + GET /api/v1/logs + WS /ws/logs + log_service; §7.10 settings extended 18 fields + migration 015; §7.11 orders pagination + portal-url endpoint; 297 tests)

---

## Framework & Stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.11+ |
| Framework | FastAPI |
| ASGI Server | Uvicorn |
| Streaming | FFmpeg (subprocess) → HLS |
| Database | SQLite (via `aiosqlite` for async) |
| LAN Discovery | `zeroconf` Python library — `AsyncZeroconf` (async-safe) |
| WebRTC Signaling | `aiortc 1.9.0` — RTCPeerConnection, ICE, DataChannel |
| Metadata | TMDB REST API |
| Payments | Polar Standard Webhooks |
| Process Management | `asyncio` subprocess for FFmpeg |

---

## Server Project Structure

```
server/
├── main.py                 # FastAPI app entry point + lifespan (DB, mDNS, HLS cleanup)
├── config.py               # Settings (BaseSettings), platform data dir, DB permissions
├── database/
│   ├── db.py               # aiosqlite connection pool, WAL mode, migration runner
│   └── migrations/
│       ├── 001_initial.sql  # libraries, media_files, clients, user_settings
│       ├── 002_sessions.sql # stream_sessions
│       ├── 003_client_status.sql  # clients.status column
│       ├── 004_tmdb_metadata.sql  # title, overview, poster_url on media_files
│       ├── 005_resume_progress.sql # last_progress_sec on media_files
│       ├── 006_settings_license.sql # license_key on user_settings
│       ├── 007_align_tier_limits.sql # corrects max_concurrent_streams per tier
│       ├── 008_polar_orders.sql # paid Polar order idempotency + generated keys
│       ├── 009_order_customer_email.sql # adds customer_email to polar_orders
│       ├── 010_transcoding_settings.sql # adds transcoding_encoder/preset/crf to user_settings
│       ├── 011_groups.sql              # groups, group_members, group_restrictions tables + idx_group_members_client
│       ├── 012_profile_fields.sql      # adds display_name, email, avatar_path, profile_created_at, last_login_at to user_settings
│       ├── 013_notifications.sql       # notifications table + idx_notifications_unread
│       ├── 014_activity_events.sql     # activity_events table + idx_activity_created + idx_activity_type_created
│       ├── 015_extended_settings.sql   # 18 new columns on user_settings (general/network/streaming/security/advanced)
│       ├── 016_media_quality_episodes_client_email.sql  # FFprobe quality cols + TV episode aggregation + client email/paired_at
│       ├── 017_hwaccel_device.sql       # transcoding_hwaccel_device on user_settings (VAAPI multi-GPU)
│       ├── 018_sanitize_encoder.sql     # legacy h264_amf etc. → libx264 reset
│       ├── 019_sanitize_license_key.sql # 4-segment legacy keys → NULL
│       ├── 020_encoder_chain.sql        # transcoding_chain JSON on user_settings (Slice C priority chain)
│       ├── 021_session_encoder.sql      # encoder_used on stream_sessions (per-session encoder pill)
│       ├── 022_remove_corrupt_media_paths.sql  # delete media_files with relative / [-prefixed paths
│       ├── 023_clients_last_ip.sql      # nullable last_ip on clients (IP column + heartbeat)
│       ├── 024_benchmark_history.sql    # benchmark_runs table + idx_benchmark_runs_started_at
│       ├── 025_groups_v2_content_spaces.sql  # v2: is_public/icon/color/requires_pin/pin_hash/pin_mode/max_concurrent_streams on groups; time_window_override on group_members; group_pin_grants + group_pin_attempts; manufactures Public group; backfills allowed_libraries; auto-adds approved clients to Public
│       ├── 026_groups_per_client_pins.sql    # M8 hybrid PIN: pin_model on groups + group_member_pins enrollment ledger
│       ├── 032_streaming_mode_auto.sql       # plan 20: widen streaming_mode CHECK to add 'auto'; default stays 'client-decode'
│       └── 033_client_codec_blocklist.sql    # plan 20: new client_codec_blocklist table (composite PK client_id+source_codec; FK CASCADE to clients)
│
├── routers/
│   ├── info.py             # GET /api/v1/info (remote_url precedence: user_settings.custom_server_url > FLUXORA_PUBLIC_URL > null), /info/stats; POST /info/restart, /info/stop, /info/support-bundle ✅
│   ├── auth.py             # /auth/* ✅ (request-pair, status, approve, reject, operator-revoke; `DELETE /auth/clients/me` self-revoke for mobile sign-out — audit §17.3 #3; `PATCH /auth/clients/me` self-rename for mobile Account-screen edit — settings remediation M2.5, 2026-05-08 — bearer-only, body `UpdateClientMeRequest{display_name}` validated 1–50 chars + control-char rejection, records `client.profile_updated` activity event with `actor_kind='client'`; `GET /auth/clients/{id}/visible-libraries` localhost-only — operator "View as" debug returning `VisibleLibraries` snapshot, M5 of `14_groups_management_page.md`; bearer-only `GET /auth/clients/me/visible-libraries` — same shape scoped to caller, backs mobile Profile "My Libraries" cards (M6); bearer-only `GET /auth/clients/me/continue-watching` — non-zero `last_progress_sec` rail filtered through v2 visibility; bearer-only `GET /auth/clients/me/stats` — `{hours, movies, shows}` per-client aggregate; `_serialize_visible` shared serializer between view-as + me variants)
│   ├── deps.py             # validate_token, validate_token_or_local, require_local_caller FastAPI dependencies ✅
│   ├── files.py            # GET/POST(upload)/DELETE /api/v1/files; POST /api/v1/files/{id}/reset-progress (zero last_progress_sec for "Start over" UI — streaming pipeline plan §4.10); validate_token_or_local; bearer callers see 404 not 403 on visibility miss to prevent enumeration ✅
│   ├── library.py          # GET/POST /api/v1/library, GET/PATCH/DELETE /{id}, POST /{id}/scan, GET /storage-breakdown; validate_token_or_local; emits library.create/update/delete activity events ✅
│   ├── stream.py           # GET /sessions, POST /start/{id}?tonemap=, PATCH /{id}/progress, POST /{id}/seek?seek_sec=&tonemap= (re-spawn FFmpeg from arbitrary seek + rewrite static playlist with monotonic `#EXT-X-DISCONTINUITY-SEQUENCE`; rate-limited 30/minute; returns `StreamSeekResponse{applied_seek_sec}`), GET/{id}, DELETE/{id} + hls_router; **plan 20: POST /{id}/fallback-transcode** (bearer + rate-limited 10/min; records (client_id, source_codec) in client_codec_blocklist; flips _session_force_transcode; restarts FFmpeg from caller-supplied position; 404/403/409 on not-found/not-owned/mode-not-auto; returns updated playlist_url + forced_transcode=true); start/{id} consults client_codec_service.is_blocked only when streaming_mode='auto'; StreamStartResponse gains streaming_mode field; stream-gate hook calls group_service.reason_to_deny_stream (v2 — replaces v1 reason_to_deny); HLS router 2 s segment-wait for seek-ahead; .m4s/.mp4 served as video/mp4 ✅
│   ├── ws.py               # WS /status (token auth + ping/pong + progress), WS /stats (live system stats) ✅
│   ├── signal.py           # WS /signal: SDP offer/answer + ICE relay ✅
│   ├── settings.py         # GET/PATCH /api/v1/settings; require_local_caller ✅
│   ├── orders.py           # GET /api/v1/orders (paginated); GET /orders/portal-url; require_local_caller ✅
│   ├── groups.py           # GET/POST /api/v1/groups, GET/PATCH/DELETE /{id}, GET/POST /{id}/members (with `?include=pin_state` for the desktop Members-tab badges), PATCH /{id}/members/{cid} (M5 of `14_groups_management_page.md` — per-member time_window_override; localhost), DELETE /{id}/members/{cid}, DELETE /{id}/members/{cid}/pin (M8 — clear per-client PIN, localhost), POST /{id}/enter (bearer — submit PIN), POST /{id}/enroll (bearer — first-time per-client enrollment, M8), POST /{id}/enroll/change (bearer — replace own per-client PIN, M8), DELETE /{id}/grant (bearer — lock), GET /{id}/grant-status (bearer — pin_model + enrollment_state for mobile UX routing), POST /{id}/grants/reset (M7 follow-up — bulk-drop every active grant for shared-mode Reset PINs; localhost), POST /{id}/master-override?client_id= (localhost — operator recovery, no PIN); mixed auth ✅
│   ├── notifications.py    # GET /api/v1/notifications, POST /{id}/read, POST /read-all, DELETE /{id}; validate_token_or_local ✅
│   ├── profile.py          # GET/PATCH /api/v1/profile; require_local_caller ✅
│   ├── activity.py         # GET /api/v1/activity?limit=&since=&type=; validate_token_or_local ✅
│   ├── transcoding.py      # GET /transcoding/status, /advisor, /devices, /fallback-history; POST /transcoding/benchmark (run synthetic encode-per-encoder; clamps duration/fps/resolutions); GET /transcoding/benchmark/progress (in-flight snapshot polled by desktop ~500 ms); GET /transcoding/benchmark/history (recent run summaries) + GET /history/{run_id} (full body) + DELETE /history/{run_id}; all routes localhost-only ✅
│   ├── transcode.py        # plan 18 — user-driven library transcode.  GET /transcode/candidates (AV1/VP9 sources without a sidecar), POST /transcode/queue (1-50 file_ids; 10/min rate-limited), GET /transcode/jobs (`?status=` csv filter), DELETE /transcode/jobs/{id} (cancel running or queued; 409 on terminal), POST /transcode/jobs/{id}/retry (failed/cancelled only); validate_token_or_local on every route ✅
│   ├── logs.py             # GET /api/v1/logs; WS /api/v1/ws/logs; validate_token_or_local ✅
│   └── webhook.py          # POST /api/v1/webhook/polar; Standard Webhooks signature ✅
│
├── services/
│   ├── ffmpeg_service.py   # FFmpeg subprocess management, HLS output ✅ — uniform `-loglevel info` (was conditional warning/error; §17 M1); transcode-only `-readrate 1.5` + capability-gated `-readrate_initial_burst 30` (§17 M3 + same-day follow-on transcode-only refinement); 30 s playlist-timeout floor when readrate is active (§17 M4); three-path audio branch (copy / re-encode-no-resample under tonemap / re-encode-resample fallback — §16 M4); per-session `_applied_seek_sec[session_id]` dict surfaces segment-snapped seek source-time to routers for `applied_seek_sec` response field; **plan 19 §M7** — direct-remux check extends to AV1 + VP9 via `_resolve_codec_passthrough(settings_row, library_row, codec)`; AV1 / VP9 / HEVC all ride the same fmp4 segment path; **plan-18 hotfix** — `start_stream` accepts `source_codec_override` + `duration_sec_override` kwargs; **plan 20** — module-level `_session_force_transcode: dict[str, bool]` keyed by session_id; `_resolve_codec_passthrough` accepts `session_force_transcode: bool` (True → transcode wins unconditionally regardless of global setting or library override); `set_session_force_transcode(session_id, value=True)` helper exposed for the router; `stop_stream` clears the flag; new `stream_decision session=… source_codec=… mode=… path=… reason=…` INFO log line on every session start (reason ∈ {forced-fallback, hdr-tonemap, library-override, global-client-decode, global-auto, global-server-transcode, always-passthrough, unsupported-source-codec}) — operator's grep target for "why is my server transcoding?"
│   ├── ffmpeg_capabilities.py # FFmpeg version probe at server startup; `FfmpegCapabilities` frozen dataclass with `is_known` + `supports_readrate_initial_burst` properties; lazy import of `_ffmpeg_bin` at call-time so test monkey-patches propagate.  Streaming pipeline plan §17 M2 ✅
│   ├── library_service.py  # Library + file CRUD + scan_library + update_library + total_size_bytes SUM aggregate; `_is_valid_absolute_media_path` rejects relative + `[`-prefixed + null-byte paths in scan and upload; `_persist_probe` writes `duration_sec`; `backfill_missing_durations(db, batch_size, max_rows)` startup task fills duration on rows that pre-date the probe-writes-duration fix ✅
│   ├── discovery_service.py # mDNS/Zeroconf broadcasting ✅
│   ├── auth_service.py     # HMAC-SHA256 tokens, pairing state machine; `revoke_client(db, client_id)` shared between operator-driven `DELETE /auth/revoke/{id}` and mobile self-revoke `DELETE /clients/me`; `update_client_display_name(db, client_id, display_name)` parameterised UPDATE — backs `PATCH /clients/me` (settings remediation M2.5, 2026-05-08) ✅
│   ├── webrtc_service.py   # aiortc RTCPeerConnection registry; SDP/ICE handling; graceful teardown ✅
│   ├── settings_service.py # GET/PATCH user_settings; tier→max_streams mapping; _enrich_license() ✅
│   ├── license_service.py  # HMAC-SHA256 key gen/validation; FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> format; CLI generator ✅
│   ├── webhook_service.py  # Polar signature validation + paid-order license issuance ✅
│   ├── tmdb_service.py     # TMDB REST API search; enriches media_files after scan ✅
│   ├── group_service.py    # Group CRUD + member management + v2 visibility resolution: VisibleLibraries dataclass (library_ids + groups_contributing provenance + pin_locked_groups + enrollment_required_groups [M8] + time_locked_groups), _MembershipState + _resolve_membership shared SQL walk, get_visible_libraries (additive UNION), reason_to_deny_stream (v2 stream-gate, picks most-specific deny reason); PIN flow: hash_pin (HMAC-SHA256), validate_pin_strength (server-authoritative obvious-PIN blocklist), enter_pin_grant (branches on pin_model — shared reads groups.pin_hash, per-client reads group_member_pins; rate-limited 5 fails / 60 s / (client, group)), enroll_pin (M8 first-time per-client; immediate session-length grant), change_member_pin (M8 verify-old + replace; charges failed attempts), clear_member_pin (M8 operator action — drops enrollment + grant), revoke_pin_grant (mobile lock), housekeep_pin_state (prune expired grants + 24 h-old attempts; called from main.py background task); create_group/update_group accept pin_model with documented mode-switch semantics (shared→per-client clears pin_hash + keeps grants; per-client→shared raises ValueError unless pin supplied + drops enrollment rows); list_members(include_pin_state=True) augments rows with enrollment_state/has_active_grant/grant_expires_at/recent_failed_attempts in one SQL via correlated sub-selects (M3 of `14_groups_management_page.md`); set_member_time_window_override sets/clears per-member windows (M5); _emit_group_activity wraps activity_service.record on member.add/remove + pin.unlock + pin.cleared (best-effort; producer errors swallowed); v1 get_effective_restrictions + reason_to_deny removed in M2 of the v2 plan ✅
│   ├── notification_service.py # CRUD (create/list/mark_read/mark_all_read/dismiss) + in-process pub/sub (subscribe/unsubscribe); backs /api/v1/notifications + WS /ws/notifications ✅
│   ├── activity_service.py # record() + list_events(limit, since, type_prefix); backs /api/v1/activity; producer errors swallowed by callers ✅
│   ├── profile_service.py  # get_profile(db) + update_profile(db, ...); avatar_letter computation ✅
│   ├── system_stats_service.py # CPU/RAM/network/uptime/IP/internet probe; backs /info/stats + /ws/stats ✅
│   ├── transcoding_service.py  # encoder discovery via `ffmpeg -encoders` (cached); GPU probe via nvidia-smi/intel_gpu_top/radeontop/system_profiler; `EncoderTestResult` dataclass (passed/error/tested_at/suggestion); `_list_active_sessions` propagates `encoder_used`; `classify_encoder_failure(encoder, error)` recognises QSV old-driver / no-iGPU / NVENC session-cap signatures; `emit_encoder_failure_notifications(db)` writes one notification per failed encoder with category+related_id+`dismissed_at IS NULL` dedup; backs GET /api/v1/transcoding/status ✅
│   ├── encoder_advisor.py      # pure function recommend(active, available, test_results) → Recommendation; backs GET /api/v1/transcoding/advisor ✅
│   ├── encoder_registry.py     # ENCODER_REGISTRY of 10 encoder metas; `concurrent_session_cap` (NVENC = 3); pre-input flags / preset maps / quality args / segment formats per vendor ✅
│   ├── hardware_probe.py       # per-OS CPU + GPU enumeration (lspci / wmic / system_profiler + nvidia-smi); lifetime cache; backs GET /api/v1/transcoding/devices ✅ (Slice B)
│   ├── session_router.py       # priority-chain walker for transcode mode; pick_encoder() / release_session() / 50-entry FIFO ring buffer of routing decisions; backs GET /api/v1/transcoding/fallback-history ✅ (Slice C)
│   ├── benchmark_service.py    # multi-second `lavfi testsrc` encode per encoder (sequential; mpegts → DEVNULL); parses stderr for fps/speed/bitrate + first-frame init_ms; midpoint GPU sample via vendor probe; clamps duration [2, 20] s, fps [24, 60], resolution; 35 s per-encoder timeout; in-flight progress snapshot via `get_progress()`; backs POST /transcoding/benchmark ✅
│   ├── benchmark_history_service.py # persists benchmark runs to `benchmark_runs` (migration 024) — top-level metadata + per-encoder JSON; `save_benchmark_run` prunes to `_HISTORY_LIMIT=50` after each insert; `list_benchmark_runs` / `get_benchmark_run` / `delete_benchmark_run` back the desktop history sidebar ✅
│   ├── transcode_service.py   # plan 18 — user-driven library transcode worker.  Public surface: `candidates(db)` / `queue(db, file_ids, preset)` / `cancel(db, job_id)` / `list_jobs(db, statuses)` / `get_job(db, id)` / `retry(db, job_id)` / `storage_aggregate(db)` / `start_worker()` / `stop_worker()`.  Single-worker FIFO loop; claims oldest `queued` row, builds an FFmpeg cmd via plan-19 §M1 `QUALITY_PRESETS` map (smaller / recommended (default `cq=23`) / mastering); plan-19 §M2 `_sidecar_path()` rewrite supports both `dedicated` (mirrors library tree under `transcode_cache_root`) and `inline` (`.fluxora-transcodes/` next to source) storage modes; `.webm` sources force `.mkv` sidecar extension.  Parses `-progress pipe:2` to update `progress_pct` + `eta_sec` in DB every ~1.5 s; on success stats the sidecar and writes `media_files.transcoded_path` + `transcoded_size_bytes` + `transcoded_at` + `transcoded_source_mtime`.  Crash-recovery on boot marks orphan `running` rows as `failed` and unlinks any partial output file derived from the row's expected sidecar path.  `storage_aggregate(db)` returns the `/transcode/storage` payload — file_count + total_bytes + per-codec + per-library breakdown (the per-library aggregate uses `LEFT JOIN libraries` so files orphaned by a previous library-delete still appear under `(orphaned)` rather than disappearing) + `shutil.disk_usage(cache_root).free`.  Audio: `-c:a copy` if AAC, else `-c:a aac -b:a 192k` ✅
│   ├── support_bundle_service.py # operator field-debug bundle generator — gzipped tar with `metadata.json` + `system/stats.json` + `system/encoders.json` + redacted `settings/redacted.json` + `database/schema.sql` (sqlite_master DDL only) + `logs/*` (active rotating log + ≤4 rotated siblings); per-collector try/except → `_collect_error` markers; backs POST /info/support-bundle ✅
│   ├── client_codec_service.py   # plan 20 — per-client codec fallback blocklist; `is_blocked(db, client_id, source_codec) -> bool` + `add_block(db, client_id, source_codec, reason)` (idempotent INSERT OR IGNORE); consulted ONLY under streaming_mode='auto' ✅
│   └── log_service.py              # parse JSON-line log file; filter (level/source/since/until/q); cursor pagination; pubsub for WS /ws/logs ✅
│
├── models/
│   ├── media_file.py       # MediaFileResponse Pydantic schema ✅
│   ├── library.py          # LibraryResponse (with file_count + total_size_bytes), CreateLibraryBody, UpdateLibraryBody, StorageByType + StorageBreakdownResponse (Dashboard donut) ✅
│   ├── client.py           # PairRequestBody, PairResponse, AuthStatusResponse, ActiveSessionInfo (in-flight session attached per client row), GroupSummary (id+name+status chips), ClientListItem, ClientListResponse, ClientMeResponse, UpdateClientMeRequest (Field-validated rename body — strips whitespace, bans control chars), ClientMeStatsResponse ✅
│   ├── stream_session.py   # StreamStartResponse (+ resume_sec, applied_seek_sec, hdr_format, tonemapped fields; **plan 20:** + `streaming_mode: str` field so mobile knows whether to arm the auto-fallback watcher), StreamSeekResponse{applied_seek_sec}, StreamSessionResponse; **plan 20 body model:** FallbackTranscodeRequest{current_position_sec: float ≥ 0}, FallbackTranscodeResponse{session_id, playlist_url, forced_transcode: true} ✅
│   ├── settings.py         # ServerInfoResponse, SystemStatsResponse, UserSettingsResponse (incl. license_status, license_tier, transcoding fields), UpdateSettingsBody ✅
│   ├── notification.py     # NotificationResponse, NotificationCreate; NotificationType, NotificationCategory type aliases ✅
│   ├── activity.py         # ActivityEventResponse (id, type, actor_kind?, actor_id?, target_kind?, target_id?, summary, payload?, created_at) ✅
│   ├── order.py            # PolarOrderItem, PolarOrderListResponse (+ total_all/next_cursor), PortalUrlResponse ✅
│   ├── profile.py          # ProfileResponse (avatar_letter computed), ProfileUpdate ✅
│   ├── group.py            # TimeWindow, GroupRestrictions, GroupResponse (v2 fields: is_public/requires_pin/pin_mode/pin_model/icon/color/max_concurrent_streams), GroupCreate (+ pin/pin_mode/pin_model — per-client groups reject pin at create), GroupUpdate (+ pin/pin_mode/pin_model with documented null/empty-string/digits semantic), GroupMemberAdd, GroupMemberPatch (per-member time_window_override — M5); GroupStatus, PinMode, PinModel literals ✅
│   ├── transcoding.py      # TranscodingStatusResponse, EncoderLoad, ActiveTranscodeSession ✅
│   ├── transcode.py        # plan 18 — TranscodeCandidate, TranscodeQueueRequest (1-50 file_ids), TranscodeQueueResponse, TranscodeJobResponse (joined `file_name`), TranscodeRetryResponse; JobStatus literal {queued, running, done, failed, cancelled} ✅
│   └── log_record.py           # LogRecord, LogListResponse ✅
│
└── tests/
    ├── conftest.py                # test_db + client fixtures; reset_rate_limits autouse
    ├── test_auth.py               # info + pairing flow + localhost restriction + client listing + self-revoke + self-rename ✅
    ├── test_library.py            # library CRUD + PATCH + total_size_bytes aggregate ✅
    ├── test_library_service.py    # library_service unit cases (continue-watching, search, client-stats, validation guard) ✅
    ├── test_files.py              # file listing + filtering + recent + search + reset-progress + visibility-miss 404 ✅
    ├── test_probe_video.py        # ffprobe lazy back-fill (codec_name + hdr_format) ✅
    ├── test_stream.py             # stream start/stop/HLS + finalize watcher + scrubber-offset (mocked FFmpeg) ✅
    ├── test_ws.py                 # WebSocket auth + pong ✅
    ├── test_signal.py             # WS signaling auth + SDP/ICE protocol ✅
    ├── test_settings.py           # GET/PATCH settings + tier concurrency + 429 + license_status ✅
    ├── test_settings_extended.py  # PATCH + GET for the 18 extended settings fields, Pydantic constraints ✅
    ├── test_license_service.py    # key validation (happy/expired/bad-sig/advisory/malformed/4-part-rejected) + generation ✅
    ├── test_orders.py             # GET /orders localhost + response schema + pagination + portal-url ✅
    ├── test_tmdb_service.py       # TMDB search (movie/TV/person/network-error/missing-poster) ✅
    ├── test_dns_override.py       # DoH override pre-warm for TMDB host ✅
    ├── test_webhook.py            # Polar signature, paid orders, router responses ✅
    ├── test_info_stats.py         # REST /info/stats shape + WS /stats localhost & non-localhost auth ✅
    ├── test_info_actions.py       # /info/restart + /info/stop localhost (202) and non-localhost (403) ✅
    ├── test_storage_breakdown.py  # empty / aggregation by type / missing-root capacity exclusion ✅
    ├── test_healthz.py            # /healthz exempt from auth + always 200 ✅
    ├── test_real_ip.py            # CF Tunnel real-IP middleware + HLSBlock + admin-hardening ✅
    ├── test_port_consistency.py   # FLUXORA_PORT vs hard-coded URLs sanity check ✅
    ├── test_sentry_init.py        # _init_sentry no-op without DSN + filter drops HTTPException ✅
    ├── test_ffmpeg_capabilities.py # version probe parser + supports_readrate_initial_burst gate ✅
    ├── test_groups.py             # CRUD + member management + auth split + stream-gate (v1) + v2 visibility matrix + PIN flow + auto-add-to-Public + PIN HTTP routes + M8 per-client + M3 `?include=pin_state` + M5 view-as + member time_window_override ✅
    ├── test_notifications.py      # REST CRUD, WS auth + fan-out, unread filter, dismiss, read-all ✅
    ├── test_profile.py            # GET/PATCH profile localhost + response schema + avatar_letter ✅
    ├── test_activity.py           # service CRUD, payload roundtrip, since/type filters, REST endpoints, pair emitter integration, off-loopback 401 ✅
    ├── test_transcoding.py        # encoder discovery, GPU probe, status response shape, localhost restriction ✅
    ├── test_encoder_advisor.py    # pure-function recommend() priority rules + vendor preference ✅
    ├── test_encoder_failure_classifier.py # QSV old-driver / no-iGPU / NVENC session-cap signature recognition ✅
    ├── test_hardware_probe.py     # per-OS CPU + GPU enumeration; vendor normalisation; failure-empty contract ✅
    ├── test_session_router.py     # priority-chain walker + concurrent_session_cap reservation + 50-entry ring buffer ✅
    ├── test_benchmark_service.py  # encoder benchmark stderr parse + clamp helpers + GPU midpoint sample + timeout ✅
    ├── test_benchmark_history.py  # JSON serialisation round-trip + prune to _HISTORY_LIMIT + CRUD ✅
    ├── test_transcode_service.py  # plan 18 — candidate detection (AV1/VP9 only, ignores already-transcoded); queue dedup + active-job skip; cancel/retry state transitions; status filter; orphan-running crash-recovery sweep ✅
    ├── test_transcode_router.py   # /api/v1/transcode/{candidates, queue, jobs, jobs/{id}, jobs/{id}/retry} happy paths + 400/404/409/422 + auth gate ✅
    ├── test_webrtc_ice_servers.py # `_ice_servers()` STUN-only when no TURN, includes TURN entry when all 3 of url/user/pass set, drops TURN if any empty (audit-follow-up regression guard for the env-var rename) ✅
    ├── test_support_bundle.py     # bundle contents + redaction + `_collect_error` partial-bundle path ✅
    ├── test_logs.py               # JSON-line parse, level/source/since/until/q filters, pagination, WS fan-out, localhost + token auth ✅
    └── test_client_codec_service.py # plan 20 — `is_blocked` / `add_block` round-trip; idempotent insert; cascade delete when client deleted ✅

Total: **792 tests passing** ✅
```

---

## Service Map

| Service | Responsibility | Key Functions |
|---------|---------------|---------------|
| `ffmpeg_service` ✅ | Spawn FFmpeg, manage HLS output, cleanup segments. Picks stream-copy (`-c:v copy`) for h264 / hevc sources (95 % CPU win) and full transcode for everything else, reading `transcoding_encoder/preset/crf` from DB. Supports software (libx264) and hardware (NVENC / QSV / VAAPI). For NVIDIA transcode sessions, injects a cuvid input-decoder hint (`_NVIDIA_CUVID_BY_CODEC` + `_input_decoder_args`) and auto-retries with `use_gpu_input=False` when `_is_cuvid_failure` matches stderr — widened markers now cover Turing GPUs where `-hwaccel cuda` itself fails. **HDR tonemap path:** when `tonemap_hdr=True` and source `hdr_format` is non-null, forces transcode mode + applies `_HDR_TO_SDR_VF` filter chain (zscale + Hable, BT.2020 PQ → BT.709 SDR yuv420p); `use_gpu_input` forced False to keep frames CPU-side for the `zscale`/`tonemap` filters. **Static VOD playlist:** `_write_static_vod_playlist` pre-emits a complete `#EXT-X-PLAYLIST-TYPE:VOD` playlist; FFmpeg writes incremental output to `_ff_playlist.m3u8` (never served). **fmp4 init segment fallback:** explicit `-hls_fmp4_init_filename "init.mp4"` in HLS args + `_ensure_fmp4_init_segment()` generates `init.mp4` via a one-shot `ffmpeg -t 0.04` if FFmpeg skipped it. Stream-copy drops `independent_segments` and uses `hls_time=10` for long-GOP sources. `test_encoder` returns `tuple[bool, str | None]` (passed + first stderr line). Per-session FFmpeg stderr captured to temp file; tail logged on premature exit / timeout; first stderr line bubbled into the `RuntimeError` message. Lazy `_resolve_source_metadata()` at stream-start back-fills both `codec_name` and `hdr_format` for files scanned before migration 016. Internal helpers: `_build_ffmpeg_cmd`, `_spawn_ffmpeg_attempt`, `_is_cuvid_failure`, `_resolve_source_metadata`, `_HDR_TO_SDR_VF`, `_ensure_fmp4_init_segment`, `_write_static_vod_playlist`. | `start_stream()`, `stop_stream()`, `probe_video()`, `test_encoder()`, `cleanup_session_dir()`, `is_running()` |
| `library_service` ✅ | Library + media file CRUD; TMDB enrichment (Phase 2); storage breakdown (Dashboard donut); per-library `total_size_bytes` SUM joined into every list/get response; corrupt-path defenses (validator on scan + upload); duration-backfill startup task | `list_libraries()`, `get_library()`, `create_library()`, `update_library()`, `delete_library()`, `list_files()`, `get_file()`, `get_storage_breakdown()`, `backfill_missing_durations(db, batch_size=50, max_rows=5000)` |
| `discovery_service` ✅ | Broadcast `_fluxora._tcp.local.` via mDNS on LAN — uses `AsyncZeroconf` to avoid blocking FastAPI's event loop | `start_discovery()` (async), `stop_discovery()` (async) |
| `auth_service` ✅ | Token generation (HMAC-SHA256), pairing state machine, token validation, **per-request heartbeat** (migration 023). `list_clients` rewritten to LEFT-JOIN `stream_sessions WHERE ended_at IS NULL` via `ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY started_at DESC) = 1` so each client carries one in-flight session at most. `create_pair_request` accepts `client_ip` + persists to `clients.last_ip` with `COALESCE` so a None caller doesn't clobber a previous value. New `update_client_heartbeat(db, client_id, last_ip=None)` helper is the single write path for `last_seen` + optional `last_ip`; called from `validate_token` (best-effort — try/except + WARNING log so a transient SQLite write failure can't 401 a valid request). **Side effect**: before migration 023 `last_seen` was frozen at pair / approval; it is now genuinely live.  **Settings remediation M2.5 (2026-05-08):** new `update_client_display_name(db, client_id, display_name)` parameterised `UPDATE clients SET name = ?, last_seen = ? WHERE id = ?` backs the new `PATCH /auth/clients/me` self-rename route — body validated by the `UpdateClientMeRequest` Pydantic model (1–50 chars, trims whitespace, rejects blank-after-trim + control chars `\x00-\x1f`). | `create_pair_request(client_id, device_name, platform, app_version, email, client_ip)`, `approve_client()`, `reject_client()`, `revoke_client()`, `update_client_display_name(client_id, display_name)`, `get_trusted_client_by_token()`, `update_client_heartbeat(client_id, last_ip)`, `list_clients()` |
| `webrtc_service` ✅ | Manage `RTCPeerConnection` registry, ICE/STUN/TURN, graceful teardown | `create_peer_connection()`, `handle_offer()`, `close_connection()` |
| `license_service` ✅ | HMAC-SHA256 signed key gen/validation; format `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>`; advisory mode when secret absent | `validate_key()`, `generate_key()`, `LicenseResult` |
| `webhook_service` ✅ | Verify Polar Standard Webhooks signatures; issue idempotent license keys for paid orders without logging PII | `verify_polar_signature()`, `handle_order_paid()`, `handle_order_created()` |
| `orders router` ✅ | Owner-only view of all processed Polar orders + generated license keys for manual customer delivery | `GET /api/v1/orders` (localhost) |
| `system_stats_service` ✅ | psutil-backed live stats — CPU%, RAM, per-interface network rate (loopback excluded), uptime via `Process.create_time()`, LAN IP via UDP-socket trick, cached internet probe to `1.1.1.1:80`. Per-instance state so REST and WS subscribers don't collide. | `SystemStatsService.collect(db)` returns `StatsPayload` |
| `group_service` ✅ | Client-group CRUD, member management, and stream-gate enforcement.  **v2 content-spaces redesign 2026-05-07** — UNION semantic; mandatory Public group every paired client auto-joins; PIN-gate per group with shared / per-client (M8) modes; per-member time-window override; per-group concurrent stream cap (M7).  `get_visible_libraries(client_id, *, now)` returns `VisibleLibraries(library_ids, groups_contributing, pin_locked_groups, enrollment_required_groups, time_locked_groups, groups)` consumed by every list endpoint AND `reason_to_deny_stream()` for the gate.  PIN flow: `enter_pin_grant`, `enroll_pin`, `change_member_pin`, `clear_member_pin`, `revoke_pin_grant`, `revoke_all_grants_for_group`, `housekeep_pin_state`, `_maybe_emit_failed_burst` (5-fails-in-10-min activity aggregator).  v1 `get_effective_restrictions` + `reason_to_deny` removed in M2 of [`13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md). | `list_groups()`, `get_group()`, `create_group(*, pin?, pin_model?, pin_mode?, icon?, color?, max_concurrent_streams?, hmac_key?)`, `update_group(*, pin/null/empty/digits semantic, pin_model with mode-switch rules)`, `delete_group()`, `add_member()`, `remove_member()`, `list_members(*, include_pin_state)`, `set_member_time_window_override()`, `get_visible_libraries()`, `reason_to_deny_stream()`, `enter_pin_grant`/`enroll_pin`/`change_member_pin`/`clear_member_pin`/`revoke_pin_grant`/`revoke_all_grants_for_group`/`housekeep_pin_state` |
| `notification_service` ✅ | Persists notifications to the `notifications` table and fans them out live via an in-process pub/sub bus. `create()` inserts a row and broadcasts to every subscribed asyncio.Queue (max 100 items per queue). Slow consumers drop frames rather than blocking producers. `subscribe()` returns a new queue; `unsubscribe(q)` removes it. CRUD: `list_notifications()`, `mark_read()`, `mark_all_read()`, `dismiss()`. | `create()`, `list_notifications(*, only_unread, limit)`, `mark_read()`, `mark_all_read()`, `dismiss()`, `subscribe()`, `unsubscribe(q)` |
| `activity_service` ✅ | Appends activity events to the `activity_events` table. `record()` inserts one event row; callers must wrap it in `try/except` so audit failures are non-fatal. `list_events()` returns most-recent-first, optionally filtered by `since` (ISO-8601 timestamp) and `type_prefix` (`LIKE 'prefix%'`). Invalid JSON in `payload` is silently returned as `null`. | `record(db, *, type, summary, actor_kind?, actor_id?, target_kind?, target_id?, payload?)`, `list_events(db, *, limit, since?, type_prefix?)` |
| `profile_service` ✅ | Reads and writes operator profile metadata from the `user_settings` singleton. Computes `avatar_letter` on every read (not stored). Pass `""` to clear a field; pass `None` to leave it unchanged. | `get_profile(db)` → `ProfileResponse`, `update_profile(db, *, display_name?, email?)` → `ProfileResponse` |
| `transcoding_service` ✅ | Discovers available FFmpeg encoders by parsing `ffmpeg -encoders` output (cached for server lifetime). Probes GPU utilization via vendor-specific tools (nvidia-smi / intel_gpu_top / radeontop / system_profiler). `_TEST_RESULTS: dict[str, EncoderTestResult]` stores `passed`, `error` (first stderr line ≤240 chars), and `tested_at` per encoder. Builds `TranscodingStatusResponse` with active encoder, available encoders, per-encoder loads (including `encoder_test_error` + `encoder_tested_at`), and per-session metadata. | `get_transcoding_status(db)` → `TranscodingStatusResponse` |
| `encoder_advisor` ✅ | Pure function `recommend(active, available, test_results) -> Recommendation`. Priority rules: (1) active failed self-test → recommend best tested-passing alternative; (2) active is software + tested-passing GPU available → recommend GPU encoder; (3) active is HEVC → compatibility note; (4) none. Vendor preference: NVIDIA → Intel → AMD → Apple. Never recommends untested encoders. | `recommend(active, available, test_results)` |
| `hardware_probe` ✅ (Slice B) | Per-OS CPU + GPU enumeration. Linux: `lspci -nn -d ::0300` + `nvidia-smi -L` + walks `/dev/dri/render*`. Windows: `wmic path Win32_VideoController` + supplements NVIDIA rows from `nvidia-smi` (wmic AdapterRAM caps at ~4 GB on 32-bit). macOS: `system_profiler SPDisplaysDataType -json`. Vendor normalisation maps free-form strings to canonical `nvidia` / `intel` / `amd` / `apple` / `unknown`. Lifetime cache; failure returns empty list, never raises. | `detect_hardware()` → `{cpus: [...], gpus: [...]}`, `reset_cache()` |
| `session_router` ✅ (Slice C) | Multi-encoder priority-chain walker for transcode sessions. `pick_encoder(chain, session_id, *, default_encoder)` walks the chain and returns `(encoder, reason)` where reason ∈ {`configured`, `gpu_session_cap_hit`, `all_encoders_saturated`, `encoder_unknown`}. Reserves a slot against the encoder's `concurrent_session_cap` (NVENC = 3 on consumer cards); `release_session` frees it in `stop_stream`. 50-entry FIFO ring buffer of routing decisions. Stream-copy bypasses the router entirely. | `parse_chain(raw)` / `encode_chain(chain)`, `pick_encoder(chain, session_id, *, default_encoder)`, `release_session(session_id)`, `get_session_encoder(session_id)`, `get_history()` |
| `log_service` ✅ | Reads the JSON-line log file (`~/.fluxora/logs/server.log`) and provides filtered, cursor-paginated access. Also runs an in-process `BroadcastHandler` attached to the root Python logger at startup that fans every emitted record to subscribed asyncio queues (drop on slow consumers). | `list_logs(*, level?, source?, since?, until?, q?, limit, cursor)` → `LogListResponse`, `subscribe()` → `asyncio.Queue`, `unsubscribe(q)` |
| `client_codec_service` ✅ (plan 20) | Per-client codec fallback blocklist — records `(client_id, source_codec)` pairs when the auto-fallback endpoint fires. Consulted at `/stream/start` time only when `streaming_mode='auto'`; strict modes ignore it. | `is_blocked(db, client_id, source_codec)` → `bool`, `add_block(db, client_id, source_codec, reason)` (idempotent) |
| `support_bundle_service` ✅ (2026-05-06) | Operator-side field-debug bundle generator. Builds a gzipped tar in memory containing `metadata.json`, `system/stats.json` (one psutil snapshot via `system_stats.collect`), `system/encoders.json` (snapshot of encoder self-test results from `transcoding_service.get_test_results()`), `settings/redacted.json` (`user_settings` row with `tmdb_api_key` / `license_key` / `email` replaced by `***REDACTED***` sentinel; null stays null), `database/schema.sql` (`sqlite_master` DDL — never row data), and `logs/*` (active rotating log + up to 4 rotated siblings). Each sub-collector wrapped in try/except → ships partial bundle with `_collect_error` markers rather than aborting. Caller delivers via `Response(content=bytes, media_type="application/gzip", headers={"Content-Disposition": ...})`. | `generate_support_bundle(db)` → `(filename, gzipped_tar_bytes)` |
| `transcoding_service.get_test_results()` ✅ (added 2026-05-06) | Public read-only snapshot of the encoder self-test cache (`_TEST_RESULTS`). Returns a shallow copy so callers can iterate without holding a reference to the live mutable dict. Added to give `support_bundle_service` a stable accessor instead of reaching into private state. | `get_test_results()` → `dict[str, EncoderTestResult]` |
| `benchmark_service` ✅ | Synthetic FFmpeg encode-per-encoder for performance comparison (desktop "Run Benchmark" button). Sequential — running encodes in parallel would contend for GPU + CPU and produce noise. Generates a `lavfi testsrc` source through each encoder, muxes to `mpegts`, pipes to `-f null -`. Streams stderr (not tempfile) so the first `frame=N≥1` line timestamps `init_ms`. Midpoint GPU probe (at `duration_sec / 2`) samples vendor-specific tools for hardware encoders. Clamps duration `[2, 20]` s, fps `[24, 60]`, resolution; 35 s per-encoder timeout (libx265 on slow CPUs hits this and the operator learns the encoder can't drive a live stream). Live progress snapshot via `get_progress()` for desktop polling. | `run_benchmark(...)` → `list[EncoderBenchmarkResult]`, `clamp_duration()`, `clamp_fps()`, `clamp_resolution()`, `clamp_resolutions()`, `get_progress()` |
| `benchmark_history_service` ✅ | Persistence layer for benchmark runs (migration 024). Stores top-level metadata + per-encoder JSON in a single JSON column rather than a relational split — runs are always fetched as one unit and the join would buy nothing at this scale. `encoder_count` denormalized for cheap list-summary queries. Pruned to `_HISTORY_LIMIT=50` after every save so the table stays bounded without a separate background task. | `save_benchmark_run(db, *, started_at, finished_at, duration_sec, fps, width, height, verify_caps, results)` → autoincrement id, `list_benchmark_runs(db, *, limit)`, `get_benchmark_run(db, run_id)`, `delete_benchmark_run(db, run_id)`, `prune_history(db)` |
| `ffmpeg_capabilities` ✅ | One-shot `ffmpeg -version` probe at server startup; parses major.minor; exposes a frozen `FfmpegCapabilities` dataclass with `is_known` + `supports_readrate_initial_burst` properties so version-dependent cmd builders don't re-probe per-session. Lazy `_ffmpeg_bin` import at call-time so test monkey-patches propagate. Failure path returns the `_UNKNOWN` sentinel and callers fall back to the conservative subset. Streaming pipeline plan §17 M2. | `probe_ffmpeg_capabilities()`, `get_capabilities()` → `FfmpegCapabilities` |

---

## Background Jobs

| Job | Trigger | Frequency |
|-----|---------|-----------|
| Library re-scan | Manual (API or Control Panel) | On demand |
| HLS segment cleanup | Stream ends | On stream close |
| TMDB metadata enrichment | After file indexed | Background queue |
| mDNS broadcast | Server startup | Continuous |
| Session heartbeat timeout | No heartbeat in 30s | Periodic check (30s) |

---

## FFmpeg Pipeline Detail

`ffmpeg_service.start_stream` picks one of two pipelines per session by reading `media_files.codec_name` (back-filled at scan time via FFprobe — migration 016). Files that pre-date that migration trigger a one-time lazy probe at stream-start (~200 ms) and the result is persisted; the next play of the same file is constant-time.

### Stream-copy path (h264 / hevc sources)

When the source video is already h264 or hevc — the typical case for personal libraries — FFmpeg just *remuxes* into HLS without re-encoding, dropping CPU usage by ~95 % vs. a full transcode. Audio is still re-encoded to AAC 128 kb/s because source audio may be AC3/DTS/FLAC and not all HLS clients decode those.

```
Input: /media/movies/Inception.mkv  (h264 + AC3)
    │
    └──▶ ffmpeg -i <input>
              -c:v copy               # No re-encode — remux only
              -c:a aac -b:a 128k      # Re-encode audio (cheap, <3% CPU)
              -f hls
              -hls_time 10            # bumped from 6 to accommodate long-GOP sources
              -hls_list_size 0
              -hls_segment_type mpegts          # h264: mpegts
              -hls_segment_type fmp4            # hevc: fmp4 (Apple HLS spec)
              # Note: -hls_flags independent_segments is NOT used for stream-copy.
              # The flag asserts every segment starts with an IDR keyframe — true for
              # transcode (encoder emits IDRs at segment boundaries) but false for
              # stream-copy when the source GOP exceeds hls_time. Game captures
              # (ShadowPlay / OBS) commonly ship 4-10s GOPs.
              /tmp/fluxora/{session_id}/playlist.m3u8
```

For hevc the segment type switches to `fmp4` (`.m4s`) and an `init.mp4` is auto-emitted referenced via `EXT-X-MAP` in the playlist. Apple's HLS spec requires fMP4 for hevc — `mpegts` segments don't reliably carry hevc.

### Full transcode path (vp9 / av1 / mpeg4 / unknown)

Falls through to the configured encoder from `user_settings.transcoding_encoder` (libx264 by default; hardware encoders `h264_nvenc` / `hevc_nvenc` / `h264_qsv` / etc. if the operator selected them in Settings → Transcoding). Hardware-accel hints (`-hwaccel cuda` etc.) are added from the encoder registry via `pre_input_args()`. For NVIDIA encoders, `_input_decoder_args()` also injects a cuvid decoder hint (e.g. `-c:v av1_cuvid`) before `-i` to keep decoded frames on the GPU and avoid broken software-decoder paths. If cuvid rejects the source's chroma format, `_is_cuvid_failure()` detects the stderr pattern and a second attempt is made without the cuvid hint.

```
ffmpeg [pre_input_args: -hwaccel cuda -hwaccel_output_format cuda]
       [-c:v av1_cuvid]                    # NVIDIA only + cuvid map match
       -i <input>
       -c:v libx264 -preset veryfast -crf 23
       -c:a aac -b:a 128k
       -f hls -hls_time 6 -hls_list_size 0
       -hls_segment_type mpegts
       -hls_flags independent_segments
       /tmp/fluxora/{session_id}/playlist.m3u8
```

### Diagnostics

Every session writes FFmpeg's stderr to a per-session temp file (`fluxora-ffmpeg-{session_id}-*.log` under the OS temp dir). On premature exit or playlist-creation timeout, `start_stream` reads the last 4 KB of the file, logs it, and bubbles the first stderr line up through the `RuntimeError` — so the operator notification's exception message names the actual reason ("No NVENC capable devices found" / "Cannot use both -hls_time and …" / etc.) instead of a generic "FFmpeg failed". The temp file is unlinked in `stop_stream`.

The log line `FFmpeg pipeline: session=… mode=stream-copy(h264/mpegts) source_codec=h264` records which path each session took.

---

## External Integrations

| Integration | Purpose | Auth Method |
|------------|---------|------------|
| TMDB API | Movie/TV metadata, posters | API Key (user-provided or default) |
| STUN Server | WebRTC NAT traversal | None (public servers) |
| TURN Server | WebRTC relay fallback | Username + Credential |
| Polar | Payment webhooks for license key issuance | Standard Webhooks HMAC secret |

---

## Error Handling Strategy

| Error Type | Handling |
|-----------|---------|
| FFmpeg not found | Startup check; graceful error with install instructions |
| FFmpeg transcode failure | Return 503; log stderr; cleanup temp files |
| SQLite locked | Retry with exponential backoff (WAL mode reduces this) |
| TMDB API down | Cache last known metadata; log + skip enrichment |
| Client token expired | Return 401; client must re-pair |
| Stream concurrency exceeded | Return 429 with `Retry-After` header |
| Polar webhook invalid signature | Return 403 before parsing JSON |
| Polar webhook secret missing | Return 501 so production misconfiguration is visible |

---

## Logging Strategy

- **Library:** Python `logging` module → structured JSON logs
- **Level:** INFO in prod, DEBUG in dev
- **Outputs:** Console (stdout, human-readable string formatter) + rotating file (`~/.fluxora/logs/server.log`, **JSON formatter** via `python-json-logger`)
- **File format:** Every line is a JSON object with fields `asctime`, `levelname`, `name`, `message` — parseable by `log_service.py`
- **Live tail:** `BroadcastHandler` is attached to the root logger at startup and fans each `LogRecord` to all subscribers of `WS /api/v1/ws/logs`
- **Key events to log:** Stream start/end, library scans, auth events, FFmpeg errors
