# Mobile App Redesign — Implementation Plan

> **Status:** Plan locked (2026-05-03) — **execution gate lifted 2026-05-03** (desktop M9 + M9.5 theme cutover landed; M10 custom window chrome shipped 2026-05-03 — see [`desktop_redesign_plan.md`](./desktop_redesign_plan.md)). Ready to start at M0 when the owner schedules it.
> **Created:** 2026-05-02 (player-scope) · **Expanded + renamed** 2026-05-03 (whole-app scope; was `mobile_player_redesign_plan.md`)
> **Owner:** Marshal
> **Source design:** [`docs/11_design/prototype/`](./prototype/) (Fluxora Mobile prototype bundle — 28 screens + flow diagram)
> **Prototype port spec:** [`docs/11_design/prototype/app/mobile/README.md`](./prototype/app/mobile/README.md)
> **Target:** [`apps/mobile/lib/`](../../apps/mobile/lib/)
>
> **Theme directive (2026-05-03):** Consume the **existing** `AppColors` and `AppTypography` V2 tokens already shipped to `packages/fluxora_core/lib/constants/`. **Do not add new theme tokens or create a parallel mobile theme file.** Where the prototype value diverges marginally from an existing token (alpha tweaks, half-pixel sizes), use the existing token unless the visual gap is plainly broken — then escalate. The legacy player-only sections (§15) at the bottom are kept intact for reference and cross-link from the new milestone breakdown.

This plan translates the high-fidelity Fluxora Mobile prototype into the existing Flutter mobile client. It is the single source of truth for the redesign — every screen / widget PR should reference a section here.

The prototype defines a brand-coherent, 5-tab mobile app with: onboarding, discover surfaces (home / library / search / notifications), title detail + episodes, dual-orientation player + bottom sheets, X-Ray + Group Watch features, downloads + profile, "beyond video" file viewers (PDF / photo / music), and a phone-as-server flow.

---

## 0. Execution gate — ✅ Lifted 2026-05-03

The desktop redesign reached M9 cutover on 2026-05-03 (legacy widgets deleted) and the V2 theme cutover landed the same day (`apps/desktop/lib/shared/theme/app_theme.dart` body rewritten — see `desktop_redesign_plan.md` §M9.5). The mobile redesign is now unblocked at the plan-defined gate.

- **Code work in `apps/mobile/lib/` against this plan is approved** when the owner schedules it. Start at M0 (§7).
- **Desktop is now fully shipped** — M0–M10 complete (M10 custom window chrome landed 2026-05-03). Mobile and desktop work can run in parallel from here.
- Documentation-only edits to this file remain fine.

---

## 1. Decisions locked in

These shape the rest of the plan. Do not relitigate without updating this section.

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Whole-app redesign, not player-only.** Every existing mobile screen is replaced; new screens (server picker, search, downloads, profile, files browser, doc / photo / music viewers, host server, notifications, x-ray, group watch) are built. | The prototype scopes the full app and the V2 brand language can't be applied piecemeal — half-violet / half-indigo would feel broken. |
| 2 | **Adopt the existing V2 (desktop) palette across mobile.** The prototype's `M` tokens already map onto `AppColors.bgRoot` / `violet` / `violetDeep` / `cyan` / `textBright` / etc. (see [`packages/fluxora_core/lib/constants/app_colors.dart`](../../packages/fluxora_core/lib/constants/app_colors.dart) lines 43-94) and `AppTypography.h1` / `h2` / `body` / `eyebrow` / etc. (see [`packages/fluxora_core/lib/constants/app_typography.dart`](../../packages/fluxora_core/lib/constants/app_typography.dart) lines 102-207). **Do not add new tokens.** The legacy mobile palette (`primary` indigo `#6366F1`, `accent`, `surfaceMuted`, etc.) and legacy text styles (`displayLg`, `headingLg`, etc.) are removed at M9 cutover. | Reverses the **2026-05-02 row 4 decision** which scoped player-only and chose to *keep* the indigo theme. The whole-app redesign forces the migration onto the V2 set the desktop already ships. Project owner directive 2026-05-03: don't recreate theme infrastructure — consume what exists. |
| 3 | **Direct replacement, no `/v2/*` route.** The PR sequence replaces existing screens in-place. No feature flag, no kept-alongside legacy UI. | Mirrors desktop redesign discipline. The mobile app has very few users and breaking the legacy UI is acceptable during the redesign window. |
| 4 | **Drop X-Ray live ML + Group Watch sync from v1.** Ship the **UI shells** for both (so they exist in the app), but X-Ray uses static cast metadata only (no live frame analysis) and Group Watch is a "coming soon" placeholder that opens but cannot start a session. | Honest scope. Live X-Ray + multi-client sync are Phase 5+ features that need backend work. |
| 5 | **Use `media_kit` for video and `just_audio` + `audio_service` for music.** Existing video stack stays; music is new. | `media_kit` already handles video (HLS, HEVC, HDR). For music we need background audio + lockscreen controls, which `media_kit` doesn't do — `audio_service` is the de-facto Flutter package for that. |
| 6 | **Bottom-tab shell with 5 tabs.** Home · Library · Search · Downloads · Profile. State preserved via `IndexedStack` / `ShellRoute`. | Matches the prototype `TAB_ITEMS` registry verbatim. |
| 7 | **Custom controls overlay for player.** Replace `MaterialVideoControls` from `media_kit_video` with a hand-rolled `FluxPlayerControls` widget (shared between portrait + landscape orientations with layout variants). | The Material defaults can't be styled enough to hit the prototype. Side rails, gesture HUDs, and lock-mode overlay aren't themable. |
| 8 | **No new BLoC for UI-only state.** Player chrome state lives in a `PlayerControlsController` (plain `ChangeNotifier`) **inside** the screen. `PlayerCubit` keeps owning network / transport / progress concerns only. The same pattern applies to other features that need UI-only state (sheet visibility, scroll position, tab selection inside a screen). | Keeps cubits pure and testable. UI-only state shouldn't pollute the cubit layer. |
| 9 | **Adopt Lucide icons via `lucide_icons`.** All new icons resolve through the prototype's HTML→Lucide map (§ 3.4 of the prototype README). Existing `Icons.*` Material icons are replaced one-screen-at-a-time as each screen is migrated. | Prototype is icon-mapped to Lucide; staying in Lucide guarantees pixel parity. |
| 10 | **Inter as the primary font.** `google_fonts: ^6.x` provides Inter at runtime; we already ship `JetBrains Mono` via the desktop bundle, so no new mono dep is needed. | Prototype specifies Inter weights 400/500/600/700/800. |
| 11 | **Defer chapters and multi-quality switching to optional later milestones.** Player ships with no chapter ticks (placeholder list field stays empty) and a stub-disabled "Quality" chip until backend HLS multi-variant work is scheduled. | Honest scope — see §6. Quality + chapters each need a server-side change. |
| 12 | **Lift shared widgets to `fluxora_core`.** `FluxButton`, `Pill`, `MChip`, `Poster`, `MAppBar`, and the bottom-sheet skeleton all migrate from `apps/desktop/` (or get newly built) into `packages/fluxora_core/lib/widgets/`. Both apps then import from core. | Prototype components are explicitly cross-platform. Mobile + desktop should share the same widget code. |

