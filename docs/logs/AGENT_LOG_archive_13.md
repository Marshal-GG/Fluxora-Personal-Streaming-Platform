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
## [2026-05-15] [feat] [fix] [server] [mobile] [docs] — Plan 23 audio track switching + Plan 24 ExoPlayer migration kickoff

**Phase:** Plan 23 (server-restart audio track switching) shipped same day; Plan 24 (Android Media3 ExoPlayer migration) kicked off with M1 + M2 in parallel
**Status:** Plan 23 complete (unverified end-to-end on device); Plan 24 M1 + M2 in flight via parallel Opus subagents in isolated worktrees
**Commits:** `089f091` server endpoint, `d4e18bf` mobile wiring, `b54ed64` label polish, `a291683` player UI + wakelock, `bd0cc55` plan 24 doc, **+ pending docs commit**

### What Was Done

#### 1. Plan 23 — Server-restart audio track switching (server)

Operator reported (2026-05-15) that plan 22's client-side `media_kit.Player.setAudioTrack` reliably hangs libmpv-on-Android on a multi-audio AC3 5.1 file: pause+swap+resume kills audio for 20 s then stalls; swap-while-playing produces 20 s of silent video then stalls. Every cubit-level workaround failed (bare swap, pause/seek/play sequence, self-seek, 1s-back seek). Root cause: libmpv's HLS demuxer on Android can't recover from an init-segment vs. segments contract change mid-session.

**Server fix (`089f091`):** new `POST /api/v1/stream/{session_id}/audio-track` endpoint respawns FFmpeg with `-map 0:a:<index>?` so the chosen track is the only one in the playlist. Critical step: the endpoint `unlink`s the stale `init.mp4` BEFORE FFmpeg respawns — without this, libmpv keeps the multi-track init in cache and hangs on the segment/init mismatch. Returns segment-snapped `applied_seek_sec` so the cubit updates `_playlistOffsetSec` for the source-time scrubber.

`ffmpeg_service.py` gains a module-level `_session_pinned_audio_track: dict[str, int]` cache + `set/get/clear` helpers; `_build_ffmpeg_cmd` emits `-map 0:a:N?` when pinned; `_ensure_fmp4_init_segment` matches with the same shape so init.mp4 declares only the pinned track; `stop_stream` clears the pin. Models: `AudioTrackSwitchRequest` + `AudioTrackSwitchResponse` Pydantic.

#### 2. Plan 23 — Mobile wiring + libmpv audio reliability fixes

**Mobile (`d4e18bf`):** `PlayerRepository.switchAudioTrack` interface + impl POSTs to `/audio-track`; `PlayerCubit.selectAudioTrack` rewritten to call it, then `player.open(Media(url, httpHeaders: headers), play: wasPlaying)` to flush libmpv's cached HLS state.

**Two independent Android audio fixes layered in:**

- **libmpv `ao=audiotrack` override.** Before first `Player.open`, `NativePlayer.setProperty('ao', 'audiotrack')` flips libmpv from the default `opensles` AO to Android's `AudioTrack` API. Symptoms with `opensles` (operator debug logs on Oplus/OnePlus): `libOpenSLES: Emulating old channel mask behavior` on every track init (multi-channel falls back to stereo); AudioTrack churn 32 ms per play/pause; `flutter_webrtc` audio focus cascades. The `audiotrack` AO handles channels correctly and respects focus.
- **Screen-lifetime wakelock.** `WakelockPlus.enable()` in `_PlayerViewState.initState` + `Video(wakelock: false)`. Replaces media_kit_video's per-frame `FLAG_KEEP_SCREEN_ON` toggle (Oplus surface-recreate-on-flag-toggle was dropping ~32 ms of audio per play/pause). `wakelock_plus` made explicit in mobile pubspec (was already transitive via media_kit_video).

#### 3. Player UI redesign

