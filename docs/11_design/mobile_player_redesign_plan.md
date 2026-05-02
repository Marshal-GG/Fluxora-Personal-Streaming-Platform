# Mobile Player Redesign — Implementation Plan

> **Status:** Plan locked (2026-05-02) — **execution gated on desktop redesign reaching M9 cutover**. No code changes until then.
> **Created:** 2026-05-02
> **Owner:** Marshal
> **Source design:** [`docs/11_design/ref images/mobile/mobile_player_with_legend.png`](./ref%20images/mobile/mobile_player_with_legend.png)
> **Target:** [`apps/mobile/lib/features/player/`](../../apps/mobile/lib/features/player/)

This plan translates the annotated mobile-player mockup into the existing Flutter mobile client. It is the single source of truth for the redesign — every screen / widget PR should reference a section here.

The mockup is a **landscape, full-bleed media player** with a dimmed-poster background, side-rail brightness/volume sliders, three-button center transport, a quick-action row beneath the scrubber, and a 4-column legend (drawn for documentation only — the legend is **not** part of the runtime UI).

## 0. Execution gate

This redesign is **planned but paused**. Per owner direction (2026-05-02), the desktop redesign ([`desktop_redesign_plan.md`](./desktop_redesign_plan.md)) takes precedence — its remaining milestones (M4–M9) ship first. Once the desktop redesign reaches M9 cutover, work on this plan resumes from M1 (§7).

Do not start any code work in `apps/mobile/lib/features/player/` against this plan until the gate lifts. Documentation-only edits to this file are fine.

---

## 1. Decisions locked in

These shape the rest of the plan. Do not relitigate without updating this section.

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Direct replacement.** No `/v2/*` route, no feature flag, no kept-alongside legacy controls. The PR replaces the existing `_VideoView` body. | Mirrors the desktop redesign discipline. |
| 2 | **Drop X-Ray.** The reference's `X-Ray` chip is Amazon Prime branding, not a Fluxora feature. | Out of scope; replace with our LAN/WAN transport badge which is already built. |
| 3 | **Defer Episodes / chapters.** Server exposes neither a TV-show grouping nor chapter markers. The mockup's "Episodes" button + "Chapters/Markers" gesture are out of scope for v1 of the redesign. Stub-disabled in UI; backend work tracked separately. | Honest scope. Adds 2 endpoints + 2 migrations otherwise. |
| 4 | **Use the existing mobile theme tokens.** Player chrome stays on the current mobile palette: `AppColors.primary` (`#6366F1` indigo), `AppColors.accentPurple` (`#A855F7` violet — already in the palette), `AppColors.accent` (`#22D3EE` cyan), `AppColors.brandGradient` (indigo → violet → cyan), `AppColors.surface`, `AppColors.textPrimary` / `textSecondary`. **No v2 palette migration on this PR.** | Owner direction 2026-05-02: the player should not visually depart from the rest of the mobile app. The desktop's v2 palette is a desktop-only concern until a full mobile token migration is scheduled separately. |
| 5 | **Custom controls overlay.** Replace `MaterialVideoControls` from `media_kit_video` with a hand-rolled `_FluxoraPlayerControls` widget. The Material defaults can't be styled enough to hit the mockup. | Confirmed by reviewing `media_kit_video`'s `MaterialVideoControlsThemeData` — top/bottom bars are themable but side rails, gestures, and the lock-mode overlay aren't. |
| 6 | **One landscape orientation.** The redesign assumes the player is landscape-only (matches the mockup + most usage). Portrait still works (the screen rotates with device), but layout is optimised for landscape. | Simpler layout. Existing `SystemChrome.setPreferredOrientations` already prefers landscape. |
| 7 | **No new BLoC.** The chrome / overlay / lock-mode state lives in a `_PlayerControlsController` (plain `ChangeNotifier`) **inside** the screen. `PlayerCubit` keeps owning network / transport / progress concerns only. | Keeps Cubit pure (testable without UI). UI-only state shouldn't pollute the Cubit. |