---

## 2. Source-of-truth files

| Concern | File |
|---------|------|
| Visual reference (whole app) | [`docs/11_design/prototype/Fluxora Mobile.html`](./prototype/Fluxora%20Mobile.html) — open in browser; pan + zoom the canvas |
| Per-screen JSX source | [`docs/11_design/prototype/app/mobile/screens/`](./prototype/app/mobile/screens/) |
| Mobile primitives + tokens (`M`) | [`docs/11_design/prototype/app/mobile/components/mobile-primitives.jsx`](./prototype/app/mobile/components/mobile-primitives.jsx) |
| Mock data shapes (translate to Dart freezed models) | [`docs/11_design/prototype/app/shared/data/fluxora-data.jsx`](./prototype/app/shared/data/fluxora-data.jsx) + [`fluxora-data-2.jsx`](./prototype/app/shared/data/fluxora-data-2.jsx) |
| Icon registry → Lucide map | [`docs/11_design/prototype/app/shared/components/icons.jsx`](./prototype/app/shared/components/icons.jsx) and § 3.4 of the prototype README |
| Prototype port spec (master narrative) | [`docs/11_design/prototype/app/mobile/README.md`](./prototype/app/mobile/README.md) |
| Player landscape annotated reference (legacy) | [`docs/11_design/ref images/mobile/mobile_player_with_legend.png`](./ref%20images/mobile/mobile_player_with_legend.png) |
| Existing mobile entry / router | [`apps/mobile/lib/app.dart`](../../apps/mobile/lib/app.dart), [`apps/mobile/lib/core/router/app_router.dart`](../../apps/mobile/lib/core/router/app_router.dart) |
| Existing player screen | [`apps/mobile/lib/features/player/presentation/screens/player_screen.dart`](../../apps/mobile/lib/features/player/presentation/screens/player_screen.dart) |
| Existing library / connect / auth screens | [`apps/mobile/lib/features/library/`](../../apps/mobile/lib/features/library/), [`connect/`](../../apps/mobile/lib/features/connect/), [`auth/`](../../apps/mobile/lib/features/auth/) |
| Brand tokens (V2 desktop palette — also our mobile target) | [`packages/fluxora_core/lib/constants/app_colors.dart`](../../packages/fluxora_core/lib/constants/app_colors.dart) lines 43-94 |
| Brand wordmark | [`packages/fluxora_core/assets/brand/logo-wordmark-h.png`](../../packages/fluxora_core/assets/brand/logo-wordmark-h.png) |

