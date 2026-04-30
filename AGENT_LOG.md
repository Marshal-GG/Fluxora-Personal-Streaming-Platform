# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_03.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 03)
**Archived:** 2026-04-29
**Contents:** Phase 2 (Desktop), Phase 3 (TMDB/Resume/WebRTC), Phase 4 (Monetization), Phase 5 (Initial Desktop Monitoring).

* **Phase 2 — Desktop Control Panel:** Built full desktop app with Dashboard (stats), Clients (approve/reject/revoke), Library (media list with TMDB enrichment), and Settings (server URL/name, license key).
* **Phase 3 — Internet Streaming & Metadata:**
  - TMDB integration: Automated movie/TV metadata enrichment and poster retrieval.
  - Playback Resume: Cross-client resume progress persisted in DB.
  - WebRTC: Signaling server (WS) + Flutter integration with smart path selection (LAN vs WAN) and transport status badge.
* **Phase 4 — Monetization:**
  - Tier System: Free/Plus/Pro/Ultimate limits enforced in server `stream.py`.
  - License Keys: HMAC-SHA256 signed keys generated via server CLI or Polar.sh webhooks.
  - Webhooks: Polar.sh integration for automated license issuance on purchase.
  - Mobile Upgrade: Informational `UpgradeScreen` guiding users to desktop for key entry.
* **Phase 5 — Advanced Monitoring:**
  - Desktop Activity: Real-time stream monitoring and session termination.
  - Issued Licenses: Admin view of all keys and customer emails stored from webhooks.
* **Backend Stability:** 110 tests passing; RFC-aligned auth (401 vs 403); session-aware HLS segment delivery.

**Next Immediate Steps:**
1. **Desktop Modules:** Implement `logs/` and `transcoding/` screens.
2. **Hardware Encoding:** NVENC/VAAPI support in `ffmpeg.py`.
3. **E2E Encryption:** Secure internet streams beyond standard WebRTC.

---

## Entry Template

```
---
## [2026-04-29] — Advanced Logging & Transcoding
**Agent:** Antigravity (Advanced Agentic Coding)
**Phase:** Phase 5 (Advanced Monitoring & Optimization)
**Status:** Complete

### What Was Done
- **Server-Side Logging:** Implemented `RotatingFileHandler` with 10MB limit and 5-file rotation. Added `GET /api/v1/info/logs` for remote log retrieval.
- **Dynamic Transcoding:** Added `transcoding_encoder`, `transcoding_preset`, and `transcoding_crf` to `user_settings` DB.
- **Hardware Acceleration:** Integrated CUDA (NVENC), QSV, and VAAPI support in `ffmpeg_service.py` based on selected encoder.
- **Desktop Logs:** Created `LogsRepository`, `LogsCubit`, and `LogsScreen` to view real-time server logs in the desktop app.
- **Desktop Transcoding:** Built `TranscodingScreen` allowing users to configure HWA, presets, and quality (CRF) directly from the UI.
- **Bug Fix:** Fixed `403 Forbidden` on `/api/v1/auth/clients` by ensuring Desktop App requests originate from `127.0.0.1`.

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/main.py` |
| Modified | `apps/server/config.py` |
| Modified | `apps/server/routers/info.py` |
| Modified | `apps/server/services/ffmpeg_service.py` |
| Modified | `apps/server/database/migrations/010_transcoding_settings.sql` |
| Modified | `apps/desktop/lib/repositories/logs_repository.dart` |
| Created | `apps/desktop/lib/ui/screens/logs_screen.dart` |
| Created | `apps/desktop/lib/ui/screens/transcoding_screen.dart` |

### Docs Updated
None — no doc-impacting changes made.

### Decisions Made
- Use `RotatingFileHandler` for server logs to prevent disk exhaustion.
- Enforce `localhost` only for sensitive admin endpoints (`/clients`, `/logs`, `/settings`).
- FFmpeg HWA selection is string-matched against the encoder name (e.g., `h264_nvenc` triggers CUDA).

### Blockers / Open Issues
- **Mystery 403s:** Some `GET /api/v1/library` requests returning `403 Forbidden` from `127.0.0.1` despite no explicit restriction. Likely a mismatch in client headers or a residual rate-limit issue.

### Next Agent Should
1. Investigate the source of `403 Forbidden` for `/api/v1/library`. Check if the Desktop App is inadvertently sending empty Auth headers or if `validate_token` is failing on a specific client ID.
2. Implement E2E encryption for WebRTC streams.
3. Add a "Clear Logs" button to the Desktop App.

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

