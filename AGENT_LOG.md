# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_10.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 09)
**Archived:** 2026-05-08
**Contents:** Tier 2 benchmark axis (resolution-tier matrix) · Groups remediation plan + M1 (restriction editing) · Groups M2-M5 + bulk member ops + activity feed · Groups v2 content-spaces redesign + M8 hybrid PIN (server + desktop) · Groups dedicated management page (M1-M5) · Groups M7 desktop polish + producer-side audit aggregation + bulk grants reset · Groups v2 mobile (M4 + M6 + M8) · Full doc audit pass · Mobile redesign audit + trending rip-out + streaming §4 leftovers + Groups M6 UX revision + DetailCubit emit-after-close · Streaming §4.5 finalise-on-exit + M10 closed (Offline + X-Ray + Group Watch) + Audit §17.3 #2 + #3.

* **Tier 2 benchmark axis (2026-05-07).** Resolution-tier matrix mode for the encoder benchmark — `BenchmarkRequest.resolutions: list[ResolutionTuple]` additive to legacy `width`/`height`; outer-loop-per-resolution × inner-loop-per-encoder; `_progress` schema extended with `total_resolutions` + `current_resolution_*` fields; history sidebar caption switches to "3 res · 30 fps · 18 enc". `EncoderBenchmarkResult` gains `width: int` + `height: int` so each row self-describes; `BenchmarkHistoryEntry.resolution_count` derived in-place from `results_json` parse (no migration). Desktop entity `Resolution` freezed; multi-select chip row replaces single-select. Server suite +N tests.
* **Groups remediation plan + M1 ship (2026-05-07).** `12_groups_remediation_plan.md` written from a 5-finding audit (decorative create/edit dialogs / raw-UUID add member / mobile 403 UX / etc.). M1 (restriction editing) shipped: desktop dialog gains rest-fields editing for time-window + max-concurrent-streams + library-blocklist; `PATCH /api/v1/groups/{id}` accepts the new fields; activity event recorded.
* **Groups M2-M5 (2026-05-07).** End-to-end Groups feature usable: M2 (delete safety + cascade tests), M3 (member-management with display names + bulk add/remove + status badges); M4 (Activity tab on group detail panel), M5 (mobile 403 → human-readable error). Plan 12 fully closed.
* **Groups v2 content-spaces redesign (2026-05-07).** Plan 13. Major semantic flip: M1 schema migrations 025 + 026 (additive UNION model — `allowed_libraries` flips from subtractive to additive without changing the wire format; pin_model='shared' vs 'per-client'); M2 service refactor (`get_visible_libraries` + `reason_to_deny_stream` replace v1 intersection logic); M3 mandatory Public group with auto-membership; M4 shared-PIN gating + grant flow + 5-fails-in-10-min activity aggregator; M8 hybrid per-client PIN enrollment with `group_member_pins` table + obvious-PIN blocklist + HMAC-SHA256 hashing. Master-override (localhost-only). Server suite **565 → 637 passing** through this work.
* **Groups dedicated management page (2026-05-07).** Plan 14. Replaced the M1 modal with a 6-tab full-page edit (`/groups/new` + `/groups/:id/edit`) — Overview / Members / Access / PIN / Activity / View As. Lifted shared form widgets to `widgets/group_form_widgets.dart`. M5 View-As tab consumes `GET /auth/clients/{id}/visible-libraries` (localhost-only).
* **Groups M7 desktop polish + bulk grants reset (2026-05-07).** Tier-2 operator quality of life: 12-icon picker + 6-color picker + `groups.max_concurrent_streams` field + `POST /grants/reset` (drops every active grant — backs Edit dialog "Reset all PINs" in shared-mode). Activity producer aggregation (`_maybe_emit_failed_burst` for 5-fails-in-10-min). 78 group-specific tests; suite reaches **637 passing**.
* **Groups v2 mobile (2026-05-07).** Plan 13 §M4 + §M6 + §M8 mobile. New `apps/mobile/lib/features/groups/` (repo + cubit + state + widgets) consumes `GET /auth/clients/me/visible-libraries` for a single-fetch payload of locked / unlocked / visible groups + libraries. Profile screen mounts `GroupsSection` with three cards — Locked (PIN-required, opens `PinEntrySheet`), Unlocked (live grants with expiry + Lock action), Visible Libraries (the additive UNION). `PinEnrollmentSheet` covers per-client mode; both sheets reuse `FluxBottomSheet` and the `_kObviousPins` blocklist. 16 cubit tests; mobile suite **48 → 64**.
* **Full doc audit pass (2026-05-07).** 14 docs touched in a comprehensive consistency sweep: current_status / data_models / data_flows / migration_guide / API contracts / API versioning policy / system_overview / tech_stack / component_architecture / frontend_architecture / backend_architecture / ship_readiness / desktop_redesign_plan / mobile_redesign_plan. Migration range refreshed (001-026), test counts re-baselined, v1→v2 stream-gate semantics propagated, "intersection" → "UNION" everywhere live (archives left frozen). Net: **637 server / 64 mobile / 90 desktop / 8 core passing**.
* **Mobile redesign audit + trending rip-out + streaming §4 leftovers + Groups M6 UX revision + DetailCubit emit-after-close (2026-05-08).** Five interleaved threads: (1) mobile_redesign_plan §17 audit added (4 subsections — plan-vs-reality table, trending removal strategy, 9 sharp edges, next-priority order); (2) trending rip-out — `MockData.trending` + `MockData.trendingSearches` deleted, `home_screen.dart` `_MockRail` → `_BrowseStrip` (4-up Movies/Shows/Music/Documents using LucideIcons), `search_screen.dart` "Trending searches" → "Browse" chip group, `Routes.libraryWithFilter(slug)` helper, `LibraryScreen.initialFilter` from `?filter=`; (3) streaming §4.3 + §4.10 — segment-wait 5s → 2s + new `POST /api/v1/files/{id}/reset-progress` "Start over" affordance + 4 server tests; (4) Groups M6 UX revision — Locked + Unlocked cards collapsed into single "My groups (N)" card with state badges, fix for the field-report "no way to see how many groups i am part of and where to enter pin?"; (5) `DetailCubit.emit` post-close guard — fixes navigate-back-mid-fetch crash from logs. Server suite **637 → 641 passing**. 4 commits landed (`3b25365` / `489a9cb` / `f8dcdc3` / `b869c3a`).
* **Streaming §4.5 finalise-on-exit + M10 closed (Offline + X-Ray + Group Watch) + Audit §17.3 #2 + #3 (2026-05-08, uncommitted at rotation).** Six threads stacked on top of the morning's commit batch: (1) §4.5 — `_finalize_vod_playlist` + watcher in `ffmpeg_service.py` replaces spawn-time over-promised playlist with FFmpeg's accurate one on natural exit + 11 tests; (2) M10 Offline screen — `OfflineScreen` widget + `Routes.offline` route, UI shell only (no `connectivity_plus`); (3) M10 X-Ray side panel — `XRayScreen` with static cast + trivia fixtures + `Icons.science_outlined` chip on player top bar; (4) M10 Group Watch modal — `GroupWatchScreen` with mock party-watch chrome + invite-link copy + ListTile in player overflow menu; (5) Audit §17.3 #2 closed as no-op (Phase A + B backfill had already wired Profile real-data — audit was stale); (6) §17.3 #3 self-revoke — new `DELETE /auth/clients/me` route + `AuthRepository.revokeMe()` + `_performSignOut` calls it before local teardown + 4 tests. Server suite **641 → 652 → 656 passing**. M10 milestone fully ✅.