> When the JSX and this plan disagree, the JSX is canonical (per the prototype README's own footer).

---

## 3. Information architecture

### 3.1 Screen inventory (28 screens, prototype IDs preserved as Flutter route names)

| § | # | Route id | Title | Shell | Maps to existing? |
|---|---|----------|-------|-------|-------------------|
| 1 · Onboarding | 01 | `splash` | Splash / Sign-in entry | Status bar + nav pill | new |
| 1 · Onboarding | 02 | `server` | Server picker | Status bar only | replaces [`connect_screen.dart`](../../apps/mobile/lib/features/connect/presentation/screens/connect_screen.dart) |
| 2 · Discover | 03 | `home` | Home / Discover | Tab shell | new (no current home) |
| 2 · Discover | 04 | `library` | Library | Tab shell | replaces [`library_screen.dart`](../../apps/mobile/lib/features/library/presentation/screens/library_screen.dart) |
| 2 · Discover | 05 | `search` | Search | Tab shell | new |
| 2 · Discover | 06 | `notifications` | Notifications | Modal-style (no tab) | new |
| 3 · Title + playback | 07 | `detail` | Title Detail | Plain | new (replaces direct files-list flow) |
| 3 · Title + playback | 08 | `episodes` | Episodes list (TV) | Plain | new |
| 3 · Title + playback | 09 | `player-portrait` | Player · Portrait | `bg=#000` | replaces [`player_screen.dart`](../../apps/mobile/lib/features/player/presentation/screens/player_screen.dart) |
| 3 · Title + playback | 10 | `mini-player` | Home with mini-player (PiP) | Tab shell + persistent bar | new |
| 4 · Landscape player | 11 | `player-landscape` | Player · Landscape | Landscape, no status bar | replaces landscape branch of `player_screen.dart` |
| 4 · Landscape player | 12 | `legend` | Player legend | **Spec only — do not ship** | — |
| 5 · Modal sheets | 13 | `audio-subs` | Audio & subtitles sheet | Bottom sheet | new |
| 5 · Modal sheets | 14 | `quality` | Streaming quality sheet | Bottom sheet | new (stub-disabled — §6) |
| 5 · Modal sheets | 15 | `speed` | Playback speed sheet | Bottom sheet | new |
| 5 · Modal sheets | 16 | `sleep` | Sleep timer sheet | Bottom sheet | new |
| 5 · Modal sheets | 17 | `cast` | Cast picker sheet | Bottom sheet | new (stub-disabled — Phase 5+) |
| 6 · Features | 18 | `xray` | X-Ray panel | Side panel over player | new (UI shell only — §1 row 4) |
| 6 · Features | 19 | `group-watch` | Group Watch (party) | Modal | new (placeholder only — §1 row 4) |
| 6 · Features | 20 | `offline` | Offline / empty state | Plain | new |
| 7 · Account | 21 | `downloads` | Downloads | Tab shell | new |
| 7 · Account | 22 | `profile` | Profile / Account | Tab shell | new |
| 8 · Beyond video | 23 | `files-browser` | All files (categorized) | Plain | replaces [`files_screen.dart`](../../apps/mobile/lib/features/library/presentation/screens/files_screen.dart) |
| 8 · Beyond video | 24 | `doc-viewer` | PDF / document viewer | Plain | new |
| 8 · Beyond video | 25 | `photo-viewer` | Photo viewer (full-bleed) | `bg=#000` | new |
| 8 · Beyond video | 26 | `music-player` | Music player (now playing) | Plain | new |
| 9 · Phone-as-server | 27 | `host-server` | Host a server | Plain | new (Phase 5+ feature shell) |
| 9 · Phone-as-server | 28 | `signin` | Sign-in / 2FA | Plain | replaces [`pairing_screen.dart`](../../apps/mobile/lib/features/auth/presentation/screens/pairing_screen.dart) |

### 3.2 Navigation map

```
splash ──► signin ──► server ──► home (default tab)
                              └► host-server   (alt: become a server)

home ──► detail ──► player-portrait ⇄ player-landscape (rotate)
     │            └► episodes (if show) ──► player-portrait
     │
     ├► mini-player (when something is playing in background)
     └► music-player (if music tile)

library ──► detail | files-browser (per category)
files-browser ──► doc-viewer | photo-viewer | music-player

search ──► detail
notifications ◄── from app bar bell icon (any tab)

profile ──► host-server, signin (if signed out)
downloads ──► detail (resumes offline)

— While player is open —
player-portrait ──► [audio-subs | quality | speed | sleep | cast] (bottom sheets)
player-portrait ──► xray (side panel) | group-watch (modal)
```

Bottom sheets are not routes — they are launched with `showFluxBottomSheet(...)`.

### 3.3 Tab shell

5 tabs, prototype `TAB_ITEMS` order preserved:

| # | id | label | icon (Lucide) |
|---|----|-------|--------------|
| 1 | `home` | Home | `LucideIcons.layoutDashboard` |
| 2 | `library` | Library | `LucideIcons.bookOpen` |
| 3 | `search` | Search | `LucideIcons.search` |
| 4 | `downloads` | Downloads | `LucideIcons.download` |
| 5 | `profile` | Profile | `LucideIcons.user` |

Tab bar background `rgba(8,6,20,0.92)` with `BackdropFilter.blur(20)`. Active tab: violet text + bold; inactive: `textDim` + 500. Crossfade 150 ms on switch.

---

## 4. Brand tokens — prototype `M` → existing `AppColors`

Every prototype token resolves to an **already-shipped** `AppColors` member. **Do not add new tokens.** Where the prototype value diverges marginally (alpha tweaks), use the existing token unless the visual gap is plainly broken — then escalate to the owner before adding anything.

| `M.*` token | Hex | Use existing `AppColors.*` | Notes |
|---|---|---|---|
| `bg` | `#08061A` | `bgRoot` | Scaffold base. Exact match. |
| `bgRaised` | `#0F0C24` | `bgRoot` *(see notes)* | Prototype lifts this slightly above `bg`. **Resolution:** use `bgRoot` everywhere; lift via the existing `surfaceGlass` over a translucent overlay where a card visibly needs to rise. Do not add a new token. |
| `bgCard` | `rgba(20,18,38,0.85)` | `surfaceGlass` *(rgba 20,18,38,0.7)* | Existing token is the same RGB at slightly lower alpha (0.7 vs 0.85). Use it. |
| `border` | `rgba(255,255,255,0.06)` | `borderSubtle` | Exact match. |
| `borderStrong` | `rgba(255,255,255,0.12)` | `borderSubtle` *(see notes)* | No exact white-strong border token exists. **Resolution:** use `borderSubtle` for default borders; for focused inputs, lean on `borderHover` (purple) per V2 hover convention. Do not add a white-strong variant. |
| `fg` | `#F1F5F9` | `textBright` | Exact match. |
| `fgMuted` | `#94A3B8` | `textMutedV2` | Exact match. |
| `fgDim` | `#64748B` | `textDim` | Exact match. |
| `accent` | `#A855F7` | `violet` | Exact match. |
| `accent2` | `#8B5CF6` | `violetDeep` | Exact match. |
| `accentSoft` | `rgba(168,85,247,0.16)` | `pillBgPurple` | Exact match. |
| `cyan` | `#22D3EE` | `cyan` | Exact match. |
| `pink` | `#EC4899` | `pink` | Exact match. |
| `success` | `#10B981` | `emerald` *(or `statusOnline`)* | Exact match. |
| `warn` | `#F59E0B` | `amber` *(or `statusIdle`)* | Exact match. |
| `danger` | `#EF4444` | `red` *(or `statusError`)* | Exact match. |

### 4.1 Background gradient

Apply to scaffold body (not status bar) via a `Stack`:

```dart
Stack(children: [
  ColoredBox(color: AppColors.bgRoot),
  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.topLeft,
      radius: 1.2,
      colors: [Color(0x2EA855F7), Colors.transparent], stops: [0, 0.5],
    ),
  ))),
  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.bottomRight,
      radius: 1.0,
      colors: [Color(0x1A22D3EE), Colors.transparent], stops: [0, 0.5],
    ),
  ))),
  child,  // the routed Scaffold
]);
```

Wrap once at the router level; each screen's `Scaffold.backgroundColor` is `Colors.transparent`.

### 4.2 Type scale — prototype role → existing `AppTypography` style

The V2 styles already shipped in [`AppTypography`](../../packages/fluxora_core/lib/constants/app_typography.dart) (lines 102-207) cover every role the prototype needs. **Do not add a `MobileTextStyles` class.** Where the prototype's exact metric diverges (e.g. 22/800 display vs `displayV2` 24/700; 17/700 app-bar title vs `h1` 18/700), use the existing token — these are within ±1 px / ±100 weight units and not visually material.

| Prototype role | Prototype metric | Use existing `AppTypography.*` | Notes |
|---|---|---|---|
| Display title | 22/800/1.15/-0.3 | `displayV2` *(24/700/1.1/-0.24)* | Closest existing display style; -1 px tracking, -100 weight. Acceptable. |
| Screen title (app bar) | 17/700/1.2/-0.1 | `h1` *(18/700/1.3)* | +1 px size; matches V2 page-title weight already used on desktop. |
| Section heading | 14/700/1.3 | `h2` *(14/600/1.4)* | Same size, -100 weight. Acceptable. |
| Section eyebrow (UPPERCASE) | 11/700/1.2/1.4 | `eyebrow` *(11/600/1.4/1.54)* | -100 weight, slightly tighter line height. Acceptable. |
| Body | 13.5/500/1.5 | `body` *(13/500/1.4)* | -0.5 px size; half-pixel rounded down. Acceptable. |
| Body small | 12/500/1.4 | `bodySmall` *(12/500/1.4)* | Exact match. |
| Caption | 11/500/1.4 | `captionV2` *(11/500/1.4)* | Exact match. |
| Tab label | 10.5/500-700/1/0.1 | `micro` *(10.5/500/1.4)* | Same size. Tab-active variant: pass `fontWeight: FontWeight.w700` at the call site via `.copyWith(...)`. Don't add a new token. |
| Status-bar time | 14/600/1/0.2 | `body.copyWith(fontSize: 14, fontWeight: w600)` | The OS draws the system status bar; this only matters in the prototype phone-shell which we don't ship (§5.1). |
| Mono — timestamps in player / logs | 13/500 | `monoBody` / `monoCaption` / `monoMicro` | Already exists. |

`AppColors` defaults baked into each style (e.g. `displayV2 → textBright`, `body → textBody`, `eyebrow → textDim`) match the prototype's `M.fg` / `M.fgMuted` / `M.fgDim` defaults. Override per-call via `.copyWith(color: ...)` only when the design demands a non-default colour (e.g. quality badge in violet).

### 4.3 Radii / spacing / shadows / icons — use existing tokens

- **Radii:** consume [`AppRadii`](../../packages/fluxora_core/lib/constants/app_radii.dart) — `xs=6` (chip), `sm=8` (small button), `md=10` (input / hover-tile), `lg=12` (card), `pill=9999`. Prototype's 9 (icon button), 14 (raised card), 18 (album art) have no exact match — round to `sm` (8), `lg` (12), and a hard-coded `BorderRadius.circular(18)` *only* for the 280×280 album art (single use case; do not add a token).
- **Spacing scale:** consume [`AppSpacing`](../../packages/fluxora_core/lib/constants/app_spacing.dart) — `s4`, `s6`, `s8`, `s10`, `s12`, `s14`, `s16`, `s18`, `s22`, `s28` are all already present. Cards padded `s14`. Screen-edge padding `s16`–`s22`.
- **Shadows:** consume [`AppShadows`](../../packages/fluxora_core/lib/constants/app_shadows.dart) — `cardGlow` for emphasised cards, `buttonGlow` for primary CTAs (already a violet glow), `dotGlow(color)` for live status indicators. The prototype's "card shadow" (`0 6px 22px rgba(0,0,0,0.45)` + 1 px inset border) is a *neutral* shadow with no existing token — use a plain `Border.all(color: AppColors.borderSubtle)` and skip the drop shadow on standard cards (the V2 desktop already standardises on glass-borderless cards). For the floating-accent shadow on the player play-button and album art, use `AppShadows.buttonGlow` (it's the same violet glow at the same intensity).
- **Icon stroke:** 1.6 px Lucide. Use `lucide_icons: ^0.x` package; defaults to 1.6 px.

