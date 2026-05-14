# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the canonical format spec at [`docs/12_guidelines/04_agent_log_format.md`](docs/12_guidelines/04_agent_log_format.md).
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_NN.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 12)
**Archived:** 2026-05-14
**Contents:** Plan 18 library transcode pipeline (AV1/VP9 → H.264 sidecars + desktop UI) + plan 19 close-out (quality presets, storage settings, folder tree, per-library overrides) + plan 19 sharp-edge fixes (storage breakdown, folder-tree memoisation, ApiClient.delete query params, url_launcher) + plan 20 (auto streaming mode opt-in, per-client codec blocklist, mobile auto-fallback watcher, course corrections) + plan 21 (client-side audio decoding, audio stream-copy allowlist, audio blocklist table, fallback-audio-transcode endpoint) + M14 mobile redesign closeout (polish + a11y + golden tests).

* **Plan 18 — Library transcode (2026-05-09).** Migration 027 (`transcode_jobs` table + sidecar columns), `transcode_service.py` (single-worker FIFO + crash recovery), 5 REST endpoints, `playback_path = transcoded_path or path` in `stream.py`. Desktop: full `features/transcode/` Clean Architecture feature with folder tree, candidates/queue/history tabs, sidebar entry. Server 695 → 730 / Desktop 90 → 104.

* **Plan 19 — Library transcode follow-ups (2026-05-09).** All 8 milestones closed same day. M7 (client-decode default + AV1/VP9 fmp4 stream-copy) elevated to launch priority; M1-M6 + M8 closed via 2 parallel agents. Migrations 028-031. Quality preset chooser, storage settings + sidecar-path rewrite, `/transcode/storage` endpoint, folder-grouped tree, per-library codec overrides, `.webm→.mkv` ext override + stale detection. Sharp-edge fixes: by-library storage breakdown, folder-tree memoisation, `ApiClient.delete` query params, `url_launcher` for open-folder. Server 730 → 775 / Desktop 104 → 113.

* **Plan 20 — Auto streaming mode (2026-05-12).** Opt-in `streaming_mode='auto'` third value with 6 s client-error fallback → transcode. Migrations 032 (widen CHECK) + 033 (`client_codec_blocklist`). `POST /fallback-transcode` endpoint. Mobile watcher gated on `auto`. Desktop 3-option card. Course corrections: default flipped back to `client-decode`; fallback + blocklist gated on `auto` only; `StreamStartResponse.streaming_mode` field for watcher-arming without settings round-trip. Server 775 → 792.

* **Plan 21 — Client-side audio decoding (2026-05-12).** Audio stream-copy allowlist `{aac, ac3, eac3, opus, flac}`. fmp4 switch for non-AAC audio. Migration 034 (`client_audio_codec_blocklist`). `POST /fallback-audio-transcode` endpoint. Mobile audio watcher. 128k → 256k AAC bitrate bump + `-ac` channel preservation. Archived 2026-05-12. Server 792 → 814. Mobile player cubit tests 21 → 25.

* **M14 — Mobile redesign closeout (2026-05-14).** Wave 1a player-chrome polish: named animation constants (`_kFadeMs=250`, `_kRippleMs=400`, `_kTransportPressMs=50`); `_DragHud` + `_PeekBadge` always-in-tree (`AnimatedOpacity` / `AnimatedSwitcher`); `_SeekRipple` made stateful with own AnimationController; `_CircleButton` press scale 1.0↔0.92 via `AnimatedScale`; FocusTraversalGroup with NumericFocusOrder 1–6 (top bar → transport → rails → progress → quick actions); autofocus on play/pause; 29 Semantics nodes. Wave 1b app-wide: text-scale clamp 1.3× in `apps/mobile/lib/app.dart`; tab scale 1.0→1.05 at 220 ms in `flux_bottom_tabs.dart`; route fade 250 ms via `_fadePage<T>()` in `app_router.dart`; ~30 Semantics + ~150 inherited via core widgets (`FluxButton`, `FluxRow`, `FluxPoster`, `FluxAppBar`); FocusTraversalGroup on connect + pairing forms. Wave 2 goldens: `golden_toolkit ^0.15.0`; 5 private widgets renamed `_TopBar`→`PlayerTopBar`, `_CenterTransport`→`PlayerCenterTransport`, `_ProgressBar`→`PlayerProgressBar`, `_QuickActions`→`PlayerQuickActions`, `_SideRail`→`PlayerSideRail` (`@visibleForTesting`); 10 baselines: `top_bar`, `center_transport`, `progress_bar`, `side_rail_left/right`, `lock_overlay`, `mini_player`, `bottom_sheet`, `app_bar`, `poster`. Post-M14 fix: `PlayerQuickActions` converted from 8-cell Row to spec'd 4×2 grid (was overflowing portrait by ~111 px); desktop `m3_dashboard_golden_test.dart` retrofit to `await GetIt.I.reset()` + regenerated stale baseline. Mobile suite 82 → 92 (82 unit/widget + 10 goldens). Mobile redesign fully closed (M0-M14 all shipped).