---

## 2. Source-of-truth files

| Concern | File |
|---------|------|
| Visual reference | [`docs/11_design/ref images/mobile/mobile_player_with_legend.png`](./ref%20images/mobile/mobile_player_with_legend.png) |
| Existing player screen | [`apps/mobile/lib/features/player/presentation/screens/player_screen.dart`](../../apps/mobile/lib/features/player/presentation/screens/player_screen.dart) |
| Existing cubit + state | [`apps/mobile/lib/features/player/presentation/cubit/`](../../apps/mobile/lib/features/player/presentation/cubit/) |
| Brand tokens (violet, gradients, radii) | [`packages/fluxora_core/lib/constants/app_colors.dart`](../../packages/fluxora_core/lib/constants/app_colors.dart) v2 section |
| Brand wordmark | [`packages/fluxora_core/assets/brand/logo-wordmark-h.png`](../../packages/fluxora_core/assets/brand/logo-wordmark-h.png) |

---

## 3. Anatomy of the screen — mockup to widget map

The mockup decomposes into 4 stacked layers. The bottom-most legend block is documentation-only; it never renders at runtime.

### Layer 1 — `Video`
Full-bleed `Video(controller:)` from `media_kit_video`. `BoxFit.cover` on the player surface; we draw a semi-opaque scrim above it when controls are visible.

### Layer 2 — Gestures (full-screen `GestureDetector`)
| Gesture | Action | Implementation |
|---------|--------|----------------|
| Single tap | Toggle controls visibility (auto-hide after 3 s of inactivity) | `_PlayerControlsController.toggle()` |
| Double tap **left third** | Seek -10 s + ripple animation | `Player.seek(position - 10s)` + `_RippleOverlay.left` |
| Double tap **right third** | Seek +10 s + ripple animation | `Player.seek(position + 10s)` + `_RippleOverlay.right` |
| Vertical drag **left half** | Adjust screen brightness | `screen_brightness` package (new dep, justify §6) |
| Vertical drag **right half** | Adjust system volume | `Player.setVolume()` (media_kit, no new dep) |
| Horizontal drag (anywhere) | Scrub | `Player.seek()` with debounced commit on drag-end |
| Long press anywhere | 2× speed peek (release returns to previous rate) | `Player.setRate(2.0)` on long-press start, restore on long-press end |
| Pinch | Toggle `BoxFit.cover` ↔ `BoxFit.contain` | Custom — fit state on `_PlayerControlsController` |

When `lockMode == true`, the gesture detector swallows everything except a single long-press on the unlock affordance.

### Layer 3 — Controls overlay (`AnimatedOpacity` 250 ms)

Renders only when `_PlayerControlsController.visible == true`. Whole layer fades together — no per-element animation noise.

#### 3.1 Top bar (height 56)

| Slot | Content | Source |
|------|---------|--------|
| Leading | Back chevron `Icons.arrow_back` | `Navigator.pop` |
| Title | `MediaFile.title ?? MediaFile.name` (1 line, ellipsis) | `PlayerReady.fileName` already passed |
| Subtitle (under title) | `audioTrack.title · qualityLabel · audioCodec` | `Player.state.track.audio` + selected quality |
| Trailing #1 | `_TransportBadge` *(existing — restyled, no longer auto-hides; stays pinned top-right)* | `PlayerReady.streamPath` |
| Trailing #2 | Cast button — **disabled stub** with cast-off glyph (greyed out, tooltip "Casting coming soon"). Confirmed 2026-05-02 — render as visible-but-disabled, not hidden. | — |
| Trailing #3 | Overflow menu (sleep timer, info, report) | new |

#### 3.2 Left rail (vertical, width 56, full-height)

```
┌──────┐
│  🔆  │  brightness icon (top)
│  ┃  │
│  ┃  │  vertical slider (0.0 … 1.0)
│  ┃  │
│  🔒  │  lock icon (bottom — toggles lockMode)
└──────┘
```