---

## 5. Component inventory

These widgets are built **first** (M0–M1) so every screen can compose them. All live in `packages/fluxora_core/lib/widgets/` unless noted.

| Widget | File | Description |
|---|---|---|
| `FluxAppBar` | `flux_app_bar.dart` | Mobile app bar (52 px). `bg=rgba(8,6,20,0.85)` blur 20, optional `leading`/`trailing`/`onBack`. `transparent` variant for player + photo viewer. |
| `FluxBottomTabs` | `flux_bottom_tabs.dart` | 5-item bottom tab bar. Active = violet + 700; inactive = `textDim` + 500. |
| `FluxChip` (renamed from desktop `Pill`) | `flux_chip.dart` | Pill chip — radius 999, 7×14 padding, 12.5/600. Active variant: violet border + `pillBgPurple` bg. |
| `FluxButton` *(lifted from desktop)* | `flux_button.dart` | Primary (gradient `violetDeep→violet`), secondary (raised glass), destructive (red tint). |
| `FluxTextField` | `flux_text_field.dart` | 48 px tall, radius 10, `rgba(255,255,255,0.04)` bg. |
| `FluxPoster` | `flux_poster.dart` | Poster card with `art` (gradient fallback) + `img` (network) + optional quality badge + title overlay. Sizes 116×174 (rail) / 150×220 (hero) / full-width (detail). |
| `FluxRow` | `flux_row.dart` | Settings row — 36×36 violet-tinted icon square + label/sub stack + optional trailing. Used in profile, host-server. |
| `FluxSectionHeader` | `flux_section_header.dart` | UPPERCASE 11 px eyebrow in `textDim` + 14 px bold heading. Used everywhere. |
| `FluxBottomSheet` | `flux_bottom_sheet.dart` | Skeleton: drag handle + title row + scrollable body. Used by all 5 player sheets. |
| `FluxMiniPlayer` | `flux_mini_player.dart` | 64 px persistent bar above bottom tabs. Poster 48×48 + title/sub + play + close. Mobile-only (lives in `apps/mobile/lib/shared/widgets/`). |
| `FluxStatusDot` | (re-export of desktop) | Already exists in core. |

### 5.1 Phone shell ≠ Flutter shell

The prototype's `<Phone>` component (38 px bezel, fake notch, status bar) **is not ported**. It exists only because the prototype runs in a browser. Flutter screens render full-screen on the OS chrome.

`SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light)` everywhere except the photo viewer.

---

## 6. New dependency justifications (Hard Prohibition #6)

| Package | Why | Alternative considered | Latest? |
|---|---|---|---|
| `google_fonts: ^6.x` | Inter (5 weights) at runtime — prototype's primary font. | Bundle Inter as asset (~250 KB). Runtime download is smaller and cached. | Check pub.dev at M0. |
| `lucide_icons: ^0.x` | 1.6 px Lucide icons — prototype maps every icon to Lucide. | `flutter_lucide` exists too; pick whichever is more recently maintained. | Check pub.dev at M0. |
| `just_audio: ^0.x` + `audio_service: ^0.x` | Music player + lockscreen / background controls. `media_kit` doesn't expose iOS audio session config we need. | `audioplayers` lacks lockscreen integration. | Check pub.dev at M9. |
| `pdfx: ^2.x` *(or `syncfusion_flutter_pdfviewer`)* | PDF viewer for `doc-viewer` screen. | Sumitomo PDF requires license; `pdfx` is MIT. | Check pub.dev at M11. |
| `photo_view: ^0.x` | Pinch-zoom for `photo-viewer`. `InteractiveViewer` works but lacks gesture polish (snap-back, double-tap to zoom). | Built-in `InteractiveViewer` if dep is unmaintained. | Check pub.dev at M11. |
| `screen_brightness: ^2.x` | Player left-rail brightness control. | Visual-only HUD overlay if package is unmaintained. | Check pub.dev at M5. |
| `cached_network_image: ^3.x` | Poster + thumb network image cache. | Already used in desktop — verify version, may already be a transitive dep. | Check pub.dev at M0. |
| `mobile_scanner: ^x` *(deferred)* | QR sign-in. Postpone until M14 (host-server / 2FA). | — | Defer. |

### 6.1 Deferred / blocked

- **Quality switching:** server emits a single HLS playlist per stream. Multi-quality requires either an HLS master playlist (preferred — `media_kit` switches automatically) or a `GET /api/v1/stream/{id}/qualities` + restart-on-pick path. Ship **Quality** chip stub-disabled with "Auto" label; activation tracked separately.
- **Episodes / chapters:** server has no TV-show grouping or chapter markers. Episodes button + chapter ticks are stub-rendered (greyed). Backend work is its own ticket.
- **Casting:** `flutter_cast_video` exists for Chromecast and AirPlay needs a platform channel on iOS. Both deferred to Phase 5+; Cast button is a **disabled stub** (visible, greyed, tooltip "Casting coming soon").

---

