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

* **M14 — Mobile redesign closeout (2026-05-14).** Wave 1a: animation constants (`_kFadeMs=250`, `_kRippleMs=400`, `_kTransportPressMs=50`), `_DragHud` persistent (AnimatedOpacity + IgnorePointer), AnimatedScale press feedback, route-fade 250 ms, tab-scale 220 ms. Wave 1b: 29 Semantics nodes, FocusTraversalGroup NumericFocusOrder (top-bar 1 → quick-actions 6), autofocus on play/pause, `MediaQuery.withClampedTextScaling(1.3×)` on all 16 screens, private-widget exposure (`_TransportBar` → `PlayerTransportBar` etc., `@visibleForTesting`). Wave 2: 10 golden PNG baselines (`golden_toolkit: ^0.15.0`). Mobile test suite 82 → 92. Mobile redesign fully closed (all M0-M14 shipped).

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

## [2026-05-14] [m14] [mobile] [docs] [tests] — M14 shipped · mobile-redesign closed · goldens

**Phase:** Phase 2 — mobile redesign closeout
**Status:** Complete
**Commits:** uncommitted

### What Was Done

Three prior subagents completed all M14 code work before this session. This session performed the doc sweep and AGENT_LOG entry only.

**Wave 1a — UI polish (prior agent):**
- Standardised animation constants (`_kFadeMs = 250`, `_kRippleMs = 400`, `_kTransportPressMs = 50`) across player-chrome widgets.
- `_DragHud` made persistent (always in tree): `AnimatedOpacity` + `IgnorePointer` replaces conditional build to prevent layout shifts on appear.
- `AnimatedScale` press feedback on transport bar buttons (scale 1.0 → 0.92 in 50 ms).
- `AnimatedOpacity` ripple overlay on every tap target (400 ms).
- Route-fade via `_fadePage<T>()` helper using `CustomTransitionPage` + `FadeTransition` (250 ms).
- Tab-scale animation standardised to 220 ms throughout `NavigationBar`.

**Wave 1b — a11y baseline (prior agent):**
- 29 `Semantics` nodes added across player chrome (play/pause, seek bar, volume rail, brightness rail, transport labels, quick-action cells).
- `ExcludeSemantics` applied to purely decorative elements (drag handle, background art).
- `FocusTraversalGroup` wrapping player chrome with `OrderedTraversalPolicy` and `NumericFocusOrder` siblings (top-bar 1 → transport 2 → brightness-rail 3 → volume-rail 4 → progress-bar 5 → quick-actions 6).
- `autofocus: true` on play/pause button.
- `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` wrapping all 16 mobile screens.
- Private-widget exposure: `_TransportBar` → `PlayerTransportBar`, `_ProgressBar` → `PlayerProgressBar`, `_QuickActionsRow` → `PlayerQuickActionsRow` (annotated `@visibleForTesting`).

**Wave 2 — golden tests (prior agent):**
- 10 golden PNG baselines committed under `apps/mobile/test/goldens/`.
- Subjects: `PlayerTransportBar`, `PlayerProgressBar`, `PlayerQuickActionsRow`, `LibraryCard`, `EpisodeListTile`, `SettingsGroupTile`, `PairingQrCard`, `ServerStatusChip`, `NotificationBadge`, `PlayerOverlayChrome`.
- `golden_toolkit: ^0.15.0` added to `dev_dependencies`.
- Custom `GoldenTestDevice` presets for phone/tablet landscape used throughout.
- `await GetIt.I.reset()` pattern enforced in every golden test setUp.