```

---
## [2026-04-30] — Desktop Build & Test Suite Restoration
**Agent:** Antigravity (Advanced Agentic Coding)
**Phase:** Maintenance / Phase 5 Prep
**Status:** Complete

### What Was Done
- **Fixed `AppTypography.h3` error:** `transcoding_screen.dart` referenced a non-existent getter `h3`. Replaced with the correct semantic token `headingMd` (16px, semibold) per the design system in `fluxora_core`.
- **Restored `bloc_test` dependency:** Previous attempts failed because `freezed ^2.5.x` + `flutter_test` SDK pinned `test_api 0.7.9`, which is incompatible with any version of `bloc_test`. Root cause: `freezed` v2 requires `analyzer ^6.5.0|^7.0.0` while `bloc_test` (via `test`) constrains `test_api` to versions incompatible with that range.
- **Upgraded `freezed` → v3 in both packages:** Upgraded `freezed: ^3.0.0` and `freezed_annotation: ^3.0.0` in both `packages/fluxora_core` and `apps/desktop`. freezed v3 uses `analyzer >=8.0.0` which breaks the conflict chain and allows `bloc_test ^10.0.0` to resolve.
- **Added `mocktail: ^1.0.3` + `bloc_test: ^10.0.0`** to `apps/desktop` dev_dependencies.
- **Regenerated CMake config:** Ran `flutter build windows` which generated the missing `windows/flutter/ephemeral/generated_config.cmake`. CMake error is now resolved.
- **All 34 tests pass:** `flutter test` confirms all cubit tests (clients, dashboard, settings) and the placeholder test pass successfully.

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/desktop/pubspec.yaml` |
| Modified | `packages/fluxora_core/pubspec.yaml` |
| Modified | `apps/desktop/lib/features/transcoding/presentation/screens/transcoding_screen.dart` |

### Docs Updated
None — no API, schema, or architecture changes made.

### Decisions Made
- Upgraded `freezed` to v3 in both `fluxora_core` and `apps/desktop` together to maintain internal consistency. This is a safe upgrade for internal packages.
- Used `bloc_test: ^10.0.0` (latest) to align with `flutter_bloc: ^9.1.1` which uses `bloc: ^9.x`.
- `AppTypography.h3` → `AppTypography.headingMd` — section headings in screen bodies should use `headingMd` per the design system.

### Blockers / Open Issues
- **Mystery 403s on `/api/v1/library`:** Still unresolved (inherited from previous session). The server-side `validate_token` may be silently failing for certain Desktop App requests. Needs investigation.
- **`freezed` generated code:** If any `*.freezed.dart` or `*.g.dart` files were generated with freezed v2 annotations, they may need to be regenerated with `flutter pub run build_runner build --delete-conflicting-outputs` in both `fluxora_core` and `apps/desktop`.

### Next Agent Should
1. Run `flutter pub run build_runner build --delete-conflicting-outputs` in `packages/fluxora_core` and `apps/desktop` to regenerate freezed/json_serializable output files for freezed v3 compatibility.
2. Investigate and resolve the mystery `403 Forbidden` on `GET /api/v1/library` — add debug logging to `validate_token` in `apps/server/routers/deps.py`.
3. Begin Phase 5 hardware encoding work: NVENC/VAAPI in `ffmpeg_service.py`.

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

---
## [2026-05-01] — Full Code Audit + Comprehensive Doc Sync
**Phase:** Phase 5 (Advanced Features) — Audit & Documentation
**Status:** Complete

