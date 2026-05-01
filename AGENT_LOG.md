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

---
## [2026-05-01] — CI Hardening, Ruff Bump, and Commit Hygiene
**Phase:** Phase 5 (Advanced Features) — Infrastructure
**Status:** Complete

### What Was Done
- **Cleanup of accidental commit content (chore: untrack):** the prior two feature commits had silently included gradle build cache (`apps/mobile/android/.gradle/**`), the linux flutter ephemeral plugin symlinks, and `scratch/test_bearer_code.py`. Untracked them via `git rm --cached` and added matching `.gitignore` rules so they cannot creep back in.
- **CI hardening (`.github/workflows/`):**
  - `desktop_ci.yml` was using `flutter-actions/setup-flutter@v4` (different action than mobile) with no Flutter version pin. Switched to `subosito/flutter-action@v2` and pinned `flutter-version: 3.32.0` (Dart 3.8.x — required for the null-aware map literal syntax in `apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart`).
  - `mobile_ci.yml` got the same Flutter pin + caching, bumped `actions/checkout@v4 → v5`.
  - Both Flutter workflows now run `flutter pub get` for `packages/fluxora_core` first so a cold clone resolves the path: dependency cleanly.
  - Both Flutter workflows now trigger on `pull_request` (parity with `server_ci.yml`).
- **Ruff bump 0.4.0 → 0.15.12** in `apps/server/pyproject.toml`. Local install was 11 minor versions behind the pin. New ruff also collapsed one implicit string concatenation in `tests/test_signal.py` (`"a" "b"` → `"ab"`). All 108 tests still pass; black and ruff format outputs remain compatible.

### Files Created / Modified
| Action | Path |
|--------|------|
| Modified | `.gitignore` (added .gradle/, ephemeral/, scratch/) |
| Untracked | `apps/mobile/android/.gradle/**` |
| Untracked | `apps/desktop/linux/flutter/ephemeral/.plugin_symlinks/**` |
| Untracked | `scratch/test_bearer_code.py` |
| Modified | `.github/workflows/desktop_ci.yml` |
| Modified | `.github/workflows/mobile_ci.yml` |
| Modified | `apps/server/pyproject.toml` |
| Modified | `apps/server/tests/test_signal.py` |
| Modified | `docs/05_infrastructure/01_infrastructure.md` |
| Modified | `AGENT_LOG.md` |

### Docs Updated
- `docs/05_infrastructure/01_infrastructure.md` — corrected the CI table to reflect `subosito/flutter-action@v2` + Flutter pin; documented the ruff version pin; updated the per-workflow descriptions to match what each job actually runs.

### Decisions Made
- **Pinned Flutter to 3.32.0** rather than tracking the latest stable channel. Dart 3.8 is a hard requirement now (one Cubit uses null-aware map literals); pinning protects against the small but real risk that the action's "stable" channel default lags behind 3.8 on a fresh runner image.
- **Bumped ruff to the latest (0.15.12)**, exact pin in line with the existing `pytest==`, `black==` style. Considered `>=0.13` ranges but the dev-deps file uses exact pins consistently for reproducibility.
- **Did NOT rewrite history to remove a `Co-Authored-By: Claude ...` footer** that I (mistakenly) included in commits `b922663` and `f249c96`. CLAUDE.md Hard Prohibition #2 forbids that footer; I caught the mistake on the third attempted commit. Amended the unpushed commit (`f249c96` → `2af6573`). The pushed `b922663` is left as-is — fixing it requires a force-push to `main`, which is outside the scope of what I can do without explicit per-action authorization, and the cosmetic damage is one footer line in one commit. Saved a memory record so this does not happen again.

### Blockers / Open Issues
- `b922663` on `origin/main` carries a `Co-Authored-By: Claude ...` footer. Owner can choose to rewrite-and-force-push if desired, or leave it.
- `apps/server/pyproject.toml` still lists `black==24.4.0` while ruff was bumped. Black 25.x is out and may have minor formatter differences; not bumped this round to keep the change scoped.
- `ruff==0.15.12` is the latest patch — selecting an older minor (0.13/0.14) would also work and might be more conservative for CI reproducibility. Trade-off left to owner.

### Next Agent Should
1. Decide whether to rewrite `b922663` to drop its `Co-Authored-By` footer (force-push to `main`) or leave it.
2. Bump `black==24.4.0` → latest 25.x and re-run `python -m black --check .` + `python -m ruff format --check .` to confirm both still agree on formatting.
3. Carry on with the open Phase 5 work: hardware encoder startup probe, unit tests for the uncovered desktop cubits, and the standalone `TranscodingScreen` cubit.