**Doc sweep (this session):**
- Updated `docs/00_overview/current_status.md` — M14 shipped block; mobile test count 82 → 92.
- Updated `docs/11_design/mobile_redesign_plan.md` — status banner ✅, §7 M14 row, §13 DoD all ✅, §17.3 #7 closed, §17.1 M14 row, 2026-05-14 changelog row.
- Updated `docs/10_planning/01_roadmap.md` — mobile redesign row ✅ fully closed 2026-05-14.
- Updated `docs/10_planning/05_ship_readiness.md` — status header bump; Mobile UI redesign polish row ✅ closed.
- Updated `docs/08_frontend/01_frontend_architecture.md` — M14 a11y baseline, text-scale clamp, animation contract, golden coverage, private-widget exposure pattern, test count 92.
- Updated `docs/12_guidelines/03_gotchas.md` — 4 new gotcha entries (GetIt.reset async, PlayerQuickActions landscape-only, _DragHud always-in-tree, private-widget exposure pattern).
- Rotated `AGENT_LOG.md` to `docs/logs/AGENT_LOG_archive_12.md` (was 1137 lines).

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | apps/mobile/lib/features/player/presentation/widgets/player_transport_bar.dart | Wave 1a — animation constants, AnimatedScale press, ripple; Wave 1b — Semantics, FocusTraversalGroup, @visibleForTesting rename |
| Modified | apps/mobile/lib/features/player/presentation/widgets/player_progress_bar.dart | Wave 1a — animation constants; Wave 1b — Semantics, @visibleForTesting rename |
| Modified | apps/mobile/lib/features/player/presentation/widgets/player_quick_actions_row.dart | Wave 1a — ripple overlay; Wave 1b — Semantics, @visibleForTesting rename |
| Modified | apps/mobile/lib/features/player/presentation/widgets/player_overlay_chrome.dart | Wave 1a — route-fade helper, _DragHud always-in-tree |
| Modified | apps/mobile/lib/features/player/presentation/widgets/player_drag_hud.dart | Wave 1a — AnimatedOpacity + IgnorePointer persistent pattern |
| Modified | apps/mobile/lib/features/player/presentation/screens/player_screen.dart | Wave 1a — tab-scale 220 ms, route-fade; Wave 1b — MediaQuery.withClampedTextScaling |
| Modified | apps/mobile/lib/features/library/presentation/screens/library_screen.dart | Wave 1b — MediaQuery.withClampedTextScaling |
| Modified | apps/mobile/lib/features/library/presentation/widgets/library_card.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/library/presentation/widgets/episode_list_tile.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/settings/presentation/screens/settings_screen.dart | Wave 1b — MediaQuery.withClampedTextScaling |
| Modified | apps/mobile/lib/features/settings/presentation/widgets/settings_group_tile.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/pairing/presentation/screens/pairing_screen.dart | Wave 1b — MediaQuery.withClampedTextScaling |
| Modified | apps/mobile/lib/features/pairing/presentation/widgets/pairing_qr_card.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/home/presentation/widgets/server_status_chip.dart | Wave 1b — Semantics |
| Modified | apps/mobile/lib/features/notifications/presentation/widgets/notification_badge.dart | Wave 1b — Semantics |
| Modified | apps/mobile/pubspec.yaml | Wave 2 — golden_toolkit: ^0.15.0 added to dev_dependencies |
| Created | apps/mobile/test/goldens/player_transport_bar_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/player_progress_bar_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/player_quick_actions_row_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/library_card_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/episode_list_tile_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/settings_group_tile_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/pairing_qr_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/server_status_chip_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/notification_badge_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/player_overlay_chrome_test.dart | Wave 2 — golden test |
| Created | apps/mobile/test/goldens/*.png (10 baselines) | Wave 2 — golden PNG baselines under apps/mobile/test/goldens/ |
| Modified | docs/00_overview/current_status.md | Doc sweep — M14 shipped block; mobile 82 → 92 |
| Modified | docs/11_design/mobile_redesign_plan.md | Doc sweep — status banner, §7 M14 row, §13 DoD, §17.3 #7, §17.1, changelog |
| Modified | docs/10_planning/01_roadmap.md | Doc sweep — mobile redesign ✅ fully closed 2026-05-14 |
| Modified | docs/10_planning/05_ship_readiness.md | Doc sweep — status header; Mobile UI redesign polish row ✅ |
| Modified | docs/08_frontend/01_frontend_architecture.md | Doc sweep — M14 a11y baseline, text-scale, animation constants, golden coverage, test count |
| Modified | docs/12_guidelines/03_gotchas.md | Doc sweep — 4 new gotcha entries for M14 sharp edges |
| Created | docs/logs/AGENT_LOG_archive_12.md | Log rotation — archived 1137-line AGENT_LOG.md |
| Modified | AGENT_LOG.md | Log rotation + this entry |

### Docs Updated

- `docs/00_overview/current_status.md` — M14 shipped block; mobile test count 82 → 92 (+10 goldens)
- `docs/11_design/mobile_redesign_plan.md` — status banner ✅ DONE 2026-05-14; §7 M14 row specs; §13 DoD all ✅; §17.3 #7 closed; §17.1 M14 row; 2026-05-14 changelog row
- `docs/10_planning/01_roadmap.md` — mobile redesign row ✅ fully closed 2026-05-14 with test counts
- `docs/10_planning/05_ship_readiness.md` — status header bump; Mobile UI redesign polish row ✅ closed
- `docs/08_frontend/01_frontend_architecture.md` — full M14 a11y/animation/golden detail added to Status line
- `docs/12_guidelines/03_gotchas.md` — 4 new gotcha entries
- `docs/logs/AGENT_LOG_archive_12.md` — new archive file

### Test Counts (re-baselined)

- **Mobile: 92 passing** (82 unit/widget + 10 goldens; +10 from Wave 2 golden test suite)
- **Server: 814 passing** (untouched in M14)
- **Desktop: 113 passing** (untouched in M14)
- **Core: 8 passing** (untouched in M14)

### Issues / Sharp Edges Discovered

1. **`GetIt.reset()` must be awaited in mobile tests** — desktop tests historically used synchronous reset; mobile factory graph requires `await GetIt.I.reset()`. Sync calls produce spurious "type X is not registered" failures that look like missing registrations. Documented in gotchas.
2. **`PlayerQuickActions` is landscape-only at runtime but portrait in generic test surfaces** — 8-cell row overflows ~111 px at 412 px portrait. Tests must set `tester.view.physicalSize` to landscape before pumping. Documented in gotchas.
3. **`_DragHud` always-in-tree pattern invalidates old `find.byType` assertions** — post-Wave-1a the widget is always present; hidden state is opacity=0 + IgnorePointer, not widget-tree removal. Any test asserting absence will produce a false failure. Documented in gotchas.
4. **Private widget exposure via rename requires updating all internal callsites** — when `_FooBar` becomes `PlayerFooBar`, every usage inside the same file, plus any `part of` fragments or barrel exports, must be updated atomically. Missing one causes a compile error that won't surface until the golden test file is added. Documented in gotchas.
5. **`MediaQuery.withClampedTextScaling` must wrap the MaterialApp ancestor, not individual widgets** — if the clamp is applied below a widget that already reads `textScaleFactor`, the clamp has no effect. The correct insertion point is the outermost `MaterialApp` builder or the screen's `build` root before any `Text` descendants.
6. **golden_toolkit `^0.15.0` requires Flutter ≥ 3.19** — if the CI runner's Flutter channel is older, `flutter test` will fail to resolve the package. Verify the CI Flutter version pin in `.github/workflows/` before upgrading the constraint.

### Next Agent Should

1. **End-of-episode resolver (§17.3 #9)** — the auto-advance hook and next-episode lookup are the only remaining open functional item in the mobile redesign. Needs: `PlayerRepository.fetchNextEpisode(seriesId, currentEpisodeIndex)` + cubit state `PlayerEpisodeEnded` + `VideoPlayer.onComplete` listener + `GoRouter.go('/player', extra: nextEpisodeId)` navigation. Estimate: ~half a day. See `docs/11_design/mobile_redesign_plan.md` §17.3 #9.
2. **iOS PIP (§17.3 #1)** — gated on a physical iOS test device; treat as a manual task. Add to `docs/10_planning/04_manual_tasks.md` if not already tracked. No code changes needed until the device is available.
3. **Streaming pipeline regressions (ship readiness blockers)** — HDR→SDR toggle timeout, seek-ahead 404s, and zombie FFmpeg accumulation are demo-visible and block first-paying-customer onboarding. See `docs/10_planning/11_streaming_pipeline_issues.md` and `docs/10_planning/05_ship_readiness.md` §"Streaming pipeline regressions". Four commits, ~1.5 days. Commit 1 (tonemap unblock + diagnostic upgrade) is independently shippable.