Track: 4 px wide, `AppColors.surfaceMuted` 30 % alpha. Fill: 4 px wide, `AppColors.brandGradient` rotated to vertical (`Alignment.bottomCenter` → `Alignment.topCenter`). Thumb: 14 × 14 white circle with `AppColors.primary` (indigo) glow. The slider is **non-interactive** by direct touch; it's a *display* of the value driven by the vertical-drag gesture on the left half. Tapping the bulb icon at the top toggles brightness boost, tapping the lock at the bottom enters lockMode.

#### 3.3 Right rail (mirror of left)

```
┌──────┐
│  🔊  │  volume icon
│  ┃  │
│  ┃  │  vertical slider
│  ┃  │
│  🔇  │  mute toggle
└──────┘
```

Same construction; bound to `Player.state.volume` via stream subscription.

#### 3.4 Center transport (3 buttons, horizontally centred)

```
   ⟲10        ⏯/⏸ (large)        ⟳10
```

- Side buttons: 56 × 56 ghost circle (`AppColors.background` 60 % alpha + 1 px `AppColors.surfaceMuted` 30 %), `AppColors.textPrimary` icon, press → tinted `AppColors.primary` 20 % overlay.
- Center button: 72 × 72 filled with `AppColors.brandGradient`, white play icon, dropshadow using `AppColors.primary` 40 % alpha (10 px blur, 0 / 4 offset).
- All three rotate + scale 0.95 on press (50 ms `AnimationController`).
- Play icon swaps to pause via `AnimatedSwitcher` 200 ms scale-in.

#### 3.5 Progress bar (full width, bottom 100 px above edge)

```
┌─────────────────────────────────────────────────────────┐
│  1:12:43  [████████▓▓░░░░░░░░░░░░░░░░░░░░]  2:49:03   │
│                                              [Episodes] │
└─────────────────────────────────────────────────────────┘
```

- Track: 3 px, `AppColors.surfaceMuted` 30 % alpha.
- Buffered: 3 px, `AppColors.surfaceRaised`.
- Played: 3 px, `AppColors.brandGradient`.
- Thumb: 12 × 12 `AppColors.accent` (cyan) circle with `AppColors.primary` (indigo) glow ring (visible only on drag).
- Chapter ticks: deferred (decision §1 row 3) — placeholder `List<Duration> chapters` field on `PlayerReady`, currently always empty.
- Timestamps: `AppTypography.mono` (`JetBrains Mono` 13 / 400) re-coloured to `AppColors.textPrimary`. Always two lines high to avoid layout shift between `1:12:43` and `0:42`.
- Episodes button: hidden in v1 (decision §1 row 3).

#### 3.6 Quick-action row (8 chips, scrollable horizontally if overflow)

| Chip | Action | Status |
|------|--------|--------|
| Quality | open sheet — list available HLS variants | **new** — needs backend work (see §6) |
| Speed | open sheet — 0.5× / 0.75× / 1× / 1.25× / 1.5× / 2× | already implemented in `_SettingsSheet` Speed tab |
| Audio | open sheet — list `Player.state.tracks.audio` | already implemented |
| Subtitles | open sheet — list `Player.state.tracks.subtitle` + "off" | already implemented |
| Episodes | — | **deferred** (decision §1 row 3) |
| Next Episode | — | **deferred** |
| Playlist | — | **deferred** (no playlist concept yet) |
| Repeat | toggle player loop | one line: `_player.setPlaylistMode(loop?single:none)` |
| Lock | enter `lockMode` (UI shows minimal "tap and hold to unlock" hint) | `_PlayerControlsController.lock()` |

Each chip is a `FluxButton(variant: ghost, size: sm, icon, label)`-style affordance — but since `FluxButton` lives in `apps/desktop/`, we either (a) lift it to `packages/fluxora_core/lib/widgets/`, or (b) inline a mobile-local copy. **Recommendation:** lift to `fluxora_core` so mobile + desktop share. Tracked as a prerequisite step (§7 M1).