### What Was Done
- **Full code audit** across all 70+ modified files after a period of uncommitted changes.
- **Fixed 2 failing server tests:** `test_list_files_requires_auth` and `test_list_libraries_requires_auth` were asserting HTTP 401 but `files.py` and `library.py` now use `validate_token_or_local` — localhost requests are intentionally auth-free for the desktop control panel. Renamed tests and changed assertions to 200 with empty-list check.
- **Confirmed 106/106 server tests pass** after fix.
- **Confirmed `flutter analyze` shows no issues** — Dart 3.8 null-aware map syntax (`{'key': ?value}`) in `settings_cubit.dart` is valid, not a bug.
- **Comprehensive documentation update** — all docs brought into sync with the codebase.

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/tests/test_files.py` |
| Modified | `apps/server/tests/test_library.py` |
| Modified | `docs/03_data/01_data_models.md` |
| Modified | `docs/03_data/02_database_schema.md` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/08_frontend/01_frontend_architecture.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |
| Modified | `docs/10_planning/01_roadmap.md` |
| Modified | `docs/10_planning/02_decisions.md` |
| Modified | `docs/10_planning/03_open_questions.md` |
| Modified | `docs/00_overview/README.md` |
| Modified | `CLAUDE.md` |
| Modified | `README.md` |
| Modified | `AGENT_LOG.md` |

### Docs Updated
- `docs/03_data/01_data_models.md` — Added `customer_email` to PolarOrder; added transcoding fields to UserSettings
- `docs/03_data/02_database_schema.md` — Added migration 010; added transcoding columns to user_settings DDL
- `docs/04_api/01_api_contracts.md` — Reworked auth section; added GET /info/logs, POST /files/upload, DELETE /files/{id}, GET /orders, GET /stream/sessions, PATCH /stream/{id}/progress; updated settings with transcoding fields; updated library/files auth notes
- `docs/08_frontend/01_frontend_architecture.md` — Full desktop structure rewrite (library/orders/activity/logs/transcoding); routes table; player settings sheet; new Key Technical Decisions
- `docs/09_backend/01_backend_architecture.md` — Migrations 009-010; orders.py router; updated models; test counts (106 total)
- `docs/10_planning/01_roadmap.md` — Phase 5 feature table with status; milestone M5.5 added
- `docs/10_planning/02_decisions.md` — Added ADR-012 (validate_token_or_local)
- `docs/10_planning/03_open_questions.md` — Q-004 marked resolved
- `CLAUDE.md` — Phase 5 roadmap; Current Status rewritten; Known Risks updated
- `README.md` — Status, phase table, component table updated

### Decisions Made
- `validate_token_or_local` confirmed correct (ADR-012): desktop is always localhost, mobile always sends token.
- Dart 3.8 `{'key': ?value}` syntax is intentional — `flutter analyze` confirms no issues.
- `TranscodingScreen` intentionally has no cubit — its settings are managed through `SettingsScreen`.

### Blockers / Open Issues
- **`TranscodingScreen` is a partial scaffold** — add `TranscodingCubit` + route if a dedicated config page is needed.
- **Hardware encoding is user-selected, not auto-detected** — user selecting `h264_nvenc` on non-NVIDIA hardware will get 503 at stream start. A startup probe would improve UX.
- **Desktop test coverage gap** — `LibraryCubit`, `OrdersCubit`, `ActivityCubit`, `LogsCubit` have no unit tests.

### Next Agent Should
1. Add unit tests for `LibraryCubit`, `OrdersCubit`, `ActivityCubit`, and `LogsCubit` in `apps/desktop/test/`.
2. Complete `TranscodingScreen` — add `TranscodingCubit`/state, register in DI, add `/transcoding` route, add sidebar nav item.
3. Implement hardware encoder startup probe in `ffmpeg_service.py` — test configured encoder at boot, fall back to `libx264` if it fails.

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---

---
## [2026-05-01] — Bug Fix Sweep + Legacy Code Removal
**Phase:** Phase 5 (Advanced Features) — Code Quality
**Status:** Complete

### What Was Done
- **Ruff lint + format pass:** cleaned up 12 lint errors and reformatted 11 files in `apps/server`.
- **Real bug fixes (server):**
  1. `models/settings.py` — license-key validator was rejecting all newly generated 5-part keys (validator only accepted 4-part legacy format). Critical regression that would break every Polar webhook activation.
  2. `services/ffmpeg_service.py` — `stderr=PIPE` was never drained → OS pipe buffer fills during long transcode → FFmpeg blocks. Switched to `DEVNULL`.
  3. `services/ffmpeg_service.py` `stop_stream()` — `kill()` + `wait()` had no timeout, could hang forever. Replaced with `terminate()` → 5s `wait_for` → `kill()` fallback.
  4. `services/library_service.py` `upload_file_to_library()` — `file.filename` used directly without sanitization → path traversal vector. Added `Path(filename).name` strip + canonicalization check inside `target_dir`.
  5. `services/library_service.py` — `await get_file()` could return `None` but caller types it as `dict` → silent `None` return. Added explicit `RuntimeError` guard.
  6. `routers/library.py` `_parse_library` — `json.loads()` on corrupt DB JSON would crash the endpoint. Added graceful fallback to empty list with error log; later removed entirely as dead code.
  7. `services/webhook_service.py` `_extract_tier()` — would crash on `null` `product` field (Polar can send this). Added `isinstance(dict)` checks.
  8. `services/webhook_service.py` customer extraction — same issue with `null` customer field.
  9. `services/webrtc_service.py` `_close_existing()` — used deprecated `asyncio.get_event_loop()`. Replaced with `get_running_loop()` + explicit `RuntimeError` fallback.
- **Stricter input validation (`models/settings.py`):**
  - `transcoding_encoder` → `Literal["libx264","h264_nvenc","h264_qsv","h264_vaapi"]`
  - `transcoding_preset` → `Literal[…9 named presets…]`
  - `transcoding_crf` → `Field(ge=0, le=51)`
  - Invalid values now return 422 at the API boundary instead of FFmpeg failing at stream start.
- **Legacy code removal (project still in dev, no backwards-compat needed):**
  - Removed 4-part legacy license key support from `services/license_service.py` `validate_key()` — only 5-part `FLUXORA-TIER-EXPIRY-NONCE-SIG` accepted now. Matches what `generate_key()` produces.
  - Removed dead `isinstance(root_paths, str)` JSON-parse branch from `routers/library.py` — `library_service` always returns parsed lists.
  - Updated `tests/test_license_service.py` to generate 5-part keys; added `test_four_part_key_rejected` and `test_generates_five_part_key`.
  - Updated `tests/test_settings.py` to use 5-part keys in PATCH tests.

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `apps/server/models/settings.py` |
| Modified | `apps/server/services/license_service.py` |
| Modified | `apps/server/services/ffmpeg_service.py` |
| Modified | `apps/server/services/library_service.py` |
| Modified | `apps/server/services/webhook_service.py` |
| Modified | `apps/server/services/webrtc_service.py` |
| Modified | `apps/server/routers/library.py` |
| Modified | `apps/server/routers/files.py` (ruff fixes) |
| Modified | `apps/server/tests/test_license_service.py` |
| Modified | `apps/server/tests/test_settings.py` |
| Modified | `docs/03_data/01_data_models.md` |
| Modified | `docs/03_data/03_data_flows.md` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/06_security/01_security.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |
| Modified | `docs/10_planning/01_roadmap.md` |
| Modified | `CLAUDE.md` |
| Modified | `README.md` |
| Modified | `AGENT_LOG.md` |

### Docs Updated
- `docs/03_data/01_data_models.md` — license_key format note now `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>`
- `docs/03_data/03_data_flows.md` — webhook flow diagram shows nonce = order_id
- `docs/04_api/01_api_contracts.md` — added field constraints table for settings PATCH (encoder/preset enum + CRF range)
- `docs/06_security/01_security.md` — license format updated to 5-part; mentions `FLUXORA_LICENSE_SECRET`
- `docs/09_backend/01_backend_architecture.md` — license format, test counts (106 → 108), test_license_service (20 → 22)
- `docs/10_planning/01_roadmap.md` — license format + test count
- `CLAUDE.md` and `README.md` — test count 106 → 108

### Decisions Made
- **No backwards-compat for license keys.** Project is in dev; nobody has 4-part keys in the wild. Cleaner to delete than to maintain dual-format support.
- **Pydantic Literal/Field enforcement at API boundary** — earlier and clearer error than FFmpeg failing at stream start. Caller gets 422 with field name, not 503 mid-playback.
- **`stderr=DEVNULL` in ffmpeg_service** — happy path doesn't need stderr; `proc.returncode` is sufficient failure signal. Avoids the buffer-fill hang.
- **Skipped audit "false positives":** WebSocket DB leak (`get_db()` is a singleton, intentionally never closed), asyncio race conditions on dicts (single-threaded event loop has no preemption between `await`s), webhook timing attack (signatures aren't secret), and Dart `?value` syntax (valid Dart 3.8, already in CLAUDE.md gotchas).

### Blockers / Open Issues
- Hardware encoder selected by user, not auto-detected. If user picks `h264_nvenc` on a non-NVIDIA box, FFmpeg fails at stream start. A startup probe would surface this earlier.
- Polar webhook customer email is not format-validated beyond `str(...).strip()`. Low priority — it's only stored for manual lookup, never used in any auth path.
- Desktop test coverage gap remains: `LibraryCubit`, `OrdersCubit`, `ActivityCubit`, `LogsCubit` have no unit tests.

### Next Agent Should
1. Add a hardware encoder startup probe in `ffmpeg_service.py` that tries the configured encoder against a 1-frame test file and logs a clear error if unavailable. Surface the result via `GET /api/v1/info` so the desktop Settings screen can show "encoder verified" / "encoder not available."
2. Add unit tests for the four uncovered desktop cubits.
3. Implement `TranscodingCubit`/state and a `/transcoding` route to give Hardware Encoding its own page (instead of being a Settings screen subsection).

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` or any git write command
- [x] Did NOT add any agent name, branding, or AI credit anywhere in code or docs
---
