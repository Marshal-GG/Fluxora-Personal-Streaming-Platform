# Known Risks & Gotchas

> Sharp edges encountered during Fluxora development. Read this when troubleshooting an unexplained failure — the answer is often here.

| Area | Gotcha | Mitigation |
|------|--------|-----------|
| FFmpeg | Must be installed separately by the user; PyInstaller cannot bundle it | Startup check with friendly error message and download link |
| mDNS on Android 12+ | Android silently drops multicast packets without `WifiManager.MulticastLock` | `MainActivity.kt` exposes `MethodChannel('dev.marshalx.fluxora/multicast')`; `ConnectCubit.startDiscovery()` acquires the lock before scanning, releases on close. Manual IP entry remains as fallback. |
| `flutter_webrtc` | v0.10.x uses removed v1 Flutter plugin API (`PluginRegistry.Registrar`) — fails to compile on AGP 8+ | v1.4.1 integrated and working. Do not downgrade. |
| SQLite concurrency | WAL mode helps but high client counts can still lock | Connection pool limit; queue writes; plan PostgreSQL migration path for Pro tier. |
| HLS temp files | FFmpeg writes to `/tmp` — can fill up on long sessions | Cleanup enforced on stream close AND on server startup (orphan cleanup in `main.py` lifespan). |
| PyInstaller + FFmpeg | FFmpeg subprocess path must use the bundled binary path, not `PATH` | Resolve FFmpeg path via `sys._MEIPASS` in frozen builds. |
| Token storage (Flutter) | `shared_preferences` is not encrypted | Use `flutter_secure_storage` for the bearer token. |
| Path traversal | File-serving routes could expose files outside the library root | Always canonicalize and prefix-check before serving. |
| Bash / Git Commits | Backticks inside double-quoted commit messages execute as bash commands, causing pathspec errors | Use single quotes (`'`) instead of double quotes to wrap commit messages containing backticks. |
| Dart 3.9 null-aware map syntax | `{'key': ?value}` looks like a syntax error to older analyzers / IDEs | Valid in SDK `>=3.8.0`; project floor is `>=3.9.0` (CI pins Flutter 3.41.3 / Dart 3.11). `flutter analyze` confirms no issues. |
| Pytest & CI | `pytest` exits with code 5 if no tests are found, breaking CI pipelines | Always include at least one placeholder test (e.g. `def test_placeholder(): pass`). |
| Git Pull / Merge | `git pull` with diverged branches creates an unwanted `Merge branch 'main' of...` commit | Always use `git pull --rebase`. |
| URL query encoding | `+` in a query string is decoded as a space (HTML form rule) — breaks ISO timestamps with `+00:00` | Use httpx `params={...}` (or `urllib.parse.quote`); never f-string a timestamp directly into the query. |
| Python `or` truthiness on lists | `lst or default` substitutes `default` when `lst` is `[]` (falsy) — silently turns "deny everything" into "allow everything" | Use `lst if lst is not None else default` for explicit None-check. |
| Auth-gate drift on admin endpoints | New endpoints get added without `require_local_caller` / `validate_token_or_local` and silently leak operator data over the public tunnel. `GET /info/stats` shipped with no auth at all (CPU/RAM/lan_ip exposed); `DELETE /auth/revoke` shipped with `validate_token` instead of `require_local_caller` (any client could revoke any other client) | Periodically `grep "@router\.\(get\|post\|patch\|delete\)" routers/` and confirm each handler has an explicit `Depends(...)` for auth. No-auth is the default in FastAPI — silence is the bug. |
| `FluxTitlebar` caption glyphs render as boxes / wrong shapes | The minimize / maximize / restore / close buttons render Unicode codepoints `U+E921` / `U+E922` / `U+E923` / `U+E8BB` from `Segoe Fluent Icons` (Win 11) with `Segoe MDL2 Assets` fallback (Win 10). Both are Windows-bundled. On macOS / Linux runners (or any Windows install older than 10 1511) the glyphs will render as `□` boxes or fall through to whatever font Flutter picks. | Windows 10 1511+ and Windows 11 are guaranteed; the codepoints are documented in [`docs/02_architecture/02_tech_stack.md`](../02_architecture/02_tech_stack.md#system-fonts-used-by-fluxtitlebar). For non-Windows runners, swap to `CustomPainter` paths or vendor a TTF. |
| Taskbar icon looks tiny next to other apps | The source `assets/brand/logo-icon.png` has ~20 % transparent margin on every side (the actual glyph fills only 59 % of canvas). When Windows downsamples that for the taskbar at 24-32 px, the visible mark is barely 60 % the size of icons from apps that ship a tight-cropped `.ico`. | Regenerate `app_icon.ico` from the master with the Pillow pipeline documented in [`assets/README.md`](../../assets/README.md): tight-crop to the alpha bounding box, then re-paste with **8 % margin** before resizing to the standard 16 / 20 / 24 / 32 / 40 / 48 / 64 / 96 / 128 / 256 sizes. |
| No taskbar Aero Peek thumbnail on hover | Two combined causes — the runner registered with `WNDCLASS` instead of `WNDCLASSEX` (so only `hIcon`, no `hIconSm` — Windows downsamples poorly and may skip thumbnail registration), AND no AppUserModelID was set, so the shell couldn't associate the running window with any pinned shortcut for thumbnail grouping. | Use `WNDCLASSEX` + `RegisterClassEx` with both icon variants loaded via `LoadImage(..., SM_CXICON / SM_CXSMICON, ...)`. Call `SetCurrentProcessExplicitAppUserModelID(L"Company.Product")` in `main.cpp` before window creation; link `shell32.lib` in `windows/runner/CMakeLists.txt`. |
| `golden_toolkit` is discontinued | `flutter pub get` reports `golden_toolkit 0.15.0 (discontinued)` — the package powering desktop golden tests (`testGoldens`, `screenMatchesGolden`, `loadAppFonts`) is no longer maintained. Still works on current Flutter but will eventually break on a future SDK bump. Used in `apps/desktop/test/goldens/`. | No action required while it still compiles. When it breaks: evaluate `alchemist` (Betterment) as the modern replacement — similar API, actively maintained. Migration cost is low (one test file today). Swap when forced, not preemptively. |
| Desktop CI cannot run golden tests | Goldens are platform-sensitive (font subpixel rendering differs between Windows and Linux). Baselines in `test/goldens/goldens/` are generated on Windows; running them on `ubuntu-latest` produces pixel diffs even when the code is correct. | CI runs `flutter test --exclude-tags=golden` (see [`.github/workflows/desktop_ci.yml`](../../.github/workflows/desktop_ci.yml)). Golden tests are tagged `@Tags(['golden'])` and run locally on Windows for visual regression. Rebaseline after intentional theme/layout changes via `flutter test --tags=golden --update-goldens`. |
| Translucent fillColor on Material widgets bleeds the background gradient | The V2 `surfaceGlass` token is `rgba(20,18,38,0.7)` — translucent by design. Without a sibling `BackdropFilter(blur)`, the page bleeds through unblurred and chrome reads as "broken" rather than "glass". Hit on dialogs, popup menus, AppBar/SnackBar themes, and `InputDecoration.fillColor`. | **Resolved 2026-05-04** (two-pass fix): (1) Added opaque token `AppColors.bgRaised` (`#0F0C24`) for surfaces where blur isn't worth the GPU cost (theme-default Material `Card` / `AppBar` / `SnackBar`, `InputDecoration.fillColor`). (2) Added two real-glass widgets — [`FluxGlassDialog`](../../apps/desktop/lib/shared/widgets/flux_glass_dialog.dart) and [`FluxGlassMenu`](../../apps/desktop/lib/shared/widgets/flux_glass_menu.dart) — that wrap content in `ClipRRect → BackdropFilter(blur 20) → Container(surfaceGlass)`, the same pattern as `FluxAppBar` / `FluxSidebar` / `FluxBottomTabs`. Library-screen dialogs (3) and popup menus (Sort + per-card 3-dot, 2 sites) consume these. Stock `PopupMenuButton` cannot host a single blur because its items are independent Material descendants — `FluxGlassMenu` uses a custom `PopupRoute` that renders all items inside one BackdropFilter. **Rule going forward**: `surfaceGlass` standalone (no BackdropFilter sibling) is a bug. Either add the BackdropFilter (real glass) or use `bgRaised` (opaque). On-page `FluxCard` / `FluxPoster` are the only legal exceptions — there the rgba reads as "tinted overlay over the page's radial gradient", not glass. Mobile still has 8 raw-`surfaceGlass` and 4 raw-`#0F0C24` literal sites awaiting the mobile agent's migration. Documented in [`DESIGN.md`](../../DESIGN.md#surface-hierarchy) and [`docs/08_frontend/01_frontend_architecture.md`](../08_frontend/01_frontend_architecture.md). |
| Cutover claims need a Grep matrix, not a spot check | The desktop M9.5 V2-theme cutover landed claiming "zero `AppColors.{primary,background,surface,...}` references in `apps/desktop/lib/`" — but a single `AppTypography.bodyMd` at [`apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart:1001`](../../apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart#L1001) survived, caught only when mobile M9 ran a comprehensive Grep before deleting V1 tokens from `fluxora_core`. The miss was a one-line typography style — but had it been a color, the V1 deletion would have broken `flutter analyze` and the cutover would have shipped a broken main branch. | Before declaring any token / API / migration cutover "complete," run an exhaustive `grep` matrix against every legacy name across all `*.dart` (or relevant extension) files. The mobile M9 entry in `AGENT_LOG.md` documents the exact pattern: `Grep` with the full disjunction of legacy names, scoped to file extensions, output `files_with_matches`. Doc-only matches (in `AGENT_LOG.md`, archives, plan files) are historical narrative — code matches are the bug. |
| `Spacer()` inside a `Column` that's a non-Positioned child of a `Stack` | `Stack` defaults to `fit: StackFit.loose`, which passes loose (`max=∞`) constraints to its non-Positioned children. A `Column` (default `MainAxisSize.max`) containing `Spacer` (which is `Flexible(flex: 1)`) requires bounded height — Spacer needs something to flex against. Inside a loose-fit Stack, the Column receives unbounded height, the Spacer assertion-fails silently, and the failure propagates as `RenderBox was not laid out: hasSize` up the entire ancestry. The visible symptom is dramatic: every parent flex (the screen's outer Columns) ends up at size zero, so `PageHeader`, `FluxTabBar`, stat tiles, toolbar, etc. all paint at the same y=0 and visually pile on top of each other. The error stack often points at an unrelated `LayoutBuilder` further down (e.g. `_LibraryGrid`) — a red herring; the real culprit is the unbounded Spacer further inside. **Hit during desktop library M4 → P0+P1 expansion** (2026-05-03): the original M4 card had no Spacers; adding a vertical `Spacer()` in the card's `Stack > Padding > Column` to push name/path to the bottom collapsed the entire Library screen's layout. | Bound the Stack vertically before placing a Column-with-Spacer inside it. Three options that work, ordered by simplicity: (1) wrap the Stack in `SizedBox(height: <fixed>, child: Stack(...))` — gives the Stack tight height constraints, the Column gets bounded height naturally; (2) set `fit: StackFit.expand` on the Stack — passes tight constraints to non-Positioned children too; (3) wrap each non-Positioned child in `Positioned.fill(child: ...)`. Note: `BoxConstraints(minHeight: N)` on an ancestor is NOT sufficient — it gives a min but no max, which is still unbounded as far as Spacer is concerned. Pre-existing pattern in this codebase: no other card / Stack uses Spacer; they use `mainAxisAlignment: spaceBetween` or fixed-height stacked children. Prefer that pattern unless you specifically need the wrapping Stack. |
| Silent query-string contract drift between client and server | FastAPI ignores unknown query parameters silently — if the client sends `?unread_only=true` but the route declares `unread: bool = Query(default=False)`, the param is dropped, `unread` falls back to its default, and the request appears to "work" while returning the wrong dataset. The bug is dormant if no caller exercises the flag (which is exactly how the desktop notifications repo shipped — the cubit never asked for unread-only, so nobody noticed the rename). | When wiring a query param: (1) look up the actual server signature in the matching `apps/server/routers/*.py`; (2) pin the param name as a constant in `Endpoints` (or a sibling) so the spelling is reviewed once and reused everywhere; (3) prefer a typed integration test that asserts both response shape AND that the filter actually filtered (e.g. assert N rows instead of "no exception thrown"). Caught 2026-05-04 during the desktop notifications audit — `unread_only` (client) vs `unread` (server). |
| FFmpeg subprocess stderr → DEVNULL = invisible failures | The original `ffmpeg_service.start_stream` set both stdout and stderr to `asyncio.subprocess.DEVNULL`. When FFmpeg failed (hardware-encoder unavailable, codec mismatch, broken file metadata, etc.) the only diagnostic was the OS exit code — on Windows that's often `0xFFFFFFFE` / 4294967294, which is `STATUS_UNSUCCESSFUL`, which is "something went wrong". `PIPE` is the textbook fix but blocks FFmpeg the moment the OS pipe buffer fills (~64 KB) during a long transcode. | Capture stderr to a per-session `tempfile.mkstemp()` file. On premature exit OR playlist-creation timeout, read the last 4 KB and (a) log it under "FFmpeg stderr (last 4 KB):" and (b) bubble the first non-empty stderr line into the `RuntimeError` message so the operator notification carries actionable copy. `stop_stream` unlinks the temp file. Pattern lives in `apps/server/services/ffmpeg_service.py` (helpers `_drain_stderr` + `_drop_stderr`). |
| Always-transcoding burns CPU even on stream-copy-eligible sources | The original pipeline ran `-c:v libx264 -preset veryfast` for every playback regardless of source codec. On a 4K h264 file that's 95–100% CPU on a desktop CPU, when a remux (`-c:v copy`) would be ~5%. Hardware encoders help when transcoding is *needed*, but doing zero-cost remux when the source is already h264 / hevc is the larger win. | Branch on `media_files.codec_name` (back-filled at scan time via FFprobe — migration 016): `h264` → stream-copy with mpegts segments; `hevc`/`h265` → stream-copy with **fmp4** segments (Apple HLS spec — mpegts can't reliably carry hevc); anything else → full transcode. Audio still re-encoded to AAC 128 kb/s because source might be AC3/DTS/FLAC and not all HLS clients decode those (audio encoding is <3 % CPU so the cost is negligible). For files that pre-date migration 016, run a lazy `probe_video()` at stream-start and persist the result so the next play is constant-time. Logged at INFO with one of `mode=stream-copy(h264/mpegts)` / `stream-copy(hevc/fmp4)` / `transcode(<encoder>)`. |
| Android Dart VM doesn't support `reusePort: true` on UDP sockets | `multicast_dns` 0.3.x defaults its socket factory to `RawDatagramSocket.bind(..., reuseAddress: true, reusePort: true)` — fine on Linux desktop, but the Dart VM only implements `SO_REUSEPORT` on Linux. On Android the bind throws `"reusePort not supported on this platform"`, the `MDnsClient.start()` future never resolves, the lookup stream completes empty, and the user sees "unable to detect server" with no underlying signal. | Override `MDnsClient.rawDatagramSocketFactory` with a copy of the default body that forces `reusePort: false` (`reuseAddress: true` is sufficient for mDNS multicast on the Wi-Fi interface). Pattern lives in `apps/mobile/lib/features/connect/data/repositories/server_discovery_repository_impl.dart::_socketFactory`. Same ceremony will be needed for any other Dart UDP-multicast bind on Android (SSDP, etc.). |
| `audio_service` notification icons render as solid blocks if not white-on-transparent | Android's notification small-icon slot extracts the alpha channel and applies the system tint. Pointing `AudioServiceConfig.androidNotificationIcon` at a colour-filled drawable (typical launcher icon at `mipmap/ic_launcher`) renders as a solid white block instead of a recognisable glyph — same root cause documented for desktop taskbar peeks but easier to miss because the notification looks "kind of right" at a glance. | Ship a separate vector drawable at `apps/mobile/android/app/src/main/res/drawable/ic_stat_*.xml` with a single white-on-transparent path (alpha is the silhouette, RGB is ignored). Reference it as `'drawable/ic_stat_fluxora'` (no extension, no `@`) in `AudioServiceConfig.androidNotificationIcon`. Same rule for any future notification icon (`Notification.Builder.setSmallIcon`). The current Fluxora F-mark glyph lives at `res/drawable/ic_stat_fluxora.xml`. |
| Android PIP rejects extreme aspect ratios | `enterPictureInPictureMode(PictureInPictureParams.Builder().setAspectRatio(Rational(w, h)))` throws `IllegalArgumentException` if the ratio falls outside roughly `[1:2.39, 2.39:1]` — narrower than what mobile portrait video (9:16) or anamorphic widescreen (21:9) actually deliver. The throw happens deep in framework code, far from the Dart caller, and reaches the user as "PIP didn't work" with no actionable signal. | Clamp before calling. Convert the source `width / height` Rational to a double, `coerceIn(1.0/2.39, 2.39)`, then back to a `Rational(num*1000, 1000)` so we don't trip `Rational.parseRational` on huge numerators. Pattern lives in `apps/mobile/android/app/src/main/kotlin/.../MainActivity.kt::clampPipAspect`. The same range applies to `setSourceRectHint` if we ever wire that. |
| `WidgetsBindingObserver` in a `Cubit` requires the test binding | The Player polish round adds a sidecar `_PlayerLifecycleObserver` registered in `PlayerCubit`'s constructor (`WidgetsBinding.instance.addObserver(_lifecycleObserver)`) so the cubit can pause playback when the app goes to background. Existing unit tests call `PlayerCubit(...)` directly without ever instantiating Flutter's binding — accessing `WidgetsBinding.instance` then throws `Binding has not yet been initialized.` and *every* test in the file fails at construction time, with the failures pointing at line numbers far from the actual cause. | Call `TestWidgetsFlutterBinding.ensureInitialized()` once at the top of `main()` in any test file that constructs a Cubit / Bloc that touches `WidgetsBinding`, `MediaQuery`, `SystemChrome`, etc. Idempotent so it's safe to call alongside other test setup. The same fix pattern applies if a future cubit calls `SchedulerBinding.instance` or any other binding singleton. |
| Groups v1 → v2 semantic flip is *more permissive* on upgrade | Migration 025 flips `group_restrictions.allowed_libraries` from subtractive ("client can ONLY stream from these") to additive ("this group EXPOSES these"), and manufactures a Public group whose `allowed_libraries` is back-filled with **every** existing library so v1 clients in the no-restrictions baseline don't lose visibility. The catch: an operator who previously created a "Kids" group with `allowed_libraries=[Movies]` to *deny* TV access will find that post-migration the kid sees Public's libraries (which include TV) UNION Kids' libraries (Movies) = TV is back. The migration is more permissive than the v1 state for clients in groups. | Operator audit banner (the desktop CP shows a "Groups feature was upgraded — review your group config; access semantics changed" banner persisting until dismissed or 7 days pass). Pre-migration audit checklist documented in `docs/10_planning/13_groups_v2_content_spaces.md` §M5: for each existing group, verify it's acceptable that members will now see Public's libraries IN ADDITION to the group's restrictions. Operator typically responds by moving anything sensitive (TV in this example) out of Public and into a PIN-gated group. |
| `'[]'` JSON empty-array vs NULL in `allowed_libraries` is semantically loaded | v1's stream-gate intersect logic reads `allowed_libraries = '[]'` as "block everything" — every stream-start 403s for clients only in Public if the migration writes `'[]'` instead of `NULL`. v2's `get_visible_libraries` reads it as "no libraries from this group" (correct). The fork happens at migration time: a fresh install (no libraries yet) would naively `INSERT json_group_array(id) FROM libraries WHERE 1=1` and write `'[]'`, breaking every stream until the operator adds a library. | Migration 025 wraps the back-fill with `NULLIF(json_group_array(id), '[]')` — empty list collapses to NULL so v1's intersect logic doesn't trip while v2's resolution sees the same "no contribution" semantic. Future migrations touching this column should use the same pattern. The semantic is documented in the migration file's comment block. |
| PIN on a shared family tablet is "barrier-to-casual-access," not real auth | A 4-digit PIN has 10 000 combinations; rate-limit caps brute-force at ~7 200/day under sustained attack — meaningful but not impossible. More importantly, a kid watching a parent type the household PIN can defeat it instantly. The shared-PIN model (M4 default) is convenience-shaped, not security-shaped. | Documented explicitly in the create-PIN dialog copy: "Anyone who reads this PIN over your shoulder can access this group's content on this device." For sensitive content, use M8 per-client PIN mode (`pin_model='per-client'`) — each device enrolls its own PIN; compromise blast radius is one device. For real protection of compliance-sensitive content (CSAM-adjacent, medical, legal), out of scope for v1 — operator should use a separate user account on the OS, not a Fluxora group PIN. |
| Master override has no master password — auth is network proximity to localhost | The `POST /api/v1/groups/{id}/master-override?client_id=` recovery endpoint bypasses PIN compare entirely. There's no master credential stored anywhere; the auth boundary is `require_local_caller` (running on the server's loopback interface). An attacker with localhost access to the SQLite database can `UPDATE groups SET pin_hash = NULL` directly and bypass the entire access-control layer regardless — same trust boundary. | This is intentional and documented in `docs/04_api/01_api_contracts.md` next to the endpoint. **Don't add a "recovery passphrase" without thinking about what it actually buys.** A second secret to leak doesn't improve the threat model when the underlying database is already on the same machine. The legitimate paranoid-operator escalation is OS-level full-disk encryption + locked screen, not a server-level credential layer. |
| `enter_pin_grant` returning `enrollment_required` is M8-specific — don't translate to 401 | Old M4 callers expected `enter_pin_grant` to fail with `incorrect_pin` (401) only; the M8 hybrid PIN model adds `enrollment_required` (the calling client is in a per-client mode group with no enrollment row yet). Treating it as 401 routes the mobile UI to the PIN entry surface, which immediately fails with the same error in a loop. | The router-layer translation maps `enrollment_required` → 400 with detail "Per-client PIN enrollment required — call /enroll first" so the mobile parser routes to the *enrollment* surface, not the entry surface. The grant-status endpoint reports `enrollment_state ∈ {'not_required','enrolled','enrollment_required'}` so mobile can pick the right surface up-front without a failed /enter call. New service helpers: see `services/group_service.py`. |
| PIN `enroll/change` has to charge failed-old-PIN attempts against the rate limiter | Without this guard, the change-PIN endpoint becomes a brute-force bypass for the existing PIN: an attacker who captures a member's bearer token can hammer `/enroll/change` with `{old_pin: "????", new_pin: "0001"}` and observe whether each call succeeds or 401s — the same oracle the rate-limited `/enter` endpoint protects against, just spelled differently. | `change_member_pin` calls `_recent_failed_attempts` and writes a `success=0` row to `group_pin_attempts` on every wrong `old_pin`. After 5 failures in 60 s the (client, group) tuple locks out — same window as `/enter`. Documented in the function docstring; the corresponding test is `test_change_member_pin_wrong_old_charges_attempt`. |
| `GroupsCubit.load()` resets `selectedGroup` to `groups.first` after every refresh | Caught at M2 of the dedicated Group page work. The cubit's `load()` re-emits with `selectedGroup: groups.isNotEmpty ? groups.first : null` — fine for the list page, but the dedicated edit page focuses a *specific* group via the URL. After `updateGroup` the post-save `load()` would silently swap `selectedGroup` to first-group, and the page header would show the wrong group's name + status pill until the next route change. | The page derives its target group via `_resolveTargetGroup(state)` which looks up by `widget.groupId` from `state.groups`, NOT from `state.selectedGroup`. General rule: when a screen owns a specific entity by URL/id, look it up by id from the cubit's collection. Don't rely on cubit selection state — that's optimized for list-page drilldown, not deep-link editing. |
| `go_router` literal segment must be registered BEFORE the `:id` pattern at the same depth | `/groups/new` and `/groups/:id/edit` collide if registered in the wrong order — go_router takes the first match, and `:id` is happy to swallow the literal `'new'` as a UUID, sending the operator to a "Group no longer exists" page on the Create button click. | Register `/groups/new` first. In general, register all literal segments (`/new`, `/import`, `/templates`) before the parametric route (`/:id/...`). Pattern documented in `apps/desktop/lib/core/router/app_router.dart`; same trap awaits anyone adding a `/library/new` next to `/library/:id/files`. |
| `use_build_context_synchronously` can't follow `mounted` checks across loops or external functions | Repeatedly hit during the M5 Danger Zone work. `await someAsyncOp(); if (context.mounted) Navigator.of(context).pop();` is fine. But `await someAsyncOp(); for (...) await otherOp(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(...)` triggers the lint — the analyzer's mounted-tracking gives up at the loop. Same for `await cubit.x(); router.go(...)` if the router was resolved BEFORE the await. | Capture `BuildContext`-derived refs (cubit, messenger, GoRouter.of) at the top of the async method, BEFORE any await. These refs survive widget unmount: the cubit is owned by a higher-level provider, the messenger walks up to the nearest live one, GoRouter.of returns the app-scoped router. Pattern: `final cubit = context.read<X>(); final messenger = ScaffoldMessenger.of(context); final router = GoRouter.of(context); /* await stuff */ messenger.showSnackBar(...); router.go(...);`. Avoids the lint without disabling it. |
| Dart `_`-prefix privacy is library-scoped, not file-scoped | Caught at M4 when extracting `_PinSection` / `_GroupRestrictionsForm` from `groups_screen.dart` to a new `widgets/group_form_widgets.dart`. Two Dart files in the same package are separate libraries by default — a `_FooClass` in one is invisible to the other. The fix isn't `part of` (rarely worth the build-graph hassle); it's to drop the underscore on the genuinely-shared types and let the file's library boundary be the privacy unit. | Strategy: keep widgets that are leaf-only-internal-to-this-form private (`_HourField`, `_ChevronButton`, `_ClientPickRow`); rename the public-API ones (`_PinSection` → `PinSection`, `_GroupRestrictionsForm` → `GroupRestrictionsForm`, etc.). Helper functions that need to be reusable get the same treatment (`_formatTimeWindow` → `formatTimeWindow`). Document the rename in the new file's library docstring so future grep-spelunkers find it. |