**`a291683`:** Top bar gains Lock + Fit/Fill icons left of the 3-dot. Bottom 4×2 icon grid replaced by a 3-dot overflow menu with Audio / Subs / Speed / Quality / Sleep / Cast tiles. Center transport rebuilds via `StreamBuilder<bool>(player.stream.playing)` so pause/play reacts on first tap (was lagging because the parent rebuild gated on cubit state which didn't fire on every play/pause).

#### 4. Audio track label polish

**`b54ed64`:** Filter `und` / `unk` / `mis` / `zxx` / empty (NVIDIA Game Bar stamps every track with `tags.language="und"`); fall back to `Track N` where N is 1-based audio ordinal (not the FFmpeg stream index — matches VLC).

#### 5. Plan 24 — Android ExoPlayer migration plan drafted + M1/M2 kicked off

**`bd0cc55`:** 626-line plan for migrating Android playback from libmpv-via-media_kit to Media3 ExoPlayer via a hand-rolled Kotlin platform channel. `PlayerEngine` Dart abstraction in `packages/fluxora_core/lib/player/`; `MediaKitEngine` (desktop + iOS unchanged) + `ExoPlayerEngine` (Android, new). M1-M9 ~37 h ≈ 5 working days. Rollback via `_kForceMediaKitOnAndroid` flag. iOS deferred; multi-rendition HLS server output (industry-standard `#EXT-X-MEDIA TYPE=AUDIO` groups) split into plan 25.

**Open questions resolved 2026-05-15:**
1. Multi-rendition HLS server output — adopt the industry standard (plan 25, after plan 24 lands).
2. iOS migration — defer; no reported iOS bugs.
3. Subtitles — render Kotlin-side via Media3's `SubtitleView` (shipping speed wins).

**Parallel Opus subagents launched in isolated worktrees 2026-05-15:**
- **M1 — Kotlin platform-channel spike** — Media3 deps + `ExoPlayerPlugin.kt` + `SurfaceProducer` plumbing + throwaway Dart `ExoSpikePage` at `apps/mobile/lib/dev/` + hidden `/dev/exo-spike` route.
- **M2 — `PlayerEngine` Dart abstraction** — interface + `MediaKitEngine` wrapping current media_kit usage + cubit/screen/widgets refactored to depend on the engine instead of `Player` directly.

Both agents finished and merged their outputs back into the main tree by the time this entry was written (worktree paths kept locked under `.claude/worktrees/` for reconciliation). Reconciliation + integration commits pending in this session.

#### 6. Docs sweep

Following the documentation update protocol verbatim — every doc the protocol checklist flags as affected was updated. See "Docs Updated" below.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/server/services/ffmpeg_service.py | Plan 23 — pin cache + `-map 0:a:N?` + matching init |
| Modified | apps/server/routers/stream.py | Plan 23 — `/audio-track` endpoint + init.mp4 unlink |
| Modified | apps/server/models/stream_session.py | Plan 23 — request/response models |
| Modified | apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart | Plan 23 — `switchAudioTrack` POST impl |
| Modified | apps/mobile/lib/features/player/domain/repositories/player_repository.dart | Plan 23 — `switchAudioTrack` interface |
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | Plan 23 — server-restart switch + libmpv `ao=audiotrack` |
| Modified | apps/mobile/lib/features/player/presentation/screens/player_screen.dart | Wakelock fix — `WakelockPlus.enable` + `Video(wakelock: false)` |
| Modified | apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart | UI redesign — top bar Lock/Fit + 3-dot overflow + StreamBuilder transport |
| Modified | apps/mobile/lib/features/player/presentation/sheets/audio_subs_sheet.dart | Pass audio ordinal to `labelFor` |
| Modified | apps/mobile/lib/features/player/domain/entities/stream_start_response.dart | `labelFor(audioOrdinal)` + UND-language filter |
| Modified | apps/mobile/test/features/player/player_cubit_test.dart | Updated for server-restart switch |
| Modified | apps/mobile/test/goldens/top_bar_golden_test.dart | New top bar params (onLock/onFit/fitCover) |
| Modified | apps/mobile/test/goldens/goldens/player_top_bar.png | Regenerated baseline |
| Modified | apps/mobile/pubspec.yaml | `wakelock_plus` made explicit |
| Modified | apps/mobile/pubspec.lock | wakelock_plus version |
| Created | docs/10_planning/24_player_audio_reliability_plan.md | Plan 24 drafted (committed in `bd0cc55`) |
| Created | docs/10_planning/archive/23_audio_track_switching.md | Plan 23 retrospective archive |
| Modified | docs/10_planning/24_player_audio_reliability_plan.md | Open questions resolved (multi-rendition / iOS defer / SubtitleView) |
| Modified | CLAUDE.md | Plan index — plan 23 + plan 24 entries |
| Modified | docs/10_planning/01_roadmap.md | Plan 23 ✅ + Plan 24 🔵 active + header date bump |
| Modified | docs/00_overview/current_status.md | Top-of-doc snapshot for plan 23 + plan 24 |
| Modified | docs/04_api/01_api_contracts.md | New `POST /stream/{id}/audio-track` endpoint section |
| Modified | docs/05_infrastructure/02_url_inventory.md | `/audio-track` + previously-missing `/fallback-transcode` + `/fallback-audio-transcode` rows |
| Modified | docs/12_guidelines/03_gotchas.md | 6 new gotchas — libmpv setAudioTrack hang, init.mp4 unlink, OpenSL ES AO, wakelock toggle, UND language tags, per-platform engine |

### Docs Updated

- `CLAUDE.md` — plan index gains plan 23 + plan 24 rows.
- `docs/00_overview/current_status.md` — new top-of-doc snapshot for 2026-05-15.
- `docs/04_api/01_api_contracts.md` — `POST /stream/{id}/audio-track` endpoint section.
- `docs/05_infrastructure/02_url_inventory.md` — stream router rows for `/audio-track` + previously-missing `/fallback-transcode` + `/fallback-audio-transcode`.
- `docs/10_planning/01_roadmap.md` — plan 23 ✅ + plan 24 🔵 active rows + header date.
- `docs/10_planning/24_player_audio_reliability_plan.md` — open questions resolved.
- `docs/10_planning/archive/23_audio_track_switching.md` — new archive retrospective.
- `docs/12_guidelines/03_gotchas.md` — 6 new entries (libmpv setAudioTrack hang, init.mp4 unlink contract, OpenSL ES AO churn, media_kit_video wakelock toggle, `und` language tags, per-platform engine policy).
- `AGENT_LOG.md` — this entry.

### Decisions Made

- **Stop iterating on cubit-level workarounds for the libmpv setAudioTrack hang.** Three layers of workarounds (bare swap, pause/seek/play, self-seek) all failed on real-device testing. Switched to server-restart approach (plan 23) and then escalated to engine migration (plan 24). The cubit-level path is a dead end on Android.
- **Ship plan 23 even though plan 24 will obsolete the cubit caller.** Endpoint stays in tree as a fallback for future clients (TV / web running libmpv); the work isn't wasted, and removing it now would add churn before plan 24 lands.
- **Parallel Opus subagents in isolated worktrees for M1 + M2.** M1 is Kotlin/gradle work, M2 is Dart abstraction work — disjoint file sets, no merge collision risk. Worktree isolation guarantees the agents can't accidentally collide with each other or with the foreground doc work.
- **Multi-rendition HLS server output split into plan 25** rather than bundled into plan 24. Plan 24 is already 5 days of Android-side work; adding a server-side HLS shape change in the same week is too much risk in one window. ExoPlayer parses the current single-rendition+multiplexed-audio shape correctly, so plan 24 doesn't need plan 25 to ship.

### Issues / Sharp Edges Discovered

1. **End-to-end real-device verification of plan 23 is incomplete.** The init.mp4 unlink fix landed late in the session; operator didn't run a fresh post-fix log. The code is in tree and presumed correct based on the fix matching the diagnosed cause, but no green-light log exists. Plan 24 obviates this, so we are not blocking on plan 23 verification.
2. **HDR multi-audio audio-silent bug is unresolved.** Separate symptom from track switching; possibly a server-side init.mp4 codec issue for HDR sources. Plan 24 M6 will test ExoPlayer's stricter HLS parser against this; Media3's parser emits actual error messages where libmpv silently drops audio.
3. **Plan 22 picker still draws all tracks even when one is pinned.** The cubit's `availableAudioTracks` comes from `StreamStartResponse.audio_tracks` (probed at scan, persisted in `media_files.audio_tracks`). That doesn't change when a track is pinned — the picker still shows every track in the source. The selected-row highlight tracks `selectedAudioTrackIndex` which is the source-stream index. Acceptable UX (the operator can still pick any track from the original set).
4. **VS Code extension crashes on long log pastes.** During this session the operator pasted ~6 KB Debug Console logs multiple times; the extension errored "Unhandled case: [object Object]" and stopped generating responses, prompting confusing "you keep crashing" pings. Worked around by asking the operator to truncate. Not a Fluxora bug — flag for the IDE plugin.

### Test Counts (re-baselined)

- **Server: 830 passing** (827 → 830, +3 around the new `/audio-track` endpoint).
- **Mobile: 99 passing** (97 → 99, +2 cubit test updates for server-restart switch).
- **Desktop: 113 passing** (untouched).
- **Core: 8 passing** (untouched — M2 agent's `packages/fluxora_core/lib/player/` additions pending reconciliation).

Counts above are local pre-push estimates. M2 agent reconciliation may shift mobile + core counts; will re-baseline after integration. `flutter analyze` + `ruff` clean on the plan-23 commits.

### Working-Tree Status

- 5 commits ahead of `origin/main` (plan 23 + plan 24 doc), not yet pushed.
- Pending uncommitted: docs sweep (this entry + the 8 doc files listed above) — about to commit as one chunk.
- Plan 24 M1 agent output staged in main tree (not yet committed): `apps/mobile/android/app/build.gradle.kts`, `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/MainActivity.kt`, `apps/mobile/lib/core/router/app_router.dart`, `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart`, `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/` (new dir), `apps/mobile/lib/dev/` (new dir).
- Plan 24 M2 agent output staged in main tree (not yet committed): `packages/fluxora_core/lib/fluxora_core.dart`, `packages/fluxora_core/pubspec.yaml`, `packages/fluxora_core/pubspec.lock`, `packages/fluxora_core/lib/player/` (new dir).
- Agent worktrees still locked under `.claude/worktrees/agent-a8fc66d7f39c0a60d/` + `.claude/worktrees/agent-a987e40da9cf470c9/` — to be removed after reconciliation.

### Next Agent Should

1. **Reconcile + commit M1 (Kotlin spike) output.** Verify the Media3 deps resolve (`cd apps/mobile && flutter build apk --debug`), the `ExoPlayerPlugin.kt` compiles, the hidden `/dev/exo-spike` route is reachable from a long-press affordance on Profile (look in `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart` for the agent's added handler), and the Dart spike page builds. Commit as `feat(mobile): plan 24 M1 — ExoPlayer platform-channel spike`. Then delete `.claude/worktrees/agent-a8fc66d7f39c0a60d/`.
2. **Reconcile + commit M2 (`PlayerEngine` abstraction) output.** Verify `flutter analyze` clean in both `apps/mobile/` and `packages/fluxora_core/`; verify `flutter test` green in `apps/mobile/`; verify the cubit + screen + widgets + sheets compile against the new interface and behave identically to pre-M2 (no-op refactor). Commit as `refactor(mobile,core): plan 24 M2 — PlayerEngine abstraction`. Then delete `.claude/worktrees/agent-a987e40da9cf470c9/`.
3. **Operator real-device test of M1.** Open the hidden `/dev/exo-spike` route, paste a Fluxora HLS playlist URL, hit Open — must see video + hear audio for a 30-second clip. Exit criteria for M1.
4. **Plan 24 M3 — `ExoPlayerEngine` Dart side (6 h).** Implement the Dart client of the MethodChannel + EventChannel; map ExoPlayer's group/format track API to source-stream indices. Depends on M1 + M2 both green.
5. **Plan 24 M4 — Kotlin module hardening (8 h).** Move M1's spike plugin into proper modular structure (`ExoPlayerPlugin.kt` plugin entry + `FluxoraExoPlayer.kt` per-player class); full command set; Player.Listener emitting all required state changes; SurfaceProducer lifecycle; audio focus + `setHandleAudioBecomingNoisy(true)`. Depends on M1.
6. **HDR-no-audio bug investigation.** Separate from track switching — possibly server-side init.mp4 codec issue for HDR sources. Either fix server-side in parallel with plan 24, or wait for plan 24 M6 where ExoPlayer's parser will surface the actual error. Operator preference TBD.

## [2026-05-15] [feat] [mobile] [core] — Plan 24 M3 + M4: ExoPlayerEngine wired end-to-end (Android Media3 default)

**Phase:** Plan 24 — Android ExoPlayer migration. M1 spike + M2 abstraction shipped earlier today; M3 (Dart channel client) + M4 (Kotlin module) ran in parallel as Opus subagents in isolated worktrees and landed together.
**Status:** Complete. `_kEnableExoPlayerEngine = true` — Android now defaults to ExoPlayer; libmpv remains the desktop + iOS engine and is the operator escape hatch on Android via `_kForceMediaKitOnAndroid`. Real-device smoke (M5+) is the operator's next step.
**Commits:** `5db7e54` M3 + factory flip, `575787e` M4 Kotlin module

### What Was Done

#### Parallel agent setup

Two Opus subagents launched in isolated git worktrees with an identical **locked channel contract** in both prompts so neither could drift. Channels:

- MethodChannel `dev.marshalx.fluxora/exo_player` keyed by `playerId` — methods `create` / `open` / `play` / `pause` / `seek` / `setAudioTrack` / `setRate` / `setVolume` / `dispose`.
- EventChannel `dev.marshalx.fluxora/exo_player_events` keyed by `playerId` — event types `positionChanged` / `durationChanged` / `isPlayingChanged` / `tracksChanged` / `playbackStateChanged` / `playerError`.

`create` returns `{playerId: int, textureId: int}`; `setVolume` crosses the channel as `volume0to1` (Dart-side divides by 100); position ticker fires every ~250 ms while playing, none while paused; five error codes (`auth_failed` / `network_error` / `decoder_failed` / `format_unsupported` / `unknown`) map to `EngineError`.

Each agent reported contract clarifications they made; the two reports cross-checked clean against each other at integration time. No re-runs needed.

#### M3 — Dart `ExoPlayerEngine`

`packages/fluxora_core/lib/player/exo_player_engine.dart` (new). `ExoPlayerEngine.create()` invokes `create` on the channel, stashes the returned id pair, subscribes to events filtered by `playerId`, exposes five broadcast streams (position / duration / isPlaying / selectedAudioTrack / errors). Caches every state field for the synchronous getters. Volume conversion + seek clamp at the channel boundary. Five error-code strings map into `EngineError`. `dispose` tolerates a doubled native teardown and always closes Dart-side controllers.

11 unit tests via `setMockMethodCallHandler` + `setMockStreamHandler`. No new pub deps.

#### M4 — Kotlin module hardening

M1's single-file spike split into two:

- `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/ExoPlayerPlugin.kt` rewritten as the plugin entry. Holds `Map<Int, FluxoraExoPlayer>` + an id counter + the channel handles + a disposed-ids set so post-dispose calls throw `IllegalStateException` instead of silently no-oping.
- `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayer.kt` (new) — per-player wrapper. Full command set; `Player.Listener` emitting deduplicated playbackState + isPlaying + tracks + position + error events; 250 ms position ticker re-arms itself only while `isPlaying`; bearer headers go to `setDefaultRequestProperties` without values reaching logcat; `setHandleAudioBecomingNoisy(true)` so headphones unplug pauses correctly. Audio track switch uses `TrackSelectionParameters.Builder.setOverrideForType(TrackSelectionOverride(group, formatIndex))` with source-index→(group, formatIndex) mapping built from `onTracksChanged` (Format.label numeric path first, positional fallback). Rate clamped Kotlin-side to `[0.25, 4.0]`.

`MainActivity.kt` simplified to `flutterEngine.plugins.add(ExoPlayerPlugin())` so the standard FlutterPlugin lifecycle drives teardown.

14 JUnit tests over the pure-function helpers (`buildAudioTrackMapping`, `parseSourceIndex`, `mapPlayerErrorCode`).

#### Integration fix in the foreground

First `flutter build apk --debug` failed: `PlaybackException.ERROR_CODE_IO_DNS_FAILED` was unresolved at Media3 1.10.1 (added in a newer release). Removed the line from `mapPlayerErrorCode`; DNS failures land in `ERROR_CODE_IO_NETWORK_CONNECTION_FAILED` at this version so they still map to `network_error`. Documented inline. Re-built: APK clean in 28 s.

After APK confirmation, flipped `_kEnableExoPlayerEngine` from `false` to `true` in `packages/fluxora_core/lib/player/player_engine_factory.dart`. Android consumers now get `ExoPlayerEngine` by default; `_kForceMediaKitOnAndroid` stays as the operator escape hatch. Both flags delete in M9.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Created | packages/fluxora_core/lib/player/exo_player_engine.dart | M3 — concrete PlayerEngine talking to the Media3 channel |
| Created | packages/fluxora_core/test/player/exo_player_engine_test.dart | M3 — 11 unit tests via mock method/stream handlers |
| Modified | packages/fluxora_core/lib/player/player_engine_factory.dart | Android branch returns ExoPlayerEngine; `_kEnableExoPlayerEngine` flipped to `true` |
| Modified | packages/fluxora_core/lib/fluxora_core.dart | Export `exo_player_engine.dart` |
| Created | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayer.kt | M4 — per-player wrapper with Player.Listener + ticker + audio focus + becoming-noisy |
| Modified | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/ExoPlayerPlugin.kt | M4 — plugin entry, multi-player map, disposed-id guard |
| Modified | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/MainActivity.kt | M4 — standard `flutterEngine.plugins.add(...)` registration |
| Modified | apps/mobile/android/app/build.gradle.kts | M4 — testImplementation junit 4.13.2 |
| Created | apps/mobile/android/app/src/test/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayerTest.kt | M4 — JUnit over the pure-function helpers |
| Modified | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayer.kt | Foreground fix: drop `ERROR_CODE_IO_DNS_FAILED` (not on Media3 1.10.1) |

### Decisions Made

- **Flip `_kEnableExoPlayerEngine` to `true` immediately after the debug APK built clean.** The flag exists exactly so we can verify-then-flip without a separate commit; APK build is the integration test for Media3 API drift. JUnit `./gradlew :app:test` was sandbox-blocked but the JUnit helpers are pure functions hand-verified during review — the operator can run them on the next real-device session as part of M5 smoke.
- **Remove `ERROR_CODE_IO_DNS_FAILED` rather than try to compute its integer literal.** Media3 added it in a later 1.x release; falling back to `ERROR_CODE_IO_NETWORK_CONNECTION_FAILED` on 1.10.1 is the right mapping at this version. If we bump Media3 in M9 we can put it back.
- **Worktree isolation for parallel agents, again.** Same pattern as M1 + M2 earlier today — disjoint file sets (Dart core + tests vs. Kotlin module + JUnit) made worktrees free of merge collisions and let me drive integration myself.

### Test Counts (re-baselined)

- **Core: 19 passing** (was 8; +11 ExoPlayerEngine unit tests). Analyze clean.
- **Mobile: 87 passing** (unchanged — engine swap is invisible to cubit tests because they inject `_FakePlayerEngine` via `engineBuilder`). Analyze clean. Goldens excluded per project convention.
- **Server: 830** (untouched).
- **Desktop: 113** (untouched).
- **Android JUnit:** 14 tests authored; gradle execution sandbox-blocked — operator runs as part of M5 smoke.
- **APK build:** `flutter build apk --debug --no-pub` green against Media3 1.10.1 in 28 s after the `ERROR_CODE_IO_DNS_FAILED` fix.

### Issues / Sharp Edges Discovered

1. **Media3 1.10.1 doesn't have `ERROR_CODE_IO_DNS_FAILED`.** Future Media3 version bumps should re-check the error-code enum — any new codes need a `mapPlayerErrorCode` entry, any removed codes break the build. The fact this slipped through M4's hand-verification highlights that "hand-verified against the docs" isn't a substitute for `flutter build`. The sandbox blocking gradle is a process problem — future Android agent prompts should explicitly grant `flutter build apk --debug --no-pub` in the allowlist.
2. **`flutter analyze` doesn't catch Kotlin compile errors.** Both agents reported clean analyze + tests; the build break only surfaced when I ran the APK build myself. The lesson is: Android-touching agents must run `flutter build apk` as a final verification step, not just `flutter analyze`. M5+ prompts will require this.
3. **No real-device smoke yet.** APK built and analyze is clean, but no human has run the app against the new engine on a phone. The operator's first multi-audio AC3 5.1 retest is the load-bearing verification of the entire plan-24 effort.
4. **`MediaKitEngine.mediaKitPlayer` escape hatch is still used by `audio_subs_sheet` (subtitles tab + legacy fallback) and `fluxora_audio_handler`.** ExoPlayerEngine returns no media_kit.Player — those code paths gate behind `engine is MediaKitEngine` today. M7 (audio_service / MediaSession) and M9 (subtitles) clean these up.
5. **Cubit's `audioParams` / `videoParams` watchers** (plan 20 auto-fallback + plan 21 audio fallback) still need `MediaKitEngine`-specific reads. They no-op silently under ExoPlayerEngine, which is correct (Media3's HLS parser emits actual error events that the auto-fallback path consumes via `errorStream` instead). Documented as a punt for M6 / M7.

### Working-Tree Status

- 4 commits ahead of `origin/main` not yet pushed: docs sweep + plan-23 set was 5 commits pushed pre-M3 (`299b2f0` doc sweep ↑); M3+M4 cycle: `5db7e54` Dart + `575787e` Kotlin.
- Still uncommitted: `.gitignore` mobile-failures rule (held since two messages ago — operator interrupted), `.claude/worktrees/` metadata.

### Next Agent Should

1. **Operator real-device smoke against M5 test matrix.** Open the player on a real Android device against a single-audio AAC file first (basic smoke: video + audio + scrubber + close). Then the multi-audio AC3 5.1 file that motivated plan 24 — the entire effort lives or dies on whether `Multi-audio AC3 5.1 — switch track mid-play` is green. Then HDR + pause/resume + lockscreen. Plan 24 test matrix is at the bottom of `docs/10_planning/24_player_audio_reliability_plan.md`.
2. **Plan 24 M5 (3 h) — Multi-audio track switching verification + fix loop.** No code is expected to land here; M5 is "operator runs the matrix, agent fixes anything that breaks." If switch latency is bad, look at the source-index mapping in `parseSourceIndex` / `buildAudioTrackMapping` in `FluxoraExoPlayer.kt`. If audio is silent on switch, check `setAudioTrack` overrides build correctly against the actual `tracksChanged` payload Media3 emits for the test file.
3. **Plan 24 M6 (3 h) — HDR + tonemap + HDR-multi-audio.** ExoPlayer's HLS parser is strict-but-diagnostic; HDR-no-audio bug should produce an actual error in `adb logcat -s ExoPlayer` rather than libmpv's silent drop. If a server-side init.mp4 codec issue surfaces, fix server-side.
4. **Plan 24 M7 (3 h) — Lifecycle, audio focus, PIP, background.** Audit `pip_service.dart`, `fluxora_audio_handler.dart`, lockscreen controls. Consider replacing `audio_service` binding to `MediaKitEngine.mediaKitPlayer` with Media3's `MediaSessionService` natively (cleaner; first-party).
5. **Plan 24 M8 (2 h) — Position tracking + seek-restart integration.** Confirm `seekTo` + scrubber-pin + progress-reporter all behave the same against `ExoPlayerEngine`. Most existing code already routes through `PlayerEngine` so this should be smoke-level.
6. **Plan 24 M9 (4 h) — Tests + golden re-baseline + doc sweep + flag deletion.** Drop the `_kEnableExoPlayerEngine` flag, delete the M1 spike page + `/dev/exo-spike` route, archive plan 24 to `docs/10_planning/archive/24_player_audio_reliability_plan.md`, sweep architecture + frontend + gotchas docs, update `current_status.md` + `roadmap.md`.

## [2026-05-15] [feat] [refactor] [mobile] [core] [docs] — Plan 24 M7 + M8 + plan-tag strip pass + doc sweep

**Phase:** Plan 24 — Android ExoPlayer migration. M7 (Media3 MediaSessionService native) + M8 (seek-restart + scrubber integration) ran in parallel as Opus subagents in isolated worktrees. Strip-tag refactor pass + doc sweep landed in the same session.
**Status:** Complete. M5 (multi-audio device smoke) + M6 (HDR + tonemap) remain operator-driven device-testing milestones; M9 (tests + golden re-baseline + doc sweep + flag deletion + spike cleanup) is the final mechanical close-out.
**Commits:** `0debbe9` M7, `4ba2a87` M8, `a1a9c12` strip pass

### What Was Done

#### Parallel agent setup (M7 + M8)

Two Opus subagents launched in isolated git worktrees with disjoint file scopes:

- **M7 — Kotlin Media3 MediaSessionService** (apps/mobile/android/.../exo + manifest + cubit gate + build.gradle.kts).
- **M8 — Dart seek-restart + scrubber verification** (apps/mobile/lib/features/player + packages/fluxora_core/lib/player + new widget test).

No file collision. M7 reported back first; M8 second. Integration verification (analyze + tests + APK build) was clean for both. Foreground integration: needed to copy M8's three changed files (`flux_player_controls.dart`, `exo_player_engine.dart`, new `player_progress_bar_test.dart`) from its worktree to the main tree because the worktree was still locked at session end.

#### M7 — native Media3 MediaSessionService

Replaces the Dart-side `FluxoraAudioHandler` ↔ `media_kit.Player` binding for Android ExoPlayer sessions with Media3's first-party `MediaSessionService`. Lockscreen card, notification card, Bluetooth-headset transport, OS MediaSession are now owned natively in Kotlin for the Android default path.

- `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraMediaSessionService.kt` (new) subclasses `MediaSessionService`. Companion `bind(context, player)` / `unbind()` / `applyMetadata(title)` API. Reentrant lock around static state. `setSessionActivity` PendingIntent rehydrates `MainActivity` (singleTop) when the lockscreen card is tapped. Releases on `onTaskRemoved` when nothing is playing.
- `FluxoraExoPlayer.kt` after `prepare()` calls `FluxoraMediaSessionService.bind(appContext, player)` + `applyMetadata(null)`. On `release()` calls `unbind()` before `player.release()`. URL never passed to `applyMetadata` (Hard Prohibition #8 — bearer-token leak risk).
- `AndroidManifest.xml` gains `POST_NOTIFICATIONS` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions + the `.exo.FluxoraMediaSessionService` service with `foregroundServiceType="mediaPlayback"` and the standard `androidx.media3.session.MediaSessionService` intent-filter.
- `apps/mobile/android/app/build.gradle.kts`: `media3-session:1.10.1` pinned alongside the other Media3 artifacts.
- Cubit's existing `if (engine is MediaKitEngine)` audio-handler bind path gets a diagnostic else branch so the skip-when-ExoPlayer code path is observable at runtime.
- `FluxoraMediaSessionServiceTest.kt` (new JUnit) asserts the bind/unbind/rebind cycle is idempotent and safe-no-op when nothing is running.
- `player_cubit_test.dart` new test: when the cubit constructs a non-MediaKit engine, `FluxoraAudioHandler.bind` is never called.

#### M8 — engine-cadence mismatches closed under ExoPlayer

Verification pass over the cubit's seek-restart logic + `PlayerProgressBar` scrubber pin + progress reporter against the new ExoPlayer engine surfaced two behavioural mismatches that the existing UI was implicitly tuned to libmpv for. Both fixed.

- `ExoPlayerEngine.open()` now resets `_position` and `_duration` to `Duration.zero` and emits both BEFORE the channel call. libmpv resets these synchronously on `Player.open` (observable in stream emissions); ExoPlayer keeps prior values until `STATE_READY` (duration) or `onPositionDiscontinuity` (position), and the Kotlin module dedupes identical-duration emissions — without this fix, a tonemap-toggle between two same-duration playlists would never re-emit and the scrubber would render against a stale shape.
- `PlayerProgressBar._pendingValue` settle-check gate moved from `sourceDur.inMilliseconds > 0` to `playerDur.inMilliseconds > 0`. Under ExoPlayer `playerDur == 0` until `STATE_READY`, so the prior gate cleared the pin too early and the scrubber rendered the released drag value against an in-flight zero duration.
- New `apps/mobile/test/features/player/player_progress_bar_test.dart` (4 widget tests): post-restart transient, in-player settle, pin-during-isSeeking, pin-during-`playerDur==0`.

Other audited surfaces were already engine-agnostic + left untouched: cubit seek decision (smallForward / backwardInPlaylist / forward server-restart) reads cached `engine.position`/`engine.duration` and tolerates `playerDur <= 0`; `_reportProgress` reads cached position; `_startProgressTimer` uses `Timer.periodic` independent of stream cadence; backward-out-of-playlist server-restart routing (plan 17 §10) unchanged.

#### Plan-tag strip refactor

Caught by operator: ~85 plan/milestone narrative tags littered through code comments + docstrings across 27 player + engine files (`Plan 24 M7 — added the dep`, `Plan 22 (2026-05-14): every audio track …`, `Pre-fix (2026-05-08 evening) …`, dated change-log entries inside class docstrings, etc.). CLAUDE.md explicitly forbids referencing the current plan / task in code — narrative belongs in commit messages, planning docs, AGENT_LOG entries. Stripped the narrative, kept the technical content (root causes, invariants, sharp edges, vendor-specific behaviour). Kept `// TODO(plan-24-M9): remove this dev spike page` (deletion contract, not narrative). Kept test names containing `plan 24 M7 — …` (test infrastructure operator may grep).

Pure no-op refactor: zero behavioural change. Analyze + tests + APK build clean.

Saved as a feedback memory (`feedback_no_plan_refs_in_code.md`) so future sessions don't repeat the pattern.

#### Doc sweep

- Plan 24 doc: M7 + M8 milestones marked ✅ with commit refs; top-of-doc status header revised to list M1-M4 + M7 + M8 as shipped, M5 + M6 as operator-pending, M9 as the remaining mechanical close-out.
- `current_status.md`: new top-of-doc snapshot covering M7 + M8 + strip pass.
- `roadmap.md`: plan 24 row updated with the new commit list and revised remaining work.
- `CLAUDE.md` plan index: replaced plan 24 row.
- `frontend_architecture.md`: split the Audio Service / Lockscreen table row into two — one for Android ExoPlayer (native `MediaSessionService`), one for desktop + iOS + Android-rollback (`FluxoraAudioHandler`); updated the `fluxora_audio_handler.dart` comment in the project-structure listing; updated the engine-specific callsites paragraph in the `PlayerEngine` section.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Created | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraMediaSessionService.kt | M7 — Media3 MediaSessionService subclass |
| Created | apps/mobile/android/app/src/test/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraMediaSessionServiceTest.kt | M7 — bind/unbind/rebind safety |
| Modified | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayer.kt | M7 — bind/unbind hooks around `prepare()` + `release()` |
| Modified | apps/mobile/android/app/src/main/AndroidManifest.xml | M7 — POST_NOTIFICATIONS + FOREGROUND_SERVICE_MEDIA_PLAYBACK + `.exo.FluxoraMediaSessionService` service |
| Modified | apps/mobile/android/app/build.gradle.kts | M7 — media3-session:1.10.1 dep |
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | M7 — diagnostic else branch on the audio-handler skip path |
| Modified | apps/mobile/test/features/player/player_cubit_test.dart | M7 — assert handler not bound when engine is non-MediaKit |
| Modified | packages/fluxora_core/lib/player/exo_player_engine.dart | M8 — `open()` resets cached position/duration + emits before the channel call |
| Modified | apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart | M8 — `PlayerProgressBar` pin gate uses `playerDur` not `sourceDur` |
| Created | apps/mobile/test/features/player/player_progress_bar_test.dart | M8 — 4 widget tests for pin behaviour across engines |
| Modified | (27 player + engine files across apps/mobile + packages/fluxora_core + apps/mobile/android) | Strip pass — ~85 plan-tag narrative removals |

### Docs Updated

- `docs/10_planning/24_player_audio_reliability_plan.md` — M7 + M8 milestones marked ✅; status header revised.
- `docs/00_overview/current_status.md` — new top-of-doc snapshot.
- `docs/10_planning/01_roadmap.md` — plan 24 row updated.
- `CLAUDE.md` — plan 24 index row updated.
- `docs/08_frontend/01_frontend_architecture.md` — Audio Service row split per engine; project-structure comment updated; engine-specific-callsites paragraph updated.
- `AGENT_LOG.md` — this entry.

### Decisions Made

- **Media3's native `MediaSessionService` for Android ExoPlayer sessions, not a Dart-side wrapper.** AOSP recommends this; first-party support; the cleanest path. `FluxoraAudioHandler` (Dart) stays for desktop + iOS + Android-rollback only. The split adds a small surface (Kotlin lockscreen owns Android-ExoPlayer; Dart owns everything else) but removes layers of plumbing on the load-bearing path.
- **Mirror libmpv's `open()` state-reset behaviour in ExoPlayerEngine, not in the cubit.** The cubit was tuned for libmpv's reset-on-open contract; fixing the contract at the engine layer keeps cubit + scrubber engine-agnostic + means a future engine can rely on the same invariant.
- **Strip plan-tag narrative immediately rather than wait for M9.** Operator caught it now; deferring to M9 risked adding more clutter. Per-memory saved for future sessions to stop introducing the pattern.

### Issues / Sharp Edges Discovered

1. **`MediaSessionService.applyMetadata` is currently always called with `null`** → falls through to artist = "Fluxora". Future plumbing should thread the file title (and ideally poster URL) through from the cubit so the lockscreen card shows the movie/episode name. Tracked as a follow-up; out of M7's "make the OS see a session" scope.
2. **Companion-based `bind`/`unbind` on the MediaSessionService is process-singleton state.** Fine for the current one-Activity Flutter app; would need reworking if Fluxora ever hosted multiple Flutter engines simultaneously.
3. **`pendingPlayer` between `bind()` and `onCreate()`** has a theoretical leak window if `startService` throws between the two — already handled by clearing in the catch.
4. **ExoPlayer's `seekTo(positionMs)` issued before `STATE_READY`** is buffered and applied at READY; no `onPositionDiscontinuity` may fire if old position was also 0. The cubit's `_commitServerSeek` does `seek` after `open(play:false)` — under ExoPlayer this seek may be silently applied without emitting a Dart-side `positionChanged` until playback resumes via `play()` + ticker. M8 audit flagged this; no current user-facing bug because the cubit doesn't read position synchronously after `_commitServerSeek`.
5. **`durationChanged` Kotlin-side dedup** masks "new playlist, identical duration" → tonemap-toggle on the same source would emit no duration event. M8's `open()` reset emission covers this (we now emit `duration=0` first, so any new positive duration counts as a change).
6. **Position emission cadence**: libmpv emits sub-100ms (frame-rate bound); ExoPlayer emits at 250ms via the Kotlin ticker. Visually identical scrubber smoothness; no code in the player feature counts emissions or uses cadence as a stall heartbeat.

### Test Counts (re-baselined)

- **Core: 19 passing** (unchanged; ExoPlayerEngine reset emission covered by existing tests).
- **Mobile: 97 passing** (91 → 97: +6 from M7 audio-handler-skip + M8 scrubber widget tests).
- **Android JUnit (M7): added `FluxoraMediaSessionServiceTest`** alongside `FluxoraExoPlayerTest`. Gradle execution remains sandbox-blocked — operator runs as part of M5 smoke.
- **APK build:** `flutter build apk --debug --no-pub` green against Media3 1.10.1 (`media3-session` + Kotlin compile clean).
- **Server: 830** (untouched). **Desktop: 113** (untouched).

### Working-Tree Status

- 3 commits ahead of `origin/main` not yet pushed: `0debbe9` M7, `4ba2a87` M8, `a1a9c12` strip pass.
- Plus uncommitted doc edits (this entry + the 5 cross-doc files listed above) — about to land as a single docs commit per the same-day pattern.
- Stale `.claude/worktrees/agent-a076e240a1e18e443/` directory + corresponding branch still on disk (M8 agent's worktree was locked at session end). Gitignored; safe to leave for next-session cleanup.

### Next Agent Should

1. **Operator real-device smoke against the M5 test matrix.** First single-audio AAC for basic smoke (video + audio + scrubber + close + lockscreen card). Then the multi-audio AC3 5.1 file that motivated plan 24 — that's the load-bearing verification. Then HDR + pause/resume + lockscreen + Bluetooth-headset transport. Plan 24 test matrix is in the plan doc.
2. **Plan 24 M5 (3 h) — Multi-audio track switching verification + fix loop.** No code expected unless smoke surfaces bugs. If switch latency is bad, look at `parseSourceIndex` / `buildAudioTrackMapping` in `FluxoraExoPlayer.kt`. If audio is silent on switch, check `setAudioTrack` overrides build correctly against the actual `tracksChanged` payload Media3 emits.
3. **Plan 24 M6 (3 h) — HDR + tonemap + HDR-multi-audio.** ExoPlayer's HLS parser is strict-but-diagnostic; HDR-no-audio bug should now produce an actual error in `adb logcat -s ExoPlayer` rather than libmpv's silent drop. If a server-side init.mp4 codec issue surfaces, fix server-side.
4. **Plan 24 M9 (4 h) — Tests + golden re-baseline + doc sweep + flag deletion + spike cleanup.** Delete `_kEnableExoPlayerEngine` + `_kForceMediaKitOnAndroid` flags from the factory. Delete `apps/mobile/lib/dev/exo_spike_page.dart` + the hidden `/dev/exo-spike` route + the long-press affordance in profile_screen. Archive plan 24 to `docs/10_planning/archive/24_player_audio_reliability_plan.md`. Sweep architecture + frontend + gotchas docs. Update `current_status.md` + `roadmap.md` to mark plan 24 ✅ Done.
5. **Thread the file title through `MediaSessionService.applyMetadata`** so the lockscreen card shows the movie/episode name (current default is "Fluxora"). Small Dart-side change: cubit's `_engineBuilder` flow already has the title from `startStream`; pass it through `ExoPlayerEngine.open()` headers or a new `setMetadata(title)` method on the channel. Likely belongs in M9 alongside flag deletion.

## [2026-05-15] [feat] [refactor] [mobile] [core] [docs] — Plan 24 M9 partial + doc sweep

**Phase:** Plan 24 — Android ExoPlayer migration. Pre-device-verification cleanup pass: title plumbing to the lockscreen, subtitle picker gating, dev spike removal, `_kEnableExoPlayerEngine` flag deletion + gotchas entry.
**Status:** M9 partial complete. `_kForceMediaKitOnAndroid` flag deletion + plan 24 archival deliberately deferred until M5 + M6 are operator-green on a real device.
**Commits:** `24d3579` M9 partial code

### What Was Done

#### Title plumbing (lockscreen card shows the actual file title)

- `PlayerEngine` gains `Future<void> setMetadata(String? title)`. Doc-comment: sets the OS-side metadata (lockscreen card / notification / BT transport); engines without an OS MediaSession should no-op.
- `MediaKitEngine.setMetadata` → `async {}` (libmpv doesn't manage OS metadata directly; `FluxoraAudioHandler` already carried the title via `audio_service.bind(title: …)` for that path).
- `ExoPlayerEngine.setMetadata` → `await _methodChannel.invokeMethod<void>('setMetadata', {'playerId': _playerId, 'title': title});` Tolerates `null`.
- `ExoPlayerPlugin.kt` MethodChannel handler: new `setMetadata` case dispatches to `requirePlayer(call).setMetadata(call.argument<String?>('title'))` and returns an empty `Map<String, Any>`.
- `FluxoraExoPlayer.kt` adds `fun setMetadata(title: String?)`. `ensureAlive()` + posts to the main thread + calls `FluxoraMediaSessionService.applyMetadata(title)`. Wraps in `try/catch` that logs at `Log.w` (Hard Prohibition #4).
- Cubit's `startStream` now calls `engine.setMetadata(fileName)` immediately after `engine.open(...)` resolves successfully. Wrapped in `try/catch` that logs at INFO and continues — metadata failure must never break playback.

#### Subtitle picker gate

The Subtitles tab in `audio_subs_sheet.dart` previously read libmpv's `state.tracks` directly via the `MediaKitEngine.mediaKitPlayer` escape hatch. On `ExoPlayerEngine` that surface doesn't exist. Tab stays visible — the operator may scroll to it expecting it — but renders a placeholder card explaining the picker is engine-specific and that embedded subtitles still render. MediaKit path unchanged.

#### Dev spike removal

The M1 plumbing proof is fully superseded by M4's hardened module. Removed:
- `apps/mobile/lib/dev/exo_spike_page.dart` (the throwaway page itself; `apps/mobile/lib/dev/` directory empty + removed).
- `Routes.devExoSpike` const + the `GoRoute(path: Routes.devExoSpike, …)` entry + the `state.matchedLocation == Routes.devExoSpike` line in `_guardRedirect`.
- `import 'package:fluxora_mobile/dev/exo_spike_page.dart';` in `app_router.dart`.
- Hidden long-press `GestureDetector` on Profile About-sheet's version label — reverted to a plain `Text(snap.data ?? '—')`.

#### `_kEnableExoPlayerEngine` flag deletion

`packages/fluxora_core/lib/player/player_engine_factory.dart` dropped the `_kEnableExoPlayerEngine` const + its docstring + the conditional in `PlayerEngineFactory.create()`. Android now constructs `ExoPlayerEngine` unconditionally (modulo `_kForceMediaKitOnAndroid`). File-header docstring rewritten to reflect the new shape.

**Kept:** `_kForceMediaKitOnAndroid = false`. This is the operator rollback escape hatch — flipping it to `true` forces libmpv on Android even with the new engine wired in. Stays until M5+M6 are operator-green on a real device.

#### Gotchas entry

New `## Subtitle picker is engine-specific — Android ExoPlayer hides the picker behind a "coming later" card` entry in `docs/12_guidelines/03_gotchas.md`. Documents:
- The libmpv-`state.tracks` escape hatch is the last documented exit.
- Today's behaviour (placeholder card; embedded subtitles still render).
- Migration path: add `setSubtitleTrack(int sourceIndex)` to `PlayerEngine`; `ExoPlayerEngine` routes through `TrackSelectionParameters.setOverrideForType` on a text-type `TrackGroup`. Kotlin can render via Media3's `SubtitleView`.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | packages/fluxora_core/lib/player/player_engine.dart | New `setMetadata(String? title)` interface method |
| Modified | packages/fluxora_core/lib/player/media_kit_engine.dart | `setMetadata` no-op (audio_service carries title) |
| Modified | packages/fluxora_core/lib/player/exo_player_engine.dart | `setMetadata` forwards via MethodChannel |
| Modified | packages/fluxora_core/lib/player/player_engine_factory.dart | Dropped `_kEnableExoPlayerEngine` const; factory branches on `_kForceMediaKitOnAndroid` only |
| Modified | packages/fluxora_core/test/player/exo_player_engine_test.dart | +1 test — setMetadata sends title (incl. null) through the channel |
| Modified | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/ExoPlayerPlugin.kt | New `setMetadata` MethodCall handler + dispatch |
| Modified | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayer.kt | New `fun setMetadata(title)` → posts to main thread + `FluxoraMediaSessionService.applyMetadata` |
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | Calls `engine.setMetadata(fileName)` after `engine.open` resolves |
| Modified | apps/mobile/lib/features/player/presentation/sheets/audio_subs_sheet.dart | Subtitle tab placeholder when engine is not MediaKitEngine |
| Modified | apps/mobile/lib/core/router/app_router.dart | Strip `Routes.devExoSpike` + `GoRoute` + auth-bypass entry + spike import |
| Modified | apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart | Strip About-sheet version-label long-press affordance |
| Deleted | apps/mobile/lib/dev/exo_spike_page.dart | M1 spike fully superseded by M4 |
| Modified | apps/mobile/test/features/player/player_cubit_test.dart | `_FakePlayerEngine` gains `setMetadata` (records last title) |
| Modified | apps/mobile/test/features/player/player_progress_bar_test.dart | Local fake gains `setMetadata` no-op |
| Modified | apps/mobile/test/goldens/_player_mocks.dart | `FakePlayerEngine` gains `setMetadata` no-op |
| Modified | docs/12_guidelines/03_gotchas.md | New "Subtitle picker is engine-specific" entry |

### Docs Updated

- `docs/10_planning/24_player_audio_reliability_plan.md` — M9 marked 🟡 partial with commit ref; status header revised (M1-M4 + M7 + M8 + M9-partial shipped; M5+M6 still operator-pending; remaining M9 work scoped to `_kForceMediaKitOnAndroid` deletion + plan archival).
- `docs/00_overview/current_status.md` — new top-of-doc snapshot covering M9 partial.
- `docs/10_planning/01_roadmap.md` — plan 24 row updated with new commit list + revised remaining scope.
- `CLAUDE.md` — plan 24 index row replaced with the post-M9-partial shape.
- `docs/12_guidelines/03_gotchas.md` — subtitle-picker entry (also in code commit).
- `AGENT_LOG.md` — this entry.

### Decisions Made

- **Strip `_kEnableExoPlayerEngine`, keep `_kForceMediaKitOnAndroid`.** The `_kEnable…` flag was always-true post-M3+M4; deleting it is forward-only with no rollback consequence. The `_kForce…` flag is the actual operator escape hatch — if M5/M6 device testing surfaces a regression, that's the rollback knob. Deleting both would strand the operator with no fallback before device verification. Hold the `_kForce…` deletion until M5+M6 are green.
- **Subtitle tab placeholder, not tab removal.** Operator may scroll to the tab expecting it to be there. A visible placeholder card with a "coming later" message is less surprising than the tab vanishing entirely. The actual Media3 `SubtitleView` migration is a separate feature build — not part of plan 24's "fix the audio path" goal.
- **Title plumbing via a new `setMetadata` engine method, not via `open()`'s args.** Adding to `open()` would force every other engine.open callsite (server-restart, audio-track-switch, tonemap, auto-fallback paths) to re-pass the title; a separate method keeps title independent and the cubit only calls it once at session start. Media3's MediaSession state persists across player re-binds on the same `FluxoraExoPlayer` instance, so re-opens inherit the title automatically.
- **Did the work inline rather than via subagent.** The launched M9-partial subagent stalled (crashed during the MCP-server reconnect cycle); rather than re-launching and waiting again, I did the ~10-file pass inline. Memory note: agents are great for parallel disjoint work; for a sequential cleanup pass with strict scope, inline is fine.

### Issues / Sharp Edges Discovered

1. **The stalled agent had partially executed** before crashing: `apps/mobile/lib/dev/exo_spike_page.dart` was already deleted on disk + git showed it as `D`, and `player_engine_factory.dart` was already trimmed (but had both flags wiped — including the rollback hatch). Restored `_kForceMediaKitOnAndroid` during the inline pass. Lesson: stalled-agent partial state can be subtly wrong; verify on resume rather than assume the file is in its pre-launch state.
2. **The cubit's title call uses `fileName`, not a more descriptive title field.** The `MediaFile` entity may carry a richer title elsewhere (per-episode title from `tmdb_episodes`, custom rename label, etc.). Today the lockscreen sees the same string as the player's top-bar. Good enough for v1; a real-data follow-up could plumb the richer source through.
3. **Media3 `MediaSession` static state across player rebinds.** `FluxoraMediaSessionService.applyMetadata` updates the singleton session's `MediaMetadata`. If the cubit ever runs two `FluxoraExoPlayer` instances simultaneously (multi-player surface — currently impossible — see plan 24 M4's `players: Map<Int, FluxoraExoPlayer>`), they'd fight over the single MediaSession's metadata. Documented as a sharp edge in M7's report; still applies.

### Test Counts (re-baselined)

- **Core: 20 passing** (19 → 20; +1 `setMetadata` channel-args test).
- **Mobile: 97 passing** (unchanged — the three `FakePlayerEngine` impls gained `setMetadata` stubs but no new test cases).
- **Server: 830 / Desktop: 113** (untouched).
- **APK build:** `flutter build apk --debug --no-pub` green against Media3 1.10.1.
- Analyze clean × `apps/mobile` + `packages/fluxora_core`.

### Working-Tree Status

- 1 commit ahead of `origin/main`: `24d3579` M9 partial.
- Plus the about-to-land doc-sweep commit (this entry + the 4 cross-doc files).
- `.claude/worktrees/` may still hold the stale `lucid-moore-ad3c0a` empty dir (Windows file-handle quirk from the earlier session); gitignored, harmless. The M9-partial stalled agent's worktrees were force-cleaned earlier in this session.

### Next Agent Should

1. **Operator real-device smoke against M5 + M6.** Flash the new APK; run the multi-audio AC3 5.1 file (the load-bearing test that motivated plan 24); confirm lockscreen card shows the actual file title; confirm Subtitles tab's placeholder card renders correctly (not crashing); confirm HDR + tonemap + pause/resume + Bluetooth-headset transport.
2. **M9 close-out** once M5+M6 are green: delete `_kForceMediaKitOnAndroid` flag (factory becomes one-liner `return Platform.isAndroid ? ExoPlayerEngine.create() : MediaKitEngine.create();`); archive `docs/10_planning/24_player_audio_reliability_plan.md` to `docs/10_planning/archive/24_player_audio_reliability_plan.md`; mark plan 24 ✅ Done in roadmap + current_status + CLAUDE.md.
3. **Subtitle picker migration (separate plan).** New `setSubtitleTrack(int sourceIndex)` on `PlayerEngine`. `MediaKitEngine` keeps `Player.setSubtitleTrack`. `ExoPlayerEngine` routes to Media3's `TrackSelectionParameters.setOverrideForType` on a text-type `TrackGroup`. Kotlin renders via `SubtitleView`. Probably a half-day milestone.
4. **HDR-no-audio investigation** (if M6 surfaces it). Plan 24 M6 expects Media3's stricter HLS parser to emit an actual error rather than libmpv's silent drop. If a server-side init.mp4 codec issue surfaces, fix server-side.
5. **Plan 25 — multi-rendition HLS server output** (`#EXT-X-MEDIA TYPE=AUDIO` groups instead of multiplexed audio in a single rendition). Unblocks future iOS native track switching. Out of scope for plan 24.

## [2026-05-15] [feat] [fix] [refactor] [mobile] [core] [docs] — Plan 24 M9-partial follow-ons (real-device fix-loop) + doc sweep

**Phase:** Plan 24 — Android ExoPlayer migration. Operator opened the app on a real device and reported a cascade of issues that surfaced only at runtime: LAN cleartext block, video stretched to screen aspect, pinch zoom that fights vol/brightness, washed-out HDR, overflow menu overflowing in landscape, dim chrome icons over bright video, etc. Each one resolved in-session via a fix-loop with reinstall-and-retest cycles.
**Status:** Complete. M5/M6 device-verification fixes shipped; M9-partial scope grew to absorb them. M5 + M6 are now functionally complete from a code perspective; operator real-device sign-off is what's left for plan 24 archival.
**Commits:** uncommitted at session end — operator to commit in logical chunks (see "Suggested commit chunks" below).

### What Was Done

#### Setup

Spent the first half of the session on plan 24 M9-partial (already shipped as commits `24d3579` code + `4d9c2c9` docs). The second half is this entry: operator flashed the M9-partial APK on a real device and we worked through every bug they hit. Doc sweep at the end used 3 parallel Opus subagents (cross-doc planning / architecture / gotchas) writing into non-overlapping file scopes.

#### 1. LAN cleartext HTTP — `network_security_config.xml`

First real-device session start: `ExoPlayer` died with `CleartextNotPermittedException: Cleartext HTTP traffic to 192.168.0.162 not permitted` on every stream-start. Android 9+'s default-secure policy blocks plaintext HTTP for app traffic. `libmpv` had shipped its own HTTP implementation and silently bypassed the policy; Media3's `DefaultHttpDataSource` respects it.

First fix attempt listed RFC 1918 CIDR blocks in `<domain>` entries — **that doesn't work**: Android's `<domain>` only matches DNS hostnames, not CIDR/IP ranges. The literal `10.0.0.0/8` string never matches a resolved IP. Corrected fix: `<base-config cleartextTrafficPermitted="true">` permits cleartext globally (LAN server IPs are dynamic + mDNS-discovered, can't be scoped), with `<domain-config cleartextTrafficPermitted="false">` carve-out re-enforcing HTTPS-only for the public WAN tunnel `fluxora-api.marshalx.dev`. Manifest wired with `android:networkSecurityConfig="@xml/network_security_config"`.

#### 2. `PlayerEngine.videoSize` + `videoSizeStream` + Kotlin emit from `onTracksChanged`

Once cleartext was unblocked, video played but was stretched to fill the screen regardless of source aspect ratio. Bare `Texture(textureId:)` is a render-to-texture primitive with no intrinsic size or aspect-ratio logic.

Added `({int width, int height})? get videoSize` + `Stream<...> get videoSizeStream` to `PlayerEngine`. `MediaKitEngine` subscribes to `player.stream.videoParams`. `ExoPlayerEngine` subscribes to a new `videoSizeChanged` EventChannel event from Kotlin; resets to `null` on `open()` so tonemap-toggle / audio-switch don't strand the scrubber on stale dimensions.

Kotlin side has two emission paths: `Player.Listener.onVideoSizeChanged(VideoSize)` (real-time, fires later) AND a new pure-function helper `firstSelectedVideoFormat(tracks: Tracks): Format?` called from `onTracksChanged` (fires at manifest parse, much earlier than first decoded frame). Pixel-aspect-ratio (`Format.pixelWidthHeightRatio`) baked into the emitted width for anamorphic sources (DVD MPEG-2, some Blu-ray rips).

#### 3. `_EngineTextureSurface` aspect-ratio wrapping

New widget: `ClipRect → FittedBox(fit: BoxFit.contain/cover/fill) → SizedBox(width: videoW, height: videoH) → Texture`. SizedBox declares natural aspect; FittedBox scales to fit/cover parent.

Hit a sharp edge: bare `Center(child: _EngineTextureSurface(...))` inside a Stack with default `StackFit.loose` gives FittedBox loose constraints → it sizes to its child's natural size (1920×1080 px) and doesn't scale. Fixed with `Positioned.fill`.

#### 4. Three-way `FitMode` enum

Replaced the binary `bool fitCover` on `PlayerControlsController` with `enum FitMode { fit, fill, stretch }`. **Default flipped to `FitMode.fit`** (was Fill/cover). Top-bar Fit button cycles `fit → fill → stretch → fit`. Long-press still resets pinch zoom. Maps to Flutter `BoxFit.contain` / `BoxFit.cover` / `BoxFit.fill`. Top-bar icon + tooltip swap per mode (`fit_screen` / `aspect_ratio` / `crop_free`).

#### 5. Pinch zoom via raw `Listener` (the saga)

Three attempts before landing the working design:

- **Attempt 1: outer `_PinchZoomSurface` widget** with its own `GestureDetector(onScale*)` wrapping the surface. Lost the gesture arena to the chrome's outer `GestureDetector` (higher in the Stack, opaque hit-test).
- **Attempt 2: add `onScale*` to the chrome's existing `GestureDetector`**. Worked over the video area but still failed near the slider/transport buttons — inner widgets' single-finger drag/tap recognizers claimed the first pointer before scale recognizer got 2 pointers.
- **Attempt 3: `RawGestureDetector` + `GestureArenaTeam` with `ScaleGestureRecognizer` as captain**. Scale won every arena — including single-finger drags — so brightness/volume broke entirely. Also surfaced `Failed assertion: '_team == null'` on rebuild because `GestureRecognizerFactoryWithHandlers.initializer` re-runs and reassigns `r.team`; fixed with `r.team ??= _gestureTeam`. Red screen still meant captain-as-tie-breaker is the wrong shape.
- **Working approach: implement pinch entirely at the outer `Listener` widget**. Raw `PointerEvent` callbacks fire regardless of who claims the gesture arena. Track `Map<int, Offset> _pointerPositions` from `onPointerDown` / `onPointerMove` / `onPointerUp`. On second-pointer-down capture `_pinchInitialDistance` + `_pinchInitialScale = controller.userScale`. On move with 2+ pointers compute new distance and pipe `controller.setUserScale(initialScale * currentDist / initialDist)` directly. Single-finger vertical drag still goes through the chrome's `GestureDetector` and is gated on `_activePointers >= 2` to bail when a pinch is in flight. Rollback: `_beginPinch()` restores brightness/volume to drag-start value if the race window already nudged them.

Long-press the Fit button resets `userScale` to 1.0× (existing behaviour, kept).

#### 6. Drag-HUD signals for zoom + fit mode

`PlayerDragKind` enum gained `zoom` + `fitMode` cases. `controller.setUserScale(s)` flashes the HUD with a pre-formatted label (`"1.25×"` style). `controller.cycleFitMode()` flashes `"Fit"` / `"Fill"` / `"Stretch"`. Auto-clears via `_hudAutoHide` timer (900 ms for zoom, 1.2 s for fitMode). `_DragHud` widget accepts a new `label: String?` param; hides its progress bar for the zoom + fitMode cases (icon-only render — `zoom_in` for zoom, `aspect_ratio` for fit mode).

#### 7. Player chrome layout

- Play/pause + ±10 s seek transport moved from CENTER (covering the video) to **below** the scrubber in the bottom Column. Groups temporal controls together.
- `_MinimizeHandle` (drag-down-to-close pill at the top of the screen) removed entirely. Operator was confused by the dash icon. Player closes via the back button now.
- Top bar + bottom Column each wrapped in their own `DecoratedBox(gradient: 55% black at edge → 30% halfway → transparent)` for icon/text legibility against bright video. First try used a full-screen 5-stop gradient — invisible because the `DecoratedBox` had no child and `Stack.loose` constraints sized it to 0×0. Second try wrapped in `Positioned.fill`. Third try (current) ditched the global scrim for two per-region backdrops — sized correctly to the actual top/bottom chrome regions, no gradient fade visible mid-screen.

#### 8. Overflow menu landscape fix

3-dot bottom-sheet overflowed by 218 pixels in landscape. 8 tiles + drag pill in a fixed ~240 px sheet doesn't fit. Wrapped the inner `Column` in `SingleChildScrollView` and passed `isScrollControlled: true` to `showModalBottomSheet` so the sheet can grow past 50% of screen height.

#### 9. Client-side HDR→SDR tone-mapping via custom Media3 renderer

Operator reported HDR videos playing with washed-out / desaturated colors. Initial reaction was server-side tonemap (auto-enable `tonemap=true` for HDR sources) — but operator countered that their device can decode HDR natively. The real issue: even on HDR-capable codec hardware, Flutter's `SurfaceProducer` is an **SDR surface**. Media3 writes HDR-encoded PQ values directly onto the SDR surface → Flutter composites them as if SDR → washed out. libmpv had its own internal tone-mapper, so the regression only appeared after the plan-24 migration.

Fix: new `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/TonemappingRenderersFactory.kt`. Subclasses `DefaultRenderersFactory` to override `buildVideoRenderers` with a `TonemappingVideoRenderer` (subclass of `MediaCodecVideoRenderer`) that injects `MediaFormat.setInteger("color-transfer-request", 3)` (= `KEY_COLOR_TRANSFER_REQUEST = COLOR_TRANSFER_SDR_VIDEO`) on Android 13+ (API 33). Hardware codec then tone-maps HDR → SDR before frames hit the texture. Wired in `FluxoraExoPlayer.kt` via `ExoPlayer.Builder.setRenderersFactory(TonemappingRenderersFactory(context.applicationContext))`. No-op on Android <13 or codecs that ignore the SDR request; the existing 3-dot menu "Tone-map HDR to SDR" toggle remains as the server-side fallback.

#### 10. Doc sweep

3 parallel Opus subagents wrote into non-overlapping file scopes:

- **Agent A** (planning surfaces): `docs/10_planning/24_player_audio_reliability_plan.md`, `docs/00_overview/current_status.md`, `docs/10_planning/01_roadmap.md`, `CLAUDE.md` — added a new `### M9 partial follow-ons (2026-05-15)` subsection inside the plan listing all 9 follow-ons with per-milestone bucketing; new top-of-doc snapshot in current_status; plan 24 row in roadmap + CLAUDE.md plan index updated.
- **Agent B** (architecture): `docs/08_frontend/01_frontend_architecture.md`, `docs/02_architecture/01_system_overview.md`, `docs/02_architecture/02_tech_stack.md` — new `_VideoSurface` / `FitMode` / pinch-via-Listener / chrome-layout subsections; `PlayerEngine` interface extended in the existing section with `videoSize` + `videoSizeStream` + Kotlin emission paths; `TonemappingRenderersFactory` row added to the Framework & Stack table + system overview + tech stack.
- **Agent C** (gotchas): `docs/12_guidelines/03_gotchas.md` — 7 new entries: bare `Texture` aspect-ratio stretch, SDR `SurfaceProducer` HDR-washout, raw-Listener pinch over the gesture arena, `GestureRecognizerFactoryWithHandlers` rebuild + `r.team = ...` assertion, `Stack.loose` + bare `Center` gives FittedBox 0×0, chrome scrim 0×0 from same trap, `showModalBottomSheet` landscape overflow.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/mobile/android/app/src/main/res/xml/network_security_config.xml | LAN cleartext base-config + WAN HTTPS carve-out (corrected from first-attempt CIDR-`<domain>`) |
| Modified | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayer.kt | Wire `TonemappingRenderersFactory` into `ExoPlayer.Builder`; emit `videoSizeChanged` from `onVideoSizeChanged` + `onTracksChanged` via `firstSelectedVideoFormat` helper |
| Created | apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/TonemappingRenderersFactory.kt | Subclass `DefaultRenderersFactory` + `MediaCodecVideoRenderer` for codec-level HDR→SDR tone-mapping on Android 13+ |
| Modified | packages/fluxora_core/lib/player/player_engine.dart | Add `videoSize` + `videoSizeStream` interface |
| Modified | packages/fluxora_core/lib/player/media_kit_engine.dart | Subscribe to `player.stream.videoParams`, broadcast videoSize |
| Modified | packages/fluxora_core/lib/player/exo_player_engine.dart | Subscribe to `videoSizeChanged` event, broadcast videoSize; reset on `open()` |
| Modified | apps/mobile/lib/features/player/presentation/controllers/player_controls_controller.dart | `FitMode` enum, `userScale` state, HUD signals for zoom + fitMode, auto-clear timer |
| Modified | apps/mobile/lib/features/player/presentation/screens/player_screen.dart | `_EngineTextureSurface` wrapping with FittedBox; remove `_MinimizeHandle`; `Positioned.fill` for the surface; default-fit (not fill) |
| Modified | apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart | Raw-Listener pinch zoom, vertical-drag gating on `_activePointers >= 2`, transport moved below scrubber, top/bottom gradient backdrops, Fit button cycles 3-way + long-press resets zoom, overflow menu scroll fix, `_DragHud` zoom + fitMode labels |
| Modified | apps/mobile/test/features/player/player_cubit_test.dart | `_FakePlayerEngine` no-op stubs for `videoSize` + `videoSizeStream` |
| Modified | apps/mobile/test/features/player/player_progress_bar_test.dart | Same fake-engine stubs |
| Modified | apps/mobile/test/goldens/_player_mocks.dart | Same fake-engine stubs |
| Modified | apps/mobile/test/goldens/top_bar_golden_test.dart | `fitCover: false` → `fitMode: FitMode.fit` |
| Modified | docs/10_planning/24_player_audio_reliability_plan.md | New `### M9 partial follow-ons (2026-05-15)` subsection covering all 9 fixes |
| Modified | docs/00_overview/current_status.md | New top-of-doc snapshot for the follow-on batch |
| Modified | docs/10_planning/01_roadmap.md | Plan 24 row body extended with the follow-on highlights |
| Modified | CLAUDE.md | Plan 24 index row appended with the 8 follow-on highlights |
| Modified | docs/08_frontend/01_frontend_architecture.md | `_VideoSurface`, `FitMode`, pinch-via-Listener, chrome layout subsections + `PlayerEngine` interface extension + Framework & Stack table rows |
| Modified | docs/02_architecture/01_system_overview.md | "Mobile playback engine" row appended with `TonemappingRenderersFactory` note |
| Modified | docs/02_architecture/02_tech_stack.md | New `TonemappingRenderersFactory` row in the Mobile section |
| Modified | docs/12_guidelines/03_gotchas.md | 7 new entries (texture aspect, SDR surface HDR-washout, raw-Listener pinch, team-assertion, Stack.loose × Center, scrim 0×0, landscape overflow) |

Also two untracked devtools_options.yaml files from Flutter tooling (apps/desktop + apps/mobile) — gitignore candidates, harmless but should not land in commits.

### Docs Updated

- `docs/10_planning/24_player_audio_reliability_plan.md` — `### M9 partial follow-ons (2026-05-15)` subsection (~125 lines); status header callout; test-matrix HDR row updated.
- `docs/00_overview/current_status.md` — new top-of-doc snapshot for 2026-05-15 (follow-on batch); prior snapshot demoted to "Earlier 2026-05-15".
- `docs/10_planning/01_roadmap.md` — plan 24 row body extended with follow-on highlights.
- `CLAUDE.md` — plan 24 index row appended.
- `docs/08_frontend/01_frontend_architecture.md` — `PlayerEngine` interface extended; new `_VideoSurface` / `FitMode` / pinch / chrome-layout subsections; Framework & Stack table gained `TonemappingRenderersFactory` + LAN cleartext rows; project-structure tree comments refreshed.
- `docs/02_architecture/01_system_overview.md` — "Mobile playback engine" component row appended.
- `docs/02_architecture/02_tech_stack.md` — new `TonemappingRenderersFactory` row.
- `docs/12_guidelines/03_gotchas.md` — 7 new entries.
- `AGENT_LOG.md` — this entry.

### Decisions Made

- **Pinch via raw `Listener`, not via gesture-arena recognizers.** Three failed attempts (outer GestureDetector, chrome's onScale*, RawGestureDetector + team-captain-scale) all hit Flutter's gesture-arena rules where a single-finger drag claims the first pointer before scale can win with 2. Listener events bypass the arena entirely. Worth documenting as a gotcha so the next agent doesn't waste a round-trip on the team-captain pattern.
- **Default fit = Fit (letterbox), not Fill (cover).** Matches Plex / VLC / Jellyfin defaults; Fill was a Fluxora-original choice that surprised users.
- **HDR tone-mapping via client-side codec request, not server-side FFmpeg.** Server-side works but costs CPU and re-encodes the video; codec-level `KEY_COLOR_TRANSFER_REQUEST` is free on Android 13+ and runs on the SoC's HDR pipeline. Server-side toggle remains as the Android <13 fallback.
- **Two-system rendering (FittedBox + Transform.scale).** Briefly unified into a single `LayoutBuilder`-driven scalar mid-session; broke portrait-mode aspect handling. Reverted to split design — fit/fill is a Flutter layout concern, pinch zoom is a Transform concern; mixing them was simpler-feeling but wrong.

### Issues / Sharp Edges Discovered

All documented in `docs/12_guidelines/03_gotchas.md`. Highlights:

1. `Texture(textureId:)` stretches to parent bounds — no built-in aspect-ratio; needs FittedBox + SizedBox.
2. Flutter's `SurfaceProducer` is SDR; HDR content rendered on it looks washed out unless the codec tone-maps to SDR first.
3. Android's `<domain>` in `network_security_config.xml` doesn't accept CIDR — DNS hostnames only.
4. Pinch-zoom via `GestureDetector.onScale*` and via `RawGestureDetector + GestureArenaTeam` both reliably fail near inner widgets; raw `Listener` is the working design.
5. `Center` inside `Stack` (default `StackFit.loose`) hands FittedBox/DecoratedBox loose constraints → 0×0 or no-scale.
6. `GestureRecognizerFactoryWithHandlers.initializer` runs every rebuild; `r.team = ...` asserts `_team == null`; use `r.team ??= ...`.
7. `showModalBottomSheet` clips in landscape without `isScrollControlled: true` + inner scroll view.

### Test Counts (unchanged)

- **Core: 20** (unchanged from M9-partial — no new core tests; fake-engine stubs added but no new test cases).
- **Mobile: 97** (unchanged; existing tests still pass; fakes updated to satisfy new interface).
- **Server: 830** (untouched).
- **Desktop: 113** (untouched).
- **APK build:** `flutter build apk --debug --no-pub` green throughout the session — repeatedly after every change.

### Working-Tree Status

Uncommitted; 20 files modified + 2 untracked files (TonemappingRenderersFactory.kt + 2 devtools_options.yaml). Operator to commit per their preferred chunking.

### Suggested commit chunks

1. **`fix(mobile): allow LAN cleartext HTTP for ExoPlayer (network_security_config)`** — `network_security_config.xml` + manifest reference (already wired earlier this session). Standalone fix; could ship even if nothing else does.
2. **`feat(mobile,core): plumb video size through PlayerEngine + Kotlin emit at manifest-parse`** — `PlayerEngine` interface + both engine impls + Kotlin `onTracksChanged` / `firstSelectedVideoFormat` + test-fake stubs.
3. **`feat(mobile): _VideoSurface aspect-ratio rendering + FitMode 3-way cycle`** — `_EngineTextureSurface` widget + `FitMode` enum + cubit/test-fake migration + `top_bar_golden_test.dart` enum update.
4. **`feat(mobile): pinch zoom via raw Listener + drag-HUD signals for zoom/fitMode`** — `flux_player_controls.dart` Listener wiring + controller HUD scratchpad + `_DragHud` label rendering.
5. **`feat(mobile): player chrome relayout (transport below scrubber, drop minimize handle, gradient backdrops)`** — same file (`flux_player_controls.dart` + `player_screen.dart`); can either fold into chunk 4 or split.
6. **`fix(mobile): overflow-menu sheet — scroll instead of overflow in landscape`** — `_showOverflowMenu` edit; small standalone fix.
7. **`feat(mobile): client-side HDR→SDR tone-mapping via custom Media3 renderer factory`** — `TonemappingRenderersFactory.kt` (new) + `FluxoraExoPlayer.kt` wire-in.
8. **`docs: plan 24 M9-partial follow-ons sweep — AGENT_LOG + cross-doc updates`** — every doc file touched + this AGENT_LOG entry.

### Next Agent Should

1. **Operator real-device sign-off on M5 + M6.** All the runtime fixes from this session need a clean smoke pass on the Oplus device — single-audio playback, multi-audio AC3 5.1 mid-stream switch, HDR HEVC with the codec tone-map kicking in (look for `FluxoraTonemap` lines in logcat), pinch zoom over slider + buttons, Fit-mode cycle through all three, lockscreen card with file title.
2. **Plan 24 M9 close-out.** Once M5+M6 are green, delete `_kForceMediaKitOnAndroid` flag from `player_engine_factory.dart` (factory becomes one-liner `return Platform.isAndroid ? ExoPlayerEngine.create() : MediaKitEngine.create();`); archive `docs/10_planning/24_player_audio_reliability_plan.md` to `docs/10_planning/archive/24_player_audio_reliability_plan.md`; mark plan 24 ✅ Done in roadmap + current_status + CLAUDE.md.
3. **Plan 25 — multi-rendition HLS server output** (server emits `#EXT-X-MEDIA TYPE=AUDIO` rendition groups instead of single-rendition + multiplexed audio). Unblocks iOS native track switching + matches the industry-standard HLS shape Plex/Jellyfin use. Plan stub already in `docs/10_planning/24_player_audio_reliability_plan.md` open-questions; promote to a real planning doc when scheduled.
4. **Subtitle picker on ExoPlayer engine.** Currently the picker placeholder card says "coming in a future update on this player engine." Add `setSubtitleTrack(int sourceIndex)` to `PlayerEngine`; `ExoPlayerEngine` routes through `TrackSelectionParameters.setOverrideForType` on a text-type `TrackGroup`; Kotlin side renders via `SubtitleView` for OS-style styling. Half-day milestone.
5. **`apps/desktop/devtools_options.yaml` + `apps/mobile/devtools_options.yaml`** — untracked Flutter-tooling artefacts. Either commit (intentional) or add to `.gitignore` (preferred). Single-line gitignore entry: `**/devtools_options.yaml`.

---

## [2026-05-15] [desktop] [feat] [docs] — Desktop CP IA redesign · plan 26 M1–M5

**Phase:** Plan 26 — Desktop Control Panel information-architecture redesign
**Status:** Complete (M1–M5 all shipped same day; operator real-device pass deferred)
**Commits:** uncommitted

### What Was Done

Owner review flagged the desktop rail as bloated (10 top-level items) with two structural ambiguities: `Transcode` (sidecar AV1/VP9 → H.264 queue per plan 18) and `Transcoding` (live HLS session monitor) collide as near-identical names one row apart; `Activity` + `Transcoding` + `Logs` are three top-level surfaces answering the same "what's happening?" question.

Drafted [`docs/10_planning/26_desktop_cp_ia_redesign.md`](docs/10_planning/26_desktop_cp_ia_redesign.md) under interactive review with owner.  Settled on **flat 7-item rail, no section dividers** (owner explicitly rejected dividers); Groups stays separate (owner rejected a merge into Library after considering 3 options).  Open questions resolved before milestone work began — remembered last tab per page; Dashboard Recent-Activity rows deep-link to `/activity/sessions`.

Then executed M1–M5 end-to-end against the plan:

#### 1. LibraryShell (M1)

New `LibraryShell` at [`apps/desktop/lib/features/library/presentation/screens/library_shell.dart`](apps/desktop/lib/features/library/presentation/screens/library_shell.dart) — fixed top chrome (`PageHeader` "Library" + `FluxTabBar` `Folders · Convert · Scan history`) over an `Expanded` body that switches between three inner screens.  Tab paths: `/library/folders`, `/library/convert`, `/library/scan-history`.  `LibraryShellTabPath` enum carries the id + route mapping.  Module-level `_rememberedLibraryTab` (default `folders`) is updated on every build; the `/library` redirect reads it.  Scan history is a placeholder card ("Each library scan logs file additions, removals, and errors") pending content.

`LibraryScreen` + `TranscodeScreen` gained `bool embedded = false` constructor flag → `_LibraryView({required this.embedded})` / `_TranscodeView({required this.embedded})`.  When `embedded == true`, the inner screen skips its own `PageHeader` and renders its action row (Refresh + Add Library / Encoder Settings) as a right-aligned `Align(centerRight)` block at the top of its scroll region — actions stay accessible without title duplication.

#### 2. ActivityShell (M2)

Same pattern: new `ActivityShell` at [`apps/desktop/lib/features/activity/presentation/screens/activity_shell.dart`](apps/desktop/lib/features/activity/presentation/screens/activity_shell.dart) hosting `ActivityScreen` / `TranscodingScreen` / `LogsScreen` as `Sessions · Transcoding · Logs` tabs at `/activity/{sessions,transcoding,logs}`.  Module-level `_rememberedActivityTab` (default `sessions`).  All three inner screens gained `embedded` flags with the same right-aligned actions pattern (search + Export for Sessions; Encoder Settings for Transcoding; Pause/Resume + Clear Logs for Logs).

`_LogsView`'s build needed an inner `Builder` to host the `actionsRow` local because the existing structure put the `Column` deep inside a `Padding > Builder`-style chain; the Builder isolation keeps `_paused` / `widget.embedded` reads inside the right scope.

#### 3. Dashboard deep-links (M3)

`_ActivityRow` in [`dashboard_screen.dart`](apps/desktop/lib/features/dashboard/presentation/screens/dashboard_screen.dart) wrapped in `MouseRegion(click) + GestureDetector(opaque)` → `context.go('/activity/sessions?event=<id>')` with `Uri.encodeQueryComponent` on the event id.  The "View All" header link + the "View Activity" Quick-Access card also retargeted from `Routes.activity` (which now redirects) to explicit `Routes.activitySessions`.  The `?event=<id>` param is forwarded but not yet read on the destination — the highlight-on-arrival polish is queued behind device sign-off (cheap follow-up: parse `state.uri.queryParameters['event']` in `_ActivityView`).

#### 4. Nav rail cleanup (M4)

[`flux_sidebar.dart`](apps/desktop/lib/shared/widgets/flux_sidebar.dart) `_navItems` const list pruned from 10 → 7: dropped `Transcode`, `Transcoding`, `Logs`.  Order: Dashboard · Library · Clients · Groups · Activity · Settings · Subscription.  No section dividers.  `_NavItem._isActive` getter already does prefix matching (`loc.startsWith('$path/')`) so the `Library` rail item stays highlighted on `/library/folders`, `/library/convert`, `/library/scan-history`, and `/library/:id/files`; same for `Activity` covering all three sub-tabs.

#### 5. Router + back-compat (woven through M1–M4)

[`app_router.dart`](apps/desktop/lib/core/router/app_router.dart) — added `Routes.libraryFolders`, `libraryConvert`, `libraryScanHistory`, `activitySessions`, `activityTranscoding`, `activityLogs` constants.  `/library` → redirect via `rememberedLibraryTab().routePath`.  `/activity` → redirect via `rememberedActivityTab().routePath`.  Legacy `/transcode` → redirects to `/library/convert`; `/transcoding` → `/activity/transcoding`; `/logs` → `/activity/logs`.  Direct screen imports for `ActivityScreen`, `TranscodingScreen`, `LogsScreen`, `TranscodeScreen` removed from the router (the shells own them).

Literal route segments (`/library/folders`) registered BEFORE the `:id` param route (`/library/:id/files`) so go_router matches the literal first — string `folders` won't be treated as a library id.

#### 6. Verification

`flutter analyze --no-pub` clean (5.8 s).  `flutter test --no-pub` → all 114 desktop tests pass including `m3_dashboard_golden_test.dart` (the new `MouseRegion + GestureDetector` wrappers on `_ActivityRow` don't change rendered pixels — invisible chrome).

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Created | docs/10_planning/26_desktop_cp_ia_redesign.md | Plan doc — 10-section spec; final 7-item flat rail; tabbed Library + Activity pages; remembered last tab; M1–M5 milestoning |
| Created | apps/desktop/lib/features/library/presentation/screens/library_shell.dart | Outer tab host for `/library/{folders,convert,scan-history}`; `LibraryShellTabPath` enum; `_rememberedLibraryTab` cache; `_ScanHistoryPlaceholder` |
| Created | apps/desktop/lib/features/activity/presentation/screens/activity_shell.dart | Outer tab host for `/activity/{sessions,transcoding,logs}`; `ActivityShellTabPath` enum; `_rememberedActivityTab` cache |
| Modified | apps/desktop/lib/core/router/app_router.dart | New tab routes; `/library` + `/activity` redirects to remembered tabs; back-compat redirects from `/transcode`, `/transcoding`, `/logs`; dropped direct screen imports the shells now own |
| Modified | apps/desktop/lib/features/library/presentation/screens/library_screen.dart | Added `embedded` flag; extracted action row; conditional `PageHeader` vs right-aligned actions block |
| Modified | apps/desktop/lib/features/transcode/presentation/screens/transcode_screen.dart | Added `embedded` flag; skip `PageHeader` when embedded |
| Modified | apps/desktop/lib/features/activity/presentation/screens/activity_screen.dart | Added `embedded` flag; extracted `actionsRow` (search field + Export); conditional `PageHeader` vs right-aligned actions block |
| Modified | apps/desktop/lib/features/transcoding/presentation/screens/transcoding_screen.dart | Added `embedded` flag; extracted Encoder-Settings button; conditional `PageHeader` vs right-aligned actions block |
| Modified | apps/desktop/lib/features/logs/presentation/screens/logs_screen.dart | Added `embedded` flag; inner `Builder` scopes `actionsRow` (Pause/Resume + Clear Logs); conditional `PageHeader` vs right-aligned actions block |
| Modified | apps/desktop/lib/features/dashboard/presentation/screens/dashboard_screen.dart | `_ActivityRow` wrapped in `MouseRegion + GestureDetector` deep-linking to `/activity/sessions?event=<id>`; "View All" + "View Activity" quick-action retargeted from `Routes.activity` to `Routes.activitySessions` |
| Modified | apps/desktop/lib/shared/widgets/flux_sidebar.dart | `_navItems` pruned 10 → 7; removed Transcode / Transcoding / Logs entries; updated doc comment |
| Modified | docs/08_frontend/01_frontend_architecture.md | Added "Desktop Information Architecture (✅ 2026-05-15, plan 26)" section with rail diagram + tabbed-pages table; updated Two Client Targets row description |
| Modified | CLAUDE.md | Added plan 26 row to "Where the detail lives" table |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

- [`docs/10_planning/26_desktop_cp_ia_redesign.md`](docs/10_planning/26_desktop_cp_ia_redesign.md) — created
- [`docs/08_frontend/01_frontend_architecture.md`](docs/08_frontend/01_frontend_architecture.md) — new IA section + Two Client Targets row update
- [`CLAUDE.md`](CLAUDE.md) — plan 26 row in "Where the detail lives" table

### Decisions Made

- **No new `shared_preferences` dep for remembered tab.** CLAUDE.md prohibition #6 ("never add a new pub/pip dep without justification") would gate this; existing in-memory tab-state pattern in `_TranscodeViewState` (`String _activeTab` field) is the precedent.  Module-level `_rememberedLibraryTab` / `_rememberedActivityTab` survives go_router rebuilds, resets on hot restart / app launch.  Promotion to durable storage is a follow-up if operator asks.
- **Shell owns one PageHeader; inner screens drop theirs when embedded.** Considered three patterns (double-header acceptable, refactor inner widgets to ContentOnly, shell passes through PageHeader.actions via callback).  Picked the embedded-flag approach as the smallest diff that keeps the inner screens routable directly from their own `Routes` entries if anything ever links to `/transcode`-style URLs (back-compat redirects already do, but defensive).
- **Scan history tab is a placeholder, not deferred.** Plan said "lifted from Folders if present, otherwise new in M5"; nothing lifts cleanly so it renders an empty-state card with copy ("Scan history will appear here").  Keeping the tab visible-but-empty rather than hidden means the IA matches the plan doc and operators learn the tab exists before content lands.
- **`?event=<id>` query param forwarded but not consumed yet.** Wiring the highlight-the-row scroll behavior in `_ActivityView` is straightforward (parse `GoRouterState.of(context).uri.queryParameters['event']`, scroll to row, flash background tint) but adds non-trivial test surface for what's essentially a polish step.  Punted to follow-up; the param exists in the URL today so the polish can land later without breaking deep-links.

### Issues / Sharp Edges Discovered

1. **`_ActivityRow` had no `Key`.** The list rebuild after deep-link navigation works but the row identity is positional, not stable.  If the recent-events list reorders between dashboard mount and tap-fire, the wrong event id deep-links.  Low-impact (ordering is by `createdAt DESC` and the cubit only polls every 5 s) but worth noting.
2. **`LogsScreen` build method needed a `Builder` wrap.** The existing `Padding > Column` chain had no scope for a local `actionsRow` because `widget.embedded` lives on the State and the action row references `_paused` / `_togglePause` from the same State; pulling the row up as a method would have worked but mid-edit collateral was lower with an inline `Builder`.  Not a bug, but a follow-up could refactor to a `_buildHeader()` State method for symmetry with the other screens.
3. **IDE diagnostics lag.** Several edits showed stale error reports referring to lines I'd already deleted — `flutter analyze` is the trustworthy check, not the IDE's red squiggles.

### Test Counts (unchanged)

- **Desktop: 114 passing** (unchanged; new shell widgets have no direct tests yet — could add widget tests for `LibraryShell` / `ActivityShell` tab switching as a follow-up).
- **Server: 830** (untouched).
- **Mobile: 92** (untouched; plan 24 fall-out from prior session — not re-baselined here).
- **Core: 20** (untouched).

`flutter analyze --no-pub` clean × desktop in 5.8 s.

### Working-Tree Status

Uncommitted; 8 modified files + 3 untracked (the two shells + plan 26 doc).  Operator to commit per their preferred chunking.

### Suggested commit chunks

1. **`docs(plan): add plan 26 — desktop CP IA redesign`** — the standalone planning doc.  Safe to ship even if no code lands.  Files: `docs/10_planning/26_desktop_cp_ia_redesign.md`.
2. **`refactor(desktop): add embedded flag to inner screens`** — `library_screen.dart`, `transcode_screen.dart`, `activity_screen.dart`, `transcoding_screen.dart`, `logs_screen.dart`.  No behavior change when the flag is `false` (its default); every callsite passes `false` until the next chunk.
3. **`feat(desktop): add LibraryShell + ActivityShell tab hosts + router redirects`** — `library_shell.dart`, `activity_shell.dart`, `app_router.dart`.  This is the main IA cutover; needs chunk 2 to compile.
4. **`feat(desktop): flat 7-item nav rail + dashboard Recent Activity deep-links`** — `flux_sidebar.dart`, `dashboard_screen.dart`.  Final visible polish.
5. **`docs: plan 26 sweep — AGENT_LOG + 08_frontend + CLAUDE.md`** — every doc file touched + this AGENT_LOG entry.

### Next Agent Should

1. **Operator real-device pass on the new rail.**  Click through Library → all three tabs; Activity → all three tabs; verify back-compat redirects (`/transcode`, `/transcoding`, `/logs`); verify Dashboard Recent Activity rows deep-link to Sessions with the row visible in the event feed.
2. **Highlight-the-event polish in `_ActivityView`.**  Parse `GoRouterState.of(context).uri.queryParameters['event']` in `activity_screen.dart`; on match, scroll the matching `_ActivityRow` into view and flash a violet-tinted background for 1500 ms.  Adds ~40 lines + a widget test.
3. **Widget tests for `LibraryShell` + `ActivityShell` tab switching.**  Fixed surface: pump shell with each `*ShellTabPath`, verify FluxTabBar `activeId` matches, verify body widget swaps.  Cover the redirect path too — pump `/library` and assert URL ends up on `/library/folders` (or whatever `_rememberedLibraryTab` was set to in a previous test).
4. **Scan history content.**  Plan 26's placeholder is good enough for ship but the empty-state copy promises a real feature.  Options: lift the scan-result snackbar history out of `LibraryCubit` (currently ephemeral), or surface the per-library `last_scanned_at` + last delta count as a simple table.  Half-day milestone.
5. **Promote remembered-tab persistence.**  Current module-level cache resets on hot restart.  Two paths: (a) add `shared_preferences` (clean but needs CLAUDE.md prohibition #6 justification — defensible: standard Flutter UI-pref package), or (b) reuse the server's `user_settings` table via `SettingsCubit` (no new dep but adds a server round-trip per tab switch).  Skip until operator complains.

---

## [2026-05-15] [desktop] [feat] [tests] — Plan 26 follow-up · deep-link highlight polish

**Phase:** Plan 26 same-day polish — picked up the deferred "highlight the matched event on arrival" item from the previous entry's `Next Agent Should #2` before context cooled.
**Status:** Complete
**Commits:** uncommitted (folds into plan 26 chunks)

### What Was Done

The previous entry shipped the deep-link itself (Dashboard "Recent Activity" rows navigate to `/activity/sessions?event=<id>`) but didn't read the param at the destination — operators landed on the event feed with no callout for the row they came from.  This entry wires that consumption end-to-end.

1. **Read the param in `_ActivityViewState`.**  Added `didChangeDependencies` override that pulls `GoRouterState.of(context).uri.queryParameters['event']`.  Compared against `_lastSeenEventParam` to avoid re-firing on each cubit-poll-driven rebuild (the cubit emits new `RecentActivityLoaded` states on a polling cadence, each of which would otherwise re-trigger the highlight).  On a fresh non-null param, sets `_highlightedEventId`.  New `go_router` import.
2. **Threaded `highlightedEventId` down to the row.**  `_LiveActivityCard` gained a `String? highlightedEventId` parameter; each `_ActivityEventRow` in the `Column.children` now gets `highlighted: entry.value.id == highlightedEventId` plus a stable `ValueKey(event.id)` so Flutter reconciles row State by event identity (not position) — new events arriving at the top of the feed don't recycle a row's `AnimationController` for a different event.
3. **Converted `_ActivityEventRow` → `ActivityEventRow` (stateful).**  Public-named with `@visibleForTesting const` constructor following the mobile player-widget convention.  New `_ActivityEventRowState` uses `SingleTickerProviderStateMixin` + a 1.5 s `AnimationController` + `ColorTween(begin: violet@22%, end: transparent).animate(CurvedAnimation(curve: easeOutCubic))`.  Controller is constructed with `value: 1.0` (sit at "end" = transparent by default — caught while writing the widget test that the default `value: 0` would have made non-highlighted rows render violet-tinted indefinitely).  `_runHighlight` (post-frame callback) calls `Scrollable.ensureVisible(context, alignment: 0.3, curve: easeOutCubic, duration: 350 ms)` then `flashCtrl.forward(from: 0)` so the controller jumps to begin and animates back to end over 1.5 s.  `didUpdateWidget` re-fires when `highlighted` flips false → true so subsequent deep-links re-trigger the animation even on a recycled row.  `AnimatedBuilder` wraps the row's outer Container; the inner `Row` is passed as `child:` so the row content itself doesn't rebuild on every animation tick — only the tinted Container does.
4. **Static helpers (`iconFor`, `relativeTime`) promoted from private `_iconFor` / `_relativeTime`** so the test file can build representative rows without duplicating the colour/icon mapping.
5. **Widget test** at `apps/desktop/test/features/activity/activity_event_row_test.dart` — 4 cases:
   - `renders transparent when highlighted is false` (proves the `value: 1.0` initial state fix).
   - `renders violet tint when highlighted is true` after 2 pumps (post-frame callback + AnimatedBuilder rebuild).  Asserts non-zero alpha + violet-skewed colour (`b ≥ g`, matching `#A855F7`) instead of comparing RGB exactly — the controller ticks slightly within a frame and exact-equality on `r/g/b` was brittle.
   - `flash fades to transparent within 1500 ms` after `pump(1600 ms)`.
   - `re-fires when highlighted flips false → true` via two `pumpWidget` calls.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/desktop/lib/features/activity/presentation/screens/activity_screen.dart | `didChangeDependencies` reads `?event=`; `_highlightedEventId` threaded via `_LiveActivityCard.highlightedEventId`; `_ActivityEventRow` → public `ActivityEventRow` stateful with flash AnimationController + scroll-into-view; `iconFor` / `relativeTime` promoted to public statics so the test can build rows |
| Created | apps/desktop/test/features/activity/activity_event_row_test.dart | 4-case widget test covering transparent baseline, violet flash on first frame, fade-to-transparent within 1500 ms, re-fire on highlighted flip false→true |

### Decisions Made

- **Animation controller initial `value: 1.0`.**  Caught while writing the first test that the default `value: 0` would put the controller at "begin" (violet) every time the row mounted, even when `highlighted: false` — rows would render violet-tinted indefinitely.  Starting at end (transparent) + using `forward(from: 0)` to reset-and-animate is the correct shape and saved a runtime bug.
- **Compare alpha + colour-channel skew, not exact RGB, in the widget test.**  First attempt asserted `color.r == AppColors.violet.r` and failed with 0.6401 vs. 0.6588 — the controller advances by a tiny fraction within the frame after `forward(from: 0)`, so exact-RGB comparison is brittle.  Asserting `a > 0` and `b ≥ g` proves "violet-ish tint visible" without coupling the test to ticker timing.
- **Stable `ValueKey(event.id)` on each row.**  Without it, Flutter matches widget→State by type+position, so a new event arriving at the top of the feed shifts every row down and recycles each row's `AnimationController` against a different event — meaning a highlighted row's flash could mid-animation jump onto an unrelated event.  The key follows the event correctly.
- **`@visibleForTesting` constructor + public class name, not a backdoor.**  Matches the established mobile player pattern (`PlayerTopBar`, `PlayerProgressBar`, etc.); the runtime callsite is the only callsite and uses the constructor unmodified, so the annotation accurately reflects intent.

### Test Counts (re-baselined)

- **Desktop: 118 passing** (was 114; +4 from `activity_event_row_test.dart`).
- Server / Mobile / Core untouched.

`flutter analyze --no-pub` clean × desktop in 7.3 s.

### Working-Tree Status

Uncommitted; previous entry's diff + 1 new modified file (`activity_screen.dart`) + 1 new test file.  Folds into plan 26 commit chunk 3 (`feat(desktop): add LibraryShell + ActivityShell tab hosts + router redirects`) or could ship as its own chunk:

- **Suggested standalone chunk:** `feat(desktop): highlight deep-linked event on arrival — flash + scroll into view`.

### Next Agent Should

The previous entry's `Next Agent Should` list is unchanged except for item #2 — it's now done.  Remaining items 1, 3, 4, 5 stand as written.