## 7. Milestones

Each milestone is one PR. Mobile tests live under `apps/mobile/test/`.

| Milestone | Scope | Depends on |
|---|---|---|
| **M0 — Foundation (no theme additions)** | **No new theme tokens, no new theme classes.** All consumption goes through existing `AppColors` / `AppTypography` / `AppRadii` / `AppSpacing` / `AppShadows`. Add the runtime deps that aren't yet present: `google_fonts`, `lucide_icons`, `cached_network_image` (verify each isn't already a transitive dep first). Build the global background-gradient `Stack` widget (mobile-only `BackgroundGradient` widget under `apps/mobile/lib/shared/widgets/`, wraps router children). `flutter analyze` green. Zero visual change to the live app. | — |
| **M1 — Shared widgets lift** | Move `FluxButton` + desktop `Pill` (rename `FluxChip`) into `fluxora_core/lib/widgets/`. Build new core widgets: `FluxAppBar`, `FluxBottomTabs`, `FluxBottomSheet`, `FluxPoster`, `FluxRow`, `FluxSectionHeader`, `FluxTextField`. Desktop call-sites updated to core imports in same PR (one-line shim or full delete). Golden tests for each new widget (light + dark colorscheme variants). | M0 |
| **M2 — Tab shell + go_router migration** | New `MobileShell` widget = `Scaffold` + `IndexedStack` of 5 tab bodies + `FluxBottomTabs`. Migrate router to `ShellRoute` for tabbed routes. Deep-link routes (`/detail/:id`, `/player/:id`, etc.) bypass shell. Each tab body is a placeholder in this PR. | M1 |
| **M3 — Discover surfaces (home + library + search + notifications)** | Full builds of: `home` (continue-watching + trending + recently-added rails), `library` (filter chips + sort + grid/list), `search` (empty state + active state with sectioned results), `notifications` (grouped today/week/earlier). Pull-to-refresh on home / library / notifications. Mock-data adapter that matches `FluxData` / `FluxData2` shapes — wired to existing library API endpoints where possible; mock for the rest. | M2 |
| **M4 — Title detail + episodes** | `detail` screen (hero + actions + synopsis + cast + crew + similar). `episodes` screen for shows (season picker + episode rows with progress). Both pull from existing `MediaFile` + new (mock-for-now) show / episode endpoints. | M3 |
| **M5 — Player chrome rebuild (portrait + landscape)** | Replace `_VideoView` with `Stack(Video + FluxPlayerControls)`. Build `PlayerControlsController`. Top bar / center transport / progress bar / quick-action grid / side rails (visual only, no drag). Tap to toggle visibility, 3 s auto-hide. `_ResumeBanner` + `_TransportBadge` migrated and restyled to V2. Both portrait + landscape layouts. Existing 25 player tests stay green. | M2 (no detail dep — player is reachable directly) |
| **M6 — Player gestures + sheets** | Double-tap left/right seek ±10 s + ripple. Vertical drag = brightness (`screen_brightness`) / volume (`Player.setVolume`). Horizontal drag = scrub. Long-press = 2× peek. Pinch = fit toggle. Build all 5 bottom sheets (`audio-subs` / `quality` / `speed` / `sleep` / `cast`). Quality + Cast are stub-disabled. Lock mode + hold-to-unlock overlay. | M5 |
| **M7 — Mini-player (PiP) + drag-down minimize** | `FluxMiniPlayer` widget (mobile-only, lives in `apps/mobile/lib/shared/widgets/`). Persistent bar above bottom tabs when something is playing in background. Tap → expand to full player. Drag handle on player → swipe down → minimize. Shared `PlaybackProvider` that both player + mini-player listen to. | M5 |
| **M8 — Downloads + Profile + Notifications wiring** | `downloads` tab (storage indicator + tabs All/Active/Completed + per-row pause/resume/delete/play-offline). `profile` tab (avatar + plan badge + sections via `FluxRow`). Wire notifications to real backend endpoint when available; mock otherwise. Sign-out flow. | M3 |
| **M9 — Cutover: delete legacy mobile palette + rewrite theme body** | Remove `AppColors.primary` (indigo `#6366F1`), `accentPurple` (superseded by `violet`), `surfaceMuted`, `primaryVariant`, etc. Remove legacy `AppTypography` styles (`displayLg`, `displayMd`, `headingLg`, `headingMd`, `headingSm`, `bodyLg`, `bodyMd`, `bodySm`, `caption`, `label`) once no remaining call-sites import them. **Rewrite the body of [`apps/mobile/lib/shared/theme/app_theme.dart`](../../apps/mobile/lib/shared/theme/app_theme.dart) in-place** to consume V2 tokens (`bgRoot`, `violet`, `surfaceGlass`, `textBright`, `h2`, `body`, etc.) — keep the file path and the `AppTheme.dark` getter signature unchanged. Verify desktop import paths still resolve (`fluxora_core/lib/constants/` is shared). `flutter analyze` green on both apps. **This is the breaking PR** — no rollback after merge. | M3 + M5 + M8 |
| **M10 — X-Ray panel + Group Watch shell + Offline state** | `xray` side panel that slides over player (driven by static cast metadata only — no live ML, decision §1 row 4). `group-watch` modal placeholder ("Coming soon — invite link copy works, sync does not"). `offline` empty state. | M5 |
| **M11 — Beyond-video: files browser + PDF + photo + music viewers** | `files-browser` categorized grid + recents. `doc-viewer` (`pdfx`). `photo-viewer` (`photo_view`). `music-player` (`just_audio` + `audio_service`, lockscreen + background audio). Share `MediaFile.kind` field on existing entity to route to the right viewer. | M4 + M9 |
| **M12 — Onboarding revamp** | New `splash` screen (centered wordmark + tagline + 2 CTAs). Rewrite `signin` (email + password + 2FA TOTP + QR + invite-code paths — TOTP wiring placeholder if backend isn't ready). Server picker rebuilt as `server` screen with LAN-discovered list + recently-used + manual entry + remote sign-in. | M2 |
| **M13 — Host-a-server shell** | `host-server` screen (running hero card + auth / sharing / performance sections via `FluxRow`). Toggles drive **placeholder** state for now — the actual phone-as-server runtime is Phase 5+. UI shell ships so the menu is reachable. | M8 + M12 |
| **M14 — Polish + a11y + golden tests** | All animations to spec (fade 250 ms, transport press 50 ms, ripple 400 ms, tab scale 1.0→1.05). `Semantics` labels on every interactive element. Focus traversal. System text-scale clamped to 1.3×. Golden tests for top bar, transport, progress bar, side rails, mini-player, bottom sheet, poster, app bar. Manual QA on real Android + iOS — landscape + portrait + WebRTC + HLS + with/without resume. | All prior milestones |

> Optional later milestones — quality switching (server-side HLS multi-variant), chapter markers (server-side schema + UI ticks), live X-Ray ML, Group Watch sync engine, Casting (Chromecast + AirPlay), phone-as-server runtime — each is its own ticket and is **not** part of the redesign cutover.

---

## 8. Files to add / modify (high-level map)

### 8.1 New under `packages/fluxora_core/lib/widgets/` (M1)

```
flux_app_bar.dart
flux_bottom_tabs.dart
flux_chip.dart                  ← rename + lift of desktop Pill
flux_button.dart                ← lift of desktop FluxButton
flux_text_field.dart
flux_poster.dart
flux_row.dart
flux_section_header.dart
flux_bottom_sheet.dart
```

`fluxora_core/lib/fluxora_core.dart` re-exports each.

### 8.2 New under `apps/mobile/lib/shared/` (M0–M2)

```
widgets/
  flux_mini_player.dart         ← mobile-only
  background_gradient.dart      ← global Stack wrapper (radial gradients + bgRoot fill)
data/
  gradient_parser.dart          ← parses "linear-gradient(135deg, #aaa, #bbb 40%, #ccc)" → Flutter LinearGradient (for mock-data `art` strings)
```

**No new theme files.** [`apps/mobile/lib/shared/theme/app_theme.dart`](../../apps/mobile/lib/shared/theme/app_theme.dart) stays at the same path — its body is rewritten at M9 to consume V2 tokens. No `mobile_text_styles.dart`, no `mobile_theme.dart`, no `mobile_gradients.dart`. Type scale lives in [`AppTypography`](../../packages/fluxora_core/lib/constants/app_typography.dart) (already shipped); art-gradient parser is data-layer, not theme-layer.

### 8.3 New under `apps/mobile/lib/features/` (M3–M13)

```
home/         home_screen.dart         home_cubit.dart         widgets/poster_rail.dart
search/       search_screen.dart       search_cubit.dart
notifications/ notifications_screen.dart
detail/       detail_screen.dart       detail_cubit.dart
episodes/     episodes_screen.dart
player/       (modified — see §8.4)
                  controllers/player_controls_controller.dart
                  widgets/flux_player_controls.dart
                  widgets/flux_player_top_bar.dart
                  widgets/flux_player_side_rail.dart
                  widgets/flux_player_transport.dart
                  widgets/flux_player_progress_bar.dart
                  widgets/flux_player_quick_actions.dart
                  widgets/flux_player_lock_overlay.dart
                  widgets/flux_player_drag_hud.dart
                  widgets/flux_player_seek_ripple.dart
                  sheets/audio_subs_sheet.dart
                  sheets/quality_sheet.dart
                  sheets/speed_sheet.dart
                  sheets/sleep_sheet.dart
                  sheets/cast_sheet.dart
                  xray_panel.dart
                  group_watch_screen.dart
downloads/    downloads_screen.dart    downloads_cubit.dart
profile/      profile_screen.dart      profile_cubit.dart
files/        files_browser_screen.dart
              doc_viewer_screen.dart
              photo_viewer_screen.dart
              music_player_screen.dart  music_cubit.dart
host/         host_server_screen.dart
onboarding/   splash_screen.dart       signin_screen.dart      server_picker_screen.dart
```

### 8.4 Modified under `apps/mobile/lib/`

| File | Change | Milestone |
|---|---|---|
| `core/router/app_router.dart` | Replace flat routes with `ShellRoute` for tabbed routes + deep-link routes for detail / player / files. Routes named to match prototype IDs (§3.1). | M2 |
| `app.dart` | Wrap `MaterialApp.router` body with global `BackgroundGradient` `Stack`. | M0 |
| `features/library/presentation/screens/library_screen.dart` | Rebuilt against new `library` design (filter chips + grid). | M3 |
| `features/library/presentation/screens/files_screen.dart` | Renamed → `files_browser_screen.dart` and rebuilt against new `files-browser` design. | M11 |
| `features/player/presentation/screens/player_screen.dart` | `_VideoView` body replaced with `Stack(Video + FluxPlayerControls)`. `_SettingsSheet` deleted (replaced by per-feature sheets). | M5 |
| `features/connect/presentation/screens/connect_screen.dart` | Renamed → `server_picker_screen.dart` and rebuilt. | M12 |
| `features/auth/presentation/screens/pairing_screen.dart` | Renamed → `signin_screen.dart` and rebuilt. | M12 |
| `pubspec.yaml` | Add deps per §6, in the milestones that need them. | rolling |
| `shared/theme/app_theme.dart` | Body rewritten in-place at M9 cutover to consume V2 tokens. File path and `AppTheme.dark` getter signature unchanged. | M9 |

### 8.5 Modified docs (every milestone)

- `docs/00_overview/current_status.md` — add line per milestone.
- `docs/08_frontend/01_frontend_architecture.md` — mobile section grows with each new feature.
- `docs/10_planning/01_roadmap.md` — Phase 5 row updated as milestones land.
- `AGENT_LOG.md` — per-session entry.

---

## 9. State model

### 9.1 `PlayerControlsController extends ChangeNotifier`

```dart
class PlayerControlsController extends ChangeNotifier {
  bool _visible = true;        // Top/side/bottom overlays shown.
  bool _lockMode = false;      // Disables every gesture except unlock.
  bool _fitCover = true;       // false = letterbox.
  Timer? _autoHide;            // 3 s idle → setInvisible.

  _DragKind? _activeDrag;      // brightness | volume | seek | null.
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

### 9.2 `PlaybackProvider` (Riverpod or Cubit, TBD at M7)

Shared between fullscreen player + mini-player. Owns the `Player` instance reference + current `MediaFile` + position / duration / playing snapshot. The mini-player listens to this; the fullscreen player reads `Player.state` streams directly for tick-rate updates.

### 9.3 Per-feature cubits

One `Cubit` per feature (home, search, downloads, profile, etc.) — each owns its data fetching + filtering + paging. The current `LibraryCubit` pattern is kept and extended.

### 9.4 What gets read directly from `Player` (no cubit round-trip)

```dart
player.stream.position    // Stream<Duration>
player.stream.buffer      // Stream<Duration>
player.stream.duration    // Stream<Duration>
player.stream.playing     // Stream<bool>
player.stream.volume      // Stream<double>
player.stream.rate        // Stream<double>
player.stream.tracks      // Stream<Tracks>
player.stream.track       // Stream<Track>
player.stream.completed   // Stream<bool>
```

Each overlay widget subscribes to only the streams it needs (via `StreamBuilder` + `RepaintBoundary`) — no global rebuild on every position tick.

---

## 10. Behaviors & motion (prototype § 9)

| Behavior | Spec |
|---|---|
| Pull-to-refresh | Home, Library, Downloads, Notifications. Use violet `RefreshIndicator`. |
| Bottom-tab switching | Crossfade 150 ms. Selected icon scales 1.0 → 1.05 with weight bump to 700. |
| Pressed states | `InkWell` with `splashColor: pillBgPurple`, `highlightColor: rgba(255,255,255,0.04)`. |
| Player auto-hide | Controls fade 250 ms after 3 s idle; tap anywhere on video → fade in. |
| Skeleton loading | While fetching, `Shimmer` (opacity 0.06 → 0.12 stripes) on poster cards / rows. |
| Pull-down on player | Drag handle → swipes down → minimizes to mini-player. |
| Rotation | Auto-rotate enabled in `player-portrait` only. Other screens portrait-locked. |
| Status bar | `SystemUiOverlayStyle.light` everywhere except photo viewer (skip dark variant if too complex). |
| Haptics | Light impact on tab switch, selection, primary button press. |

---

## 11. Accessibility

- Minimum hit-target **44×44 px** (already met by prototype).
- Every icon-only button gets a `Semantics(label: ...)`.
- Color contrast: `textBright` on `bgRoot` = AAA; `textMutedV2` on `bgRoot` = AA. **Never use `textDim` for body text.**
- Player controls expose seek/skip via screen reader.
- Subtitle rendering must support OS-level captions style settings.
- Honor system text-scale up to 1.3× (cap to keep layout); fonts in design are `px`-equivalent, so scale via `MediaQuery.textScaler.clamp(maxScaleFactor: 1.3)`.

---

## 12. Risks

| Risk | Mitigation |
|---|---|
| `media_kit_video`'s `Video` widget repaints on every frame; layered `CustomPainter` overlays could cost FPS on low-end Android. | Wrap each overlay in `RepaintBoundary`. Use `StreamBuilder` per-widget so unrelated streams don't trigger rebuilds. |
| `screen_brightness` / `pdfx` / `photo_view` — any of these unmaintained at execution time. | Each has a documented fallback (visual-only HUD / `InteractiveViewer` / built-in `pdfx` rivals). |
| V2 palette migration in the middle of a player redesign. Touching every screen at once = broad regression risk. | M0 + M1 are tokens / widgets only — zero visual change. M2–M8 migrate screen-by-screen with `flutter analyze` gating each PR. M9 deletes legacy palette in one explicit cutover commit. |
| Background gradient + glass blur on every screen could cost FPS on low-end devices. | Gradient is two static `RadialGradient`s painted once at the router level — not per-screen. Backdrop blur only on app bars + tab bar (small surface area). |
| Lock-mode swallows all gestures — easy to make user feel trapped. | Hold-to-unlock has a clear visible hint that fades back in on any tap; double-tap-with-three-fingers also unlocks (system fail-safe). |
| Mini-player + fullscreen player both touching the same `Player` instance → race conditions on transition. | One `PlaybackProvider` owns the `Player` instance. Both UIs are subscribers, never owners. The fullscreen route on push reads from the provider (no new instance). |
| 28 screens at once = months of work; risk of drift between plan and code. | Update this file at the end of every milestone. The plan is the source of truth, not the JSX. |

---

## 13. Definition of done

The redesign ships when:
- All M0–M14 milestones merged.
- `flutter analyze` green for `apps/mobile` and `packages/fluxora_core`.
- `flutter test apps/mobile` green (existing 25 tests + new tests per milestone).
- Golden images per overlay component (`top_bar`, `transport`, `progress_bar`, `side_rail_left`, `side_rail_right`, `lock_overlay`, `mini_player`, `bottom_sheet`, `app_bar`, `poster`).
- Manual QA on a real Android device + a real iOS device against an active LAN stream **and** a WebRTC stream.
- `docs/00_overview/current_status.md`, `docs/08_frontend/01_frontend_architecture.md`, `docs/10_planning/01_roadmap.md` updated.
- This plan's "Status" line at top updated to ✅ Done with the merge date.

---

## 14. (Reference) Per-screen specs

These are condensed specs for each screen — enough to build it without re-reading the prototype JSX. For pixel-level fidelity, refer to the matching JSX file in `docs/11_design/prototype/app/mobile/screens/`.

### Splash / Sign-in entry — `splash`
Centered wordmark + tagline + two CTAs ("Sign in" primary, "Set up a server" secondary). Footer: version + tiny "Privacy · Terms". On launch: splash for ~800 ms then push `signin` if no token, else `home`.

### Server picker — `server` *(replaces `connect_screen.dart`)*
App bar "Choose a server". Top: "On this network" with discovered LAN servers (icon `server` + name + IP + latency badge with pulsing dot). Below: "Recently used" + "Add manually" + "Sign in to a remote server". Tap → connects → routes to `home`.

### Home / Discover — `home`
App bar: avatar (left) + Fluxora logo (center) + bell + cast (right). Sections: **Continue watching** (poster 116×174 + progress bar 3 px + resume time chip), **Trending now**, **Recently added**, **Your music** (square album art mini-rail), **Documents** quick-access tiles. Pull-to-refresh.

### Library — `library` *(replaces existing)*
App bar "Library" + filter chips (All · Movies · Shows · Music · Photos · Documents) + grid/list toggle + sort menu (Recently added / A-Z / Year / Rating). Default 3-up grid with title + year underneath posters.

### Search — `search`
App bar with text field "Search Fluxora", scan/voice icons trailing. Empty state: "Recent searches", "Try" suggestion chips, popular categories. Active state: top-3 results horizontal rail, then sectioned (Movies / Shows / People).

### Notifications — `notifications`
App bar with back + "Mark all read". Grouped: Today / This week / Earlier. Each row: round colored icon + title + sub + timestamp + unread dot.

### Detail — `detail`
Hero (full bleed, ~340 px): backdrop image + dark gradient + title + meta (year · rating · duration · quality badge). Primary "▶ Play" (gradient). Secondary: + Watchlist · Download · Share · Cast. Synopsis (3 lines, "more" expand). Cast row · Crew · Trailers · Similar titles · Reviews.

### Episodes — `episodes`
App bar with show title. Season selector chips. Episode list rows: thumbnail 120×68 + title + date + duration + progress bar.

### Player · Portrait — `player-portrait` *(replaces existing player)*
Top half: video tile (220 px) with transparent app bar (back, ext-link, grid, more) + center transport (rewind 10 / play-pause / forward 10) + progress bar with violet thumb. Bottom half: title (22/800) + meta row + 4×2 quick-control grid (Audio · Subs · Cast · Speed · Quality · Sleep · Episodes · More) + "Up next" card with auto-play countdown + Play CTA.

### Mini-player — `mini-player`
Persistent 64 px bar above bottom nav. Poster 48×48 left + title/sub middle + play + close right. Tap bar → expand to full player.

### Player · Landscape — `player-landscape` *(replaces existing landscape branch)*
892×412. No status bar. Same controls as portrait, laid out as horizontal strips: top bar (back + X-Ray chip + center title with audio/quality pills + ext-link/msg/layers/more) + left brightness rail with bulb shield button + center transport (rewind/play/forward with chapter ticks under progress) + right volume rail with mute button + bottom progress bar + bottom-bar with Lock/Screen/Speed/Audio + Episodes pill + Next/Playlist/Resize/More.

### Player legend — `legend`
**Do not ship.** Designer's reference of gestures.

### Bottom sheets — `audio-subs` / `quality` / `speed` / `sleep` / `cast`
All share skeleton: phantom backdrop `rgba(0,0,0,0.55)` + sheet `bg=#0F0C24` top-radius 18 + drag handle 40×4 + title 17/700 + selectable rows with violet check on selected.
- **Audio & subs:** two tabs (Audio / Subtitles), rows include language and codec.
- **Quality:** Auto / 4K / 1080p / 720p / 480p — current selection has check. *(Stub-disabled in v1 — §6.)*
- **Speed:** 0.5× / 0.75× / 1× (default) / 1.25× / 1.5× / 2×.
- **Sleep:** Off / 15 min / 30 min / End of episode / Custom…
- **Cast:** discovered devices (TV / speaker / browser); tap → connect. *(Stub-disabled in v1 — §6.)*

### X-Ray — `xray`
Side panel that slides in over player. "On screen now": cast members in current scene (avatar + name + role + more). Sections: "Music in this scene", "Trivia", "Goofs". Static cast metadata only — no live ML in v1.

### Group Watch — `group-watch`
Hero "Watching together". Avatars row at top + reaction tray + chat below. Sync status indicator (everyone within 1 s). **UI shell only in v1** — sync engine is Phase 5+.

### Offline — `offline`
Empty illustration (placeholder svg). Message: "You're offline" + "Showing downloads only". CTA: "View Downloads".

### Downloads — `downloads`
App bar "Downloads" + storage indicator. Tabs: All / Active / Completed. Rows: thumbnail + title + status (downloading 62%, paused, ready) + size. Per-row menu: pause/resume, delete, play offline.

### Profile — `profile`
Hero: avatar + display name + plan badge. Sections (each a `FluxRow`): Account · Server connections · Playback · Downloads · Notifications · Privacy & security · Appearance (theme) · Help · About · Sign out.

### All files — `files-browser` *(replaces `files_screen.dart`)*
Categories grid 2-up: Movies · TV Shows · Music · Photos · Documents · Books & PDFs (each with count + size). Below: "Recent files" list.

### Document viewer — `doc-viewer`
App bar with download + more. Page area on dark; page itself white "paper" with shadow. Bottom toolbar: prev page / page indicator (1 / N) / next page / search.

### Photo viewer — `photo-viewer`
Black bg. Full-bleed photo (`photo_view`). Top: x + filename + date+index + more. Bottom: Share · Edit · Info · Save · Delete.

### Music player — `music-player`
Vertical gradient `#1a0820 → #08061A`. App bar: chevron-down + more. 280×280 album art with deep shadow. Title + artist + album. Scrubber (current / total time). Controls: shuffle · prev · play/pause (64 px gradient circle) · next · queue.

### Host a server — `host-server`
"Running" hero card (green with pulse dot + server name + IP + client count + uptime). Sections via `FluxRow`:
- **Authentication:** Password (on) · 2FA (on) · Pair via QR · Invite codes (3 active).
- **Sharing:** Remote access (on) · Friends & family · Shared libraries.
- **Performance:** Hardware transcode (on) · Background streaming (off).
Destructive button at bottom: Stop server. **UI shell only in v1** — runtime is Phase 5+.

### Sign-in / 2FA — `signin` *(replaces `pairing_screen.dart`)*
Eyebrow + greeting + connecting-to label. Email + Password fields + primary button. Divider "OR". Two secondary buttons: Scan QR to sign in · Use 6-digit invite code. Footer: Terms & Privacy.

---

## 15. (Legacy) Original player-only plan — preserved for reference

The earlier plan (drafted 2026-05-02, scoped to the player screen only) made several decisions that are **superseded** by the whole-app scope above:

- **Superseded — §1 row 4 of the original plan ("keep mobile theme tokens, no v2 palette migration").** Now overridden by §1 row 2 of this plan: **the whole app migrates to V2**. See §1 row 2 for the new decision; §4 for the token map.
- **Superseded — original M1 ("standalone PR to lift `FluxButton`/`Pill`").** Folded into M1 of this plan, which is broader (lifts `FluxButton`, `FluxChip`, `FluxAppBar`, `FluxBottomTabs`, `FluxBottomSheet`, `FluxPoster`, `FluxRow`, `FluxSectionHeader`, `FluxTextField` all in one PR).
- **Carried forward — gestures, side rails, lock mode, sheets.** §3 (gesture map), §3.1–§3.6 (top bar / side rails / center transport / progress bar / quick-action chips), §3 Layer 4 (lock / peek / drag-feedback / ripple overlays), §6 (`screen_brightness` justification + Quality stub-disable), §10 (risks), §11 (definition of done). All of these are absorbed into M5 / M6 / M14 of this plan.
- **Carried forward — owner decisions table (§8 of original plan).** The 6 resolved questions (Q2–Q5 ✅, Q1 ⏸ defer until M5, Q6 ⏸ defer until M5/M6) still apply; only Q2 is now overridden.

The original plan file is preserved in git history (commit `df5234c` and prior). For the player-screen detail that still applies (gesture math, side-rail visuals, button geometry), the canonical source is now §14 of this plan + the prototype JSX.

---

## 16. Changelog

| Date | Change |
|------|--------|
| 2026-05-02 | Initial player-only plan drafted. |
| 2026-05-02 | Owner review pass: keep mobile palette, cast = disabled stub, episodes/chapters deferred, M1 prerequisite approved, execution gate added. |
| 2026-05-03 | **Scope expansion** — plan rewritten to cover the entire mobile app redesign based on the new prototype bundle in `docs/11_design/prototype/`. V2 palette migration is now in scope (§1 row 2 reverses the earlier "keep mobile theme" decision). 14 milestones (M0–M14) replace the original 7. Original player-only sections preserved as §15. |
| 2026-05-03 | **Renamed** `mobile_player_redesign_plan.md` → `mobile_redesign_plan.md` (matches `desktop_redesign_plan.md` convention; reflects whole-app scope). Owner directive: **don't recreate theme infrastructure** — §1 row 2, §4, §4.2, §4.3 revised to consume existing `AppColors` / `AppTypography` / `AppRadii` / `AppSpacing` / `AppShadows` only. M0 no longer adds tokens; M9 rewrites `app_theme.dart` body in-place rather than creating a new theme file. §8.2 + §8.4 updated to match. |
