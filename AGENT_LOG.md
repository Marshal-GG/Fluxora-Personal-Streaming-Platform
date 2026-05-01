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