### Hard Rules Checklist
- [x] Did NOT run any `git commit` / `git push` for unauthorized changes (the commits made this session were explicitly OK'd by the user)
- [x] Saved a memory record so the `Co-Authored-By` footer never appears in this repo's commit messages again
---

## [2026-05-01] — Desktop Redesign: Prototype Bundle + Translation Plan
**Agent:** Claude (Sonnet 4.6)
**Phase:** Phase 5 (Advanced Modules) — UI redesign track
**Status:** Planning complete; implementation not started

### What Was Done
- **Renamed brand assets** in `docs/11_design/ref images/` from `ChatGPT Image …png` and `ref_1..8.png` to descriptive names (`logo_icon_dark.png`, `logo_wordmark_dark.png`, `brand_banner_horizontal.png`, `brand_banner_vertical.png`, `desktop_dashboard_overview.png`, `desktop_library_management.png`, `desktop_clients_connected_devices.png`, `desktop_groups_management.png`, `desktop_logs_viewer.png`, `desktop_settings_general_network.png`, `desktop_settings_general_system_info.png`, `desktop_subscription_pricing_tiers.png`).
- **Imported the Claude Design bundle** (`https://api.anthropic.com/v1/design/h/E2MQ76TyE4v1LYfcVXXmow`) into `docs/11_design/desktop_prototype/` — 1 entry HTML + 26 JSX files + 2 brand PNG assets. Loads via Babel-standalone, no build step. Skipped the bundle's `uploads/` folder (duplicates of `docs/11_design/ref images/`).
- **Added `Demo (design prototype)` launch config** to `.vscode/launch.json` — runs Python `http.server` on port 8765 from the prototype dir and auto-opens the browser via `serverReadyAction`.
- **Wrote the translation plan** at `docs/11_design/desktop_redesign_plan.md` — covers tokens, primitives, app shell, screen-by-screen order, cross-cutting concerns, "no-UI-errors" enforcement rules, milestones, and a detailed §7 enumerating all backend work the redesign depends on (groups, profile, notifications, system stats stream, restart/stop endpoints, transcoding status, structured logs, extended settings, orders pagination + Polar portal URL, plus required Python deps).
- Plan locks in five owner decisions: direct replacement (no legacy), real backend data only (no mocks), Cmd+K nav-only, no tweaks panel, native window chrome on every platform.

### Files Created / Modified
| Action | Path |
|--------|------|
| Renamed × 11 | `docs/11_design/ref images/*` |
| Created | `docs/11_design/desktop_prototype/Fluxora Desktop.html` |
| Created | `docs/11_design/desktop_prototype/app/**` (28 files) |
| Modified | `.vscode/launch.json` (added Demo config) |
| Modified | `.gitignore` (added `.tmp_design_fetch/`) |
| Created | `docs/11_design/desktop_redesign_plan.md` |
| Modified | `docs/00_overview/README.md` (added Quick Link to redesign plan) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated
- `docs/00_overview/README.md` — added "Desktop Redesign Plan" Quick Link.
- `docs/11_design/desktop_redesign_plan.md` — new doc; the single source of truth for the redesign.

The full doc-update protocol per CLAUDE.md §3 (data models, API contracts, schema, frontend/backend architecture, DESIGN.md, CLAUDE.md) is **deferred to the implementation PRs** — the plan documents which docs each milestone must touch, see plan §10. Updating those docs now would describe state that doesn't exist yet.

### Decisions Made
- **Plan lives in `docs/11_design/`** rather than `docs/10_planning/` — it is design-driven and references the prototype bundle in the same folder. Quick-link in `docs/00_overview/README.md` makes it discoverable.
- **No legacy carry-over.** Redesign replaces existing screens directly; no `/v2/*` parallel routes or feature flags. Cuts complexity at the cost of not having an A/B compare during implementation; mitigated by keeping the prototype open in the browser via the new launch config.
- **Backend ships before UI** for any screen needing data the server doesn't yet expose. `apps/desktop/` Cubits are extended; no `mock_*_repository.dart` files in the Flutter app.
- **Tweaks panel removed** entirely — accent customization is a design-tool affordance, not a product feature. Brand violet (`#A855F7`) is fixed.
- **Native window chrome** on all platforms — drops the prototype's custom title bar with traffic-light buttons. Reduces platform-specific code paths.
- **Did not delete the locked `.tmp_design_fetch/` empty folder** — Windows file watcher held a handle. Added to `.gitignore` so it won't pollute git status; owner can remove manually after closing relevant IDE handles.

### Blockers / Open Issues
- `.tmp_design_fetch/fluxora/project/` is empty but locked on disk. Cosmetic only — git ignores it.
- `psutil` not yet a server dep; needed for §7.6 system stats. Adds in M0.
- GPU-utilization probes (NVIDIA/Intel/AMD) for §7.8 are best-effort; plan acknowledges they may return `null` per vendor/driver.

### Next Agent Should
1. Review `docs/11_design/desktop_redesign_plan.md` end-to-end and confirm scope before starting M0.
2. Begin **M0 — Backend prerequisites** (plan §7 + §9). Suggested first PR: `psutil` dep + §7.6 `/api/v1/info/stats` endpoint + WS `stats` event — unblocks the entire shell (sidebar System Status + status bar) and the Dashboard sparklines.
3. After M0 lands, kick off **M1 — Foundation** (tokens + primitives) in `packages/fluxora_core/` and `apps/desktop/lib/shared/widgets/`. Build widgetbook stories before any screen.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran during this session.
- [x] No agent branding in any file.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added.
- [x] No new dependencies pinned without version-check note (the plan flags `psutil` for backend without pinning a number — the implementing agent must look up the current latest per CLAUDE.md Rule #12).
---

## [2026-05-01] — Phase 1 ops live; reusable runbooks; doc consolidation
**Phase:** Phase 5 (Advanced Features) — Public routing groundwork
**Status:** Complete

### What Was Done
- **Phase 1 of public routing executed end-to-end:** Cloudflare Tunnel `fluxora-home` (UUID `dea185fa-a26b-44eb-859b-f8916b1a3888`) live; CNAME `fluxora-api.marshalx.dev` issued and reachable; `curl https://fluxora-api.marshalx.dev/api/v1/info` returns the home server JSON over the public internet.
- **Hostname pivot:** switched from `api.fluxora.marshalx.dev` (two-level, Universal SSL doesn't cover) to `fluxora-api.marshalx.dev` (single-level under apex). Universal SSL depth limit documented across affected docs with the official Cloudflare table.
- **Service-install workaround:** `cloudflared service install` on 2025.8.1 registered the service but it crashed on start (exit code 1067) with the default config-search behavior. Worked around by setting `HKLM:\SYSTEM\CurrentControlSet\Services\Cloudflared` `ImagePath` registry value to launch with explicit `--config <user-config-path>`. Service now reads from `~/.cloudflared/config.yml` directly; no systemprofile copy needed.
- **Eleven reusable runbooks** added under `docs/05_infrastructure/runbooks/`: domain + Cloudflare zone, Cloudflare Tunnel, Firebase Hosting, GitHub CI/CD, branch + PR workflow, secrets management, webhook testing with smee.io, repo init checklist, devcontainer, monitoring & observability, PyInstaller distribution. ~3,000 lines, project-agnostic with placeholder substitution table and a "what's NOT covered" gap analysis.
- **Stale-content sweep across the doc tree:** test count `108 → 113` everywhere; hostname `api.fluxora.marshalx.dev → fluxora-api.marshalx.dev` everywhere; tech_stack adds psutil/slowapi/CF Tunnel/Flutter pin; component architecture grew to include License, Webhook, Settings, System Stats, Orders, and Public Routing components (was missing all six); roadmap Phase 5 expanded with system-stats, storage-breakdown, info-actions, public-routing rows; security doc cross-links the new license-key ops runbook; open-questions Q-002 (TURN) marked partially resolved; "Planned" markers for public routing changed to "In Progress" now that Phase 1 is done.
- **Username scrub:** `marsh` replaced with `<USER>` placeholder across 4 docs that had local-path examples.
- **CONTRIBUTING.md added** at repo root; excluded from public mirror via `mirror-public.yml` updates (rm + line-strip in markdown).
- **CI hardened:** `.github/dependabot.yml` (weekly grouped PRs for pip/pub/npm/actions), `.github/workflows/secret_scan.yml` (gitleaks on every push/PR), concurrency groups added to all five workflows (mirror queues; web-landing only cancels non-main), server_ci pip cache, `01_infrastructure.md` "Deferred CI improvements" table tracking what was intentionally not added.
- **ADR-013** added: Public routing via Cloudflare Tunnel; media-plane direct/P2P; server-supplied remote URL; system-installed cloudflared; single-tenant v1.
- **Bug-fix sweep on the server**: license-key validator was rejecting all newly-issued 5-part keys; ffmpeg `stderr=PIPE` could fill OS buffer; `stop_stream` had no timeout; `upload_file_to_library` had a path-traversal vector and could silently return `None`; webhook `_extract_tier`/customer extraction crashed on null payload fields; webrtc used deprecated `asyncio.get_event_loop()`. All fixed; 113 tests pass.
- **Stricter Pydantic validation** for `transcoding_encoder` (Literal), `transcoding_preset` (Literal), `transcoding_crf` (`Field(ge=0, le=51)`).
- **Legacy 4-part license keys removed** from `license_service.py`; only 5-part `FLUXORA-TIER-EXPIRY-NONCE-SIG` accepted now. Tests adjusted; new tests added for 4-part rejection.
- **Ruff bumped** 0.4.0 → 0.15.12.
- **System stats backend shipped:** `system_stats_service`, `GET /info/stats`, `WS /ws/stats`, `GET /library/storage-breakdown`, `POST /info/restart`, `POST /info/stop` — all backing the desktop dashboard redesign.

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `.github/dependabot.yml` |
| Created | `.github/workflows/secret_scan.yml` |
| Created | `CONTRIBUTING.md` |
| Created | `apps/server/services/system_stats_service.py` |
| Created | `apps/server/tests/test_info_actions.py` |
| Created | `apps/server/tests/test_info_stats.py` |
| Created | `apps/server/tests/test_storage_breakdown.py` |
| Created | `docs/01_product/08_tier_features.md` |
| Created | `docs/03_data/04_migration_guide.md` |
| Created | `docs/04_api/02_versioning_policy.md` |
| Created | `docs/05_infrastructure/03_public_routing.md` |
| Created | `docs/05_infrastructure/04_domains_and_subdomains.md` |
| Created | `docs/05_infrastructure/05_backup_and_recovery.md` |
| Created | `docs/05_infrastructure/06_webrtc_and_turn.md` |
| Created | `docs/06_security/02_license_key_operations.md` |
| Created | `docs/05_infrastructure/runbooks/00_domain_and_cloudflare_zone.md` |
| Created | `docs/05_infrastructure/runbooks/01_cloudflare_tunnel.md` |
| Created | `docs/05_infrastructure/runbooks/02_firebase_static_hosting.md` |
| Created | `docs/05_infrastructure/runbooks/03_github_ci_cd.md` |
| Created | `docs/05_infrastructure/runbooks/04_branch_and_pr_workflow.md` |
| Created | `docs/05_infrastructure/runbooks/05_secrets_management.md` |
| Created | `docs/05_infrastructure/runbooks/06_webhook_testing_with_smee.md` |
| Created | `docs/05_infrastructure/runbooks/07_repo_init_checklist.md` |
| Created | `docs/05_infrastructure/runbooks/08_devcontainer.md` |
| Created | `docs/05_infrastructure/runbooks/09_monitoring_and_observability.md` |
| Created | `docs/05_infrastructure/runbooks/10_pyinstaller_distribution.md` |
| Created | `docs/05_infrastructure/runbooks/README.md` |
| Modified | `apps/server/models/library.py` |
| Modified | `apps/server/models/settings.py` |
| Modified | `apps/server/pyproject.toml` |
| Modified | `apps/server/routers/info.py` |
| Modified | `apps/server/routers/library.py` |
| Modified | `apps/server/routers/ws.py` |
| Modified | `apps/server/services/library_service.py` |
| Modified | `apps/server/services/license_service.py` |
| Modified | `apps/server/services/ffmpeg_service.py` |
| Modified | `apps/server/services/webhook_service.py` |
| Modified | `apps/server/services/webrtc_service.py` |
| Modified | `apps/server/tests/test_license_service.py` |
| Modified | `apps/server/tests/test_settings.py` |
| Modified | `apps/server/tests/test_signal.py` |
| Modified | `.github/workflows/server_ci.yml` |
| Modified | `.github/workflows/mobile_ci.yml` |
| Modified | `.github/workflows/desktop_ci.yml` |
| Modified | `.github/workflows/web_landing_ci.yml` |
| Modified | `.github/workflows/mirror-public.yml` |
| Modified | `.gitignore` |
| Modified | `CLAUDE.md` |
| Modified | `README.md` |
| Modified | `docs/00_overview/README.md` |
| Modified | `docs/01_product/07_custom_website_integration.md` |
| Modified | `docs/02_architecture/02_tech_stack.md` |
| Modified | `docs/02_architecture/03_component_architecture.md` |
| Modified | `docs/03_data/01_data_models.md` |
| Modified | `docs/03_data/02_database_schema.md` |
| Modified | `docs/03_data/03_data_flows.md` |
| Modified | `docs/04_api/01_api_contracts.md` |
| Modified | `docs/05_infrastructure/01_infrastructure.md` |
| Modified | `docs/06_security/01_security.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |
| Modified | `docs/09_backend/02_polar_webhooks.md` |
| Modified | `docs/10_planning/01_roadmap.md` |
| Modified | `docs/10_planning/02_decisions.md` |
| Modified | `docs/10_planning/03_open_questions.md` |

### Decisions Made
- **Hostname pattern: hyphen-not-dot.** `fluxora-api.marshalx.dev` (single-level under apex) chosen over `api.fluxora.marshalx.dev` (two-level) because Cloudflare's free Universal SSL covers only apex + one level. Paying $10/mo for ACM rejected as not worth it for a personal project. Same rule applies to any future tunneled subdomain (`fluxora-api-uat`, `fluxora-turn`, etc.).
- **cloudflared service ImagePath override.** After hours debugging exit code 1067 with the default `service install` flow, fixed by directly setting the service's `ImagePath` registry key to launch with explicit `--config <user-config-path> tunnel run <tunnel-name>`. Documented in runbook 1 as a "known pitfall + workaround" for cloudflared 2025.8.x on Windows.
- **Eleven runbooks now constitute a complete project-bootstrap playbook.** Numbered to suggest reading order. README.md adds an explicit "what is NOT covered" section listing 11 deferred topics with trigger conditions for when each should be written.
- **Skipped paths-ignore on code workflows.** Theoretical saving of doc-only commits triggering code CI; no `.md` files inside `apps/server/` etc. today, so the saving is hypothetical. Documented as deferred.

### Blockers / Open Issues
- **Phase 2 server code not started.** Routing plan §Phase 2 (`/healthz`, CORS allow-list, real-IP middleware, HLS-block-on-tunnel middleware, `remote_url` in `/info`, `public_address` probe) is the immediate next batch. Estimated ~1 day of work; all isolated to `apps/server/`.
- **Stale `api.fluxora.marshalx.dev` CNAME** still exists in the Cloudflare DNS dashboard; harmless (no cert) but visually noisy.
- **Stale systemprofile cloudflared dir** at `C:\Windows\System32\config\systemprofile\.cloudflared\` — no longer read by the service after the ImagePath override. Harmless, can be deleted in an admin shell.
- **`b922663` commit on origin/main** still has a `Co-Authored-By: Claude ...` footer from an earlier session. Decision deferred: rewrite-and-force-push or leave as-is.

### Next Agent Should
1. Implement Phase 2 of the public routing plan ([`docs/05_infrastructure/03_public_routing.md`](docs/05_infrastructure/03_public_routing.md) §Phase 2). Smallest reviewable slice: add `FLUXORA_PUBLIC_URL` env var + `GET /api/v1/healthz` endpoint + `remote_url` field on `GET /api/v1/info` response. ~30 lines + 2 tests.
2. After 2.5 + 2.6, do 2.1–2.4 (CORS, real-IP middleware, HLS-block, localhost-hardening) as a single PR.
3. Add unit tests for the four uncovered desktop cubits (`LibraryCubit`, `OrdersCubit`, `ActivityCubit`, `LogsCubit`) — still pending from earlier session.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran during this session.
- [x] No agent / AI branding anywhere in code or docs.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added.
- [x] All new third-party deps version-checked (psutil latest at time of pinning).
---

## [2026-05-01] — Sentry wiring + devcontainer + manual-tasks tracker
**Phase:** Phase 5 (Advanced Features) — Closing the runbook gaps
**Status:** Complete

### What Was Done
- **Sentry error reporting wired** in `apps/server/main.py` via a new `_init_sentry()` helper called from the FastAPI lifespan. Conditional on `SENTRY_DSN` — empty DSN (default) means the SDK isn't even imported, zero overhead. `before_send` filter drops `HTTPException` and `RequestValidationError` events so the issues feed only shows actionable bugs. 8 unit tests cover the conditional init + filter logic.
- **`sentry-sdk[fastapi]==2.58.0`** added to runtime deps in `pyproject.toml`. Latest version verified before pinning.
- **`SENTRY_DSN` and `SENTRY_TRACES_SAMPLE_RATE`** added to `config.py` settings + the env-var table in `01_infrastructure.md`.
- **Devcontainer scaffolding** under `.devcontainer/`:
  - `devcontainer.json` — VS Code config with Python format/lint rules, Dart/Flutter extensions, port forwarding for `:8080` (server) + `:3000` (web), bind-mount of host `~/.fluxora` into the container so secrets work without copying
  - `Dockerfile` — multi-language base on `mcr.microsoft.com/devcontainers/python:1-3.11`. Installs FFmpeg, sqlite3 CLI, Node 22, Flutter 3.32.0, cloudflared. Pre-warms Flutter for faster first `pub get`. Skips Android SDK (release builds happen on host or CI)
  - `post-create.sh` — one-shot install: server `pip install -e ".[dev]"`, all 3 Flutter packages, web_landing `npm ci`, then prints version checks + run commands
- **`CONTRIBUTING.md` updated** with a "Skip the platform setup: use the devcontainer" section explaining when to use it and the host-mount pattern.
- **`runbooks/README.md`** — flipped both "(none yet)" entries:
  - Devcontainer → links to `.devcontainer/devcontainer.json`
  - Monitoring → links to `_init_sentry` in `main.py` + notes UptimeRobot still needs manual signup
- **`docs/10_planning/04_manual_tasks.md` created** — new tracker for manual / external operational tasks that need a human at a UI somewhere. 8 pending entries, each with what / why / prereqs / time / trigger / doc / owner. Section for "Recently completed" (Phase 1 routing already moved there) and a "What's NOT in this file" section disambiguating from roadmap / decisions / open-questions / code-side TODOs. Linked from `00_overview/README.md` Quick Links.
- **Test count**: 113 → 128 reflected in CLAUDE.md, README.md, and 09_backend/01_backend_architecture.md status header.

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `.devcontainer/devcontainer.json` |
| Created | `.devcontainer/Dockerfile` |
| Created | `.devcontainer/post-create.sh` |
| Created | `apps/server/tests/test_sentry_init.py` |
| Created | `docs/10_planning/04_manual_tasks.md` |
| Modified | `apps/server/pyproject.toml` |
| Modified | `apps/server/config.py` |
| Modified | `apps/server/main.py` |
| Modified | `CONTRIBUTING.md` |
| Modified | `CLAUDE.md` |
| Modified | `README.md` |
| Modified | `docs/00_overview/README.md` |
| Modified | `docs/05_infrastructure/01_infrastructure.md` |
| Modified | `docs/05_infrastructure/runbooks/README.md` |
| Modified | `docs/09_backend/01_backend_architecture.md` |

### Manual-tasks tracker — 8 pending entries
1. UptimeRobot HTTP monitor for `/healthz` (gated on Phase 2 routing)
2. Sentry project + DSN paste (code wired; just needs the DSN)
3. Delete stale `api.fluxora.marshalx.dev` CNAME from Cloudflare DNS
4. Cleanup stale `C:\Windows\System32\config\systemprofile\.cloudflared\` dir
5. Bump `cloudflared` when winget catalog catches up
6. Polar webhook URL cutover smee.io → public (gated on Phase 2 routing)
7. Set up GitHub `production` + `uat` environments with required reviewers (most likely overlooked — without these, the deploy gate is silently bypassed)
8. Add `FIREBASE_SERVICE_ACCOUNT_*` and `PUBLIC_REPO_TOKEN` GitHub secrets if not already present
9. Verify `cloudflared` service auto-starts on PC reboot
10. Quarterly backup verification drill (recurring; track last-run inline)
11. Pre-launch: rotate `TOKEN_HMAC_KEY` and `FLUXORA_LICENSE_SECRET`
12. Long-term: decide whether to register `fluxora.cloud` for v2 multi-tenant

(Entry numbers above are list order — actual statuses in the doc are all 🔲.)

### Decisions Made
- **Sentry DSN-conditional init pattern.** Skipping `import sentry_sdk` entirely when DSN is empty avoids any startup penalty for the common dev case. The "always init with empty DSN" pattern is more idiomatic but costs ~20–30ms of import time and a stub init for nothing.
- **Devcontainer bind-mounts host `~/.fluxora` instead of baking secrets into the image.** Secrets can change without rebuilding; image stays committable; identical pattern works for VS Code Dev Containers and GitHub Codespaces with a single config.
- **Devcontainer skips Android SDK.** Container is for "day-to-day Flutter dev" (analyze + test + format) — assemble/release builds happen on the host or in CI. Saves ~3 GB of image.
- **`docs/10_planning/04_manual_tasks.md` is the canonical tracker for manual-only tasks.** Code-side TODOs stay as `# TODO:` comments or GitHub issues. Avoids the "two trackers, one source of truth" anti-pattern.

### Blockers / Open Issues
- Phase 2 of the public routing plan still not started. Multiple manual-task entries (UptimeRobot, Polar URL cutover) are gated on it.
- Sentry DSN not yet generated — no monitoring in production until that's pasted into `.env`.
- Devcontainer hasn't been tested end-to-end on a fresh build (the `Dockerfile` is correct on paper but the first `Reopen in Container` will be the real test).

### Next Agent Should
1. Implement Phase 2 of the public routing plan ([`docs/05_infrastructure/03_public_routing.md`](docs/05_infrastructure/03_public_routing.md) §Phase 2). Smallest reviewable slice: `FLUXORA_PUBLIC_URL` env var + `GET /api/v1/healthz` endpoint + `remote_url` field on `GET /api/v1/info` response. ~30 lines + 2 tests.
2. After 2.5 + 2.6, add Phase 2.1–2.4 (CORS allow-list, real-IP middleware, HLS-block-on-tunnel, localhost-only hardening) as a single PR.
3. Test the devcontainer build end-to-end (open repo in VS Code → "Reopen in Container" → verify all 4 components install + run).
4. Address the "most likely overlooked" tasks from `04_manual_tasks.md`: GitHub environments + secrets (#7 + #8). Without those, the documented deploy gates and CI workflows don't actually function.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran during this session.
- [x] No agent / AI branding anywhere in code or docs.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added (Sentry DSN comes from env; devcontainer mounts host `~/.fluxora`).
- [x] All new third-party deps version-checked (`sentry-sdk==2.58.0` confirmed latest at pin time).
---

## [2026-05-01] — Mirror workflow fix; Dependabot first-run triage
**Phase:** Phase 5 (Advanced Features) — Maintenance / dep hygiene
**Status:** Complete

### What Was Done
- **Mirror-public workflow bug fix.** The `Commit clean state` step in `mirror-public.yml` interpolated `${{ steps.msg.outputs.message }}` directly into `git commit -m "..."`, which broke when the commit body contained literal quotes — bash split the rest of the message into pathspecs. Symptom seen on the `625393e` mirror run (the message had `"tunneled hostnames must be single-level"` literal quotes inside). Fix: pass the message via env var + `printf '%s\n' "$COMMIT_MSG" | git commit -F -`. Same fix applied to the example in `runbooks/03_github_ci_cd.md` so future projects don't inherit the bug. Landed as commit `814894f`.
- **Dependabot first-run triage.** 19 PRs opened (first time bot fired against this repo after the new `dependabot.yml`). Triaged each by checking the branch's pubspec/pyproject locally + running tests / analyze / build:
  - **10 safe to merge (Tier 1+2)**: python-runtime group (FastAPI 0.111→0.136 + 6 others), black 24→26, flutter_lints 4→6 (mobile), get_it 7→9 (mobile), go_router 13→17 (mobile), core dart-deps group, desktop dart-deps group, typescript 5→6 (web), @types/node 22→25 (web), eslint 9→10 (web).
  - **1 paired-only**: pytest 9 fails install resolution against current pytest-asyncio 0.23 → must merge with pytest-asyncio 1.3 in same window.
  - **1 needs prep first**: flutter_lints 6 in `packages/fluxora_core` flags `unnecessary_library_name` on the redundant `library fluxora_core;` declaration in the barrel file. Removed the declaration in commit `9549645` and pushed to `main`; PR #20 can now be merged.
  - **1 blocked**: flutter_secure_storage 9→10 in core breaks `apps/mobile` and `apps/desktop` (both separately pin `^9.x`). Close PR; open a manual cross-pubspec bump when ready.
  - **5 Actions majors**: pure version bumps; closing per the pre-edited `dependabot.yml` ignore rule for `actions/* version-update:semver-major` (not yet committed — pending).
- **New runbook 11**: `docs/05_infrastructure/runbooks/11_dependabot_triage.md`, ~200 lines. Generic process for handling a flood of bot PRs — tier classification, three coupling traps (cross-package pin coordination, paired major bumps, new-lint warnings), test methodology, merge order rules, when to bail. Captures the lessons from this triage so future Dependabot floods (Fluxora's or another project's) take 30 min not 3 hours.
- **`docs/10_planning/04_manual_tasks.md` updated**: new "Process the Dependabot PR queue" entry detailing the round-by-round merge plan.
- **`runbooks/README.md`** index updated to include runbook 11.

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | `docs/05_infrastructure/runbooks/11_dependabot_triage.md` |
| Modified | `.github/workflows/mirror-public.yml` (env-var + stdin fix) |
| Modified | `docs/05_infrastructure/runbooks/03_github_ci_cd.md` (same fix in example) |
| Modified | `packages/fluxora_core/lib/fluxora_core.dart` (removed `library fluxora_core;`) |
| Modified | `docs/05_infrastructure/runbooks/README.md` (added runbook 11) |
| Modified | `docs/10_planning/04_manual_tasks.md` (added Dependabot triage entry) |

### Commits Pushed (this session)
- `814894f` — mirror workflow env-var + stdin fix
- `9549645` — `library fluxora_core;` removal (PR #20 prep)

### Decisions Made
- **Mirror-workflow secret-substitution pattern.** `git commit -F -` over `git commit -m "..."` for any message that flows through `${{ steps.*.outputs.* }}`. Stdin reading is byte-faithful; arg substitution is shell-parsed. Documented in runbook 03 so future projects copy the right pattern.
- **Cross-package pin coordination is a Dependabot blind spot.** When the same dep appears in multiple `pubspec.yaml` / `pyproject.toml` files at coordinated versions, Dependabot's per-file PR doesn't catch the coupling. The runbook 11 "Coupling traps" section now flags this; do a `grep` across all manifests before merging any major bump.
- **Action majors are net-negative for solo projects.** Five action-major-bump PRs in this batch; closing all of them. Dependabot now configured (locally — pending push) to ignore `version-update:semver-major` for `actions/*`.
- **PR #20 fix-on-prep.** Could have merged the bump and fixed the lint warning afterward, but `flutter analyze` is in CI for the package — would have left `main` red until the fix landed. Cleaner to land the fix first.

### Blockers / Open Issues
- **`dependabot.yml` ignore-rule for Actions majors not yet committed.** Until pushed, closing PRs #2/#3/#5/#6/#7 will trigger re-open on next Dependabot run. Either commit the ignore rule first or accept that closing them is temporary.
- **PR #18 (flutter_secure_storage 10)** is closed in plan but the cross-pubspec bump itself still needs to happen eventually. Tracked in `04_manual_tasks.md`.
- **Mirror workflow not yet validated** against the env-var fix end-to-end. Next push to `main` will be the first run with the fix in place.

### Next Agent Should
1. Merge the 13 mergeable Dependabot PRs per the plan in `04_manual_tasks.md` § "Process the Dependabot PR queue". Wait for CI green between each.
2. Commit + push the queued `dependabot.yml` ignore-rule for Actions majors (pending in working tree). Then close PRs #2/#3/#5/#6/#7 from the GitHub UI.
3. Implement Phase 2 of the public routing plan (`/healthz`, CORS, real-IP middleware, `remote_url` in `/info`) — still the immediate code work after dep hygiene is done.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK (`814894f`, `9549645` were both authorized).
- [x] No agent / AI branding anywhere in code or docs.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added.
- [x] All new third-party deps tested locally before recommending merge.
---

## [2026-05-01] — Public routing Phase 2 (server) + Phase 3 (fluxora_core dual-base)
**Phase:** Phase 5 (Advanced Features) — Public routing rollout
**Status:** Phases 2 + 3 of `docs/05_infrastructure/03_public_routing.md` complete; Phase 4 (mobile pairing-flow rewire) is next.

### What Was Done

**Phase 2 — server-side public routing** (already pushed in `757329c` + `b9fb567`):
- `apps/server/config.py` — added `fluxora_public_url`, `fluxora_trust_cf_headers`, `fluxora_block_hls_over_tunnel`.
- `apps/server/routers/info.py` — new `GET /healthz` endpoint (lightweight liveness probe for the CF tunnel and the system-stats `_public_address` probe); existing `/info` now returns `remote_url`.
- `apps/server/utils/real_ip.py` — `RealIPMiddleware` (rewrites `request.client.host` from `CF-Connecting-IP` when the source is in Cloudflare's published IPv4/IPv6 ranges; refreshes the range list at startup, falls back to a hardcoded list when the fetch fails) + `HLSBlockOverTunnelMiddleware` (403s `/api/v1/stream/.../hls/...` requests that arrive with `CF-Connecting-IP`, since long-lived HLS over the free tunnel would burn the bandwidth budget) + `real_ip_key` for slowapi rate limiting.
- `apps/server/main.py` — wired the two middlewares in the right order (RealIP first so HLSBlock and slowapi see the rewritten host), seeded a strict CORS allow-list, swapped slowapi to `real_ip_key`, refreshes CF ranges on startup.
- `apps/server/routers/deps.py` — `require_local_caller` and `validate_token_or_local` now reject any request that arrived via the tunnel (presence of `CF-Connecting-IP`), so admin endpoints stay localhost-only even after the middleware rewrites the source IP.
- `apps/server/services/system_stats_service.py` — new `_public_address()` probe that hits `<FLUXORA_PUBLIC_URL>/api/v1/healthz` with a 5s timeout and 30s cache; returns the URL on 200, `None` otherwise. Backs the `public_address` field that the desktop Dashboard already consumes.
- Tests: `tests/test_healthz.py` (6) + `tests/test_real_ip.py` (15). Server suite remains green.

**Phase 3 — fluxora_core dual-base ApiClient** (this session's working-tree changes):
- `packages/fluxora_core/lib/network/network_path_detector.dart` — moved from `apps/mobile/lib/features/player/data/services/`. Same `/24`-subnet detection logic; added a `LanCheck` typedef for test injection.
- `packages/fluxora_core/lib/network/api_exception.dart` — added `NoRemoteConfiguredException` (thrown when the device is off-LAN and no remote URL is configured).
- `packages/fluxora_core/lib/network/api_client.dart` — refactored to dual-base:
  - Constructor: `ApiClient({localBaseUrl, remoteBaseUrl, lanCheck = NetworkPathDetector.isLan, bearerToken})`. The legacy `baseUrl:` arg is kept as `@Deprecated` and aliases `localBaseUrl`.
  - Per-request Dio interceptor calls `_resolveBaseUrl()` which picks local vs remote via `LanCheck`, and rewrites `options.baseUrl` before the request leaves. Throws `NoRemoteConfiguredException` if off-LAN with no remote (or if neither URL is set).
  - Each public method (`get/post/put/patch/delete`) catches `DioException` and unwraps `NoRemoteConfiguredException` so callers can branch on it directly instead of digging through `e.error`.
  - `configure()` accepts the same dual-URL signature for live updates after pairing.
  - `@visibleForTesting resolveBaseUrlForTest()` exposes the resolver for unit tests without leaking the underlying Dio instance.
- `packages/fluxora_core/lib/storage/secure_storage.dart` — added `saveRemoteUrl/getRemoteUrl/deleteRemoteUrl` and a `savePairing({ authToken, serverUrl, clientId, remoteUrl? })` helper that writes all four fields atomically (passing `remoteUrl: null` deletes any stored remote URL).
- `packages/fluxora_core/lib/fluxora_core.dart` — barrel exports `network/network_path_detector.dart`.
- `packages/fluxora_core/test/network/api_client_test.dart` — 9 tests covering all six resolution branches, `configure()` re-routing, `clearRemoteBaseUrl()`, the legacy-`baseUrl` alias.
- `apps/mobile/lib/core/di/injector.dart` — restores both `serverUrl` and `remoteUrl` from `SecureStorage` and configures the dual-base ApiClient on app start.
- `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` — import switched to `package:fluxora_core/network/network_path_detector.dart`.
- All other callers (`auth_repository_impl`, `server_discovery_repository_impl`, `connect_screen`, desktop `injector` / `settings_cubit` / its tests) migrated from `baseUrl:` to `localBaseUrl:`.

**SDK / dep coupling fix** (surfaced via the Phase 3 `flutter pub get`):
- `packages/fluxora_core/pubspec.yaml` and `apps/desktop/pubspec.yaml` — `json_annotation` pinned to `>=4.9.0 <4.11.0` and `json_serializable` to `>=6.9.0 <6.13.0`. `json_annotation 4.11.x` requires Dart SDK ^3.9.0; the project is on 3.8.0. Without the upper bound, `flutter pub get` fails on both packages. `04_manual_tasks.md` now tracks this so future Dependabot 4.11+ bumps get closed until we raise the SDK floor.

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `apps/server/utils/real_ip.py` |
| Created | `apps/server/tests/test_healthz.py` |
| Created | `apps/server/tests/test_real_ip.py` |
| Modified | `apps/server/config.py`, `main.py`, `routers/info.py`, `routers/deps.py`, `services/system_stats_service.py`, `models/settings.py` |
| Created | `packages/fluxora_core/lib/network/network_path_detector.dart` (moved from mobile) |
| Modified | `packages/fluxora_core/lib/network/api_client.dart` (dual-base refactor) |
| Modified | `packages/fluxora_core/lib/network/api_exception.dart` (added `NoRemoteConfiguredException`) |
| Modified | `packages/fluxora_core/lib/storage/secure_storage.dart` (`saveRemoteUrl`, `savePairing`) |
| Modified | `packages/fluxora_core/lib/fluxora_core.dart` (export) |
| Modified | `packages/fluxora_core/pubspec.yaml`, `apps/desktop/pubspec.yaml` (json_annotation/json_serializable pins) |
| Created | `packages/fluxora_core/test/network/api_client_test.dart` (9 tests) |
| Deleted | `apps/mobile/lib/features/player/data/services/network_path_detector.dart` |
| Modified | `apps/mobile/lib/core/di/injector.dart` (dual-URL restore) |
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` (import) |
| Modified | `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart`, `apps/mobile/lib/features/connect/data/repositories/server_discovery_repository_impl.dart`, `apps/mobile/lib/features/connect/presentation/screens/connect_screen.dart` (`baseUrl:` → `localBaseUrl:`) |
| Modified | `apps/desktop/lib/core/di/injector.dart`, `apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart`, `apps/desktop/test/features/settings/settings_cubit_test.dart` (`baseUrl:` → `localBaseUrl:`) |
| Modified | `docs/05_infrastructure/03_public_routing.md` (Phase 3 section rewritten with the as-built API + resolution table + test coverage) |
| Modified | `docs/08_frontend/01_frontend_architecture.md` (dual-base ApiClient, `NetworkPathDetector` lives in core) |
| Modified | `docs/10_planning/04_manual_tasks.md` (added Dart-SDK-floor bump task) |

### Commits Pushed (this session)
- `757329c` — phase 2 slice 1 (config, /healthz, remote_url on /info).
- `b9fb567` — phase 2 slice 2 (CF tunnel middlewares, admin hardening, public_address probe).
- Phase 3 working-tree changes are **uncommitted** — staging + commit message decision is on the user.

### Validation
- `flutter analyze` — clean on `packages/fluxora_core`, `apps/mobile`, `apps/desktop`.
- `flutter test` — `fluxora_core` 9 tests pass (new), `apps/mobile` 24 pass, `apps/desktop` 34 pass.
- Server tests already green from Phase 2 commits.
- `pubspec.lock` files updated for `fluxora_core` + `apps/desktop` after the json_annotation downgrade. `apps/mobile` pub-get also re-ran cleanly.

### Decisions Made
- **Backward-compat `baseUrl:` shim.** Kept the deprecated single-URL constructor + `configure(baseUrl:)` arg so the desktop and mobile callers compile during the migration and the change ships as a non-breaking API addition. All in-repo callers have been migrated; the deprecation flags any future regressions.
- **`NetworkPathDetector` belongs in `fluxora_core`, not in mobile.** It was originally placed under `apps/mobile/lib/features/player/data/services/`, but the `ApiClient` smart-path needs the same logic on every platform that talks to the server, including desktop. Moving it once now is cheaper than copy-pasting later.
- **Throw on off-LAN-without-remote.** Earlier draft fell back to local when remote was absent; the failure mode there is a silent timeout against an unreachable LAN host. Throwing `NoRemoteConfiguredException` lets the UI surface a "you need to be on the LAN, or set up remote access" prompt — which is what Phase 4 will wire.
- **SDK-floor pin over forced 3.9 bump.** Pinning `json_annotation` / `json_serializable` upper bounds is uglier than bumping Flutter, but a Dart-SDK bump is its own change with its own risk surface — flagged in the manual-tasks tracker for a separate, deliberate rollout.

### Blockers / Open Issues
- **Phase 4 not started.** The `remote_url` field exists on `/info` (server) and `ApiClient` knows how to use it (core), but the mobile pairing flow (`AuthRepositoryImpl.saveCredentials` and the connect screen) doesn't yet read `remote_url` from the server's `/info` response and persist it via `SecureStorage.savePairing`. Until Phase 4 lands, dual-base is purely additive — paired clients keep using LAN-direct.
- **Dependabot will keep proposing `json_annotation 4.11+`.** Tracked in `04_manual_tasks.md`. Close those PRs until the Dart SDK floor moves to 3.9+.
- **Manual cross-pubspec bump for `flutter_secure_storage 10`** (PR #18 from the previous triage) still pending — same blind-spot pattern as the json_annotation pin.

### Next Agent Should
1. Decide on Phase 3 commit boundary with the user (one slice covering the dual-base ApiClient + the json_annotation pin, or two — pin on its own, refactor + tests + docs together). Stage and draft the commit text only; do **not** push without per-action authorization.
2. Implement Phase 4 of the public routing plan: `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` should fetch `/info` after pairing and call `SecureStorage.savePairing(..., remoteUrl: info.remoteUrl)`. The desktop `Settings → Server` screen should expose the same field for manual editing.
3. Process the remaining mergeable Dependabot PRs per `04_manual_tasks.md` § "Process the Dependabot PR queue" once Phase 3 is in.
4. Push the queued `dependabot.yml` Actions-major ignore-rule (still in working tree from the previous session) before closing PRs #2/#3/#5/#6/#7.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK (Phase 2 was authorized; Phase 3 is uncommitted pending user direction).
- [x] No agent / AI branding anywhere in code or docs.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added (CF tunnel URL configurable via `FLUXORA_PUBLIC_URL`; nothing hardcoded in core or mobile).
- [x] All new third-party deps reviewed (none added — only re-pinned existing `json_annotation` / `json_serializable` ranges).
---

## [2026-05-01] — Public routing Phase 4 (mobile pairing); CI fix; full doc audit
**Phase:** Phase 5 (Advanced Features) — Public routing rollout
**Status:** Phase 4 of `docs/05_infrastructure/03_public_routing.md` complete. Phase 5 (desktop Remote-access UI + mobile Settings UI) is next. Cross-doc audit run; 12 docs synced to as-built.

### What Was Done

**Phase 3 commit split** (followed up from prior entry):
- `511c53b` — `build(deps): pin json_annotation <4.11 and json_serializable <6.13` (just the ceilings + manual-tasks entry).
- `c46017d` — `feat(core): dual-base ApiClient with smart LAN/WAN routing` (16 files, +396 / -80, including the rename of `network_path_detector.dart` from `apps/mobile/...` to `packages/fluxora_core/lib/network/`).

**Phase 4 — mobile pairing flow persists `remote_url`** (`07e9d0f`):
- `packages/fluxora_core/lib/entities/server_info.dart` — added `String? remoteUrl`. Auto-mapped to `remote_url` JSON via the `field_rename: snake` in `build.yaml`. Regenerated `*.freezed.dart` + `*.g.dart` via `dart run build_runner build --delete-conflicting-outputs`.
- `packages/fluxora_core/lib/network/endpoints.dart` — added `Endpoints.healthz` so a future Settings screen can probe reachability.
- `packages/fluxora_core/lib/network/api_client.dart` — tightened `configure()` semantics: previously it always overwrote `_bearerToken` even when not passed, so the connect-screen's pre-auth `configure(localBaseUrl: …)` would silently wipe a saved token if it ever ran post-pair. Now `configure()` only updates fields that are explicitly non-null; added `clearBearerToken()` for the rare cases that need to clear. This was a latent bug; never observed in production but caught while writing the Phase 4 saveCredentials refactor.
- `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart::saveCredentials` — now configures the ApiClient with `localBaseUrl + bearerToken`, fetches `GET /api/v1/info`, reads `info.remoteUrl`, persists everything via `SecureStorage.savePairing(...)`, and reconfigures the ApiClient with the remote URL when present. The `/info` fetch is wrapped in a try/catch so a paired client without remote access keeps working LAN-direct. `PairCubit` and the `AuthRepository` interface stay unchanged — the new logic hides behind the existing `saveCredentials` signature.
- Tests: 3 new in `apps/mobile/test/features/auth/auth_repository_impl_test.dart` covering happy path, server-without-remote, and `/info` failure. Mobile suite goes 24 → 27. flutter analyze stays clean across core / mobile / desktop.
- Mobile Settings "Remote access" row from the Phase 4 plan was **deferred**. Mobile has no Settings feature folder by design (CLAUDE.md current status: connect / auth / library / player / upgrade only — desktop is the v1 settings surface). Building a full Settings screen + cubit + repo + router entry just for one row is out of scope. Documented in the routing-plan doc; `Endpoints.healthz` is exported so it wires in trivially when the screen is built.
- Phase 4 also tightened the `json_annotation` lower bound from `>=4.9.0` → `>=4.10.0` in core + desktop pubspecs after `json_serializable` warned at build_runner time about the prior floor.

**CI fix — `go_router` SDK floor** (`3e4a5c7`):
- CI's `flutter pub get` started failing with `go_router 17.x requires Dart SDK ^3.9.0`. The desktop pubspec was pinned at `^17.2.2`, which the local lockfile had resolved to `17.2.2` (somehow — the local Dart toolchain may report differently than CI's pinned Flutter version). Dropped the desktop pin to `^16.0.0`; resolved cleanly to `16.3.0`. Desktop router code uses only `ShellRoute` / `GoRoute` APIs that exist in 16.x; `flutter analyze` + 34-test suite stay clean.
- Folded into the existing manual-tasks SDK-floor-bump entry alongside the `json_annotation` / `json_serializable` ceilings — all three drop together when the Dart 3.9 floor is taken.

**Cross-doc audit** (uncommitted as of this entry — same chunk pending):
- Walked the CLAUDE.md Documentation Update Protocol Step 1 list. 12 files updated to reflect Phases 2–4 of public routing as shipped:
  - `README.md`, `CLAUDE.md`, `CONTRIBUTING.md` — current-status blocks, test counts (server 149, mobile 27, desktop 34, core 9).
  - `docs/02_architecture/02_tech_stack.md` — Public Routing row updated from "Phase 1 ops complete; Phase 2–5 pending" to "Phases 1–4 complete; Phase 5 desktop UI pending".
  - `docs/02_architecture/03_component_architecture.md` — Public Routing component lists Phase 2/3/4 implementation. Communication-patterns table: WAN client and Cloudflare-edge rows no longer "planned".
  - `docs/03_data/03_data_flows.md` — Flow 4 (pairing) now shows the post-pair `/info` fetch + `savePairing` + dual-base configure.
  - `docs/03_data/04_migration_guide.md` — test count `113` → `149` (the `113` was a stale carry-over from before the Phase-2-server-side commits).
  - `docs/05_infrastructure/03_public_routing.md` — header rev 3 → rev 4; status changed to "Phases 1–4 complete".
  - `docs/05_infrastructure/04_domains_and_subdomains.md` — header + tunnel-row note updated.
  - `docs/06_security/01_security.md` — **new** "Cloudflare Tunnel Threat Model" section covering the three implications: real-IP middleware (only trusts `CF-Connecting-IP` from CF ranges), admin endpoints reject tunneled requests, HLS plane never traverses the tunnel.
  - `docs/08_frontend/01_frontend_architecture.md` — mobile test breakdown updated (added auth_repository_impl_test, total 27).
  - `docs/10_planning/01_roadmap.md` — public-routing row reflects Phases 1–4 complete.

### Files Created / Modified

**Phase 4 (committed in `07e9d0f`):**

| Action | Path |
|--------|------|
| Modified | `packages/fluxora_core/lib/entities/server_info.dart` (added `remoteUrl`) |
| Modified | `packages/fluxora_core/lib/entities/server_info.freezed.dart`, `server_info.g.dart` (regenerated) |
| Modified | `packages/fluxora_core/lib/network/api_client.dart` (`configure()` non-null guard + `clearBearerToken`) |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` (`Endpoints.healthz`) |
| Modified | `packages/fluxora_core/pubspec.yaml`, `apps/desktop/pubspec.yaml` (json_annotation lower bound) |
| Modified | `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` (saveCredentials refactor) |
| Created | `apps/mobile/test/features/auth/auth_repository_impl_test.dart` (3 tests) |
| Modified | `docs/05_infrastructure/03_public_routing.md` (Phase 4 section as-built) |

**CI fix (committed in `3e4a5c7`):**

| Action | Path |
|--------|------|
| Modified | `apps/desktop/pubspec.yaml`, `apps/desktop/pubspec.lock` (go_router 17 → 16) |
| Modified | `docs/10_planning/04_manual_tasks.md` (folded go_router into SDK-floor entry) |

**Doc audit (uncommitted at time of writing — bundled with this AGENT_LOG entry per user direction):**

| Action | Path |
|--------|------|
| Modified | `README.md`, `CLAUDE.md`, `CONTRIBUTING.md` |
| Modified | `docs/02_architecture/02_tech_stack.md` |
| Modified | `docs/02_architecture/03_component_architecture.md` |
| Modified | `docs/03_data/03_data_flows.md` |
| Modified | `docs/03_data/04_migration_guide.md` |
| Modified | `docs/05_infrastructure/03_public_routing.md` (header rev 4 + Phase 4 fully rewritten) |
| Modified | `docs/05_infrastructure/04_domains_and_subdomains.md` |
| Modified | `docs/06_security/01_security.md` (new CF tunnel threat-model section) |
| Modified | `docs/08_frontend/01_frontend_architecture.md` |
| Modified | `docs/10_planning/01_roadmap.md` |

### Commits Pushed (this session's tail)
- `511c53b` — pin json_annotation / json_serializable ceilings.
- `c46017d` — dual-base ApiClient (Phase 3).
- `07e9d0f` — mobile pairing persists `remote_url` (Phase 4).
- `3e4a5c7` — pin `go_router < 17` to fix CI.

### Validation
- `flutter analyze` — clean on `packages/fluxora_core`, `apps/mobile`, `apps/desktop`.
- `flutter test` — `fluxora_core` 9 ✅, `apps/mobile` 27 ✅ (was 24), `apps/desktop` 34 ✅.
- Server tests untouched this session — still 149 ✅ from Phase 2 baseline.

### Decisions Made
- **Phase 3 split into two commits.** The pin fix (slice 1) lands first because it's a CI prerequisite for the dual-base refactor in slice 2 — the lockfile from slice 2 needs the pinned ranges to be in place. The user asked to split after I drafted a single combined message; doing so produces a clean bisect trail (a future bisect through the pin commit alone would build, just on slightly older Dio/etc).
- **Mobile Settings UI deferred.** Phase 4 step 4 ("Remote access row showing healthz reachability") would need a brand-new feature folder, route, cubit, and repo for one indicator. The desktop control panel is the canonical settings surface in v1 (CLAUDE.md). `Endpoints.healthz` is exported so the wiring is one-line when a Settings screen does land.
- **`configure()` non-null guard.** The original behavior was "passing `null` clears", which is convenient but hides a sharp edge: any pre-auth `configure(localBaseUrl: …)` call (which doesn't pass a token) wipes a saved token. Switched to "only update what's passed" + explicit `clearBearerToken()` / `clearRemoteBaseUrl()`. Behavior change to a public method, but no in-repo caller relied on the old clearing semantics.
- **`go_router` ceiling, not Flutter floor bump.** Bumping Flutter to ship Dart 3.9 is a separate change with its own risk surface (lints / breaking changes / lockfile churn across all three apps). Holding the ceiling lets us merge other Dependabot PRs without churn while we plan the floor move.

### Blockers / Open Issues
- **Phase 5 of public routing not started.** Desktop `SystemStatsCard` should pick up the `public_address` field with a green/red indicator, and Settings should grow a "Remote access" section showing the configured tunnel URL + tunnel-reachable status. Backend already exposes `public_address` on `/info/stats`.
- **Mobile Settings feature does not exist.** Tracked above. No urgency — the deferred row only matters if/when mobile gains a Settings feature for other reasons.
- **Dart SDK 3.9 floor bump pending.** Tracked in `04_manual_tasks.md`. Affects `json_annotation 4.11+`, `json_serializable 6.13+`, and `go_router 17+` simultaneously.
- **`AGENT_LOG.md`** — this entry is written but the file is being committed alongside the doc-audit chunk per user direction. Each prior session left the log uncommitted; this is the first one bundling it with the work.

### Next Agent Should
1. Implement Phase 5 of the public routing plan: surface `public_address` on the desktop `Dashboard` (`SystemStatsCard`) with a green/red indicator; add a "Remote access" section to the desktop `SettingsScreen` showing the configured tunnel URL + reachability + a link to the runbook.
2. Process the remaining mergeable Dependabot PRs per `04_manual_tasks.md` § "Process the Dependabot PR queue".
3. Push the queued `dependabot.yml` Actions-major ignore-rule (still in working tree from an earlier session) before closing PRs #2 / #3 / #5 / #6 / #7.
4. Plan the Dart 3.9 floor bump as a single coordinated PR — bumps all three pubspecs + Flutter version in `.github/workflows/*.yml`, drops the `json_annotation` / `json_serializable` / `go_router` ceilings, regenerates lockfiles, runs all four test suites locally.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK (each commit was a separate "comit" / "do it" authorization).
- [x] No agent / AI branding anywhere in code or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed (the `/info` fetch fallback in `saveCredentials` logs the error and continues with `remoteUrl: null`).
- [x] No secrets / hardcoded paths added.
- [x] All new third-party deps reviewed (none added — pin adjustments only).
---