### Layer 4 — Conditional overlays

- `_ResumeBanner` *(existing — restyle to use `AppColors.surface` pill with `AppColors.primary` accent)* — auto-dismisses 4 s.
- `_TierLimitView` *(existing — keep as-is, it's the 429 fallback)*.
- `_ErrorView` *(existing — restyle to brand colours)*.
- **New** `_LockOverlay` — when `lockMode == true`, full-screen transparent gesture-eater with a small chip top-right "Hold to unlock" (long-press 800 ms → unlock).
- **New** `_PeekOverlay` — when long-pressing for 2× speed peek, shows centre chip "▶▶ 2×".
- **New** `_DragGestureFeedback` — top-centre HUD chip during a vertical-drag (e.g. "🔆 64%" or "🔊 12/15"). Auto-hides 600 ms after drag-end.
- **New** `_RippleOverlay` — centred semi-circle ripple from edge after double-tap seek; shows "+10 s" / "-10 s" caption; 400 ms.

---

## 4. Files to add / modify

### New files (under `apps/mobile/lib/features/player/presentation/`)

```
controllers/
  player_controls_controller.dart   # ChangeNotifier — visibility, lockMode, fit, brightness HUD
widgets/
  flux_player_controls.dart         # The full overlay composition
  flux_player_top_bar.dart
  flux_player_side_rail.dart        # Left/right rail (left/right variant)
  flux_player_transport.dart        # Three-button center cluster
  flux_player_progress_bar.dart     # CustomPainter scrubber + thumb
  flux_player_quick_actions.dart    # Horizontally-scrollable chip row
  flux_player_lock_overlay.dart
  flux_player_drag_hud.dart         # Top-centre HUD chip during drag
  flux_player_seek_ripple.dart      # Double-tap seek ripple
  flux_player_quality_sheet.dart    # New — replaces _SettingsSheet's missing "Quality" tab
  flux_player_speed_sheet.dart      # Lift from current _SettingsSheet
  flux_player_audio_sheet.dart      # Lift from current _SettingsSheet
  flux_player_subtitle_sheet.dart   # Lift from current _SettingsSheet
```

### Modified files

| File | Change |
|------|--------|
| `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` | `_VideoView` no longer wraps `MaterialVideoControlsTheme` — replaced with `Stack` containing `Video` + `FluxPlayerControls`. `_SettingsSheet` deleted (replaced by per-feature sheets). |
| `apps/mobile/pubspec.yaml` | Add `screen_brightness: ^2.x`. |
| `packages/fluxora_core/lib/widgets/flux_button.dart` | **Lift** from `apps/desktop/lib/shared/widgets/flux_button.dart`. Both apps then import from core. (Prereq — see §7 M1.) |
| `packages/fluxora_core/lib/fluxora_core.dart` | Re-export `flux_button.dart`. |
| `apps/desktop/lib/shared/widgets/flux_button.dart` | Becomes a 1-line re-export from core, or deleted if all desktop call-sites switch to the core import in the same PR. |
| `docs/00_overview/current_status.md` | Add "Mobile player redesign" line. |
| `docs/08_frontend/01_frontend_architecture.md` | Add subsection under "Phase 1 — Core" → mobile player surface. |
| `docs/10_planning/01_roadmap.md` | New row under Phase 5 — "Mobile player redesign". |
| `AGENT_LOG.md` | Per-session entries during build-out. |

### Deleted files

None until the redesign ships and the legacy `_SettingsSheet` is fully replaced by the per-feature sheets.

---

## 5. State model

### `_PlayerControlsController extends ChangeNotifier`

```dart
class _PlayerControlsController extends ChangeNotifier {
  bool _visible = true;        // Top/side/bottom overlays shown.
  bool _lockMode = false;      // Disables every gesture except unlock.
  bool _fitCover = true;       // false = letterbox.
  Timer? _autoHide;            // 3 s idle → setInvisible.

  // Drag-HUD state
  _DragKind? _activeDrag;       // brightness | volume | seek | null.
  double _dragHudValue = 0.0;
  bool _dragHudVisible = false;

  void toggle();
  void show();
  void hide();
  void lock();
  void unlock();
  void setBrightnessHud(double v);
  void setVolumeHud(double v);
  void setSeekHud(Duration v);
  void clearHud();
}
```

### `PlayerCubit` — unchanged surface

No new public API. The cubit keeps owning network / transport / progress. The screen reads `Player.state` streams directly for position, duration, buffer, volume, rate, tracks — it does **not** need to round-trip those through the cubit.

### What gets read directly from `Player`

```dart
context.read<PlayerCubit>().state // → PlayerReady (one-time read for controller)
final player = readyState.player;
player.stream.position    // Stream<Duration>
player.stream.buffer      // Stream<Duration>
player.stream.duration    // Stream<Duration>
player.stream.playing     // Stream<bool>
player.stream.volume      // Stream<double>
player.stream.rate        // Stream<double>
player.stream.tracks      // Stream<Tracks>
player.stream.track       // Stream<Track>
player.stream.completed   // Stream<bool> — end-of-media
```

Each widget in the overlay subscribes to only the streams it needs (via `StreamBuilder`) — no global rebuild on every position tick.

---

## 6. New dependency justifications (Hard Prohibition #6)

### `screen_brightness: ^2.x` *(required for left-rail brightness control)*

| Question | Answer |
|----------|--------|
| Does an existing dep cover this? | **No.** `media_kit` controls media volume but not screen brightness. There is no other brightness-capable package in `pubspec.yaml`. |
| Is the alternative trivial? | No — Flutter has no built-in brightness API. The platform channels are non-trivial (`UIScreen.brightness` on iOS, `WindowManager.LayoutParams.screenBrightness` on Android). `screen_brightness` is the de-facto package, MIT-licensed, federated plugin model. |
| Latest version on pub.dev? | **Must check before adding** (Hard Prohibition #12). Confirm the actual current version on pub.dev when implementing M2. |
| Maintenance signals | Used by ~all Flutter video players (chewie, better_player). Federated, multi-platform. |
| Bundle impact | Adds ~5 KB Dart + native channel; negligible. |

If the package is unmaintained at implementation time, fall back to a **light-only** brightness HUD (display-only, no system-brightness write — value is purely visual on a dimming overlay layered above the `Video`). The user-visible behaviour is identical in dim conditions; only the always-on display brightness wouldn't move.

### Quality switching — backend work, not a Dart dep

Server currently exposes a single HLS playlist URL per stream. Multi-quality requires either:
- Server emits an HLS master playlist with multiple variants (preferred — `media_kit` will switch automatically on bandwidth), or
- Server exposes `GET /api/v1/stream/{id}/qualities` + `POST /api/v1/stream/{id}/quality` and we restart the stream on user pick.

**Recommendation:** the redesign ships with the **Quality** chip stub-disabled (greyed out with "Auto" label). Quality selector is a separate ticket (M0 §X — to be added to the M0 backend list in `desktop_redesign_plan.md`).

---

## 7. Milestones

Each milestone is one PR. Mobile-player tests live under `apps/mobile/test/features/player/`.

### M1 — Prerequisites *(approved 2026-05-02 as standalone PR)*
- Lift `FluxButton` from `apps/desktop/lib/shared/widgets/` to `packages/fluxora_core/lib/widgets/`. The desktop variant pulls `app_colors` v2 / `app_radii` / `app_typography` v2 — those imports stay valid because v2 tokens already live in `fluxora_core/lib/constants/`.
- Lift `Pill` similarly (used by the restyled transport badge).
- `apps/desktop/` switches to the core imports; one-line re-export shim or full delete in the same PR.
- Mobile-side: when consuming `FluxButton` / `Pill` from the player, instantiate with the **mobile palette** (`AppColors.primary`, `AppColors.surface`, `AppColors.brandGradient`) — the widgets accept colour overrides per-call. If they don't, add a `colorScheme` parameter to each widget that defaults to the v2 desktop palette.
- `flutter analyze` green on both apps.
- No visual change to the desktop app; mobile app unchanged at this milestone.

### M2 — Custom controls scaffold (replaces MaterialVideoControls)
- `_PlayerControlsController` + `FluxPlayerControls`.
- Top bar (back, title, transport badge, overflow stub).
- Center transport (rewind, play/pause, forward).
- Progress bar (no chapter ticks; just track / buffered / played / thumb / timestamps).
- Quick-actions row — only **Speed / Audio / Subtitles / Lock** wired live; **Quality / Episodes / Next / Playlist / Repeat** are stub-rendered (greyed out).
- Side rails — visual only (no drag binding yet).
- Tap to toggle visibility, 3 s auto-hide.
- `_ResumeBanner` + `_TransportBadge` migrated from existing code, restyled to use the mobile palette (`AppColors.surface` background, `AppColors.primary` accent, `AppColors.textPrimary`).
- Player chrome consumes **only** the existing mobile tokens — `AppColors.primary` (#6366F1 indigo), `AppColors.accentPurple` (#A855F7 violet, already in palette), `AppColors.accent` (#22D3EE cyan), `AppColors.surface`, `AppColors.background`, `AppColors.textPrimary` / `textSecondary`, `AppColors.brandGradient`. **Confirmed 2026-05-02: no v2 palette migration on this PR** (decision §1 row 4).

### M3 — Gestures
- Double-tap left/right seek ±10 s + `_RippleOverlay`.
- Vertical drag left half = brightness (uses `screen_brightness`).
- Vertical drag right half = volume (uses `Player.setVolume()`).
- Horizontal drag = scrub (with `_DragHud` showing the target timestamp).
- Long-press = 2× speed peek + `_PeekOverlay`.
- Pinch = fit toggle.

### M4 — Lock mode + per-feature sheets
- `_LockOverlay` with hold-to-unlock affordance.
- Tap-bottom-left bulb-lock toggle on left rail.
- Speed / Audio / Subtitles each in their own bottom sheet (replaces single tabbed sheet).
- Repeat chip wired (`Player.setPlaylistMode`).

### M5 — Polish
- All animations (fade 250 ms, transport press 50 ms, ripple 400 ms, badge restyle).
- Accessibility: `Semantics` labels on every interactive element, focus traversal, large-text support, screen-reader transcripts of the transport-badge state changes.
- Golden tests for top bar, transport, progress bar, side rail (no live `Player`; supply a stub controller).
- Widget tests for `_PlayerControlsController` (visibility timer, lock state machine, drag HUD lifecycle).
- Manual QA pass on real device (Android + iOS) — landscape and portrait, with WebRTC and HLS, with and without resume.

### M6 *(optional, future)* — Quality switching
- Backend: HLS master playlist with multiple variants (server-side ffmpeg encode-once, transmux at delivery).
- Client: Quality chip activates; opens sheet listing variants; selecting one restarts the stream at the new variant.

### M7 *(optional, future)* — Chapters & Episodes
- Backend migrations for `chapters` (per-file) and `episodes` (per-tv-show).
- TMDB integration for episode metadata.
- UI: chapter ticks on progress bar, Episodes button → bottom sheet with thumbnail grid.

---

## 8. Owner decisions (2026-05-02 review)

| # | Question | Resolution |
|---|----------|------------|
| 1 | **Brightness package:** OK to add `screen_brightness` as a new dep? | **Open — defer until execution.** Re-validate latest pub.dev version + maintenance signals at the start of M3. Fallback path (visual-only dimming overlay) is documented in §6. |
| 2 | **Brand colour scope:** v2 violet (`#A855F7`) for player only, or keep mobile theme? | **✅ Keep current mobile theme.** Player consumes existing `AppColors.primary` (indigo) / `accentPurple` / `accent` / `brandGradient` only. No v2 palette migration. Locked in §1 row 4. |
| 3 | **Lift FluxButton / Pill to core:** standalone PR? | **✅ Approved as a standalone PR.** Run M1 first, no visual change. Decision recorded in §7 M1. |
| 4 | **Cast button:** disabled stub or omit? | **✅ Disabled stub.** Visible but greyed out with tooltip. Recorded in §3.1. |
| 5 | **Episodes / chapters defer:** confirm v1 cut? | **✅ Confirmed deferred.** M6 (chapters) and M7 (episodes) tracked in §7 as future-only milestones, gated on backend work. Recorded in §1 row 3 + §3.5 + §3.6 + §9. |
| 6 | **Quality chip:** stub or block on master-playlist work? | **⏸ Wait.** No code work begins until the desktop redesign reaches M9. Re-decide at execution time. Stub-disabled remains the placeholder spec in §3.6. |

### Items still tracked as open

- **Q1 — `screen_brightness` dep:** re-decide at start of M3.
- **Q6 — Quality chip activation:** revisit at start of M2 / M6.

All other questions are resolved; the plan is ready to execute when the gate (§0) lifts.

---

## 9. Out of scope for v1

- AirPlay / Chromecast / DLNA casting
- Picture-in-picture
- Background audio playback (foreground service / iOS audio session)
- TV-show / episode browser
- Chapter markers
- AI-driven scene markers (X-Ray analogue) — Phase 5+ exploration if at all
- Multi-quality variant switching (M6, contingent on owner approval)
- Per-server preferred-quality settings
- Picture quality post-processing (HDR tone-mapping, etc.)

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| `media_kit_video`'s `Video` widget repaints on every frame; layering complex `CustomPainter` overlays could cost FPS on low-end Android. | Wrap each overlay in `RepaintBoundary`. Use `StreamBuilder` per-widget so unrelated streams don't trigger rebuilds. |
| `screen_brightness` package may not be maintained. | Fallback to visual-only HUD (decision in §6). |
| Long-press 2× peek could conflict with system long-press accessibility actions on Android. | Use `kLongPressTimeout - 50ms` threshold, defer to system long-press first when accessibility services are active. |
| Lock-mode swallows everything — easy to make user feel trapped. | Hold-to-unlock has a clear visible hint that fades back in on any tap; double-tap-with-three-fingers also unlocks (system fail-safe). |
| Replacing `MaterialVideoControls` removes some free affordances (e.g. `MaterialDesktopVideoControls` desktop variant). | Mobile-only redesign — desktop player path is unchanged. If desktop ever wants media playback, build a separate set then. |
| Quality stub button looks broken to users. | Show as `disabled + "Auto"` label, with tooltip "Quality is automatic. Manual selection coming soon." |

---

## 11. Definition of done

The redesign ships when:
- All M1–M5 milestones merged.
- `flutter analyze` green for `apps/mobile` and `packages/fluxora_core`.
- `flutter test apps/mobile` green (existing 25 tests + new tests for `_PlayerControlsController` and the four sheets).
- One golden image per overlay component (`top_bar`, `transport`, `progress_bar`, `side_rail_left`, `side_rail_right`, `lock_overlay`).
- Manual QA on a real Android device + a real iOS device against an active LAN stream **and** a WebRTC stream.
- `docs/00_overview/current_status.md`, `docs/08_frontend/01_frontend_architecture.md`, `docs/10_planning/01_roadmap.md` updated.
- This plan's "Status" line at top updated to ✅ Done with the merge date.

---

## 12. Changelog

| Date | Change |
|------|--------|
| 2026-05-02 | Initial plan drafted. |
| 2026-05-02 | Owner review pass: §1 row 4 flipped — keep mobile theme tokens, no v2 palette migration. Cast button confirmed as disabled stub (§3.1). Episodes / chapters confirmed deferred (§9 + M6 / M7). M1 prerequisite approved as standalone PR (§7 M1). Execution gate added (§0) — paused until desktop redesign reaches M9. Open questions section reframed as resolutions table (§8). |