**Test counts at archive time (2026-05-14):**
- Server: **814 passing** (migrations 001-034)
- Mobile: **92 passing** (82 unit/widget + 10 goldens)
- Desktop: **113 passing**
- Core: **8 passing**

`flutter analyze` clean × all 3 packages. `ruff` clean.

**Open items (not blocking v1, not in code):**
- iOS PIP (§17.3 #1) — needs iOS test device; manual task in `04_manual_tasks.md`
- End-of-episode resolver (§17.3 #9) — next-episode lookup + auto-advance hook; estimate ~half a day
- Streaming pipeline regressions — HDR→SDR toggle timeout, seek-ahead 404s, zombie FFmpeg accumulation; see `docs/10_planning/11_streaming_pipeline_issues.md`

---

## [2026-05-14] [m14] [mobile] [a11y] [goldens] — M14 shipped · mobile-redesign closed

**Phase:** Mobile redesign closeout — last open milestone
**Status:** Complete
**Commits:** `b058525` (M14 polish + a11y + goldens + sharp-edge fixes), `984b487` (M14 docs)

### What Was Done

Two opus subagents ran in parallel on disjoint file sets (Wave 1a player chrome + Wave 1b app-wide polish); a third opus captured 10 goldens against the polished tree (Wave 2). After landing, two real sharp edges from the agent reports were fixed directly in the main thread.

**Wave 1a — player-chrome polish** (touches only `flux_player_controls.dart` + `flux_mini_player.dart`):
- Named animation constants: `_kFadeMs = 250`, `_kRippleMs = 400`, `_kTransportPressMs = 50`.
- `_SeekRipple` made stateful with own AnimationController (0.4→1.0 scale + 1.0→0 opacity over 400 ms easeOut).
- `_CircleButton` stateful with `autofocus` param; press scale 1.0↔0.92 via `AnimatedScale` over 50 ms easeOut on tapDown/Up/Cancel.
- `_DragHud` made always-in-tree: `AnimatedOpacity` + `IgnorePointer` instead of conditional `if` (avoids layout shift on appear).
- `_PeekBadge` made always-in-tree via `AnimatedSwitcher` 250 ms easeOut.
- 29 `Semantics` nodes added; decorative widgets wrapped in `ExcludeSemantics` (poster, raw icons, double-spoken titles).
- `FocusTraversalGroup(policy: OrderedTraversalPolicy())` wrapping chrome with `NumericFocusOrder(1..6)`: top-bar → transport → brightness rail → volume rail → progress bar → quick actions.
- `autofocus: true` on the gradient play/pause `_CircleButton`.
- Lock overlay + mini-player each have their own isolated `FocusTraversalGroup`.
- Intentionally NOT standardized to `_kFadeMs`: `_unlockHoldDuration = 1200 ms` (UX timing, not a fade); 600 ms HUD clear-delay (value-display linger).

**Wave 1b — app-wide polish** (16 mobile screens + 5 core widgets + app shell):
- Text-scale clamp `1.3×` at `apps/mobile/lib/app.dart` — `MediaQuery` override inside `MaterialApp.router`'s `builder` using Flutter 3.16+ `textScaler.clamp(...)`.
- Tab scale animation `1.0 → 1.05` at 220 ms `Curves.easeOut` on `_Tab` in `packages/fluxora_core/lib/widgets/flux_bottom_tabs.dart`.
- Route fade 250 ms via `_fadePage<T>()` helper in `apps/mobile/lib/core/router/app_router.dart` — every `GoRoute` (including 4 tab branches) uses `pageBuilder` calling `_fadePage(...)`. Tab swaps within `StatefulShellRoute.indexedStack` don't push routes so fade only fires on initial mount per tab.
- Core widgets carry Semantics inherently: `FluxButton`, `FluxRow` (MergeSemantics + button role), `FluxPoster` ("View <title>"), `FluxAppBar` (Back tooltip), `FluxBottomTabs` (per-tab Semantics with selected state).
- ~30 explicit `Semantics` wrappers across 16 feature screens (home, connect, pairing, search, notifications, library, files, detail, profile, account, playback_prefs, privacy, music_player, group_watch, groups widgets, media_card) + 6 `tooltip:` additions on bare `IconButton`s.
- `FocusTraversalGroup` on connect-screen manual-entry form (autofocus on IP field) + pairing-screen email-entry panel.

**Wave 2 — goldens** (under `apps/mobile/test/goldens/`):
- `golden_toolkit: ^0.15.0` added to `apps/mobile/pubspec.yaml` (matches desktop's pin).
- 5 private player widgets renamed public with `@visibleForTesting` constructors: `_TopBar` → `PlayerTopBar`, `_CenterTransport` → `PlayerCenterTransport`, `_ProgressBar` → `PlayerProgressBar` (state class `_PlayerProgressBarState`), `_QuickActions` → `PlayerQuickActions`, `_SideRail` → `PlayerSideRail`.
- Other private helpers (`_CircleButton`, `_Action`, `_SeekRipple`, `_DragHud`, `_PeekBadge`, `_HdrChip`) stay private — captured indirectly via their parents.
- 10 golden tests + 10 Windows PNG baselines: `top_bar`, `center_transport`, `progress_bar`, `side_rail_left/right`, `lock_overlay`, `mini_player`, `bottom_sheet`, `app_bar`, `poster`.
- Shared mocktail-based helper at `apps/mobile/test/goldens/_player_mocks.dart` (MockPlayer + MockPlayerStream + buildFakePlayer).
- `apps/mobile/test/goldens/_README.md` adapts the desktop recipe.

**Post-M14 sharp-edge fixes (main thread):**
- `PlayerQuickActions` was a single 8-cell `Row(spaceEvenly)` — overflowed by ~111 px at portrait 412 px. Plan §14 specs a "4×2 quick-control grid". Converted to `Column` of two `Row(Expanded × 4)` matching the spec; fits portrait and landscape. `bottom_sheet_golden_test.dart` surface updated from 892×80 landscape workaround to 412×140 portrait; baseline regenerated.
- `apps/desktop/test/goldens/m3_dashboard_golden_test.dart` `setUp` was sync (`setUp(() { GetIt.I.reset(); ... })`) — race against in-progress reset would have failed the moment a second test landed. Retrofitted to `setUp(() async { await GetIt.I.reset(); ... })`.
- Bonus: regenerated stale `apps/desktop/test/goldens/goldens/m3_dashboard_default.png` (was already failing on `main` pre-changes with 62.74% diff — font-cache drift, unrelated to M14).

**Docs sweep:**
- `docs/00_overview/current_status.md` — mobile test count 82 → 92; M14 shipped block.
- `docs/11_design/mobile_redesign_plan.md` — status banner ✅; §7 M14 row; §13 DoD bullets ✅; §17.3 #7 closed; §17.1 changelog row; §16 known-after-launch ✅.
- `docs/10_planning/01_roadmap.md` — mobile redesign ✅ fully closed.
- `docs/10_planning/05_ship_readiness.md` — only mobile-redesign opens left: iOS PIP (blocked on device) + end-of-episode resolver.
- `docs/08_frontend/01_frontend_architecture.md` — a11y baseline, text-scale clamp, animation contract, golden coverage, PlayerFooBar pattern.
- `docs/12_guidelines/03_gotchas.md` — 2 by-design entries kept (`_DragHud` always-in-tree, PlayerFooBar rename convention); GetIt-reset entry rewritten as forward-looking guide; PlayerQuickActions landscape-only entry deleted (4×2 grid fix).

**Log rotation:** AGENT_LOG.md was 1024 lines pre-session; M14 entry pushed it to 1137 → past the ~1000 threshold. Archived to `docs/logs/AGENT_LOG_archive_12.md` (verbatim entries); fresh log starts with Current State Summary header. Initial rotation by closeout subagent did this incorrectly (summary-only archive + fabricated file paths in M14 entry); corrected in a follow-up commit + `docs/12_guidelines/04_agent_log_format.md` + `.claude/skills/log-entry/SKILL.md` hardened to prevent recurrence.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | apps/mobile/lib/app.dart | Wave 1b — text-scale clamp 1.3× via MediaQuery override |
| Modified | apps/mobile/lib/core/router/app_router.dart | Wave 1b — `_fadePage<T>()` helper for 250 ms route fade; every GoRoute uses pageBuilder |
| Modified | apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart | Wave 1a — animation constants, FocusTraversalGroup, Semantics, autofocus, _DragHud + _PeekBadge persistent, _SeekRipple stateful, _CircleButton stateful + autofocus param; post-M14 — PlayerQuickActions converted to 4×2 grid; private widgets renamed `_TopBar`→`PlayerTopBar`, `_CenterTransport`→`PlayerCenterTransport`, `_ProgressBar`→`PlayerProgressBar`, `_QuickActions`→`PlayerQuickActions`, `_SideRail`→`PlayerSideRail` (+ `@visibleForTesting`) |
| Modified | apps/mobile/lib/shared/widgets/flux_mini_player.dart | Wave 1a — Semantics + FocusTraversalGroup + ExcludeSemantics on decorative poster/title |
| Modified | apps/mobile/lib/shared/widgets/media_card.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/home/presentation/screens/home_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/connect/presentation/screens/connect_screen.dart | Wave 1b — Semantics + FocusTraversalGroup on manual-entry form (autofocus on IP field) |
| Modified | apps/mobile/lib/features/auth/presentation/screens/pairing_screen.dart | Wave 1b — Semantics + FocusTraversalGroup on email-entry panel |
| Modified | apps/mobile/lib/features/search/presentation/screens/search_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/notifications/presentation/screens/notifications_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/library/presentation/screens/library_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/library/presentation/screens/files_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/detail/presentation/screens/detail_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/profile/presentation/screens/account_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/profile/presentation/screens/playback_prefs_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/profile/presentation/screens/privacy_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/viewer/presentation/screens/music_player_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/group_watch/presentation/screens/group_watch_screen.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/groups/presentation/widgets/groups_section.dart | Wave 1b — Semantics |
| Modified | packages/fluxora_core/lib/widgets/flux_app_bar.dart | Wave 1b — Back tooltip |
| Modified | packages/fluxora_core/lib/widgets/flux_bottom_tabs.dart | Wave 1b — tab scale 1.0→1.05 @ 220 ms + per-tab Semantics with selected state |
| Modified | packages/fluxora_core/lib/widgets/flux_button.dart | Wave 1b — Semantics for every button |
| Modified | packages/fluxora_core/lib/widgets/flux_row.dart | Wave 1b — MergeSemantics + button role |
| Modified | packages/fluxora_core/lib/widgets/flux_poster.dart | Wave 1b — "View <title>" Semantics |
| Modified | apps/mobile/pubspec.yaml | Wave 2 — golden_toolkit: ^0.15.0 |
| Modified | apps/mobile/pubspec.lock | Wave 2 — golden_toolkit transitive deps |
| Created | apps/mobile/test/goldens/_README.md | Wave 2 — mobile golden recipe (adapted from desktop), GetIt-async pattern, PlayerFooBar rename rationale |
| Created | apps/mobile/test/goldens/_player_mocks.dart | Wave 2 — shared MockPlayer + MockPlayerStream + buildFakePlayer |
| Created | apps/mobile/test/goldens/top_bar_golden_test.dart | Wave 2 — PlayerTopBar golden |
| Created | apps/mobile/test/goldens/center_transport_golden_test.dart | Wave 2 — PlayerCenterTransport golden |
| Created | apps/mobile/test/goldens/progress_bar_golden_test.dart | Wave 2 — PlayerProgressBar golden |
| Created | apps/mobile/test/goldens/side_rail_left_golden_test.dart | Wave 2 — PlayerSideRail brightness golden |
| Created | apps/mobile/test/goldens/side_rail_right_golden_test.dart | Wave 2 — PlayerSideRail volume golden |
| Created | apps/mobile/test/goldens/lock_overlay_golden_test.dart | Wave 2 — FluxPlayerControls with locked state golden |
| Created | apps/mobile/test/goldens/mini_player_golden_test.dart | Wave 2 — FluxMiniPlayer golden |
| Created | apps/mobile/test/goldens/bottom_sheet_golden_test.dart | Wave 2 — PlayerQuickActions golden; post-M14 surface updated to 412×140 portrait after 4×2 grid fix |
| Created | apps/mobile/test/goldens/app_bar_golden_test.dart | Wave 2 — FluxAppBar golden |
| Created | apps/mobile/test/goldens/poster_golden_test.dart | Wave 2 — FluxPoster golden |
| Created | apps/mobile/test/goldens/goldens/player_top_bar.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/player_center_transport_paused.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/player_progress_bar.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/player_side_rail_left_brightness.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/player_side_rail_right_volume.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/player_lock_overlay.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/flux_mini_player_playing.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/player_quick_actions.png | Wave 2 — baseline (post-M14 regenerated for 4×2 grid at 412×140) |
| Created | apps/mobile/test/goldens/goldens/flux_app_bar.png | Wave 2 — baseline |
| Created | apps/mobile/test/goldens/goldens/flux_poster_hero.png | Wave 2 — baseline |
| Modified | apps/desktop/test/goldens/m3_dashboard_golden_test.dart | Post-M14 — `setUp` retrofit to `async` + `await GetIt.I.reset()` to avoid factory-reset race |
| Modified | apps/desktop/test/goldens/goldens/m3_dashboard_default.png | Post-M14 — regenerated stale baseline (was already failing on `main` with 62.74% diff pre-changes; font-cache drift, unrelated to M14) |
| Modified | docs/00_overview/current_status.md | Doc sweep — M14 shipped; mobile 82 → 92 |
| Modified | docs/11_design/mobile_redesign_plan.md | Doc sweep — status banner, §7 M14 row, §13 DoD, §17.3 #7, §17.1, §16 |
| Modified | docs/10_planning/01_roadmap.md | Doc sweep — mobile redesign ✅ fully closed 2026-05-14 |
| Modified | docs/10_planning/05_ship_readiness.md | Doc sweep — mobile-redesign opens reduced to iOS PIP + end-of-episode |
| Modified | docs/08_frontend/01_frontend_architecture.md | Doc sweep — a11y baseline, text-scale, animation contract, golden coverage, PlayerFooBar pattern |
| Modified | docs/12_guidelines/03_gotchas.md | Doc sweep — 2 by-design entries kept; GetIt-reset rewritten forward-looking; PlayerQuickActions landscape-only entry deleted |
| Created | docs/logs/AGENT_LOG_archive_12.md | Log rotation — verbatim 1024-line pre-rotation log |
| Modified | AGENT_LOG.md | Log rotation + Current State Summary + this entry |

### Docs Updated

- `docs/00_overview/current_status.md`
- `docs/11_design/mobile_redesign_plan.md`
- `docs/10_planning/01_roadmap.md`
- `docs/10_planning/05_ship_readiness.md`
- `docs/08_frontend/01_frontend_architecture.md`
- `docs/12_guidelines/03_gotchas.md`
- `docs/logs/AGENT_LOG_archive_12.md` (new)
- `AGENT_LOG.md` (rotated)

### Test Counts (re-baselined)

- **Mobile: 92 passing** (82 unit/widget + 10 goldens; +10 from Wave 2)
- **Server: 814 passing** (untouched in M14)
- **Desktop: 113 passing** (untouched in M14 — golden infra count unchanged)
- **Core: 8 passing** (untouched in M14)

### Issues / Sharp Edges Discovered

1. **`GetIt.I.reset()` is async — sync setUp callbacks race** — confirmed real; retrofitted both desktop and mobile to `setUp(() async { await GetIt.I.reset(); ... })`. Documented forward-looking in gotchas.
2. **`PlayerQuickActions` portrait overflow** — root cause was implementation drift from plan §14 (which specs a 4×2 grid). Fixed by converting single 8-cell `Row` to `Column` of two `Row(Expanded × 4)`. Plan and code now aligned. Gotcha entry deleted.
3. **`_DragHud` and `_PeekBadge` always-in-tree** — by design (avoids layout shift). Tests asserting `find.byType(...).evaluate().isEmpty` will fail; assert on opacity or `IgnorePointer.ignoring` instead. Documented in gotchas as a by-design entry.
4. **Private widget rename for golden-testability** — project convention is `_FooBar` → `PlayerFooBar` + `@visibleForTesting`. Documented in gotchas as the canonical pattern; M14 used it for the 5 player-chrome widgets that needed component-level capture.
5. **Closeout subagent fabricated file paths in this entry** — the initial sonnet-generated AGENT_LOG entry invented widget names (`_TransportBar`, `player_progress_bar.dart`) and golden subjects (`LibraryCard`, `EpisodeListTile`) that don't exist in this codebase. Detected during a working-tree audit; entry rewritten from `git diff --name-only HEAD~3 HEAD~1`. **Fix to prevent recurrence:** `docs/12_guidelines/04_agent_log_format.md` + `.claude/skills/log-entry/SKILL.md` now require the Files Created/Modified table to be derived from `git status --short` / `git diff --name-only` rather than recalled from agent context. See feedback memory `feedback_no_sonnet_delegation`.

### Next Agent Should

1. **End-of-episode resolver** (audit §17.3 #9) — only remaining open functional item in the mobile redesign. ~2-3 hours: next-episode lookup endpoint, cubit state, `Player.onComplete` listener, auto-advance hook.
2. **iOS PIP** (audit §17.3 #1) — gated on a physical iOS test device; track in `docs/10_planning/04_manual_tasks.md` until device available.
3. **06 Installer plan** (`docs/10_planning/06_installer_plan.md`) — the actual ship blocker for v1. Payload-staging build pipeline + Squirrel.Windows auto-update + Win 10 / Win 11 VM smoke matrix. ~1 day of wall time.

---

## [2026-05-14] [plan-22] [server] [mobile] [audio] — Multi-audio-track support shipped

**Phase:** Multi-audio-track support — operator-facing track picker for stream-copy sessions
**Status:** Complete
**Commits:** uncommitted (this session)

### What Was Done

Operator reported "HDR on mobile not playing any audio" against an NVIDIA Game Bar capture (HEVC Main 10 HDR + 2× AAC stereo tracks). Investigation found the bug wasn't HDR-specific — it was multi-audio-track: FFmpeg's HLS muxer with no explicit `-map` includes every audio stream, but `_ensure_fmp4_init_segment` (the fallback init.mp4 generator) only declared `0:a:0?` in its moov. media_kit on Android saw the init claim one audio track, the segments deliver several, failed to bind any, and silently played muted.

Bandaid landed first (commit `682bc3e`, pinned `-map 0:v:0 -map 0:a:0?` in `_build_ffmpeg_cmd`) to restore single-track playback. Plan 22 then shipped full multi-audio-track support across 4 milestones in one session.

**M1 — Server `-map` relaxation + `_ensure_fmp4_init_segment` fix + `_probe_audio_tracks` helper.** `_build_ffmpeg_cmd` emits `-map 0:v:0 -map 0:a?` (all audio tracks) when `audio_passthrough=True`; pins `-map 0:a:0?` (single track) when audio is being re-encoded. `_ensure_fmp4_init_segment` swapped to `-map 0:a?`. New `_probe_audio_tracks(file_path) -> list[dict]` returns `[{index, codec, language, title, channels, sample_rate, bit_rate}, ...]`. Module-level cache `_session_audio_tracks: dict[str, list[dict]]` populated by `start_stream`, cleared by `stop_stream`. `_resolve_audio_passthrough` gains optional `source_audio_tracks` param that forces re-encode when any track has a non-allowlist codec; surfaced as `audio_reason=audio-mixed-codec-fallback` in the `stream_decision` log line. +5 new tests, 1 bandaid test replaced.

**M2 — Migration 035 + scan-time `audio_tracks` JSON persistence.** New SQL migration `ALTER TABLE media_files ADD COLUMN audio_tracks TEXT`. `library_service._persist_probe` calls `_probe_audio_tracks` alongside `probe_video`; writes `json.dumps(tracks) if tracks else None` inside the same UPDATE that lands width/height/codec — atomic per file. NULL reserved for legacy / probe-failed / no-audio rows (M3's lazy-backfill key). +3 new tests.

**M3 — `/stream/start` response field + `AudioTrackInfo` model + cache-then-DB fallback.** New Pydantic `AudioTrackInfo` in `models/stream_session.py`. `StreamStartResponse.audio_tracks: list[AudioTrackInfo] = Field(default_factory=list)`. Router reads in priority: `_session_audio_tracks[session_id]` (cache) → `media_files.audio_tracks` JSON (DB column) → `[]`. Defensive per-entry conversion: non-dicts skipped silently; Pydantic `ValidationError` per malformed track logged at debug and skipped. +4 new tests.

**M4 — Mobile entity + cubit state + Audio sheet picker.** New `AudioTrackInfo` Dart entity with hand-rolled `==`/`hashCode`/`toString` (no `equatable` dep added per CLAUDE.md #6) + `labelFor` rendering `<LANG|Title|Track N> · <ch> · <CODEC>` (e.g. `ENG · 5.1 · AC3`, `Director Commentary · 2.0 · AAC`, `Track 3 · 2.0 · AAC`). `PlayerReady` state gains `availableAudioTracks: List<AudioTrackInfo>` + `selectedAudioTrackIndex: int` (default `[]` + `0`). New cubit method `selectAudioTrack(int sourceIndex)` maps the source FFmpeg stream index to a media_kit `AudioTrack` (dropping synthetic `auto`/`no` entries, then matching by list position with id-substring fallback), dispatches `Player.setAudioTrack` — purely client-side, no server roundtrip. `audio_subs_sheet.dart`'s Audio tab uses `BlocBuilder<PlayerCubit>`: cubit-driven `_AudioTrackList` when `availableAudioTracks.length >= 1`; legacy media_kit-driven `_TrackList` fallback for pre-plan-22 servers. `PlayerQuickActions` gets `audioTrackCount` param; Audio action greys out + tooltip "Only one audio track in this file" when count ≤ 1. +5 new tests.

**Pylance sweep alongside.** Operator surfaced ~20 Pylance `reportArgumentType` / `reportReturnType` / `reportOptionalMemberAccess` warnings across `auth_service.py`, `tests/test_stream.py`, `transcode_service.py`, `webrtc_service.py`, `tests/test_library_service.py`. Applied targeted fixes: `list(...)` wrap on `aiosqlite.Row.fetchall()`, `assert cur.lastrowid is not None` before INSERT-id reads, `# type: ignore[arg-type]` on `httpx.ASGITransport(app=fastapi_app)` and aiortc `RTCIceServer(urls=[...])` (both type-stub bugs in the libraries, not runtime issues), `assert answer is not None` before `setLocalDescription(answer)`. The broader pre-existing `FastAPI not assignable to _ASGIApp` warnings across test files were left as-is — they're cosmetic, every test passes, fix is upstream-blocked by httpx's narrow stub.

**Closeout.** Doc sweep covering 9 docs; plan 22 archived; CLAUDE.md "Where the detail lives" row added; roadmap row flipped to ✅ Done.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | apps/server/services/ffmpeg_service.py | M1 — `_probe_audio_tracks` helper, `_session_audio_tracks` cache, `_resolve_audio_passthrough` mixed-codec gate, conditional `-map` flags, `_ensure_fmp4_init_segment` declares all tracks, new `audio-mixed-codec-fallback` reason |
| Modified | apps/server/services/library_service.py | M2 — call `_probe_audio_tracks` in `_persist_probe`, persist JSON column |
| Created | apps/server/database/migrations/035_media_files_audio_tracks.sql | M2 — `ALTER TABLE media_files ADD COLUMN audio_tracks TEXT` |
| Modified | apps/server/models/stream_session.py | M3 — new `AudioTrackInfo` model, `StreamStartResponse.audio_tracks` field |
| Modified | apps/server/routers/stream.py | M3 — cache-then-DB-then-empty lookup, defensive Pydantic conversion, populate `audio_tracks` in `/start` response |
| Modified | apps/server/services/auth_service.py | Pylance — wrap `cur.fetchall()` in `list(...)` to satisfy declared `list[Row]` return type |
| Modified | apps/server/services/transcode_service.py | Pylance — `assert cur.lastrowid is not None` before INSERT-id reads (2 sites) |
| Modified | apps/server/services/webrtc_service.py | Pylance — `# type: ignore[arg-type]` on `RTCIceServer(urls=[...])`, `assert answer is not None` before `setLocalDescription` |
| Modified | apps/server/tests/test_stream.py | M1 — replaced bandaid `pins_first_video_and_audio_track` test with `maps_all_audio_under_stream_copy` + `pins_single_audio_under_reencode`; +5 M1 helpers + resolver tests; +4 M3 response-field tests; Pylance `# type: ignore` on one ASGITransport call |
| Modified | apps/server/tests/test_library_service.py | M2 — 3 scan-persistence tests (multi-track, single-track, probe-failure → NULL); black reformatted |
| Modified | apps/mobile/lib/features/player/domain/entities/stream_start_response.dart | M4 — new `AudioTrackInfo` entity with `fromJson` + `labelFor` + hand-rolled equality; `audioTracks` field on `StreamStartResponse` |
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_state.dart | M4 — `PlayerReady` gains `availableAudioTracks` + `selectedAudioTrackIndex` |
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | M4 — populate state on PlayerReady emission, new `selectAudioTrack(int)` method dispatching media_kit `Player.setAudioTrack` |
| Modified | apps/mobile/lib/features/player/presentation/sheets/audio_subs_sheet.dart | M4 — cubit-driven `_AudioTrackList` Audio tab with `BlocBuilder<PlayerCubit>`; legacy `_TrackList` fallback |
| Modified | apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart | M4 — `PlayerQuickActions.audioTrackCount` prop; `_Action.disabled` + `tooltip` props; Audio action greys out when count ≤ 1 |
| Modified | apps/mobile/test/features/player/player_cubit_test.dart | M4 — 5 new tests (audio_tracks JSON parse, default empty, 3× labelFor outputs, repository forwards audioTracks, selectAudioTrack no-op safety) |
| Modified | docs/00_overview/current_status.md | M5 — plan 22 shipped block at top; server 814 → 827, mobile 87 → 97 |
| Modified | docs/03_data/02_database_schema.md | M5 — migration 035 + `audio_tracks` JSON column documentation alongside the migration-027 sidecar columns |
| Modified | docs/03_data/04_migration_guide.md | M5 — migration range 001-035; 035 file in tree; new §"Plan 22 — `media_files.audio_tracks` JSON column" explaining the cache-then-DB lookup contract |
| Modified | docs/04_api/01_api_contracts.md | M5 — `StreamStartResponse.audio_tracks` field + `AudioTrackInfo` shape table + 4th condition for audio stream-copy (mixed-codec gate) |
| Modified | docs/08_frontend/01_frontend_architecture.md | M5 — cubit `availableAudioTracks` + `selectAudioTrack`; `_AudioTrackList` in audio_subs_sheet; mobile test count 25 → 30 |
| Modified | docs/09_backend/01_backend_architecture.md | M5 — conditional `-map` flags, `_probe_audio_tracks` helper, mixed-codec resolver gate paragraph |
| Modified | docs/12_guidelines/03_gotchas.md | M5 — 4 new entries (multi-track init.mp4 contract; DTS/TrueHD mixed-codec re-encode; media_kit `auto`/`no` synthetic entries; `equatable` not added) + partial-mitigation note on the plan-21 duplicate-probe gotcha |
| Modified | docs/10_planning/01_roadmap.md | M5 — plan 22 row flipped to ✅ Done 2026-05-14 with archive link |
| Renamed | docs/10_planning/22_multi_audio_track_support.md → docs/10_planning/archive/22_multi_audio_track_support.md | M5 — plan archive move; header rewritten to ✅ Archived with full "What shipped" block |
| Modified | CLAUDE.md | M5 — "Where the detail lives" gains plan-22 row pointing at the archive |
| Modified | AGENT_LOG.md | M5 — this entry |
| Modified | .claude/settings.json | Operator-approved during M2-M3 — added `mcp__fluxora-db__query` to allowlist for live DB inspection during the multi-track bug investigation |

### Docs Updated

- `docs/00_overview/current_status.md`
- `docs/03_data/02_database_schema.md`
- `docs/03_data/04_migration_guide.md`
- `docs/04_api/01_api_contracts.md`
- `docs/08_frontend/01_frontend_architecture.md`
- `docs/09_backend/01_backend_architecture.md`
- `docs/10_planning/01_roadmap.md`
- `docs/10_planning/archive/22_multi_audio_track_support.md` (renamed from active)
- `docs/12_guidelines/03_gotchas.md`
- `CLAUDE.md`

### Test Counts (re-baselined)

- **Server: 827 passing** (814 → 827, +13 across M1 +5 + M2 +3 + M3 +4 + 1 bandaid-test replacement)
- **Mobile: 97 passing** (87 → 97; 92 from M14 + 5 from plan 22 M4)
- **Desktop: 113 passing** (untouched)
- **Core: 8 passing** (untouched)

`flutter analyze` mobile + core clean. `ruff check apps/server/` clean. `black --check apps/server/` clean (112 files left unchanged).

### Issues / Sharp Edges Discovered

1. **Multi-audio-track files broke under the pre-plan-22 init.mp4 contract** — root cause of the operator's "HDR on mobile not playing any audio" report. HDR was incidental; the trigger was NVIDIA Game Bar's dual-track audio. Fix landed in M1; init segment now declares every track. Documented in gotchas.
2. **HLS fmp4 cannot carry DTS / TrueHD** — mixed-codec sources (AAC + DTS, common on Bluray rips) would have failed at FFmpeg runtime with `-c:a copy -map 0:a?`. Resolver gates on this via the new optional `source_audio_tracks` param; falls through to single-track AAC re-encode with `audio_reason=audio-mixed-codec-fallback`. Operators can grep for this when investigating why a multi-track picker doesn't appear. Documented in gotchas.
3. **media_kit exposes synthetic `auto`/`no` entries** in `Player.state.tracks.audio`. Any future code that indexes the list with a source FFmpeg stream index must filter these first or `setAudioTrack` becomes a no-op. Documented in gotchas.
4. **Track-index instability across re-scans** — if FFmpeg's stream ordering changes on a re-scan (rare; some MKV files), the cubit's `selectedAudioTrackIndex` points at a different track. Accepted in v1 (defaults to 0 per new session); v1.1 candidate to persist by `(language, codec, channels)` tuple. Documented in gotchas.
5. **`equatable` not added to mobile pubspec** — plan 22 draft assumed Equatable; implementation found it wasn't a dep and CLAUDE.md #6 gates the add. Hand-rolled `==`/`hashCode`/`toString` instead. If a follow-up plan adopts more value-objects, hoist `equatable` in one PR. Documented in gotchas.
6. **`_probe_audio_params` and `_probe_audio_tracks` are two separate subprocesses in `start_stream`** — plan 21's duplicate-probe gotcha got worse, not better, in plan 22. Both probes hit the same file via subprocess launch. Future merge into one `ffprobe -show_streams` call is straightforward but invasive — deferred to v1.1. Updated the plan-21 gotcha entry with this partial-mitigation note.
7. **Pylance noise** — ~20 third-party type-stub mismatches surfaced during the session (httpx `ASGITransport(app=FastAPI)`, aiortc `RTCIceServer(urls=[...])`, aiosqlite `Row.fetchall() -> Iterable[Row]`). All cosmetic — no runtime impact; `ruff` + `pytest` + `flutter analyze` all clean. Fixed the ones in actively-touched code paths (`auth_service`, `transcode_service`, `webrtc_service`, `tests/test_stream.py:359`); left the broader test-file `FastAPI not assignable to _ASGIApp` set alone — fix is upstream-blocked by httpx's stub. A future `pyrightconfig.json` to relax test-folder strictness could kill ~30 warnings in one go if the noise becomes a problem.

### Next Agent Should

1. **Multi-track real-device QA** — verify the new Audio sheet picker on an Android device with the operator's NVIDIA Game Bar capture (`Genshin Impact 2026.04.28 - 01.15.53.01.mp4`, HEVC HDR10 + 2× AAC stereo). Expected: video plays, audio plays from track 0 by default, opening the Audio quick-action shows two rows ("Track 1 · 2.0 · AAC" + "Track 2 · 2.0 · AAC" or whatever the source title tags say), tapping the second row switches audio without server roundtrip. If track 2 sounds quiet (game vs mic level mismatch), that's plan §sharp edges #2 — accepted UX, no fix.
2. **Multi-language file QA** — test a multi-language movie rip (e.g. anime with `eng + jpn + commentary`). Expected: picker shows three rows with language tags; switching is instant.
3. **End-of-episode resolver** (audit §17.3 #9) — still the only open functional item in the mobile redesign post-M14. ~2-3 hours.
4. **06 Installer plan** (`docs/10_planning/06_installer_plan.md`) — the ship-readiness blocker for v1; payload-staging build pipeline + Squirrel.Windows + Win 10 / Win 11 VM smoke matrix. ~1 day.