---

## License key format changed silently from 4 to 5 segments

**Symptom:** Every settings `PATCH` returns 422 with `license_key: Value error, license_key must be in FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> format`, even when the user isn't editing the license field. The desktop UI shows "Server rejected one of the other settings" on every save attempt and there is no in-app path to clear the key (`license_key: null` means "leave unchanged"; `""` fails the validator).

**Root cause:** The Pydantic license-key validator was tightened from a 4-segment shape (`FLUXORA-<TIER>-<EXPIRY>-<HMAC8>`) to a 5-segment shape (`FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<HMAC8>`) during phase-4 development without a sanitiser migration. Existing rows in `user_settings` that held a 4-segment key continued to 422 every PATCH that included `license_key` in the body — which the Settings → General screen was doing unconditionally.

**Fix:** Migration 019 (`019_sanitize_license_key.sql`) runs `UPDATE user_settings SET license_key = NULL WHERE ...` on any row whose key doesn't match the 5-segment shape (counts dashes via `length - length(replace(key, '-', ''))`). The Settings → General `_save` was also updated to only include `license_key` in the PATCH body when the user has actually edited the field (compare to `_loadedSnapshot.licenseKey`). The Encoder Settings screen passes `licenseKey: null` unconditionally since it never edits the license.

**Lesson:** when tightening a Pydantic validator that governs a DB-persisted field, also write a sanitiser migration for any rows already in the DB that wouldn't pass the new validator. A validator change with no migration is a time-bomb that surfaces as a non-obvious 422 on the next settings save.