**Test counts at archive time (2026-05-08):**
- Server: **656 passing** (+91 since archive 08 baseline of 565: Groups v2 +72, streaming §4.10 +4, §4.5 +11, audit §17.3 #3 +4)
- Mobile: **64 passing** (+19 since archive 08's 45: Groups v2 mobile +16, streaming Commit 3 already counted in 45)
- Desktop: **90 passing** (+6 since 84)
- Core: **8 passing** (unchanged)

`flutter analyze` clean × all 3 packages.

**Migrations at archive time:** 001 → **026** (`groups_per_client_pins.sql` is latest; 025 = Groups v2 content-spaces flip, 026 = M8 hybrid PIN ledger).

**Mobile redesign progress at archive time:**
- ✅ M0–M9 (foundation through theme cutover, 2026-05-03)
- ✅ Post-M9 polish (Phase A + B backfill, QR-pairing scanner, player polish, seek-restart, Groups v2 mobile, trending rip-out, Groups M6 UX revision, DetailCubit emit-after-close)
- ✅ M10 (Offline + X-Ray + Group Watch — all UI shells, 2026-05-08)
- 🔲 M11 Beyond-video (files browser + PDF + photo + music viewers) — next unstarted milestone
- 🔲 M12 Onboarding revamp (QR scanner partly done; splash + signin + server-picker rebuild owed)
- 🔲 M13 Host-a-server shell (Phase 5+ runtime)
- 🔲 M14 Polish + a11y + golden tests

**Audit progress (mobile_redesign_plan §17.3 sharp edges) at archive time:**
- ⏸ #1 iOS PIP — separate ticket (out of v1 scope)
- ✅ #2 Profile real-data endpoint — already shipped; audit was stale
- ✅ #3 Sign-out revokes server-side — shipped 2026-05-08
- 🔲 #4 Continue-watching empty state — open (small)
- 🔲 #5 `background_gradient.dart` `RepaintBoundary` — open (tiny)
- 🔲 #6 Dep version sweep — open (start of M11)
- 🔲 #7 Player-overlay goldens — open (M14 work)
- 🔲 #8 Notifications panel FIFO cap parity — open (small)
- 🔲 #9 Sleep-timer "Custom" + "End of episode" — open (small)
- ✅ #10 Groups M6 self-hide gap — shipped 2026-05-08
- ⏯ #11 DetailCubit emit-after-close (+ remaining cubit sweep) — partial; DetailCubit + MobileGroupsCubit have the override; ProfileCubit / ProfileStatsCubit / RecentCubit / ContinueWatchingCubit / NotificationsCubit / SearchCubit / LibraryBloc / PlayerCubit still need it (one line each)

**Streaming pipeline plan status at archive time:** **No outstanding tactical work.** All §3 user-reported regressions and §4 leftovers closed (4.3 / 4.5 / 4.8 / 4.10 ✅; 4.7 explicitly deferred as low priority). Future iterations would be field-report-driven (e.g. in-progress playback case still 404s on the over-promised tail because media_kit caches the VOD playlist on first load — would require either custom 410 + `Retry-After` handling or a WS-pushed playlist-refreshed signal).

**Recent commit history at archive time:**
```
b869c3a docs: sync mobile redesign audit + cross-cutting status updates
f8dcdc3 fix(mobile): consolidate "My groups" card + guard DetailCubit against emit-after-close
489a9cb feat(server,mobile): close streaming pipeline §4 leftovers — reset-progress + segment-wait
3b25365 feat(mobile): drop trending rail + chip group, replace with Browse navigation
dd480f9 docs: sync for groups v2 + dedicated page + mobile UX
456d9ea feat(mobile/groups): Profile-screen group surfaces + PIN modals
93e7948 feat(desktop/groups): dedicated /groups/:id/edit page + v2/M7/M8 UI
b237dab feat(core): extend Group entity with v2/M8 fields + endpoints
ba74742 feat(groups): v2 content-spaces redesign + M8 hybrid PIN + M7 polish
89af7fc docs(plans): add v2 groups content-spaces + dedicated page plans
```

**Working-tree status at rotation:** Single big uncommitted batch since `b869c3a` covering §4.5 + M10 Offline + M10 X-Ray + M10 Group Watch + §17.3 #2 doc-close + §17.3 #3 self-revoke + 11 doc files (full list in archive 09's last entry).

**Next Immediate Steps (carried forward from archive 09):**
1. **Commit the uncommitted batch** in logical chunks: (a) §4.5 finalise-on-exit (server + tests + plan / api / backend doc updates); (b) M10 milestone — three new mobile screens + router + player chrome + frontend-arch doc; (c) §17.3 #2 doc close-out + §17.3 #3 self-revoke (server + mobile + tests + 5 docs); (d) cross-cutting doc sync (current_status / roadmap / ship_readiness / data_flows / mobile_redesign_plan / AGENT_LOG rotation).
2. **Smoke-test M10 + self-revoke + §4.5 on the user's box.** Sign-out should now actually invalidate the bearer server-side (verify via curl with the cleared token returning 401). Open the player → top bar X-Ray chip → X-Ray panel renders. Open the player → 3-dot overflow → "Group Watch" → Group Watch screen renders + invite-link copy works. Play any stream-copy HEVC source through to natural completion → tail segments shouldn't 404 on a fresh load of the same playlist URL.
3. **Pick the next audit item or M11**: §17.3 #4 (Continue-watching empty state — small), #5 (`background_gradient.dart` `RepaintBoundary` — tiny), #11 finish (mechanical sweep across remaining cubits — ~10 min), or **M11 Beyond-video** (files browser + PDF / photo / music viewers — bigger, ~1–2 sessions; would commit `pdfx` + `photo_view` + `just_audio` + `audio_service` deps).
4. **§4.5 follow-up consideration:** the in-progress playback case still 404s on the over-promised tail because media_kit caches the VOD playlist on first load. If the user reports it, the next iteration would either (a) add a server-side hint on the segment-serve handler to flag "tail past the actual end" with a custom 410 / `Retry-After` header, or (b) push a "playlist refreshed" notification through the WS channel so media_kit re-fetches. Defer until a real complaint surfaces.
5. **iOS PIP** (audit §17.3 #1) remains the only audit-list priority that's neither shipped nor explicitly deferred. `media_kit`'s MPV doesn't bridge to `AVPictureInPictureController`; two paths — swap backend on iOS only (heavy) or build a custom AVPlayerLayer surface (medium). Separate ticket scope.

---

<!-- New session entries go below this line. -->

---

## Session 2026-05-08 (continuation) — §17.3 audit close-out + M11 Beyond-video

### What was done

**§17.3 audit items closed:**
- **#11 cubit emit-after-close sweep** — Added `@override void emit(...) { if (isClosed) return; super.emit(...); }` to 7 remaining cubits: `ProfileCubit`, `ProfileStatsCubit`, `RecentCubit`, `ContinueWatchingCubit`, `NotificationsCubit`, `SearchCubit`, `PlayerCubit`. `LibraryBloc` skipped (Bloc framework's `Emitter<S>` already handles this). `FilesCubit` also guarded as part of M11 work.
- **#4 Continue-watching empty state** — `_CwRailEmpty` in `home_screen.dart` enhanced from plain-text container to a proper empty state: icon + title + subtitle + "Browse library" CTA routing to `/library?filter=movies`.
- **#5 `background_gradient.dart` RepaintBoundary** — Wrapped the routed `child` in `RepaintBoundary` so child repaints don't propagate to the static gradient layers.

**M11 Beyond-video shipped:**
- **Deps added to `apps/mobile/pubspec.yaml`:** `pdfx ^2.9.2`, `photo_view ^0.15.0`, `just_audio ^0.10.5` (was transitive via audio_service), `share_plus ^12.0.2`, `path_provider ^2.1.5` (was transitive; promoted to direct). `audio_service` was already a direct dep.
- **`MediaKind` enum + `MediaFile.kind` extension** added to `packages/fluxora_core/lib/entities/media_file.dart` — pure extension, no code-gen needed; routes video / photo / pdf / music / other from the file's `extension` field.
- **`GET /api/v1/files/{file_id}/content` server endpoint** added to `apps/server/routers/files.py` — serves raw file bytes with correct MIME type; same group-visibility guard as `GET /{file_id}`; registered before `/{file_id}` to avoid path-parameter shadowing.
- **`files_screen.dart` rebuilt** — categorized grid by `MediaKind`; horizontal scroll strips per category (Videos / Photos / Documents / Music / Other); each chip taps to the appropriate viewer. "Other" files trigger "Open in..." directly via `SharePlus`.
- **`doc_viewer_screen.dart`** (new) — downloads the file to a temp path via `dart:io` `HttpClient` + bearer token, then opens with `PdfControllerPinch` / `PdfViewPinch`. Caches the temp path so "Open in..." (top-bar icon) reuses the download without a second request. Uses `SharePlus.instance.share(ShareParams(...))`.
- **`photo_viewer_screen.dart`** (new) — loads the image URL directly as `NetworkImage` with bearer header into `PhotoView` (no download needed). "Open in..." downloads to temp and shares.
- **`music_player_cubit.dart`** (new) — wraps `just_audio` `AudioPlayer`; streams position / duration / playing / processing-state into `MusicPlayerReady` state; `isClosed` guard on emit; `close()` cancels all subscriptions and disposes player. Audio_service lockscreen integration deferred to v1.1 (separate `MusicHandler` needed to avoid conflict with `FluxoraAudioHandler`).
- **`music_player_screen.dart`** (new) — prototype-spec layout: vertical gradient #1a0820→#08061A, 280×280 album-art gradient placeholder, scrubber with `Slider`, play/pause button (64 px gradient circle), stub prev/next/shuffle/queue controls.
- **Router wired:** `Routes.docViewer` / `Routes.photoViewer` / `Routes.musicPlayer` constants + three new `GoRoute` entries in `app_router.dart`; all accept `MediaFile` via `extra`.
- **"Open in external app" feature** — integrated into all three viewers and the files browser "Other" category; downloads to `getTemporaryDirectory()` then calls `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`.

`flutter analyze` clean (0 issues). Mobile test suite unchanged at **64 passing** (no new unit tests this session — widget tests for the three new screens are M14 work).

### Files created / modified

| File | Change |
|---|---|
| `apps/server/routers/files.py` | Add `GET /{file_id}/content` endpoint + `import os`, `import mimetypes`, `from fastapi.responses import FileResponse` |
| `packages/fluxora_core/lib/entities/media_file.dart` | Add `MediaKind` enum + `MediaFileKind` extension |
| `apps/mobile/pubspec.yaml` | Add `pdfx ^2.9.2`, `photo_view ^0.15.0`, `just_audio ^0.10.5`, `share_plus ^12.0.2`, `path_provider ^2.1.5` |
| `apps/mobile/lib/features/library/presentation/screens/files_screen.dart` | M11 rebuild — categorized grid by MediaKind |
| `apps/mobile/lib/features/library/presentation/cubit/files_cubit.dart` | Add `isClosed` guard |
| `apps/mobile/lib/features/viewer/presentation/screens/doc_viewer_screen.dart` | New — pdfx PDF viewer + "Open in..." |
| `apps/mobile/lib/features/viewer/presentation/screens/photo_viewer_screen.dart` | New — photo_view image viewer + "Open in..." |
| `apps/mobile/lib/features/viewer/presentation/cubit/music_player_cubit.dart` | New — just_audio cubit |
| `apps/mobile/lib/features/viewer/presentation/screens/music_player_screen.dart` | New — music player UI |
| `apps/mobile/lib/core/router/app_router.dart` | Add Routes.docViewer/photoViewer/musicPlayer + 3 GoRoutes |
| `apps/mobile/lib/features/home/presentation/screens/home_screen.dart` | §17.3 #4 — enhanced _CwRailEmpty with icon + CTA |
| `apps/mobile/lib/shared/widgets/background_gradient.dart` | §17.3 #5 — RepaintBoundary on child |
| `apps/mobile/lib/features/profile/presentation/cubit/profile_cubit.dart` | §17.3 #11 — isClosed guard |
| `apps/mobile/lib/features/profile/presentation/cubit/profile_stats_cubit.dart` | §17.3 #11 — isClosed guard |
| `apps/mobile/lib/features/home/presentation/cubit/recent_cubit.dart` | §17.3 #11 — isClosed guard |
| `apps/mobile/lib/features/home/presentation/cubit/continue_watching_cubit.dart` | §17.3 #11 — isClosed guard |
| `apps/mobile/lib/features/notifications/presentation/cubit/notifications_cubit.dart` | §17.3 #11 — isClosed guard |
| `apps/mobile/lib/features/search/presentation/cubit/search_cubit.dart` | §17.3 #11 — isClosed guard |
| `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` | §17.3 #11 — isClosed guard |

### Docs updated

_(No doc files updated this session — current_status, mobile_redesign_plan, and API contracts need updating next session.)_

### Next agent should

1. **Update `docs/11_design/mobile_redesign_plan.md`** — mark M11 ✅ in the milestone table (§7); add the 5 new deps to the §6 dep table rows; mark §17.3 #4 / #5 / #11 as ✅.
2. **Update `docs/00_overview/current_status.md`** — mobile test count stays 64; note M11 shipped; refresh dep list.
3. **Update `docs/04_api/01_api_contracts.md`** — add `GET /api/v1/files/{id}/content` endpoint entry.
4. **Add server tests** for the `/content` endpoint (happy path + 404 not-in-DB + 404-not-on-disk + group-visibility deny).
5. **Continue with M12 Onboarding revamp** or pick remaining small items: §17.3 #6 (dep version sweep — now partially done), #7 (player-overlay goldens — M14), #8 (Notifications FIFO cap parity), #9 (Sleep-timer "Custom" + "End of episode").
6. **Smoke-test M11**: browse to a PDF in the library browser → tap → loading indicator → PDF renders. Tap photo → PhotoView renders with pinch-zoom. Tap music → gradient screen + play button → audio starts. Tap "Open in..." → system share sheet appears.
7. **Note on music `audio_service` lockscreen:** `MusicPlayerCubit` uses a bare `AudioPlayer` with no lockscreen wiring. If the user reports missing lockscreen controls for music, the fix is a dedicated `MusicAudioHandler extends BaseAudioHandler` bound after `start()` — kept separate from `FluxoraAudioHandler` (video). Deferred to v1.1.

---

## [2026-05-08] [m11] [audit] [fix] [tests] [docs] — M11 audit + files_screen resource-leak fix + /content server tests + docs sync + AGENT_LOG format spec

**Phase:** Phase 5 — mobile-redesign cutover; M11 close-out audit + the doc work the prior continuation deferred + a format-canonicalisation pass on AGENT_LOG itself
**Status:** Complete; uncommitted (working tree carries the files_screen fix + 5 new server tests + 4 doc files + memory + this log entry — awaiting commit round)
**Commits:** uncommitted (last shipped: `4d96fb0`; prior continuation: `cfc859a`)

### What Was Done

Four threads, all picked up after a deep cross-check of the prior continuation's M11 + §17.3 audit-cleanup work.

#### 1. Deep audit of the prior continuation's M11 + §17.3 deliverables

Verified every claimed change exists and is wired correctly:

- **9 `isClosed` `emit` guards** — all present (`grep` over `apps/mobile/lib` returns 11 matches: 7 from §17.3 #11 sweep + `FilesCubit` + `MusicPlayerCubit` born with the guard at M11 + `DetailCubit` and `MobileGroupsCubit` from earlier sessions). The four cubits with pre-existing `close()` overrides (`NotificationsCubit`, `SearchCubit`, `PlayerCubit`, `MusicPlayerCubit`) have the new `emit` override placed correctly **before** the existing `close()` so both coexist.
- **`_CwRailEmpty`** at `home_screen.dart:323` — full empty-state card with eyebrow + title + icon + headline + subcopy + violet "Browse library" CTA routing to `Routes.libraryWithFilter('movies')`.
- **`RepaintBoundary`** at `background_gradient.dart:46` — `Positioned.fill(child: RepaintBoundary(child: child))` so the static two-radial backdrop never repaints when the routed child invalidates.
- **`pubspec.yaml`** — all 5 deps present (`just_audio ^0.10.5`, `pdfx ^2.9.2`, `photo_view ^0.15.0`, `path_provider ^2.1.5`, `share_plus ^12.0.2`).
- **Server `/content` endpoint** at `files.py:162` — placed BEFORE `/{file_id}` (line 204) so FastAPI doesn't match `"content"` as a path-param value. Returns 404 (not 403) on group-visibility deny, mirroring `get_file`'s enumeration-prevention semantics. MIME-detected via `mimetypes.guess_type` with `application/octet-stream` fallback.
- **`MediaKind` enum + `MediaFileKind` extension** at `media_file.dart:51` — pure extension, no codegen, all extensions braced.
- **3 viewer screens** (`doc_viewer_screen.dart`, `photo_viewer_screen.dart`, `music_player_screen.dart`) + **3 routes** (`/doc-viewer`, `/photo-viewer`, `/music-player`) — all wired via `state.extra as MediaFile`.
- **`flutter analyze` × `apps/mobile`** — clean (10.3 s).
- **`flutter test` × `apps/mobile`** — 64/64 passing.

#### 2. Bug surfaced during audit + fixed: files_screen `_openInExternal` resource leak + silent failure

`files_screen.dart`'s `_FileChip._openInExternal` had two issues that the doc/photo viewers got right but this code path didn't:

- **`HttpClient` was leaked** if `getTemporaryDirectory()` or `pipe()` threw — there was no `try/finally`, so the client never reached `.close()` on the error path.
- **Failures were silently swallowed** — only logged via `Logger().e(...)`; the user got no feedback when "Open in..." couldn't reach the file.

Fixed by capturing `ScaffoldMessenger.of(context)` before any async gap (so a navigate-away-mid-download still surfaces the SnackBar), wrapping the `HttpClient` work in `try/finally`, surfacing a "Could not open in external app." SnackBar on failure, and promoting the per-call `Logger()` to a `static final _log = Logger();` field. Pattern now mirrors the doc/photo viewer behaviour.

#### 3. Server tests for `GET /{file_id}/content`

Added 5 new tests in `tests/test_files.py` — happy path + 3 failure shapes + 1 localhost-bypass case. Mirrors the existing `reset-progress` visibility-deny pattern (uses `unittest.mock.patch` on `services.group_service.get_visible_libraries` + the `CF-Connecting-IP` trick to push `validate_token_or_local` off the loopback bypass).

- `test_get_file_content_streams_bytes_with_correct_mime` — 200; bytes match payload; `content-type` is `application/pdf`; `content-disposition` carries `filename=doc.pdf`.
- `test_get_file_content_404s_when_file_not_in_db` — unknown `file_id` → 404.
- `test_get_file_content_404s_when_path_missing_on_disk` — DB row exists but on-disk path missing → 404 (not 500 / FileNotFoundError).
- `test_get_file_content_404s_when_library_not_visible` — bearer caller whose groups don't expose the file's library → 404; bytes never streamed.
- `test_get_file_content_local_caller_skips_visibility` — localhost (no bearer) bypasses the visibility filter, same as `get_file` / `reset-progress`.

Server suite **656 → 661 passing**. `flutter analyze` × `apps/mobile` still clean (8.8 s) after the files_screen fix; mobile suite still 64/64.

#### 4. Three-doc sync + AGENT_LOG format spec

Three files updated end-to-end so docs match shipped code (this was the prior continuation's "next agent should" #1–#3):

- **`docs/04_api/01_api_contracts.md`** — added `GET /api/v1/files/{file_id}/content` entry between `GET /{file_id}` and `POST /upload`. Documents the 404-not-403 group-visibility behaviour and the `mimetypes.guess_type` MIME detection.
- **`docs/00_overview/current_status.md`** — mobile section banner extended with the §17.3 #4/#5/#11 audit cleanup facts and the M11 closure (deps, viewer screens, route additions, deferred lockscreen integration). Test count stays 64.
- **`docs/11_design/mobile_redesign_plan.md`** — §6 dep table rows for `just_audio` / `pdfx` / `photo_view` flipped from "check pub.dev at MX" placeholders to ✅-locked entries with shipped versions; 2 new rows for `share_plus ^12.0.2` and `path_provider ^2.1.5`. M11 row in §7 milestone table flipped to ✅ done with full landed scope. §17.3 entries #4 / #5 / #6 / #11 marked ✅. §17.4 next-priorities refreshed (iOS PIP / M12 / Notifications FIFO cap parity / sleep-timer wiring). 2 new §16 changelog rows (M11 landed, audit cleanup landed). Plan-vs-reality table flipped M11 from "pending" to "✅ landed 2026-05-08".

Plus: a format audit on AGENT_LOG.md itself — the prior continuation's entry (and my first version of this entry) drifted from the canonical archive 01–08 shape (lowercase headers, `#### Code` / `#### Docs` split, performative `### Hard Rules Checklist`). New canonical spec written to **`docs/12_guidelines/04_agent_log_format.md`** with the new shape: Title Case headers, single combined `| Action | Path | Why |` 3-column Files table, `[tag]`'d header for grep-filtering, **`Commits:`** field after Status, `### Hard Rules Checklist` and `### Verification` dropped. CLAUDE.md "Where the detail lives" table + "Before ending your session" rule both updated to point at the new spec. This entry is the first written under the new spec.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | `apps/mobile/lib/features/library/presentation/screens/files_screen.dart` | `_openInExternal` HttpClient leak fix + SnackBar on failure + static `_log` field |
| Modified | `apps/server/tests/test_files.py` | +5 tests for `GET /{file_id}/content` (happy path / 3 failure shapes / localhost bypass) |
| Created | `docs/12_guidelines/04_agent_log_format.md` | Canonical AGENT_LOG entry-format spec (resolves archive 09 drift) |
| Modified | `CLAUDE.md` | Reference the new format spec from "Where the detail lives" + "Before ending your session" rules |
| Modified | `docs/04_api/01_api_contracts.md` | New `GET /api/v1/files/{file_id}/content` endpoint entry inserted before `POST /upload` |
| Modified | `docs/00_overview/current_status.md` | Mobile banner extended with §17.3 #4/#5/#11 cleanup + M11 closure facts |
| Modified | `docs/11_design/mobile_redesign_plan.md` | M11 row ✅ in §7; §6 dep table 3 rows locked + 2 new rows; §17.3 #4/#5/#6/#11 ✅; §17.4 priorities refreshed; §16 +2 changelog rows; plan-vs-reality table M11 ✅ |
| Created | `~/.claude/projects/.../memory/reference_agent_log_format.md` | Memory entry pointing at the new format spec |
| Modified | `~/.claude/projects/.../memory/MEMORY.md` | Index row for the new memory |
| Modified | `AGENT_LOG.md` | This entry — first one written under the new format |

### Docs Updated

- `docs/12_guidelines/04_agent_log_format.md` — new file; canonical AGENT_LOG entry-format spec.
- `CLAUDE.md` — "Where the detail lives" gained a row pointing at the new spec; "Before ending your session" rules now reference it.
- `docs/04_api/01_api_contracts.md` — new `GET /api/v1/files/{file_id}/content` section.
- `docs/00_overview/current_status.md` — mobile banner extended with §17.3 #4/#5/#11 cleanup + M11 closure facts.
- `docs/11_design/mobile_redesign_plan.md` — M11 milestone row + §6 dep table + §17.3 audit items + §17.4 next-priorities + §16 changelog + plan-vs-reality table.

### Decisions Made

- **Reuse the doc/photo viewer error-handling pattern in files_screen, don't extract a shared helper yet.** The `_openInExternal` HttpClient flow is now duplicated 3×. Per CLAUDE.md ("three similar lines is better than premature abstraction") each call site stays separate — each has slightly different UX (different SnackBar copy, different button-state handling). Revisit at M14 polish.
- **Adopted format improvements 1–4 from the audit recommendation; skipped 5–8.** Tag suffix on header (`[m11] [fix] …`), `**Commits:**` field, 3-column Files table with `Why`, drop `### Hard Rules Checklist` + `### Verification` blocks. Skipped: diff-stat lines (duplicates `git diff --stat`), Risk/Reversibility tag (would always say "low" — useless gradient), and time-tracking (no reliable wall-clock).
- **Added a localhost-bypass test for `/content` even though it wasn't on the next-agent-should list.** The four required tests cover bearer-token paths but not localhost. Without it, a regression on the localhost dep would slip through CI silently. Mirrors the test coverage shape `reset-progress` already has.
- **Did NOT add `package:http`** despite the temp-download flow needing an HTTP client — used `dart:io.HttpClient` instead, honoring CLAUDE.md hard prohibition #6 (no new deps without justification). Same rationale as the prior continuation's doc/photo viewer choice.

### Issues / Sharp Edges Discovered

- **`_openInExternal` HttpClient pattern duplicated 3× across `files_screen.dart`, `doc_viewer_screen.dart`, `photo_viewer_screen.dart`.** Each instance has slightly different UX, so we kept them separate. Revisit at M14 polish.
- **Music player has no "Open in..." action.** By design (music plays in-app), but worth confirming in real-device QA that users don't expect to AirDrop / share the source MP3 from the player chrome.
- **Music player `audio_service` lockscreen integration is genuinely missing.** The deferral is documented inline in `music_player_cubit.dart`, but if a v1 user pairs the app and tries to control music from the lockscreen, they'll get nothing. The video `PlayerCubit` owns the singleton `FluxoraAudioHandler` and a second handler can't be attached without a refactor. v1.1 work — flag in release notes if the v1 ship date is close.
- **AGENT_LOG format drift in archive 09 is now permanent in the historical record.** The prior continuation's entry (in the live log, just above this one) and a couple of archive 09 entries use the lowercase + `#### Code/Docs` shape. Logs are append-only so we don't rewrite them — but the new format spec at `docs/12_guidelines/04_agent_log_format.md` documents the canonical shape so all *future* entries land in the right place.

### Test Counts (re-baselined)

- **Server: 661 passing** (+5 from `/content` tests; 656 → 661)
- **Mobile: 64 passing** (unchanged — `files_screen` fix is a pure error-path correction; not exercised in unit tests, would need a widget test to cover the SnackBar)
- **Desktop: 90 passing** (untouched)
- **Core: 8 passing** (untouched)

`flutter analyze` clean × all 3 packages.

### Working-Tree Status

Single uncommitted batch on top of `4d96fb0`:

- `files_screen.dart` resource-leak fix (1 code file)
- `test_files.py` +5 cases (1 test file)
- `docs/12_guidelines/04_agent_log_format.md` (new)
- `CLAUDE.md` (2 small edits — table row + rule reference)
- 3 sync'd doc files (`api_contracts.md`, `current_status.md`, `mobile_redesign_plan.md`)
- `AGENT_LOG.md` (this entry)
- 2 memory files outside the repo (`reference_agent_log_format.md` + `MEMORY.md` index — these don't ship)

Awaiting commit round. Suggested split: (a) server fix + tests + api docs, (b) format spec + CLAUDE.md, (c) status / plan doc sync + AGENT_LOG.

### Next Agent Should

1. **Smoke-test M11 on a real device** — M11 has only been compile-tested + unit-tested; no live-server walk-through. Take a PDF / photo / MP3 through the files browser → viewer → "Open in..." flow on Android (and iOS if the dev cert is current). Verify the `Content-Type`-based "Open in..." picker shows the expected app list (Adobe Reader / Gallery / Apple Music / etc.).
2. **§17.3 #8 — Notifications FIFO cap parity.** Desktop's `NotificationsCubit.liveStream` caps the `seen` set at 500 entries; verify mobile mirrors this. Mechanical, one-line if it doesn't.
3. **§17.3 #9 — Sleep-timer "Custom…" + "End of episode" stubs.** "Custom" is one `showTimePicker(...)` returning a `Duration`; "End of episode" needs the next-episode handoff that already exists for Group Watch wiring. Cheap follow-up to M6.
4. **M12 Onboarding revamp** — the next major milestone. Splash screen + signin (email + 2FA TOTP + QR + invite-code paths — TOTP placeholder if backend isn't ready) + server-picker rebuild. M2 dependency only.
5. **iOS PIP (§17.3 #1)** — its own ticket; out of redesign-cutover scope. `media_kit` uses MPV which doesn't bridge to `AVPictureInPictureController`; either swap player backend to AVKit on iOS only, or build a custom `AVPlayerLayer` for iOS PIP and keep `media_kit` for Android + desktop.
6. **Future log entries: follow `docs/12_guidelines/04_agent_log_format.md`.** This entry is the worked example. Use the `[tag]` vocabulary on the header so `grep -E '^## .* \[m12\]'` etc. just works.