---

## FastAPI's bad-response body uses `detail`, not `error`

**Symptom:** `ApiException` surfaces as `ApiException(null, 422): Server error` — no actionable message. The user sees "couldn't reach the server" or a similarly generic string even though the server returned a 422 with a clear validation message.

**Root cause:** FastAPI puts validation errors under `body['detail']` — a string for `HTTPException`, or a list of `{loc, msg, type, ctx}` dicts for `RequestValidationError`. A client-side bad-response parser that only inspects `body['error']` silently swallows every Pydantic validation message into the generic fallback.

**Fix:** `ApiException.fromDioException` (in `packages/fluxora_core/lib/network/api_exception.dart`) was rewritten with an `extractMessage(body)` helper: prefer `body['error']` for legacy compatibility, fall back to `body['detail']` as a string, or render a Pydantic-list entry as `<loc[-1]>: <msg>` joined by `; `. The caller payoff: `license_key: Value error, license_key must be in FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> format` instead of `Server error`.

**Rule going forward:** any new API endpoint should put its user-facing error message under `detail` (FastAPI's default) and the client parser should already handle it. The old `body['error']` field is legacy — do not introduce new endpoints that use it.

---

## Pydantic v2 `ValueError` in `ctx` is non-JSON-serialisable

**Symptom:** a custom `RequestValidationError` handler returns 500 instead of the intended 422. The server log shows `TypeError: Object of type ValueError is not JSON serializable` inside the handler.

**Root cause:** Pydantic v2 attaches the original exception instance to each error dict's `ctx` field (e.g. `{"ctx": {"error": ValueError("must be in FLUXORA-...")}}`). A handler that calls `JSONResponse(content={"detail": exc.errors()})` passes a raw Python dict to `json.dumps` — which can't serialise a `ValueError` object. The handler itself crashes, and FastAPI surfaces the crash as a 500.

**Fix:** replace the `JSONResponse(...)` body with `await request_validation_exception_handler(request, exc)` (FastAPI's default handler). The default handler uses `jsonable_encoder` which wraps non-serialisable values correctly. Keep the logging call before delegating so the custom observation purpose is preserved. Pattern in `apps/server/main.py` (`_log_validation_error` handler).

**Rule going forward:** custom `RequestValidationError` handlers must either call `jsonable_encoder` on `exc.errors()` before passing to `JSONResponse`, or simply delegate to `request_validation_exception_handler` after their custom logic.

---

## `-hwaccel cuda` doesn't reliably auto-pick cuvid decoders for AV1

**Symptom:** AV1 source files fail during transcode with `[av1 @ ...] Failed to get pixel format` or similar, even when the operator has selected an NVIDIA encoder and the server log shows `-hwaccel cuda` in the FFmpeg argv.

**Root cause:** FFmpeg's `-hwaccel cuda` is documented to auto-select cuvid decoders (`av1_cuvid`, `hevc_cuvid`, etc.) for the input. In practice, on many bundled FFmpeg builds (especially Windows static builds), it falls through to the native software AV1 decoder — which is broken or missing on those builds. The auto-selection is silently a no-op.

**Fix:** inject an explicit `-c:v av1_cuvid` (or `hevc_cuvid`, `vp9_cuvid`, etc.) BEFORE `-i` via `_input_decoder_args(source_codec, encoder_meta)`. The position before `-i` is mandatory — FFmpeg processes input options before the `-i` flag; flags after `-i` apply only to output. Use the `_NVIDIA_CUVID_BY_CODEC` map to look up the correct cuvid decoder for each source codec.

However, cuvid AV1 itself rejects unusual chroma formats (HDR 10-bit on some GPUs, 4:4:4 / 12-bit on most consumer cards). Pair the hint with an auto-fallback retry path: `_is_cuvid_failure(stderr_tail)` matches cuvid-specific error strings; on match, retry without the hint. On bundled FFmpeg builds without `libdav1d`, the software fallback also fails — the operator sees the second error tail and must re-encode the source or replace the FFmpeg binary.

---

## HLS `independent_segments` flag lies during stream-copy with long-GOP sources

**Symptom:** stream-copy playback of game captures (NVIDIA ShadowPlay, OBS recordings) shows a black screen or stalls indefinitely until an IDR keyframe appears, which can be several seconds into the stream. The effect is worst on `libmpv`-based players and certain Roku / older smart TV builds.

**Root cause:** the `#EXT-X-INDEPENDENT-SEGMENTS` tag asserts that every HLS segment begins with an IDR (instantaneous decode refresh) keyframe. This is true for transcoded output — the encoder emits IDRs at segment boundaries via `-g` / `-force_key_frames`. It is NOT true for stream-copy when the source GOP exceeds `hls_time`. FFmpeg can only place segment boundaries at existing keyframes in the source; if the source uses 4–10 s GOPs (common in game captures), some `hls_time=6` boundaries land mid-GOP and the segment does not start with an IDR. Players that honour the tag buffer forever waiting for a segment-opening IDR that isn't there.

**Fix:** remove `-hls_flags independent_segments` for the stream-copy path. Also bump `-hls_time` from 6 to 10 seconds for stream-copy — more breathing room to align segment boundaries with long-GOP keyframes. Transcode mode keeps both flags and the 6 s segment time (the encoder controls the IDR cadence). Pattern in `apps/server/services/ffmpeg_service.py` — separate `common_hls` + per-path tail lists.

---

## Lazy import to break service circular dependencies

**Symptom:** server fails to start with `ImportError: cannot import name 'X' from partially initialised module 'services.Y'` (or similar). The error shows up at the top of the stack trace immediately on first request handling; existing tests that don't exercise the affected code path keep passing.

**Root cause:** two services in `apps/server/services/` reference each other at module-top. Specifically, `services/session_router.py` and `services/ffmpeg_service.py` form a cycle: `start_stream` calls `session_router.pick_encoder` to pick the encoder, while `release_session` is invoked from `stop_stream`. If both modules import each other at the top, Python's import resolver hits a partial-init state.

**Fix:** import the *callee* lazily, inside the function body that actually needs it, rather than at module-top. Pattern in `apps/server/services/ffmpeg_service.py`:

```python
async def start_stream(...):
    from services import session_router  # lazy — breaks the cycle
    ...
    encoder, _ = session_router.pick_encoder(chain, session_id, ...)

async def stop_stream(session_id: str) -> None:
    from services import session_router  # lazy — same reason
    ...
    session_router.release_session(session_id)
```

Per-call import cost is ~µs after the first call (Python caches modules); the structural cleanliness is worth it. Lifting the imports to module-top is a tempting clean-up — don't, you'll break startup.

---

## `-hwaccel cuda` itself fails on GPUs without AV1 NVDEC (Turing / RTX 20-series)

**Symptom:** AV1 source files fail with `Failed setup for format cuda: hwaccel initialisation returned error` or `Your platform doesn't support hardware accelerated AV1 decoding` in the stderr tail, even after the cuvid retry path should have caught the failure. Both the first and second FFmpeg attempts error out; the session returns 503.

**Root cause:** on RTX 20-series (Turing) and older GPUs there is no AV1 NVDEC hardware at all — not just "rejected chroma format" but "the decoder doesn't exist". Because the failure happens before the cuvid hint is even evaluated, the old `_CUVID_FAILURE_MARKERS` (which only matched `"cuvid"` substrings) did not recognise it as a GPU-input failure. The retry kept `-hwaccel cuda` in the second attempt, which failed for the same reason, leaving both attempts dead.

**Fix:** `_CUVID_FAILURE_MARKERS` was widened with three new substrings: `"hwaccel initialisation returned error"`, `"doesn't support hardware accelerated"`, `"hardware is lacking required capabilities"`. Additionally, the `use_cuvid` parameter in `_build_ffmpeg_cmd` was renamed `use_gpu_input` — when `False`, it drops **both** `meta.pre_input_args(device=…)` (which adds `-hwaccel cuda`) **and** `_input_decoder_args(…)` (which adds `-c:v *_cuvid`). The retry path now fully disables the GPU input pipeline; software decode feeds directly into NVENC encode via FFmpeg's automatic tensor upload. Pattern: `apps/server/services/ffmpeg_service.py`, `_CUVID_FAILURE_MARKERS` + `_build_ffmpeg_cmd(use_gpu_input=)`.

---

## fmp4 HLS init segment is unreliable across FFmpeg builds

**Symptom:** `seg00000.m4s` returns 200 but `init.mp4` returns 404; the player (media_kit / Safari) refuses to start playback. The log shows `"Manual init-segment generation raised for session"` or the HLS router logs repeated 404s for `init.mp4`.

**Root cause:** some bundled FFmpeg builds (especially Windows static builds) silently skip writing the fmp4 init segment under `-c:v copy` (stream-copy mode) even when `-hls_fmp4_init_filename init.mp4` is explicitly set. The HLS playlist already has `#EXT-X-MAP URI="init.mp4"` pointing at a file that doesn't exist on disk. In addition, `.m4s` and `.mp4` served with the wrong `Content-Type: video/MP2T` (correct for mpegts segments) cause Safari and media_kit to silently reject the response without reporting a parse error.

**Fix:** two changes together:
1. Explicit `-hls_fmp4_init_filename "init.mp4"` in the FFmpeg HLS args (was missing on some code paths, letting the build use its own default name which sometimes differs).
2. `_ensure_fmp4_init_segment(session_dir, file_path)` helper: after `start_stream` confirms FFmpeg is running, it checks whether `init.mp4` exists. If not, it runs a one-shot `ffmpeg -i <file> -t 0.04 -movflags +empty_moov+default_base_moof+frag_keyframe -f mp4 init.mp4` to write the init segment from scratch. The `moov` box produced this way matches the source's video configuration and the AAC config used for the segments; players parse it, set up the decoder, and skip the tiny `mdat`.
3. HLS router content-type: `.m4s` and `.mp4` extensions return `Content-Type: video/mp4`; only `.ts` files return `video/MP2T`. Pattern: `apps/server/routers/stream.py` `serve_hls` content-type block and `ffmpeg_service._ensure_fmp4_init_segment`.

---

## `Slider.onChanged` calling `player.seek(value)` per-tick rubber-bands the scrubber to max during forward drag

**Symptom:** dragging the scrubber forward in `FluxPlayerControls` causes the thumb to visually jump to the right edge mid-drag, then snap back to the actual release point once the seek-restart completes.

**Root cause:** `_ProgressBar` was a `StatelessWidget` whose Material `Slider.onChanged` callback fired `player.seek(clampedPlayerMs)` on every drag-tick.  For a forward drag, the requested player-time often exceeded the current playlist's apparent end-time → libmpv clamped the seek to the playlist end → the slider redrew using the player's clamped position → user saw the thumb rubber-band to the right edge.  The actual server-side seek-restart on `onChangeEnd` was already correct; the bug was purely a preview-rendering issue.

**Fix:** convert any seek-controlling slider to a `StatefulWidget` with a nullable `_dragValue: double?` local state.  During drag (`onChangeStart` + `onChanged`), only `setState(() => _dragValue = v)` — never call `player.seek` per-tick.  Render the `Slider.value` as `_dragValue ?? liveValue`.  On release (`onChangeEnd`), clear `_dragValue` and fire the parent's `onSeekCommit(target)`.  Pattern in `apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart::_ProgressBar`; future M14 polish should audit the desktop + offline UIs for the same shape.

## Scrubber paints at end of track for one frame after a forward server-restart finishes

**Symptom:** drag the scrubber forward >5 s, release, the seeking overlay shows, the seek completes — and just as playback resumes, the slider thumb visibly slams to the right edge of the track for a single paint, then settles at the actual seek target.

**Root cause:** `_commitServerSeek` ends with `emit(isSeeking: false, playlistOffsetSec: K_new)` — a single state update. In the widget tree the new `offsetMs = K_new × 1000` lands a paint or two **before** libmpv's `player.stream.position` catches up to the new playlist coordinates (the position emission lags the state emission). For one frame: `sourcePos = oldPlayerPos + K_new` against `sourceDur = newPlayerDur + K_new`, ratio explodes past 1.0, `clamp(0, 1)` drops it to 1.0, slider paints at the right edge.

**The seductive wrong fix:** clear the post-release pin in `didUpdateWidget` on the `isSeeking: true → false` transition. It looks clean. It preempts the very transient it's meant to mask.

**Fix:** keep a `_pendingValue: double?` "release pin" set in `Slider.onChangeEnd` and clear it via two paths only:
1. **Streams-have-settled** — post-frame check in `build`: when `!widget.isSeeking` AND the player's reported `sourcePos` lands within ~750 ms of the pinned target, schedule a clear via `WidgetsBinding.instance.addPostFrameCallback`. Handles both the in-player path (`isSeeking` never flips) and the post-restart path once libmpv catches up.
2. **5 s fallback `Timer`** armed in `onChangeEnd`, so a stalled seek can never strand the pin permanently.

Render `Slider.value = _dragValue ?? _pendingValue ?? liveValue`. The pin holds the slider at the user-released fraction across the whole seek-commit window, including the bad-ratio frame after the final emit. Pattern in `apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart::_ProgressBar`. Cubit complement: emit `isSeeking=true` *immediately* on entering the server-restart branch in `seekTo` (before the 300 ms debounce), so the pin's gate is 1:1 with the cubit's flag through the whole window.

## `-readrate 1.5` on stream-copy delays the post-restart first segment past the segment-serve timeout → 404 storm

**Symptom:** after a forward seek-restart on a stream-copy session (h264/mpegts or hevc/fmp4), the next segment 404s repeatedly (`seg00195.ts not found`) until media_kit gives up after a handful of retries.

**Root cause:** the §17 M3 retry of `-readrate 1.5` was being applied to stream-copy too.  Stream-copy is already CPU-cheap (~real-time disk-read + remux); the throttle delays the post-restart first segment past the 2 s segment-serve wait timeout.  Router returns 404 → media_kit retries a few times, then surrenders.

**Fix (§17 same-day follow-on):** gate `-readrate` (and the burst flag) to **transcode-only**: `if not direct_remux and not apply_hdr_tonemap:`.  Stream-copy paths get neither flag.  The timeout-floor bump in `_spawn_ffmpeg_attempt` was tightened to match the same gate.  Pinned by the new `test_build_ffmpeg_cmd_omits_readrate_for_stream_copy` regression guard.

## "FFmpeg failed: exit code 1" with `<no stderr captured>` actually means we killed it ourselves

**Symptom:** server logs `FFmpeg exited prematurely with code 1: session=<sid>\nFFmpeg stderr (last 4 KB):\n<no stderr captured>`. Operator notification says "FFmpeg failed: exit code 1". No clue what went wrong.

**Root cause:** `_spawn_ffmpeg_attempt` polls for the playlist file to appear within 10 s. CPU-bound pipelines (HDR→SDR tonemap with `zscale` runs at ~0.6× realtime; software AV1 decode + NVENC encode similar) can't produce the first segment within that window. After 10 s, `proc.terminate()` is called. On Windows, `terminate()` is `TerminateProcess(handle, 1)` — which **sets the returncode to 1** even though FFmpeg never voluntarily exited with code 1. Combined with `-loglevel error` and stderr buffering, FFmpeg never flushes any error-class output before being killed, so the captured stderr is empty.

**Why this is misleading:** the diagnostic looks like a real FFmpeg crash. Operators chase nonexistent codec / driver / source-file bugs. The actual answer is "FFmpeg was working fine; we didn't wait long enough".

**Fix (shipped 2026-05-05, Commit 1 of [`docs/10_planning/11_streaming_pipeline_issues.md`](../10_planning/11_streaming_pipeline_issues.md)):** `_spawn_ffmpeg_attempt` now accepts `playlist_timeout_sec`. `start_stream` selects 60 s for tonemap, 30 s for software transcode, 10 s for stream-copy + hardware transcode (cuvid retry bumps to ≥30 s). The function returns `killed_after_timeout: bool` in its tuple so the error path can distinguish "we killed it" from a real FFmpeg crash and emit "FFmpeg killed after Ns timeout — likely slow tonemap or software transcode on this CPU" instead of "exit code 1". `_build_ffmpeg_cmd` switches transcode sessions to `-loglevel warning` so suppressed-under-error stderr finally reaches the captured tempfile; stream-copy stays `error`.

**Follow-on fix (shipped 2026-05-08, [`docs/10_planning/17_ffmpeg_diagnostics_and_m2_retry_plan.md`](../10_planning/17_ffmpeg_diagnostics_and_m2_retry_plan.md) M1):** the conditional `warning`/`error` split was the original sin — two M2 `-readrate` retries failed with `<no stderr captured>` because FFmpeg's init messages were below the warning threshold, AND the HDR-audio diagnostic blind-spot recurred because `error` on stream-copy hid the AAC mux warnings.  `_build_ffmpeg_cmd` now uses `-loglevel info` for **every** session.  Init-time errors, decoder-rejection messages, and slow-source-disk read complaints all reach the captured stderr.  The 4 KB `_drain_stderr` cap means in-memory cost is unchanged.  Plan §17 §1.3 has the full incident.

---

## HLS playlist grows during encode unless pre-emitted as VOD

**Symptom:** the player's seek bar starts at 0 s and grows in real time over the encode duration. The user cannot seek past FFmpeg's current write position — attempts to do so result in a 404 on the requested segment.

**Root cause:** FFmpeg's HLS muxer emits an incremental, ever-growing playlist as it produces segments. Without `#EXT-X-PLAYLIST-TYPE:VOD` + `#EXT-X-ENDLIST`, `media_kit`, Safari, and most other HLS players treat the stream as live. Their seek bar only spans the duration covered by segments already in the playlist.

**Fix:** `_write_static_vod_playlist(playlist, duration_sec, hls_time, use_fmp4)` runs immediately after `_spawn_ffmpeg_attempt` succeeds. It writes a complete `#EXT-X-PLAYLIST-TYPE:VOD` playlist to `playlist.m3u8` (the path the HLS router serves) listing every expected segment (`ceil(duration_sec / hls_time)` EXTINF lines) and `#EXT-X-ENDLIST`. FFmpeg's own incremental playlist is redirected to `_ff_playlist.m3u8` so it doesn't overwrite ours. The HLS router waits up to 5 s for not-yet-written segments (50 × 100 ms polls) before returning 404, which covers seek-ahead-of-encode without stalling indefinitely. Fallback: when `duration_sec` is unknown (file pre-dates migration 016 and lazy probe returned nothing), the service copies `_ff_playlist.m3u8` to `playlist.m3u8` and the player degrades to the old growing-bar behaviour.

**Limitation:** stream-copy aligns segments to source keyframes, not to `hls_time`. The predicted segment count is an upper bound — the last few segments listed in the static playlist may never be written if the source's final keyframe falls before the last predicted boundary. Players retry-then-skip on 404 within reason; the operator-visible effect is at most a brief stutter at end-of-file.

---

## `session_id` is generated by the route handler, owned by `session_router`

**Symptom:** a future refactor moves session-ID generation into `ffmpeg_service.start_stream`. Cap accounting starts to leak: `_active_session_count_for_encoder('h264_nvenc')` keeps climbing past 3 even when streams have stopped.

**Root cause:** `services/session_router.py` reserves a slot keyed on `session_id` at `pick_encoder` time and frees it via `release_session(session_id)`. The contract is that the *caller* (`apps/server/routers/stream.py`) generates the UUID, hands it to `start_stream`, and the same UUID later flows into `stop_stream`. If the route handler stops generating it and `ffmpeg_service` starts manufacturing IDs internally, the released ID won't match the reserved ID — and the cap accounting silently leaks.

**Fix:** keep `session_id` generation in `routers/stream.py`'s `start_stream` route handler. Treat `start_stream(file_path, session_id, hls_root)` and `stop_stream(session_id)` as ID-consuming, not ID-generating. The router persists the same `session_id` to `stream_sessions.id`, so the chain `route handler → start_stream → session_router → stop_stream → release_session` all uses one ID. Document in the `session_router` module docstring that the cap accounting is keyed on caller-supplied `session_id` and any change to the ownership of that ID must be traced through every call site.

---

## TMDB queries with year/quality suffixes return zero results

**Symptom:** files like `Harry_Potter_and_the_Half_Blood_Prince_2009` or `Inception.2010.1080p.BluRay.x264` produce `TMDB enrichment done: 0/N files updated` even though the titles are real and the API key is valid.

**Root cause:** TMDB's `?query=` endpoint treats every word as a content keyword that must appear somewhere in the title or overview.  Movie titles almost never contain the release year, resolution, codec, or release-source tokens — so leaving "2009" / "1080p" / "BluRay" / "x264" in the search keyword filters out the very title we're trying to find.  Field-confirmed against the user's library: zero results with the year, one match without.

**Fix:** `library_service._clean_tmdb_query(stem)` strips trailing scene-noise (year + quality / codec / source / audio markers) before the TMDB call.  The strip is *trailing-only* — `"Blade Runner 2049 sequel notes"` keeps its year because the strip pattern only fires when year-and-after runs cleanly to end-of-string through known scene tokens.  See `_TRAILING_SCENE_NOISE` regex in [`apps/server/services/library_service.py`](../../apps/server/services/library_service.py) for the full noise-token list.

The cleanup also handles two adjacent issues that surface together: underscore-separated stems (`Harry_Potter_..._2009`) get spaced out before the strip runs, and Plex-style year wrapping (`Inception (2010)` / `Inception [1999]` / `Inception - 2010`) is normalised into the same end-of-string pattern.

---

## ISP-level DNS hijack and IP-block on TMDB hosts

**Symptom:** `services.tmdb_service` raises `ConnectTimeout` on every TMDB call.  No specific TMDB query works.  The server log shows `ConnectTimeout: ConnectTimeout('')` for every enrichment attempt.

**Root cause:** Some ISPs block media-metadata sites at the network level.  Two patterns we've seen:

1. **DNS hijack** — the ISP's resolver returns a sinkhole IP (typically inside their own AS) for `api.themoviedb.org`.  TCP to that IP times out because nothing is listening for HTTPS there.  Confirmed with `nslookup api.themoviedb.org 1.1.1.1` (returns the real Amazon CloudFront `3.165.239.x`) vs `nslookup api.themoviedb.org` against the ISP resolver (returns e.g. `49.44.79.236`, in Reliance Jio AS).
2. **IP block** — even with the correct DNS answer (via DoH lookup against `1.1.1.1/dns-query`), packets to TMDB's CDN ranges still get dropped.  The hijack is enforced at the routing layer too.

**Fix:** two complementary mitigations:

- **DoH override** ([`apps/server/utils/dns_override.py`](../../apps/server/utils/dns_override.py)) — monkey-patches `socket.getaddrinfo` with a per-process map.  On the first `ConnectTimeout`, `TmdbService` resolves the TMDB host via Cloudflare DoH (URL `https://1.1.1.1/dns-query` reached by IP, no recursive DNS needed) and retries.  Handles the DNS-hijack-only case.
- **Cloudflare Worker reverse proxy** — operator deploys a Worker on a domain they control that proxies `/tmdb/*` and `/tmdb-img/*` to TMDB.  Server uses `FLUXORA_TMDB_BASE_URL` / `FLUXORA_TMDB_IMAGE_BASE_URL` env vars to point at the proxy.  ISP can't IP-block your domain without breaking everything else on Cloudflare's anycast edge.  Handles the harder IP-block case.  See [`docs/05_infrastructure/runbooks/12_tmdb_proxy_worker.md`](../05_infrastructure/runbooks/12_tmdb_proxy_worker.md) for the Worker code + deployment steps.

The two mitigations stack: DoH override is the always-on fallback that handles simple hijack networks at zero ops cost; the Worker proxy is the operator's deliberate setup that handles the harder networks for every Fluxora user under their domain.

---

## Operator reports "server is still using CPU/GPU during client-decode mode"

**Symptom:** the operator set `streaming_mode = 'client-decode'` in Settings → Encoder Settings, but the server's CPU or GPU load remains elevated during playback. The transcoding screen shows an active transcode session. "Why is my server transcoding?"

**Root cause (multiple):** `client-decode` stream-copies h264/hevc/av1/vp9 when the source codec is in the direct-remux whitelist. But several conditions override the whitelist and force a transcode regardless of the global setting:

1. **Source codec outside the whitelist** — `mpeg4`, `prores`, `mjpeg`, `wmv`, `mpeg2video`, and other older codecs are not in `{h264, hevc, av1, vp9}`. The server has no choice but to transcode. This is correct and expected behaviour.
2. **HDR + tonemap enabled** — when the session is started with `?tonemap=true`, the server forces a full transcode to apply the `zscale + Hable BT.2020 PQ → BT.709 SDR` filter chain. CPU-side decoding (`zscale` requires CPU frames) is the reason.
3. **Per-library override** — an individual library may have `av1_stream_copy_override = 0` or `vp9_stream_copy_override = 0` (force transcode). Set by the operator on the Library edit form.
4. **Per-client blocklist hit under `streaming_mode = 'auto'`** — if the mode is `auto` (not `client-decode`), a prior player-error within 6 s may have written a `(client_id, source_codec)` row to `client_codec_blocklist`, causing that session to start directly in transcode. Strict `client-decode` ignores the blocklist.

**Diagnostic:** every session start writes exactly one `stream_decision` INFO log line to the server log:

```
stream_decision session=<id> source_codec=<codec> mode=<auto|client-decode|server-transcode> path=<stream-copy|transcode> reason=<reason>
```

`reason` values:

| Reason | Means |
|--------|-------|
| `always-passthrough` | Source is h264/hevc and always stream-copies (no override) |
| `global-client-decode` | AV1/VP9 stream-copy because `streaming_mode='client-decode'` |
| `global-auto` | AV1/VP9 stream-copy first attempt under `streaming_mode='auto'` |
| `global-server-transcode` | AV1/VP9 forced transcode because `streaming_mode='server-transcode'` |
| `unsupported-source-codec` | Codec not in whitelist (mpeg4, prores, etc.) → forced transcode |
| `hdr-tonemap` | Tonemap requested → forced transcode |
| `library-override` | Per-library `av1/vp9_stream_copy_override = 0` |
| `forced-fallback` | `streaming_mode='auto'` + prior blocklist hit for this `(client, codec)` |

**Quick grep to find every session that transcoded unexpectedly:**

```bash
grep 'stream_decision.*path=transcode' ~/.fluxora/logs/server.log | tail -20
```

Check the `reason=` field on each line — the first unexpected value tells you which cause applies.

**Diagnostic checklist when a user reports "TMDB doesn't work":**

1. **Confirm the exception class** — log line should now read `ConnectTimeout: ConnectTimeout('...')` (the `repr()` makes the class name explicit; without it the line read `'X': ` with nothing after the colon, masking the cause).
2. **`nslookup api.themoviedb.org 1.1.1.1`** — if the IP is in Cloudflare/Amazon CloudFront ranges (`104.x`, `172.x`, `3.x`), DNS is fine.  If it's anywhere else (private space, ISP AS), DNS is hijacked.
3. **`Test-NetConnection api.themoviedb.org -Port 443`** — if `TcpTestSucceeded: False` even when DNS returned a real IP, IP-level block is in play.  Worker proxy is required.
4. **Workers.dev URL test** — `curl https://<worker-name>.<account>.workers.dev/tmdb/3/configuration?api_key=KEY` → if this works, Cloudflare anycast reaches you and the Worker is the right fix.

---

## Windows DNS Client caches NXDOMAIN past `ipconfig /flushdns`

**Symptom:** A subdomain that resolves correctly via `nslookup <host> 1.1.1.1` and `nslookup <host> 8.8.8.8` still produces `curl: (6) Could not resolve host` from `curl.exe` even after `ipconfig /flushdns`.  `httpx` / `requests` / Python `socket.getaddrinfo` calls produce the same failure.

**Root cause:** Windows' DNS Client service maintains its own NXDOMAIN cache that `ipconfig /flushdns` doesn't always clear.  When a hostname previously didn't exist (e.g. you just added the DNS record), the negative cache can hold onto that for the original TTL despite the flush.  `nslookup` queries DNS directly and bypasses this cache, so it sees the fresh record while `curl` sees the cached miss.

**Fix:** restart the Windows DNS Client service (admin PowerShell):

```powershell
Restart-Service Dnscache
```

Or wait for the negative cache to expire (typically 15 minutes to several hours depending on TTL).  This is a Windows quirk; not reproducible on Linux / macOS.

**For Fluxora specifically:** if a user reports a custom proxy URL (`fluxora-api.<your-domain>`) doesn't resolve, instruct them to use the workers.dev URL fallback or run the service-restart.  The workers.dev subdomain is functionally identical and avoids this whole class of issue.

---

## FastAPI dependency-injector hides positional-arg signature changes from the type checker

**Symptom (2026-05-06, F2/F3 work):** added a positional `request: Request` parameter to `validate_token(...)`. Every call site that resolves through `Depends(validate_token)` keeps working (the injector binds parameters by name, not position). One direct call site at `routers/stream.py:425` — `await validate_token(credentials, db)` — silently broke at runtime: `credentials` was being passed as the new `request` argument, surfacing as `AttributeError: 'Connection' object has no attribute 'credentials'` from inside `get_trusted_client_by_token`. Pyright / mypy did not catch it because Python's gradual typing is permissive about positional argument count for async functions.

**Root cause:** FastAPI's dependency injector inspects function signatures and binds by name, so adding a parameter at any position is safe for `Depends()`-resolved callers. Direct calls (`await validate_token(...)`) bind positionally and break. The two coding patterns coexist in `apps/server/routers/` (most routes use `Depends`; `stream.stop_stream` and `validate_token_or_local` call directly to allow conditional auth).

**Fix:**
1. **Catch:** Always grep for direct call sites of any function used as a FastAPI dependency before changing its signature. `Grep` for `await <fn_name>\(` (excluding the `Depends(<fn_name>)` form) and update each by hand.
2. **Test:** Keep at least one integration test per such function that exercises the non-`Depends` direct path. `test_stop_stream_wrong_client` caught the F2/F3 break — it's the kind of test that should never be deleted.
3. **Prefer keyword args at direct call sites** (`validate_token(request=request, credentials=credentials, db=db)`) so future positional rearrangements don't break them.

---

## `clients.last_seen` was frozen at pair/approval before migration 023

**Symptom:** Reading `clients.last_seen` and treating it as "minutes-ago freshness" returned stale data — the column was only written at `request_pair` (insert/upsert) and `approve_client` (token rotation). Any UI that displayed "Last seen 3 minutes ago" was lying about traffic volume; the value was effectively a "last paired/approved" timestamp.

**Root cause:** No heartbeat path existed. `validate_token` did not write back to the row it validated against. The desktop's "Online Now" stat tile counts `is_trusted=1 AND status='approved'`, which masked the issue visually — you can be "online now" without your `last_seen` being recent.

**Fix (migration 023):** `auth_service.update_client_heartbeat(db, client_id, last_ip=None)` is now called from `validate_token` after every successful resolution. Best-effort — wrapped in try/except + WARNING log so a transient SQLite write failure can't 401 a valid request.

**Audit follow-up:** Anything that previously interpreted `last_seen` as a paired-at proxy now sees a live value and may surprise users. Mobile profile screen, desktop Clients table "Last Active" column, and Dashboard "Connected Clients" stat tile are the known consumers — verify each renders the new semantics correctly. Tracked in [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md).

---

## Tunneled requests record loopback IP, not real public IP

**Symptom:** `clients.last_ip` (migration 023) for any request that arrived via the Cloudflare Tunnel records `127.0.0.1`, not the device's real public IP.

**Root cause:** `request.client.host` returns the immediate socket peer. For tunneled traffic, that's cloudflared forwarding from loopback. The real public IP arrives in the `CF-Connecting-IP` HTTP header, which the heartbeat path (`auth_service.update_client_heartbeat`, called from `validate_token`) does not consume.

**Fix (current behaviour, intentional):** The field's primary v1 use case is **LAN device identification** for pair-debug — the operator looks at the desktop Clients table to confirm a phone is on the expected network. For that use case, the loopback IP recorded for tunneled traffic is a clear "this device isn't on LAN" signal, not a bug.

**If you need the real public IP:** read `request.headers.get("CF-Connecting-IP")` in the heartbeat path, gate it behind an opt-in setting, and update [`docs/06_security/01_security.md`](../06_security/01_security.md) "Sensitive Data Handling" to reflect the new privacy surface (persisting public IPs from internet traffic is materially different from persisting LAN IPs).

---

## Golden-test baselines drift silently after theme cutovers

**Symptom (2026-05-06):** `apps/desktop/test/goldens/m3_dashboard_golden_test.dart` fails with 62.77 % pixel diff against the stored baseline. Dashboard code untouched in the failing session — the diff is leftover drift from the V2 theme cutover whose baseline was never regenerated.

**Root cause:** Theme / typography / token changes propagate through every screen at once. A single golden baseline against an old theme then fails on every run until regenerated. `flutter test` (no exclusion) surfaces it in the suite output even though the failure has nothing to do with the change being tested. False-positive "regression" signal masks real ones.

**Mitigation (immediate):** When intentionally changing global theme tokens, regenerate every golden baseline in the same PR via `flutter test --tags=golden --update-goldens`. When *not* changing global tokens but a baseline is failing, investigate whether the baseline was ever updated for the last cutover — if not, regenerate or re-skip rather than treating the diff as a regression.

**Mitigation (long-term):** [`golden_toolkit` is discontinued](#golden_toolkit-is-discontinued); migrating to `alchemist` or vanilla `flutter_test` `matchesGoldenFile` is queued in [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md). Until then, treat the `m3_dashboard_golden_test.dart` baseline as suspect and prefer `flutter analyze` + targeted unit tests for verifying screen-level changes.

---

## `FluxGlassDialog` is the canonical `AlertDialog` replacement — discoverability gap

**Symptom (2026-05-06, F7 work):** Replacing 5 Material `AlertDialog` instances on the Groups screen, the original audit framing said "build a `FluxDialog` primitive." `FluxGlassDialog` had been shipped at `lib/shared/widgets/flux_glass_dialog.dart` since the M3 era and was already in production use on Library / Pair Device / Subscription Upgrade — but no doc named it as the canonical replacement, so a fresh agent reading the audit had no signal.

**Fix:** Doc-only. [`DESIGN.md`](../../DESIGN.md#real-glass-vs-opaque-raised-the-policy-after-2026-05-04) and [`docs/08_frontend/01_frontend_architecture.md`](../08_frontend/01_frontend_architecture.md) now both flag `FluxGlassDialog` as the canonical replacement explicitly. **Rule:** never use Material `AlertDialog` for new code; always use `FluxGlassDialog`. `Dialog`-with-custom-child patterns are also fine for special cases (Library Add/Edit uses `StatefulBuilder` inside) but they should still wrap the inner content in the `FluxGlassDialog` shell rather than rolling their own `Dialog(transparent) → BackdropFilter` boilerplate. The widget already accepts arbitrary `Widget` children for `title` / `content` / `actions`.

---

## Dart 3 records don't allow forward declarations

**Symptom (2026-05-06, A10 work):** Tried to forward-declare three typed locals before an `if/else` branch that would assign them:

```dart
final stats = ...;
final (String label, Color color, DotStatus dot);  // ← parse error
if (...) { label = '...'; color = ...; dot = ...; }
```

The Dart 3 parser interprets `(String label, Color color, DotStatus dot)` at expression position as a record *literal* (with positional fields named `label` / `color` / `dot`), so `final (...);` becomes `final <record-literal>;` — invalid because record literals can't be uninitialised. Diagnostics surface as a cascade of "Expected an identifier" / "Expected to find ';'" with `Color`-the-class flagged as a "variable name."

**Root cause:** Dart 3 records support **destructuring on assignment** (`final (a, b) = (1, 2);`) and **pattern-matching** (`switch (record) { (a, b) => ... }`), but there is no syntax for "declare uninitialised vars in record shape." The pattern `final (T x, T y);` looks like it should work by analogy with C# tuple deconstruction; it doesn't.

**Fix:** Use three separate `late final` declarations:

```dart
late final String label;
late final Color color;
late final DotStatus dot;
if (...) { label = '...'; color = ...; dot = ...; }
```

`late final` is the right escape hatch — it preserves the "assigned exactly once" guarantee and works inside any control-flow branch.

---

## Stateful → Stateless conversion misses references inside conditional branches

**Symptom (2026-05-06, A9 work):** Converted `_NetworkTab` from `StatefulWidget` to `StatelessWidget` to lift its state up to the parent. After the conversion, four references survived the first edit pass and broke `flutter analyze`:

- `widget.cubit.checkRemoteAccess()` (no longer has `widget`).
- `widget.state` access inside an `if (configured && state != null)` block where Dart's flow analysis no longer narrows `state` (was a local; now a class field).
- `_relayCtrl` (was an instance field; now a constructor param named `relayCtrl`).

The references were inside conditional branches the IDE pattern-match didn't reach during the rename, so they weren't auto-fixed.

**Root cause:** "Convert to Stateless" is mechanical at the class declaration but leaves the body's references to instance state untouched. Anything inside an `if`, `switch`, or nested closure can hide an old `widget.X` or instance-field access.

**Fix recipe** when converting `StatefulWidget` → `StatelessWidget`:
1. Rename the class; drop the `State<...>` half.
2. Search-replace `widget\.` → `` (bare access) inside the class.
3. Convert each instance field to a constructor parameter (`final ... this.x;`).
4. **Re-run `flutter analyze`** before declaring the conversion done — every surviving reference will surface as either "Undefined name 'widget'" or "Undefined name '_field'." Step 4 is non-negotiable; without it conditional branches silently retain dead references.
5. For class fields that read as `state.X` where `state` is nullable, Dart's flow analysis no longer narrows them inside `if (state != null)` blocks the way it does for locals — use `state!.X` or extract a local copy first.

---

## Cubit state shapes — sealed unions vs flat classes

**Symptom (2026-05-06, A10 work):** Pattern-matched on `SystemStatsCubit`'s state assuming it was a sealed union with `SystemStatsLoaded` / `SystemStatsError` subclasses:

```dart
final (label, color, dot) = switch (stats) {
  SystemStatsLoaded() when stats.latest != null => ('Running', emerald, online),
  SystemStatsError() => ('Unreachable', red, offline),
  _ => ('Checking…', muted, idle),
};
```

Compiled to "Undefined class `SystemStatsLoaded`" — those subclasses don't exist.

**Root cause:** Different Cubits in this codebase use different state-class patterns:

- **Sealed-union pattern**: `SettingsState` (`SettingsInitial` / `SettingsLoading` / `SettingsLoaded` / `SettingsSaved` / `SettingsError`), `ClientsState`, `LibraryState`. Designed for `switch`-on-subclass.
- **Flat-with-nullables pattern**: `SystemStatsState` is a *single* `Equatable` class with nullable `latest` and `errorMessage`. The "loading" / "loaded" / "error" axes are encoded as combinations of those nullables.

**Rule of thumb:** before pattern-matching on a Cubit's state, open the `_state.dart` file and confirm the shape. If you see one class with `final ... ?` fields, it's flat — match on tuples or guards (`(latest: != null, errorMessage: != null)`). If you see `sealed class X` or a hierarchy of `final class A extends X / B extends X / ...`, it's a union — switch on the subclass.

**Pattern for `SystemStatsState` specifically** (kept here so the next consumer doesn't re-derive it):

```dart
final stats = context.select<SystemStatsCubit, SystemStatsState>((c) => c.state);
late final String label;
late final Color color;
late final DotStatus dot;
if (stats.latest != null && stats.errorMessage == null) {
  label = 'Running'; color = AppColors.emerald; dot = DotStatus.online;
} else if (stats.errorMessage != null) {
  label = stats.latest != null ? 'Degraded' : 'Unreachable';
  color = AppColors.red; dot = DotStatus.offline;
} else {
  label = 'Checking…'; color = AppColors.textMutedV2; dot = DotStatus.idle;
}
```

The `latest != null && errorMessage != null` case ("had a sample, latest poll failed") is what distinguishes "Degraded" from "Unreachable" — drop that branch only if you don't care about the difference.

---

## "Every desktop request times out at 30 s but the server is up"

**Symptom (2026-05-06):** the desktop app's poll cubits (`SystemStatsCubit`, `DashboardCubit`, `LibraryCubit`, `RecentActivityCubit`, `LogsCubit`, `NotificationsCubit`, `StorageCubit`) all log `DioException [receive timeout]: The request took longer than 0:00:30.000000 to receive data` with `HTTP null` against every endpoint they hit. From the desktop, the UI freezes on loading skeletons; from a separate `curl` / PowerShell `Invoke-WebRequest` the same endpoints respond in tens of milliseconds.

**Root causes** (in observed order of frequency):

1. **VSCode `debugpy` paused.** When the server runs under `python -m debugpy --connect ... -m uvicorn main:app`, any breakpoint hit OR any "Break on raised exceptions" trip freezes the entire async event loop. The TCP listener still accepts connections (so the desktop sees `connection succeeded`) but the request handler never runs, so Dio waits the full `receiveTimeout` for a response. Common trip: `asyncio.CancelledError` in `ffmpeg_service.test_encoder` cleanup — fires routinely during encoder probes, but VSCode's "Raised Exceptions" breakpoint will halt on it. Fix: hit Continue in the debugger, and uncheck "Raised Exceptions" / "User Uncaught Exceptions" under Run & Debug → Breakpoints.
2. **Stale `serverUrl` in `flutter_secure_storage`.** The desktop saves the last-used URL. If it's a LAN IP that's no longer the server's address (laptop moved networks, DHCP renewal), Windows accepts the SYN to "some address that has a route" and waits for a response that never comes. Fix: Settings → General → "Control Panel Connection URL" → click **Test** to probe (uses `/healthz` with 3 s timeout and reports inline), then **Reset** → Save.
3. **Dio connection-pool wedge after a previous slow request.** Less common; usually clears with a hot-restart.

**Why the symptom looks like the server is hung:** receive-timeout, not connect-timeout. The connection establishes (TCP three-way handshake completes against the kernel listener), but no application-level response arrives. From the desktop's perspective there's no way to tell "server hung" from "wrong host that happens to accept connections."

**Mitigations shipped 2026-05-06:**

- **Desktop `ApiClient` registers with 3 s connect / 10 s receive timeouts** ([`apps/desktop/lib/core/di/injector.dart`](../../apps/desktop/lib/core/di/injector.dart)) instead of the shared core's 10 s / 30 s defaults. Mobile keeps the longer values because cellular round-trips can legitimately exceed 10 s on weak signal. Constructor params on `ApiClient` (`connectTimeout` / `receiveTimeout`) are the seam — pass them at registration; do not edit the core defaults.
- **Always-visible "Test" button** on Settings → General → URL row. Pings `/healthz` against the URL currently typed in the field (not the saved one) using a throwaway Dio with 3 s timeouts. Reports "Reachable in N ms" / "Connect timed out" / "No response within timeout — check if the debugger is paused" / "Could not reach …" via SnackBar. Self-serve for both the debugger-pause case and the wrong-URL case. Lives in `_SettingsViewState._probeServer`.

**Diagnostic order** (when this symptom shows up again):
1. Click **Test** in Settings → General. SnackBar text tells you what's wrong:
   - "Reachable in N ms" → not a network problem; check the cubit's specific endpoint with curl.
   - "No response within timeout" → server accepted connection but never responded. **Debugger paused** is the leading cause.
   - "Could not reach …" → wrong URL or server down.
2. If debugger is paused, hit Continue and uncheck "Raised Exceptions" in VSCode Run & Debug.
3. If URL is wrong, click **Reset** → Save.
4. If server is genuinely down, restart it.

If the desktop UI is wedged before you can click Test (poll cubits saturating the Dio queue), close the app, reopen — the new 3 s/10 s timeouts mean any wedge clears in seconds rather than minutes.

---

## Cubit `emit` after `close()` — `Bad state: Cannot emit new states after calling close`

**Symptom (2026-05-06):** post hot-restart, the desktop app logs `Bad state: Cannot emit new states after calling close` from cubits' async methods. Stack traces point at `BlocBase.emit` in places like `RecentActivityCubit._fetchAll`, `LibraryCubit.load` — methods with `await _repository.fetch(); emit(...)` patterns. The exception is non-fatal (it propagates as an unhandled async exception, not a crash), but it pollutes the log and indicates a real lifecycle hazard: data fetched after the cubit closed is silently discarded with no clean signal to the caller.

**Root cause:** `bloc` 9.x throws on `emit` after `close()` instead of silently no-oping. Any cubit method that awaits something (HTTP request, timer tick, stream event) and then calls `emit(...)` is at risk if the cubit can be closed mid-await — which happens during:

- **Hot restart.** Old cubit instances are torn down while in-flight requests / timers complete.
- **Screen disposal.** `BlocProvider`-scoped cubits close when the screen pops; an in-flight request finishing afterward calls `emit` on a dead cubit.
- **DI singleton churn.** `getIt.reset()` during testing.

**Fix pattern** (applied across the desktop cubit fleet, 2026-05-06):

```dart
class XCubit extends Cubit<XState> {
  // ... existing constructor + fields + methods that emit ...

  @override
  void emit(XState state) {
    // Guard against late callbacks (timer ticks, in-flight HTTP)
    // completing after close() — common during hot-restart and screen
    // teardown.
    if (isClosed) return;
    super.emit(state);
  }
}
```

Override at the cubit level, not the call site. Every existing `emit(...)` becomes safe automatically; no need to sprinkle `if (!isClosed)` at every call site (which would also be churn-prone — easy to miss one in a long file).

**Why not `try/catch StateError` instead?** Catching the error after the fact still prints the stack trace via the global Zone error handler unless you swallow it. Overriding `emit` is cleaner — the late callback becomes a silent no-op, which is exactly what "the cubit is dead, stop talking to it" should look like.

**When NOT to apply the override:** if a cubit's emit-after-close case actually represents a logic bug (e.g., you're calling `emit` from the cubit itself after explicitly calling `close()`), the guard hides it. Use the override on cubits whose async methods can outlive disposal (poll timers, stream subscriptions, HTTP fetches) — which in practice is most of them. For a stateless utility cubit with synchronous emits only, the guard adds no value.

**Cubits in this codebase that have the override** (as of 2026-05-08): every cubit under `apps/desktop/lib/features/*/presentation/cubit/`; on mobile, `MobileGroupsCubit` (since 2026-05-07) and `DetailCubit` (since 2026-05-08, after a field log surfaced `BlocBase.emit` from `DetailCubit.load` mid-navigate-back).  Remaining mobile cubits without the guard — apply when next touched: `ProfileCubit`, `ProfileStatsCubit`, `RecentCubit`, `ContinueWatchingCubit`, `NotificationsCubit`, `SearchCubit`, `LibraryBloc`, `PlayerCubit` (and `library/presentation/bloc/library_bloc.dart` which is a Bloc, not a Cubit — same fix applies via the `emit` override on its event handlers' `Emitter`).

---

## `sc.exe stop` is asynchronous — file deletion races the service shutdown

**Symptom (2026-05-06, installer audit):** Inno Setup uninstall script ran `sc.exe stop FluxoraServer` then proceeded to delete files. The uninstaller popped "Cannot remove file: it is in use by another process" with no Cancel option, mid-uninstall, leaving the install half-deleted.

**Root cause:** `sc.exe stop <service>` returns when the Service Control Manager **accepts the stop request**, not when the service has actually stopped. Between "accepts" and "stopped" the service is shutting down and still holding file handles. Inno Setup's `[UninstallRun]` runs entries sequentially with no native "wait for service to actually stop" option.

**Fix pattern.** Poll `sc.exe query <service>` until either the service is gone (`exit code != 0` = service no longer registered) or `STATE: STOPPED` appears in the output. Cap at 30 seconds; if it exceeds that, proceed anyway (Windows will queue the file deletion for next reboot).

```pascal
// Pascal Script idiom in installer/Fluxora.iss.
procedure RemoveServiceFromPascal;
var
  ResultCode, Tries: Integer;
begin
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Tries := 0;
  while Tries < 60 do  // 60 * 500 ms = 30 s
  begin
    Exec(ExpandConstant('{sys}\sc.exe'), 'query {#ServiceName}', '',
         SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if ResultCode <> 0 then Break;  // service no longer registered
    Sleep(500);
    Inc(Tries);
  end;
  Exec(ExpandConstant('{sys}\sc.exe'), 'delete {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;
```

The same async-stop hazard applies to `taskkill` against a long-running process — use `taskkill /F` (force) for installer scenarios, and `taskkill /F /T` (force + tree) when the target may have child processes (e.g. a Python server with FFmpeg subprocess children).

---

## `reg.exe add /t REG_MULTI_SZ /d "a\0b"` is brittle — use the native API

**Symptom (2026-05-06, installer audit):** Inno Setup script set a service's environment block via `reg.exe add ... /t REG_MULTI_SZ /d "FLUXORA_DATA_DIR=C:\ProgramData\Fluxora\0FLUXORA_FFMPEG_BIN=..."`. On some shell configurations the `\0` was passed through verbatim instead of being interpreted as a null separator, leaving a single-line REG_SZ value that the Service Control Manager either rejected or read as one giant env var name.

**Root cause:** `reg.exe`'s documentation says `\0` is the REG_MULTI_SZ separator, but the parsing happens after shell argument expansion. Different Windows command interpreters handle `\0` differently — `cmd.exe` mostly passes it through, PowerShell may not, and Inno Setup's `[Run]` `Parameters:` string is yet another layer of escaping.

**Fix.** From Inno Setup `[Code]` Pascal, use `RegWriteMultiStringValue` directly:

```pascal
SetArrayLength(EnvLines, 4);
EnvLines[0] := 'FLUXORA_DATA_DIR=C:\ProgramData\Fluxora';
EnvLines[1] := 'FLUXORA_FFMPEG_BIN=' + AppDir + '\ffmpeg\ffmpeg.exe';
EnvLines[2] := 'FLUXORA_FFPROBE_BIN=' + AppDir + '\ffmpeg\ffprobe.exe';
EnvLines[3] := 'FLUXORA_PORT=8000';
RegWriteMultiStringValue(HKEY_LOCAL_MACHINE,
  'SYSTEM\CurrentControlSet\Services\FluxoraServer',
  'Environment', EnvLines);
```

Inno Setup's native API takes a `TArrayOfString` and writes it as a properly-encoded REG_MULTI_SZ. No string escaping. From other contexts, prefer the corresponding Win32 API (`RegSetValueExW` with `REG_MULTI_SZ` and explicit double-null terminator) over `reg.exe` for any multi-string write.

---

## Inno Setup has no native repair UI — re-running the installer must be idempotent

**Symptom (2026-05-06, installer audit):** user re-ran the Fluxora installer to "repair" their install. The installer's `[Run]` step `sc.exe create FluxoraServer ...` returned exit code 1073 (`ERROR_SERVICE_EXISTS`); Inno Setup ignored the failure (no `Check:` clause); the install reported "successful" with the existing (possibly broken) service registration left in place.

**Root cause.** Unlike MSI, Inno Setup has no native Modify / Repair UI. The supported "repair" flow is **re-running the original installer** — Inno detects the existing install via the `AppId` GUID and offers an in-place upgrade. All `[Files]` entries copy over (with `ignoreversion` flag) but `[Run]` entries fire fresh, including any non-idempotent ones like `sc.exe create`.

**Fix pattern.** Wrap any non-idempotent post-install operation in a Pascal `[Code]` helper that detects existing state first:

- `sc.exe create` → first do `sc.exe stop` + wait + `sc.exe delete`, THEN `sc.exe create`.
- Firewall rule add → `netsh delete` first (silent failure ok), then `add`.
- Defender exclusion → `Add-MpPreference` is idempotent (adding an existing exclusion is a no-op); safe to call directly.
- Registry HKLM writes → use Inno Setup's `[Registry]` section with `Flags: uninsdeletevalue`; native idempotency.

The smoke-test matrix should specifically include "re-run installer over existing install" as a case (see [`installer/AUDIT.md`](../../installer/AUDIT.md) finding #1 for the full pattern).

---

## ProgramData files created by service accounts inherit restrictive ACLs

**Symptom (2026-05-06, installer audit):** Fluxora server runs as `LocalService`; writes `C:\ProgramData\Fluxora\fluxora.db` and `fluxora.log`. The desktop app (running as the user) tries to read those files and gets `ACCESS_DENIED`. Same problem affects the support-bundle generator: the server-side endpoint can't read its own log files because of how the file ACL was inherited.

**Root cause.** `C:\ProgramData` defaults to "Authenticated Users: read+execute (inherited)" + "Creator Owner: full control (inherited)." When `LocalService` (SID `S-1-5-19`) creates a file under `ProgramData\Fluxora\`, the file's ACL inherits from `ProgramData\Fluxora\`'s ACL — but if `ProgramData\Fluxora\` was created by `LocalService`, ITS ACL inherits from `ProgramData\` BUT the inheritance chain for files-created-by-service-accounts often loses the "Authenticated Users" entry depending on how the service-account creates the dir (some Win API paths strip inherited ACEs).

**Fix.** During install, after creating `C:\ProgramData\Fluxora\`, explicitly grant both LocalService (full-control inheritable) and Authenticated Users (read+execute inheritable) via `icacls`:

```cmd
icacls "C:\ProgramData\Fluxora" ^
  /grant "*S-1-5-19:(OI)(CI)F" ^
  /grant "*S-1-5-32-545:(OI)(CI)RX" ^
  /T /Q
```

The SIDs are language-independent: `S-1-5-19` is `LocalService`, `S-1-5-32-545` is `BUILTIN\Users`. `(OI)(CI)` makes the ACEs inherit to descendants. `/T` recurses to existing children. `/Q` suppresses success messages.

The same pattern applies to any Windows service that needs to share data with a user-mode process: don't rely on default inheritance; set ACLs explicitly during install.

---

## `-f null -` makes FFmpeg report `bitrate=N/A` — use `-f mpegts -` for benchmarks

**Symptom.** Every progress line in stderr lands with `bitrate=N/A`, so any benchmark that parses bitrate from FFmpeg's progress output (`services/benchmark_service.py` until 2026-05-07) shows blank for that column even on successful encodes.

**Root cause.** `-f null -` tells FFmpeg "discard output before muxing" — bytes never reach a muxer, so there's nothing to measure rate against. The encoded video data is still produced + counted for fps/speed, but the bitrate counter is muxer-side.

**Fix.** Switch the output to `-f mpegts -` and pipe stdout to DEVNULL. The mpegts muxer measures bytes through it and reports a real bitrate; the bytes never touch disk. mpegts is the lightest mux that keeps the counter live (`-f matroska -` also works but adds container header overhead that pollutes the measurement).

```python
cmd.extend(["-an", "-f", "mpegts", "-"])
proc = await asyncio.create_subprocess_exec(
    *cmd,
    stdout=asyncio.subprocess.DEVNULL,  # bytes go nowhere
    stderr=asyncio.subprocess.PIPE,     # but progress lines do
)
```

If you ever see `bitrate=N/A` on every row of FFmpeg progress, check the output flag first.

---

## "First non-empty FFmpeg stderr line" is the input header, not the error

**Symptom.** Failed encoder benchmark surfaces the message `Input #0, lavfi, from 'testsrc=duration=8:size=1280x720:rate=30':` as the error reason — informational, not the actual failure.

**Root cause.** FFmpeg writes its input-file metadata before any error.  Picking "the first non-empty stderr line" (a tempting shortcut for one-line summaries) grabs that header; the real error is somewhere lower in the buffer with markers like `Error querying encoder params: unsupported (-3)`.

**Fix.** Walk stderr looking for substrings that mark a line as a real error: `error`, `failed`, `could not`, `unable to`, `invalid`, `unsupported`, `no such`, `not found` (case-insensitive). Fall back to the *last* non-empty line (typically `Conversion failed!`) before resorting to the first.

The pattern is implemented in `services/benchmark_service._pick_error_line` — reuse it in any service that needs a one-line error summary from FFmpeg stderr.

---

## `AnimatedContainer(width:)` is silently overridden by tight parent constraints

**Symptom.** A custom progress bar / sized box / animated stripe is built with `AnimatedContainer(width: someFraction * parentWidth, ...)` but renders as if the width is always 100% of parent. Setting different fraction values has no visual effect.

**Root cause.** When the AnimatedContainer is inside a tight-constrained parent (`SizedBox(width: double.infinity, height: 4) → ColoredBox → ...`), the layout engine forces the child to fill the parent. `Container`/`AnimatedContainer`'s `width` is a *request*, not a *constraint*; under tight constraints from above it gets clamped to the parent's exact width.

**Fix.** Use `Stack(fit: StackFit.expand)` + `Positioned(left: 0, top: 0, bottom: 0, width: ...)` (or `AnimatedPositioned` for animated transitions). `Positioned` sets the child's geometry directly via Stack's parent-data layout pass — independent of the Stack's tight constraints from above.

```dart
Stack(
  fit: StackFit.expand,
  children: [
    const ColoredBox(color: trackColor),                  // track
    AnimatedPositioned(
      duration: const Duration(milliseconds: 240),
      left: 0, top: 0, bottom: 0,
      width: fraction * parentWidth,                      // honoured!
      child: const DecoratedBox(decoration: BoxDecoration(gradient: ...)),
    ),
  ],
)
```

Same trap applies to `AnimatedContainer(height:)` inside a tight horizontal box. `Align` works as an escape hatch too (gives the child loose constraints) but Stack+Positioned is the cleanest pattern for "fill from one edge to a fraction of the parent."

---

## `MouseRegion.onExit` can fire after widget dispose during route transitions

**Symptom.** Tapping a button that triggers a route pop crashes with `setState() called after dispose()`. The button itself disposed cleanly; the crash comes from a hover-state setter.

**Root cause.** `MouseRegion.onExit` fires when the cursor leaves the region — including the synthetic exit that happens because the widget itself moved out from under the cursor (e.g. the page popped). That exit fires asynchronously, after the State has been disposed, and any `setState` in the handler throws.

**Fix.** Always guard hover-state setters with a `mounted` check:

```dart
void _setHover(bool value) {
  if (!mounted) return;
  setState(() => _hover = value);
}
// ...
MouseRegion(
  onEnter: (_) => _setHover(true),
  onExit: (_) => _setHover(false),
  ...
)
```

Same pattern applies to any async callback that calls `setState` after the widget might have been disposed (network responses, animation listeners, etc.). The 16-cubit emit-after-close audit from May 6 is the same class of bug at the BLoC layer.

---

## `go_router`'s `context.pop()` crashes on an empty navigation stack

**Symptom.** A Cancel / Back button on a sub-page works fine when the operator navigates from the parent screen, but crashes when they hot-restart on the sub-page directly or land via a deep link.

**Root cause.** `context.pop()` requires a previous route to pop *to*. Hot-restart + deep-link entries can land directly on a sub-route with no parent on the stack; `pop()` throws "There is nothing to pop." Same bug existed in the old Cancel button on Encoder Settings — never triggered because operators only ever reached the page via the Transcoding screen's button.

**Fix.** Guard with `canPop`, fall back to `context.go(parentRoute)`:

```dart
onBack: () {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.transcoding); // explicit parent
  }
}
```

Apply this pattern anywhere the user can hit a Back affordance — Encoder Settings, future detail pages, anywhere reachable both from a parent route and via a deep link.

---

## Mocking async helpers: `patch.object(..., return_value=X)` returns a sync MagicMock

**Symptom.** Test mocks an async helper like `_probe_nvidia` with `patch.object(transcoding_service, "_probe_nvidia", return_value=(34.0, 580))`. The call site `await`s the helper. Test assertion against the captured value fails — the mock returned without ever being awaited; the call site sees `None` (or a coroutine warning).

**Root cause.** `patch.object` defaults to `MagicMock` (sync). Awaiting a sync MagicMock at runtime doesn't error in Python 3.11+ but doesn't return the configured value either — the side-effect is silently broken.

**Fix.** Pass `new=AsyncMock(return_value=...)` instead of `return_value=...`:

```python
with patch.object(
    transcoding_service,
    "_probe_nvidia",
    new=AsyncMock(return_value=(34.0, 580)),
):
    ...
```

The same trap applies to `patch(...)` (without `.object`) and to any test-side mocking of an async function. Default to AsyncMock for any helper that's `await`-ed at the call site.

---

## `FluxTabBar`'s `mainAxisSize.min` collapsed the bottom-border divider

**Symptom.** A page using `FluxTabBar` shows a short divider line under the tabs that ends right where the rightmost tab's text ends — the rest of the content area's width has no divider.  Looks broken next to `Settings`'s custom tab row whose divider extends across the full content area.

**Root cause.** `FluxTabBar`'s inner `Row(mainAxisSize: MainAxisSize.min)` sized the row to the tabs' combined width.  The Container's bottom border (the divider) only paints across the Container's width, which equalled the inner row's width.

**Fix (shipped 2026-05-07).** Drop `mainAxisSize.min` so the Row defaults to `MainAxisSize.max`.  Tabs themselves stay left-aligned via the default `mainAxisAlignment` (start).  Container then fills the parent's width and the border extends across.

The `bottom: 16` padding on the same Container is also worth removing so the active tab's 2 px violet underline overlaps the 1 px divider — the prototype's `marginBottom: -1` design intent.  Both fixed in `flux_tab_bar.dart` together.

---

## Polling cubits need a silent-refresh path or the UI flickers every tick

**Symptom.** A `BlocBuilder` consumer of a polling cubit visibly flickers — list collapses to a spinner, then reappears — every poll interval.  Classic instance: a `Timer.periodic` calling `cubit.load()` every 5 s.

**Root cause.** The standard `load()` method on a Bloc / Cubit emits a `Loading` state first, then `Loaded` once the API call returns.  That's correct for a one-shot fetch (operator opens the screen, sees a spinner, then content) but unusable for a poll loop.  Every tick replaces the visible content with a spinner.

A second, subtler trap: even if the user-facing widget is unaffected, **derived UI state riding on the `Loaded` instance gets blown away** — e.g. `processingIds` in `ClientsCubit` (which dims the row buttons during a revoke) is set to `{}` on every Loading→Loaded cycle.  A poll tick during a revoke would thus re-enable the row's button mid-call.

**Fix.** Add a separate `refreshSilent()` (or whatever name fits the cubit) method that:
1. **No-ops unless the state is already `Loaded`.** Refresh has nothing to render against `Initial` / `Loading` / `Failure`; let the user's manual `load()` handle those.
2. **Calls the repo, then `emit(current.copyWith(items: fresh))`.** Crucially, `copyWith` preserves `filter`, `processingIds`, and any other derived UI state.
3. **Re-checks `state` after the await.** If the state changed under the silent refresh (e.g. operator triggered a hard `load()` mid-poll), bail out instead of stomping the new state.
4. **Swallows errors silently** with a warn-level log.  A transient blip on a poll tick should NOT replace the last-known good state with a `Failure`.  The whole point is best-effort — surface errors only on the explicit `load()` path.

```dart
Future<void> refreshSilent() async {
  final current = state;
  if (current is! ClientsLoaded) return;
  try {
    final clients = await _repository.getClients();
    final next = state;
    if (next is! ClientsLoaded) return;  // state changed under us
    emit(next.copyWith(clients: clients));
  } catch (e, st) {
    _log.w('Silent refresh failed', error: e, stackTrace: st);
  }
}
```

`ActivityCubit` does the same thing implicitly via "only emit Loading on first load"; `ClientsCubit` (post-2026-05-07) does it explicitly via `refreshSilent`.  Either pattern is fine — pick the one that reads better for your call sites.

**Pin it in tests.** A regression test that asserts `expect: () => []` on a poll-tick during a transient API failure is the only way to catch a future refactor that re-introduces the flicker.

---

## SQLite `json_group_array` returns NULL for clients with no matches, not `[]`

**Symptom.**  A `LEFT JOIN` aggregating a 1:N relationship via SQLite's `json_group_array` produces `NULL` (not `'[]'`) for parent rows that have no matching child rows.  Naively passing the column straight to a JSON parser explodes; passing it through to Pydantic without a coercion blows up with a type error.

**Concrete instance (M3 of `docs/10_planning/12_groups_remediation_plan.md`, 2026-05-07).**  `auth_service.list_clients` aggregates each client's group memberships via:

```sql
LEFT JOIN (
    SELECT gm.client_id,
           json_group_array(json_object(
               'id', g.id,
               'name', g.name,
               'status', g.status
           )) AS groups_json
      FROM group_members gm
      JOIN groups g ON g.id = gm.group_id
     GROUP BY gm.client_id
) grp ON grp.client_id = c.id
```

A client in zero groups has no row in the inner subquery, so `grp.groups_json` is `NULL`.  The router has to treat NULL as `[]` before handing to Pydantic.

**Fix.**  Defensive parsing at the router boundary:

```python
groups: list[GroupSummary] = []
if row["groups_json"]:                         # truthy check first
    try:
        parsed = json.loads(row["groups_json"])
        if isinstance(parsed, list):
            for item in parsed:
                if isinstance(item, dict):
                    groups.append(GroupSummary(**item))
    except (json.JSONDecodeError, ValueError):
        logger.warning("malformed groups_json for client %s", row["id"])
```

**Why not `COALESCE(groups_json, '[]')` in the SQL?** You can — `COALESCE(json_group_array(...), '[]')` works.  But the Python-side parse still has to be defensive against malformed JSON (schema drift, manual `UPDATE` from sqlite3 CLI, etc.) so the helper exists either way.  Using both belt-and-braces costs nothing.

**Document this on the service function.**  The docstring for any `list_*` query that uses `json_group_array` should flag the NULL behaviour so the next person reading the SQL knows to expect it.

---

## Mobile substring-matches the server's error `detail` string — keep both sides anchored

**Symptom.**  Server returns a 4xx with a human-readable `detail` field; mobile parses it via `String.contains` to classify the failure mode (e.g. group-gate denial vs generic forbidden).  An innocent server-side reword breaks the classification silently — the mobile UI surfaces the raw string anyway, but the *category* (gate vs error) is wrong, so users see a generic "stream failed" error when the server actually denied them on a parental control restriction.

**Concrete instance (M5 of `docs/10_planning/12_groups_remediation_plan.md`, 2026-05-07).**  `services/group_service.reason_to_deny` emits two strings:
- `"Library not allowed for this client's group(s)"`
- `"Outside the allowed streaming time window"`

Mobile `PlayerCubit._isGroupGateMessage` matches them by substring:

```dart
return lower.contains('group(s)') || lower.contains('time window');
```

Distinctive markers (`'group(s)'` parens; `'time window'` two-word phrase) chosen so the matcher won't false-positive on unrelated 403s like `"Forbidden: localhost only"`.

**Fix.**  Three rules for cross-service substring contracts:

1. **Pin the contract in tests on the consumer side.**  A test case for each known message + a test case for an unrelated 4xx response that must NOT classify as the special category.  The "must NOT" case is the important one — it stops a future agent from broadening the matcher to catch every 4xx.
2. **Use distinctive markers, not common words.**  `'group(s)'` is unlikely to appear in unrelated server messages; `'group'` alone might.  `'time window'` is a two-word phrase that's also very specific; `'time'` alone is too generic.
3. **Document the contract on both sides.**  The producer's docstring lists the strings it emits + a note that mobile parses them.  The consumer's parser comment links back to the producer.  When someone reaches for a reword, they see the contract first.

**Anti-pattern.**  A single `lower.contains('not allowed')` matcher would catch `"Library not allowed for this client's group(s)"` but also any future 403 like `"Operation not allowed"` — broadening the matcher silently.

**Better alternative when feasible.**  Add a structured `error_code: "group_gate_library"` field to the response body and match on that.  We didn't do that here because the server's existing 403 path emits a plain string and the desktop already consumes it directly; adding a structured field would be a wider refactor.  Substring match + pinned tests is acceptable for the size of this surface.


## `Process.start("explorer", [path])` returns non-zero on Windows even when the launch succeeded

**Symptom:** an "Open folder" / "Reveal in Finder" affordance using `Process.start("explorer", [path])` (or `start "" "<path>"` via `cmd`) reports failure to the user via SnackBar/snackbar even though Explorer did open and showed the folder. Operator clicks "Open folder", the folder window appears, AND a "Could not open path" toast appears. Confusing.

**Root cause:** Windows `explorer.exe`'s exit code is **non-deterministic** for shell-spawn cases. Even on a successful launch it may return a non-zero code because the spawned process forks the navigation off to a pre-existing Explorer instance and the original `explorer.exe` invocation exits with a status the shell interprets as failure. `Process.start` returns the exit code of *that initial process*, so the success path looks like a failure to Dart's error handling.

**Fix:** prefer `url_launcher` with a `file://` URI — the OS resolves the scheme to its native opener (Explorer / Finder / xdg-open) and `launchUrl` returns a clean `bool` based on whether the URL handler accepted the request, not the spawned process's exit code:

```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> openPathInFileManager(String path) async {
  final ok = await launchUrl(Uri.file(path));
  if (!ok) {
    // Genuine failure (no handler registered, etc.) — surface to user.
    // ...
  }
}
```

This works on Windows / macOS / Linux uniformly. Only catch: on Linux desktop without `xdg-utils` installed (`xdg-open` missing), `launchUrl` returns `false`. Pre-existing requirement; just worth noting that the failure path is now genuine ("no handler") rather than spurious ("explorer's exit code lied").

Pattern in `apps/desktop/lib/features/transcode/presentation/widgets/storage_strip.dart::openPathInFileManager`. Migrated from `Process.start` 2026-05-10 after the original implementation surfaced false-failure SnackBars on Windows.


## Plan 21 — Audio stream-copy bandwidth is uncapped

**Context:** Plan 21 (2026-05-12) enables audio stream-copy for `{aac, ac3, eac3, opus, flac}` sources. A FLAC audio track on a Blu-ray rip can be 1000–5000 kbps. Combined with the video stream at full source bitrate, the total stream can easily exceed marginal WAN throughput (e.g. LTE, weak Wi-Fi) where the prior `aac@128k` re-encode kept audio bandwidth trivially low.

**There is no code-side bitrate cap** — the "near-zero server CPU" win comes with "no server-side audio bitrate floor" as the trade. On LAN this is fine (LAN has ample headroom). On WAN with marginal bandwidth, the operator or client may see buffer stalls that the prior AAC re-encode path never triggered.

**Mitigation (none implemented in plan 21):** this is consistent with plan 19's existing video stream-copy bandwidth profile (which already passes the full source video bitrate). If an operator reports audio-stall regressions after plan 21, the lever is to reduce the `_AUDIO_STREAM_COPY_ALLOWLIST` to exclude FLAC, or to add a bitrate-gated fallback path. Neither is in scope for v1.

**Flagged in:** plan 21 §Sharp edges #7.


## Plan 21 — Mid-stream audio codec changes can produce broken segments under stream-copy

**Context:** some files (concatenated rips, DVD VOBs, some capture tools) change audio codec partway through the file — e.g. the first chapter uses AC3 and the second uses DTS. FFmpeg handles this cleanly for transcode (it re-encodes to AAC throughout). For audio stream-copy, a codec change at the segment boundary may produce a broken `.m4s` segment because the fmp4 track's codec box describes the *first* codec.

**Detection is impractical** without scanning the entire file beforehand (too slow at stream-start for large files). The failure mode is: audio drops out at the codec-change boundary; in `auto` mode the player's audio-error heuristic fires within 6 s and triggers `POST /fallback-audio-transcode`, recovering automatically. In `client-decode` (strict) mode the error surfaces to the user as a player error.

**Accept and document** — do not add per-segment codec detection in v1. If a user reports audio drop at mid-file, the diagnostic is to check `stream_decision` log for `audio_path=stream-copy` and whether the source is a concatenated rip.

**Flagged in:** plan 21 §Sharp edges #9.


## Plan 21 — Audio-error detection heuristic is fragile on slow WAN

**Context:** The mobile player's audio-fallback watcher (`_scheduleAutoAudioFallbackWatcher`) uses two signals:
1. `player.stream.error` events whose payload mentions `'audio'`, `'aac'`, or `'codec'` keywords.
2. `audioParams` stream not emitting a non-empty value within 4 s (proxy for "audio track failed to initialize").

**The `audioParams` silence watchdog is fragile on slow WAN.** On a marginal internet connection, the player may genuinely need more than 4 s to buffer the first audio segment and initialize the decoder. The silence is a network stall, not a decode failure. When this fires, the cubit calls `POST /fallback-audio-transcode`, which restarts the stream with audio transcoded — correct behavior but with ~1 s of unnecessary latency for users who would have recovered normally.

**Acceptable failure mode:** one extra server restart per session on slow WAN. The audio-forced-fallback path is stable once triggered. The alternative (a longer timeout) increases the window where a genuine decode failure goes undetected on fast networks.

**Needs real-device field testing:** the M4 agents implemented this heuristic against headless tests only. Real-device testing on iOS + Android with FLAC/AC3 sources over varying WAN conditions is required to tune the 4 s threshold.

**Flagged in:** plan 21 §Sharp edges #1.


## Plan 21 — `_ensure_fmp4_init_segment` audio codec mismatch for non-AAC stream-copy

**Context:** `_ensure_fmp4_init_segment` is a helper that generates a fallback `init.mp4` when FFmpeg fails to emit one (see the "fmp4 HLS init segment is unreliable across FFmpeg builds" gotcha above). Its internal one-shot FFmpeg command uses `-c:a aac -b:a 128k` to produce the audio config box in the init segment.

**When audio stream-copy is active with a non-AAC codec** (e.g. AC3, Opus, FLAC), the init segment generated by `_ensure_fmp4_init_segment` will have an `AAC` audio config box, but the actual `.m4s` segments will carry the non-AAC codec. The mismatch can confuse players into misreading the audio track.

**This is a latent defect, not a confirmed blocker:** FFmpeg normally emits `init.mp4` correctly for non-AAC fmp4 sessions, so `_ensure_fmp4_init_segment` only fires as a fallback. But it should be audited during real-device testing with FLAC/AC3 sources. Fix: pass the source audio codec and channels through to `_ensure_fmp4_init_segment` and use `-c:a copy` when stream-copy is active.

**Flagged in:** plan 21 M2 agent sharp edge.


## Plan 21 — Duplicate `_probe_audio_params` call per `/stream/start` (~50-100 ms overhead)

**Context:** `routers/stream.py::start_stream` calls `_probe_audio_params(file_path)` to determine the source audio codec before calling `ffmpeg_service.start_stream`, so it can populate `StreamStartResponse.audio_streaming_mode`. However, `ffmpeg_service.start_stream` runs its own probe internally. This means **every `/stream/start` call runs two FFprobe probes** against the same file.

**Cost:** ~50-100 ms per session start (each FFprobe is a subprocess launch + file metadata read). Negligible for v1 usage (one active stream), but would accumulate under concurrent sessions.

**Future fix:** thread the probe result from the router into `start_stream` as an optional parameter, or persist `audio_codec` + `audio_channels` onto the `media_files` row at scan time (similar to `codec_name` for video). Neither is in scope for plan 21.

**Flagged in:** plan 21 M3 agent sharp edge.


## Desktop has no player feature — "mirror player to desktop" is net-new architecture

**Context:** The desktop app (`apps/desktop/`) is a pure server control panel — it has no `lib/features/player/` directory and no media playback infrastructure whatsoever. Plans 20 and 21 both originally included "mirror mobile player cubit change to desktop" as a milestone item. Both times the subagent confirmed that `apps/desktop/lib/features/player/` does not exist.

**Implication:** any future feature described as "add audio/video fallback watcher to desktop player" or similar is **net-new architecture**, not an incremental update. The work involved is: defining the desktop player UX, building the player screen, integrating media_kit or an alternative, and then adding the feature on top. This is at minimum a 1-2 day milestone of its own, well beyond the few-line cubit change the phrase "mirror to desktop" implies.

**When planning desktop playback:** do not reference plans 20/21 as prior art for the cubit pattern unless the desktop has already shipped a player screen. The mobile cubit and repository implementations remain the reference.


## `GetIt.I.reset()` is async — always `await` in test setUp

**Context:** `GetIt.I.reset()` returns a `Future<void>` because resetting clears scopes that may have running async dispose callbacks. If a `setUp` callback is synchronous (`setUp(() { ... })`) the `reset()` call returns the Future but nothing awaits it, so the `registerSingleton` calls below race against the in-progress reset and produce `Object/factory with type X is not registered` errors that are easy to misdiagnose as missing registration (the reset just hasn't finished). Desktop's existing single-test case never surfaced the race; a second test would have failed.

**Fix:** make the `setUp` callback async and `await GetIt.I.reset()` before calling `registerSingleton`. For `tearDown`, the arrow form `tearDown(() async => GetIt.I.reset())` is fine (the framework awaits any returned Future).

**Where it lives:** mobile golden suite at `apps/mobile/test/goldens/` + the desktop golden at `apps/desktop/test/goldens/m3_dashboard_golden_test.dart` were both updated 2026-05-14 to follow this pattern.


## `_DragHud` (and similar fade-overlay widgets) are always in the widget tree

**Context:** Wave 1a of M14 made the player drag HUD persistent — it stays in the tree at all times and is shown/hidden with `AnimatedOpacity` + `IgnorePointer` to avoid layout shifts on appear/disappear. Any test asserting `find.byType(_DragHud).evaluate().isEmpty` when the HUD is "hidden" will fail: the widget is present, just invisible. The same pattern applies to `_PeekBadge` (AnimatedSwitcher) — when "absent" it still occupies its slot.

**Fix:** assert on opacity or `IgnorePointer.ignoring`, not on widget presence. To confirm a fade-overlay is non-interactive, verify `IgnorePointer.ignoring == true`.

**This is by design**, not a bug — layout stability is the reason. Future fade-style overlays in the player chrome should follow the same pattern.


## Private widget exposure pattern — `_FooBar` → `PlayerFooBar` rename convention

**Context:** Flutter's golden_toolkit requires the widget under test to be directly constructible in a test file. Private widgets (`_FooBar`) cannot be imported or instantiated outside their defining library. The project convention is to rename a private player-chrome widget to `PlayerFooBar` (public, but prefixed with the feature name) and annotate it `@visibleForTesting` to signal it is not part of the public widget API.

**Fix pattern:**
```dart
// Before (not testable from golden_test.dart):
class _TransportBar extends StatelessWidget { ... }

// After (golden-testable):
@visibleForTesting
class PlayerTransportBar extends StatelessWidget { ... }
```

This rename must be reflected in the widget tree, all internal usages, and the golden test import. Do not use `part of` directives as an alternative — they produce tight coupling between test and production files.

**Flagged in:** M14 §17.3 #7 sharp edge.

**Flagged in:** plan 21 M4 agent architectural finding.
