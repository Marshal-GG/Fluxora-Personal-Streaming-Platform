# Mobile App Redesign — Implementation Plan

> **Status:** M0–M9 landed 2026-05-03. Mobile theme is now V2-pure — legacy `AppColors.{primary,accentPurple,surface,...}` and `AppTypography.{displayLg,headingLg,bodyMd,...}` deleted from `fluxora_core`; both apps share the same V2 token set.  Post-M9 out-of-plan work: Phase A + B real-data backfill 2026-05-04; QR-pairing scanner 2026-05-04; player polish (PIP + audio_service + bg toggle) 2026-05-04; seek-restart wire-up 2026-05-05; **Groups v2 mobile UX (M4 + M6 + M8 of [`docs/10_planning/13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md)) shipped 2026-05-07** — `apps/mobile/lib/features/groups/` adds Profile-screen Locked / Unlocked / Visible Libraries cards + PIN entry / enrollment modals. **Test suite: 64 passing** (was 27 at M0; +37 from feature work above).  Next milestone: **M10 — X-Ray panel + Group Watch shell + Offline state** (note: the prototype's "Group Watch" feature is a separate multi-client party-watch UI, NOT related to "client groups" / Groups v2 — both terms exist; don't conflate them).  Audit completed 2026-05-08 — see §17 for findings + improvised suggestions.
> **Created:** 2026-05-02 (player-scope) · **Expanded + renamed** 2026-05-03 (whole-app scope; was `mobile_player_redesign_plan.md`) · **Audited** 2026-05-08
> **Owner:** Marshal
> **Source design:** [`docs/11_design/prototype/`](./prototype/) (Fluxora Mobile prototype bundle — 28 screens + flow diagram)
> **Prototype port spec:** [`docs/11_design/prototype/app/mobile/README.md`](./prototype/app/mobile/README.md)
> **Target:** [`apps/mobile/lib/`](../../apps/mobile/lib/)
>
> **Theme directive (2026-05-03):** Consume the **existing** `AppColors` and `AppTypography` V2 tokens already shipped to `packages/fluxora_core/lib/constants/`. **Do not add new theme tokens or create a parallel mobile theme file.** Where the prototype value diverges marginally from an existing token (alpha tweaks, half-pixel sizes), use the existing token unless the visual gap is plainly broken — then escalate. The legacy player-only sections (§15) at the bottom are kept intact for reference and cross-link from the new milestone breakdown.
>
> **Trending dropped from scope + ripped out 2026-05-08.** The Home "Trending now" rail and Search "Trending searches" chip group are removed from the design **and from code**. Rationale: Fluxora is single-tenant self-hosted — there is no cross-user popularity signal to back "Trending", and the curator-managed alternative is feature-creep we don't need. Replacements landed: a 4-up Browse strip on Home and a Browse chip group on Search, both routing to `Routes.libraryWithFilter(...)` (new helper). See §17.2 for the (now-archived) implementation handoff.

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
| `just_audio: ^0.10.5` ✅ landed M11 (2026-05-08) + `audio_service: ^0.18.18` (already shipped at M14 player polish 2026-05-04) | Music player. `just_audio` consumes `AudioSource.uri(headers:)` for bearer-token streaming. `audio_service` lockscreen integration for the music handler is **deferred to v1.1** — the existing singleton `FluxoraAudioHandler` is owned by the video `PlayerCubit`, so a separate `MusicAudioHandler` is needed to avoid shared-state conflicts. | `audioplayers` lacks lockscreen integration. | ✅ locked. |
| `pdfx: ^2.9.2` ✅ landed M11 (2026-05-08) | PDF viewer for `doc-viewer` screen. **Note:** pdfx 2.x has no network-loading API, so the screen downloads the file via `GET /api/v1/files/{id}/content` to a temp path before opening with `PdfDocument.openFile`. The temp file is then reused by the "Open in..." share action. | Sumitomo PDF requires license; `pdfx` is MIT. | ✅ locked. |
| `photo_view: ^0.15.0` ✅ landed M11 (2026-05-08) | Pinch-zoom for `photo-viewer`. Uses `NetworkImage(url, headers: {Authorization: Bearer …})` directly — no temp download for viewing. The "Open in..." flow downloads via `dart:io.HttpClient`. | Built-in `InteractiveViewer` if dep is unmaintained. | ✅ locked. |
| `share_plus: ^12.0.2` ✅ landed M11 (2026-05-08) | OS share sheet for "Open in..." flows on doc / photo / "other" file kinds. New 12.x API: `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`. | `flutter_share` is unmaintained. | ✅ locked. |
| `path_provider: ^2.1.5` ✅ landed M11 (2026-05-08) | Promoted from transitive to direct dep at M11 for `getTemporaryDirectory()` (used by doc/photo viewers + files browser "Open in..." downloads). | — | ✅ locked. |
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
| **M0 — Foundation (no theme additions)** ✅ done 2026-05-03 | **No new theme tokens, no new theme classes.** All consumption goes through existing `AppColors` / `AppTypography` / `AppRadii` / `AppSpacing` / `AppShadows`. Added runtime deps: `google_fonts: ^8.1.0`, `lucide_icons_flutter: ^3.1.13` (chosen over the 2-year-stale `lucide_icons` per the plan's "pick whichever is more recently maintained" allowance), and bumped existing `cached_network_image: ^3.3.1` → `^3.4.1`. New `apps/mobile/lib/shared/widgets/background_gradient.dart` mounts the prototype's two-radial brand gradient (topLeft violet alpha 0.18, bottomRight cyan alpha 0.10) over an opaque `bgRoot` fill; wired through `MaterialApp.router`'s `builder` so every routed screen sits over the same painted backdrop. `flutter analyze` clean; 27 mobile tests still pass; existing screens have opaque scaffolds so the gradient is hidden — zero visual change until M2 migrates the shell. | — |
| **M1 — Shared widgets lift** ✅ done 2026-05-03 | Lifted `FluxButton` (desktop → `packages/fluxora_core/lib/widgets/flux_button.dart`) and `Pill` → `FluxChip` (rename, `core/widgets/flux_chip.dart`). Updated 13 desktop call-sites to import from `fluxora_core`. Added 7 new core widgets: `FluxAppBar` (52 px + 20-blur + transparent variant), `FluxBottomTabs` (5-tab nav, violet-active states, light haptic on switch), `FluxBottomSheet` + `showFluxBottomSheet()` helper, `FluxPoster` (rail / hero / full sizes, quality badge, progress bar; `cached_network_image ^3.4.1` newly added as a `fluxora_core` dependency for network image loading), `FluxRow` (settings row with destructive variant), `FluxSectionHeader` (eyebrow + bold heading). All 9 widgets re-exported from `fluxora_core.dart`. **Deferred:** `FluxTextField` — desktop ships its own `flux_text_field.dart` with a different density spec; will unify at M2 / M3 when a mobile screen first needs the input. **Deferred:** golden tests for each widget — added in M14 polish pass alongside screen-level goldens, since the widgets only render meaningfully inside a screen at this stage. `flutter analyze` clean on all three packages; 39 desktop tests + 27 mobile tests + 8 core tests all pass. | M0 |
| **M2 — Tab shell + go_router migration** ✅ done 2026-05-03 | New `apps/mobile/lib/shared/widgets/mobile_shell.dart` wraps `StatefulNavigationShell` with `Scaffold(body: shell, bottomNavigationBar: FluxBottomTabs(...))`. Tab registry uses `LucideIcons.{layoutDashboard,bookOpen,search,download,user}`. `app_router.dart` rewritten as `StatefulShellRoute.indexedStack` with one branch per tab — state preserved across switches. New routes `/home`, `/library`, `/search`, `/downloads`, `/profile` live inside the shell; auth-gate routes (`/connect`, `/pairing`) and full-screen deep-link routes (`/library-files/:id`, `/player`) bypass it. Old `/library/:id/files` path renamed to `/library-files/:id` to disambiguate from the new tab path. `pairing_screen.dart` redirect after successful pair: `Routes.library` → `Routes.home`. Four placeholder tab screens at `features/{home,search,downloads,profile}/presentation/screens/*_screen.dart` (Library tab keeps the existing `LibraryScreen` until M3). Each placeholder is a transparent scaffold so the M0 background gradient is finally visible. `flutter analyze` clean; 27 mobile tests still pass. | M1 |
| **M3 — Discover surfaces (home + library + search + notifications)** ✅ done 2026-05-03 · trending replaced 2026-05-08 | Full builds of all four. `home_screen.dart` (avatar+wordmark+bell+cast app bar; `RefreshIndicator`; **post-rip-out shape: Continue-watching hero rail + 4-up Browse strip (Movies / Shows / Music / Documents) + Recently-added rail** with `FluxPoster` + `FluxSectionHeader`); bell pushes `/notifications`. `search_screen.dart` (mobile-spec `FluxTextField` newly built in `fluxora_core`; **post-rip-out empty-state: Recent searches list + Browse chip group**; active-state with top-3 horizontal rail + sectioned results; no-results fallback). `notifications_screen.dart` (back + Mark-all-read app bar; Today/This week/Earlier bucketing; 36×36 coloured icon squares + relative timestamps + violet unread dots). `library_screen.dart` rewritten with 6 filter chips + grid/list toggle + sort popup; **as of 2026-05-08, accepts `?filter=` query param so the Home strip + Search chip group can pre-filter the tab**. Mock data backs the discover content; the legacy `LibraryRepository` + `/library-files/:id` deep-link still use real backend data and will be replaced at M11 `files_browser`. New `Routes.notifications` route + `Routes.libraryWithFilter(slug)` helper. `flutter analyze` clean × 3 packages; 64 mobile tests still pass post-rip-out. | M2 |
| **M4 — Title detail + episodes** ✅ done 2026-05-03 | `mock_data.dart` extended with `synopsis`/`year`/`rating`/`duration`/`cast`/`crew`/`similarIds`/`seasons` optional fields + new `MockCastMember` / `MockSeason` / `MockEpisode` shapes; `MockData.findById(id)` lookup. New `detail_screen.dart` (hero with full-bleed backdrop + dark fade + meta row; primary Play/Resume + Episodes button for shows; 4-up icon-action row; collapsible synopsis; cast / crew / similar rails). New `episodes_screen.dart` (season chip selector + episode rows with 120×68 thumbnails + violet progress bars). Top-level deep-link routes `/detail/:id` and `/episodes/:id` (bypass the shell). Home / Library / Search posters now route to detail. `flutter analyze` clean × 3 packages; 74 tests pass. | M3 |
| **M5 — Player chrome rebuild (portrait + landscape)** ✅ done 2026-05-03 | `_VideoView` body now `Stack(Video + FluxPlayerControls)` — `MaterialVideoControls` from `media_kit_video` no longer rendered (replaced by a `(state) => SizedBox.shrink()` controls callback). New `PlayerControlsController extends ChangeNotifier` at `features/player/presentation/controllers/` with visibility / lockMode / fitCover toggles + 3-second auto-hide `Timer` + drag-HUD scratchpad. New `FluxPlayerControls` widget at `features/player/presentation/widgets/` — tap-to-toggle scrim, top bar (back + title + more), center transport (rewind 10 / play-pause gradient 72 px / forward 10) wired to `player.seek` + `player.playOrPause`, progress bar via `StreamBuilder<Duration>` over `player.stream.position` / `duration` + violet `Slider` thumb, 8-up quick-action row (Lock + Fit live; Audio/Subs/Speed/Quality/Sleep/Cast stub-disabled until M6 sheets), landscape side rails (Brightness/Volume, visual only), lock-mode unlock chip. `_ResumeBanner`, `_TransportBadge`, `_LoadingView`, `_ErrorView`, `_TierLimitView` all restyled to V2 tokens (`AppColors.violet`, `AppGradients.brand`, `AppTypography.{displayV2,body,captionV2}`, `FluxButton`). All 25 `PlayerCubit` tests still pass — cubit interface untouched. | M2 (no detail dep — player is reachable directly) |
| **M6 — Player gestures + sheets** ✅ done 2026-05-03 | All 5 bottom sheets shipped under `features/player/presentation/sheets/`: `audio_subs_sheet.dart` (DefaultTabController two-tab Audio + Subtitles), `speed_sheet.dart` (6 presets), `sleep_sheet.dart` (Off/15/30/60 live + End-of-episode/Custom stub-disabled; expiry calls `player.pause()`), `quality_sheet.dart` (stub-disabled per §6.1), `cast_sheet.dart` (stub-disabled). All consume the M1 `FluxBottomSheet` skeleton + `showFluxBottomSheet`. `FluxPlayerControls` gestures: **double-tap** left/right halves seek ±10 s + 400-ms violet ripple at tap point + light haptic; **long-press** starts 2× peek (saves prior rate, restores on release) + medium haptic + small `_PeekBadge`; **vertical drag** = brightness on left half (`screen_brightness ^2.1.7` newly added) / volume on right half (`player.setVolume`), with a centred `_DragHud` pill driven by `controller.setBrightnessHud/setVolumeHud`; **pinch-end** = `controller.toggleFit()` + light haptic. Lock chip replaced with a press-and-hold-to-unlock circle + 80×80 violet `CircularProgressIndicator` filling over 1.2 s + medium haptic on success + "Press and hold to unlock" caption. **Deferred to M7/M14:** horizontal-drag scrub (conflicts with M7 drag-down-to-minimize) and the larger ripple animation polish. | M5 |
| **M7 — Mini-player (PiP) + drag-down minimize** ✅ done 2026-05-03 | `PlayerCubit` promoted to a long-lived `GetIt.lazySingleton` (the `PlaybackProvider` per plan §9.2). Cubit refactored: extracted `_disposeCurrentSession()` private; `startStream` re-entry safe; new public `dismiss()` for explicit teardown. New `apps/mobile/lib/shared/widgets/flux_mini_player.dart` — 64-px bar; visible only when state is `PlayerReady`; 48×48 violet-gradient poster + title + tiny violet progress bar + play-pause + X via `StreamBuilder` over `player.stream.{position,duration,playing}`. Mounted in `MobileShell.bottomNavigationBar` as a `Column(MiniPlayer + FluxBottomTabs)` with a 200-ms `AnimatedSize`. New `PlayerScreen.resume()` constructor + `Routes.playerResume = '/player/resume'` route; both push paths (`PlayerScreen({required file})` and the resume variant) use `BlocProvider<PlayerCubit>.value(...)` over the singleton. New `_MinimizeHandle` at top of player (24-px tap target + 36×4 grab pill) — vertical drag accumulates downward delta into `_dragOffset` clamped to 600 px; release ≥ 150 px pops the route, springs back otherwise; while dragging, `Transform.translate` + `Transform.scale` (0.85–1.0) + scaffold-bg opacity (0.4–1.0) animate the dismissal feel. All 25 `PlayerCubit` tests still pass — the singleton refactor preserved external behaviour. | M5 |
| **M8 — Downloads + Profile + Notifications wiring** ✅ done 2026-05-03 | Notifications wired to real `/api/v1/notifications` REST endpoint via new `features/notifications/` repo + cubit + state mirroring the desktop's polling pattern (singleton-scoped so the live tail survives back-pops). Screen rewritten to consume the cubit with bucketed Today/Week/Earlier rendering keyed off `AppNotification.createdAt`, category→icon+color helpers, loading/failure/empty/retry views, tap-to-markRead. Mark-all-read calls `cubit.markAllRead`. Both desktop and mobile carry `// TODO(WS):` markers — true WS migration deferred until a shared HMAC-bearer wrapper exists. Removed unused `MockNotification` class + fixture list. Downloads tab built from the prototype: header (26/800 title + 12.5 muted "26.3 GB used · 64 GB available" + 6-px violet→cyan gradient progress bar at the used-fraction); violet-tinted DOWNLOADING cards (56×80 gradient poster + meta + 4-px violet progress + percent + 32-px round pause button); AVAILABLE OFFLINE flat rows (50×72 poster + meta + expires + 32-px round more button opening a `FluxBottomSheet` with Play offline / Delete download). `mock_data.dart` extended with `MockDownloadStatus` + `MockDownload` + `storageUsedGb`/`storageTotalGb` + 6 fixture entries. Profile tab built from the prototype: header (26/800 title + 38-px round settings icon button); avatar block (radius 16, violet→cyan-radial gradient surface, 64-px circle with violet→pink gradient + initials + glow shadow + name + email + crown PLUS-MEMBER pill); stats row (Hours 284 / Movies 62 / Shows 18, vertical dividers); 9 sectioned `FluxRow`s (Account, Subscription with Plus pill, Downloads, Playback, Language & region, Notifications, Privacy & security, Help & support, About Fluxora v1.0.0 build 482); red-tinted Sign out button → confirm dialog → `playerCubit.dismiss()` + `apiClient.clearBearerToken()` + `secureStorage.deleteAll()` + `context.go(Routes.connect)`. Profile data hardcoded since `/api/v1/profile` is the operator profile, not a per-paired-client surface. `flutter analyze` clean × `apps/mobile` + `packages/fluxora_core`; 27 mobile tests still pass. | M3 |
| **M9 — Cutover: delete legacy mobile palette + rewrite theme body** ✅ done 2026-05-03 | Migrated 7 mobile call-sites + 1 desktop straggler (`clients_screen.dart:1001`) off V1 tokens, then deleted them from `packages/fluxora_core/lib/constants/`. Removed colors: `primary`, `primaryVariant`, `accent`, `accentPurple`, `background`, `surface`, `surfaceRaised`, `surfaceMuted`, `textPrimary`, `textSecondary`, `textMuted`, `textDisabled`, `success`, `warning`, `error`, `info`, `brandGradient`. Removed typography: `displayLg`, `displayMd`, `headingLg`, `headingMd`, `headingSm`, `bodyLg`, `bodyMd`, `bodySm`, `caption`, `label`, `mono`. Rewrote [`apps/mobile/lib/shared/theme/app_theme.dart`](../../apps/mobile/lib/shared/theme/app_theme.dart) body in-place to V2 tokens — `ColorScheme.dark(primary: violet, secondary: cyan, surface: surfaceGlass, error: red, ...)`, `scaffoldBackgroundColor: bgRoot`, `textTheme` mapped onto V2 styles, button + input + card + snackbar themes all on V2; new `dividerTheme`. The `AppTheme.dark` getter signature unchanged. One nuance: `upgrade_screen.dart` had Pro tier = `primary` (indigo) and Ultimate = `accentPurple` (violet); V1→V2 mapping collapsed both to `violet`, so reshuffled to Pro = `violetDeep` / Ultimate = `violet` to keep the tier hierarchy visually distinct. Plus moved from `info` → `blue` (same hex). Validation: `flutter analyze` clean × `apps/mobile` + `apps/desktop` + `packages/fluxora_core`; 27 + 38 + 8 = 73 tests pass. **Breaking PR** — no rollback. | M3 + M5 + M8 |
| **M10 — X-Ray panel + Group Watch shell + Offline state** ✅ done 2026-05-08 (3 slices: Offline / X-Ray / Group Watch) | `xray` side panel that slides over player (driven by static cast metadata only — no live ML, decision §1 row 4). `group-watch` modal placeholder ("Coming soon — invite link copy works, sync does not"). `offline` empty state. **Offline shipped 2026-05-08** as the first M10 slice: new `apps/mobile/lib/features/offline/presentation/screens/offline_screen.dart` with the prototype's 84-px violet-glow circle + `LucideIcons.wifiOff` icon + "You're offline" h1 + body copy quoting the server name + primary "Retry connection" `FluxButton` (defaults to `context.pop()` → falls through to `context.go(Routes.home)` if nothing to pop, so the router's auth-gate redirect lands the user wherever's appropriate). New `Routes.offline = '/offline'` with the route reading `state.extra` as an optional server-name string. **No live connectivity detector** — `connectivity_plus` not in `pubspec.yaml`; the route is registered so a v1.1 `connectivity_plus` listener (or an `ApiClient.unauthorizedStream`-style "no-network" stream) can push `/offline` without touching the screen. **No "Open downloads" secondary button** — Downloads tab is hidden in v1 per the real-data backfill plan §5 row 4; restore alongside the Downloads tab in v1.1 / Phase E. `flutter analyze` clean; 64 mobile tests still pass. | M5 |
| **M11 — Beyond-video: files browser + PDF + photo + music viewers** ✅ done 2026-05-08 | New server endpoint `GET /api/v1/files/{file_id}/content` serves raw bytes with MIME-detected `Content-Type`; group-visibility filter mirrors `GET /{file_id}` (404, not 403, on deny — prevents id-enumeration of gated content); +5 server tests (happy path / 404 not-in-DB / 404 not-on-disk / 404 group-deny / localhost-bypass) — server suite **656 → 661 passing**. New `MediaKind` enum + `MediaFileKind` extension on `MediaFile` in `fluxora_core` deriving video / photo / pdf / music / other from the file extension — pure extension, no codegen. `files_screen.dart` rebuilt as a categorized horizontal-rail browser routing per kind to `Routes.{player,photoViewer,docViewer,musicPlayer}` (other kinds open the system share sheet). 3 new viewer screens at `features/viewer/presentation/screens/`: `doc_viewer_screen.dart` (`pdfx ^2.9.2` `PdfControllerPinch` over a temp-downloaded copy since pdfx 2.x exposes no network-loading API; same temp file is reused for the "Open in..." share action), `photo_viewer_screen.dart` (`photo_view ^0.15.0` over `NetworkImage(url, headers: {Authorization: Bearer …})` direct streaming; "Open in..." downloads + shares via `share_plus ^12.0.2` `SharePlus.instance.share(ShareParams(...))`), `music_player_screen.dart` (`just_audio ^0.10.5` `AudioSource.uri` with bearer-token headers; vertical 280×280 album-art placeholder + scrubber + 64-px gradient play-pause; shuffle / prev / next / queue rendered but disabled — no queue in v1; lockscreen `audio_service` integration deferred to v1.1, requires a separate `MusicHandler` since the singleton `FluxoraAudioHandler` is owned by the video `PlayerCubit`). 3 new routes in `app_router.dart` (`/doc-viewer` / `/photo-viewer` / `/music-player`, all consuming `state.extra as MediaFile`). New `MusicPlayerCubit` + `FilesCubit` both gain the `if (isClosed) return;` `emit` guard. `path_provider ^2.1.5` promoted to a direct dep for `getTemporaryDirectory()`. **One bug fix surfaced post-merge audit:** the `files_screen.dart _openInExternal` flow was leaking the `HttpClient` if `getTemporaryDirectory()` or `pipe()` threw, and silently swallowed failures with no user feedback — fixed by wrapping in `try/finally` + showing a `SnackBar` on failure (mirrors the doc/photo viewer pattern). `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass. | M4 + M9 |
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

**No new theme files.** [`apps/mobile/lib/shared/theme/app_theme.dart`](../../apps/mobile/lib/shared/theme/app_theme.dart) stayed at the same path — its body was rewritten at M9 (✅ landed 2026-05-03) to consume V2 tokens. No `mobile_text_styles.dart`, no `mobile_theme.dart`, no `mobile_gradients.dart`. Type scale lives in [`AppTypography`](../../packages/fluxora_core/lib/constants/app_typography.dart) (V2-only post-M9); art-gradient parser is data-layer, not theme-layer.

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
| `shared/theme/app_theme.dart` | ✅ Body rewritten in-place at M9 cutover (2026-05-03) onto V2 tokens. File path and `AppTheme.dark` getter signature unchanged. M9 follow-up: `InputDecorationTheme.fillColor` opaque `Color(0xFF0F0C24)` to keep Material `TextField` from bleeding the gradient. | M9 |

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
- `flutter test apps/mobile` green (64 passing as of 2026-05-07, was 25 at plan-draft time; new tests per milestone).
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
App bar: avatar (left) + Fluxora logo (center) + bell + cast (right). Sections: **Continue watching** (poster 116×174 + progress bar 3 px + resume time chip), **Recently added**, **Your music** (square album art mini-rail), **Documents** quick-access tiles. Pull-to-refresh.

> **Note (2026-05-08):** "Trending now" was originally rail #2; dropped from scope per the trending-removal decision (status banner + §17.2). Suggested fill-the-gap replacement: a 4-up content-type quick-jump strip (Movies / Shows / Music / Documents) just under Continue-watching, since the prototype already plans "Your music" + "Documents" callouts further down — promoting them to a single browse strip removes the gap without inventing new content.

### Library — `library` *(replaces existing)*
App bar "Library" + filter chips (All · Movies · Shows · Music · Photos · Documents) + grid/list toggle + sort menu (Recently added / A-Z / Year / Rating). Default 3-up grid with title + year underneath posters.

### Search — `search`
App bar with text field "Search Fluxora", scan/voice icons trailing. Empty state: "Recent searches" + a "Browse" chip group of content-type categories (Movies / Shows / Music / Photos / Documents) that route to the matching Library filter. Active state: top-3 results horizontal rail, then sectioned (Movies / Shows / People).

> **Note (2026-05-08):** Original empty-state had "Try — Trending searches" chips below recent searches; that block is dropped (no popularity signal in single-tenant mode). Replacement above ("Browse" → Library filter shortcuts) keeps the empty state useful without inventing fake data.

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
| 2026-05-03 | **M0 landed.** `google_fonts ^8.1.0`, `lucide_icons_flutter ^3.1.13`, `cached_network_image` bumped to `^3.4.1`. New `apps/mobile/lib/shared/widgets/background_gradient.dart`; wired via `MaterialApp.router.builder`. `flutter analyze` clean, 27 tests pass, zero visual change. M0 row in §7 marked done. |
| 2026-05-03 | **Branding pass — mobile launcher icons.** Default Flutter `ic_launcher` and `Icon-App-*` PNGs replaced with Fluxora F-mark. 5 Android mipmap densities + 16 iOS appiconset sizes regenerated from `assets/brand/logo-icon.png` (1254×1254 RGBA). iOS `Info.plist` `CFBundleName` `fluxora_mobile` → `Fluxora`. Sync recipe added to `assets/README.md`. |
| 2026-05-03 | **M1 landed — shared widgets lift.** `FluxButton` lifted to `packages/fluxora_core/lib/widgets/flux_button.dart`. `Pill` → `FluxChip` rename + lift to `flux_chip.dart`. 13 desktop call-sites updated to `package:fluxora_core/widgets/...` imports (one collateral private widget rename: `_StatusPill` → `_StatusChip` in `clients_screen.dart`; one section comment + sentinel widget renamed in the showcase screen). Added 7 new core widgets: `FluxAppBar`, `FluxBottomTabs`, `FluxBottomSheet` (+ `showFluxBottomSheet()` helper), `FluxPoster`, `FluxRow`, `FluxSectionHeader` (no `FluxTextField` — deferred per the M1 row). `cached_network_image ^3.4.1` newly added to `fluxora_core/pubspec.yaml`. All re-exported from `fluxora_core.dart`. `flutter analyze` clean × 3 packages; 39 + 27 + 8 = 74 tests pass. |
| 2026-05-03 | **M2 landed — tab shell + go_router migration.** New `apps/mobile/lib/shared/widgets/mobile_shell.dart` consumes `StatefulNavigationShell` and mounts `FluxBottomTabs` at the bottom. `app_router.dart` rewritten as `StatefulShellRoute.indexedStack` with 5 branches (`/home`, `/library`, `/search`, `/downloads`, `/profile`); auth-gate + deep-link routes sit outside. Old `/library/:id/files` path renamed to `/library-files/:id`. Pair-success redirect now `/home`. Placeholder tab screens at `features/{home,search,downloads,profile}/presentation/screens/`. Library tab keeps the existing `LibraryScreen` until M3. Tabs use `LucideIcons.{layoutDashboard,bookOpen,search,download,user}` from `lucide_icons_flutter`. `flutter analyze` clean; 27 mobile tests pass. |
| 2026-05-03 | **M3 landed — Discover surfaces.** Mock-data adapter at `apps/mobile/lib/shared/data/mock_data.dart` (MockMediaItem + MockNotification + named gradients + 4 fixture lists). New mobile-spec `FluxTextField` in `fluxora_core` with `density: {mobile, compact}` enum; the existing desktop `flux_text_field.dart` stays put — the `compact` density is the compatibility hook for a later unification. Home / Library / Search / Notifications screens rewritten with full V2 styling, `FluxPoster` rails, filter chips, sort popup, grid/list toggle, pull-to-refresh, relative timestamps. Library uses mock data; legacy `LibraryRepository` + `/library-files/:id` retain real-backend wiring for M11 to replace. New `Routes.notifications` route reached from the Home tab bell icon. |
| 2026-05-03 | **M4 landed — Detail + Episodes.** `mock_data.dart` extended with `synopsis`/`year`/`rating`/`duration`/`cast`/`crew`/`similarIds`/`seasons` optional fields plus new `MockCastMember` / `MockSeason` / `MockEpisode` shapes + `MockData.findById(id)` lookup. New `detail_screen.dart` (full-bleed 340-px hero with backdrop gradient + dark fade + 28-px display title + meta row + quality chip; Play/Resume primary + Episodes button for shows; 4-up icon-action row; collapsible synopsis; cast / crew / similar rails). New `episodes_screen.dart` (season chip selector + episode rows). Routes `/detail/:id` and `/episodes/:id` added (deep-link, bypass shell). Posters across Home / Library / Search now navigate to detail. |
| 2026-05-03 | **M5 landed — Player chrome rebuild.** `_VideoView` swapped from `MaterialVideoControls` to `Stack(Video + FluxPlayerControls)`. New `PlayerControlsController` (`ChangeNotifier`, plan §9.1) and new `FluxPlayerControls` widget — tap-to-toggle 250-ms scrim fade + 3-second auto-hide; top bar / 72-px gradient play-pause center transport / violet progress bar / 8-up quick-action row (2 live, 6 stub) / lock-mode unlock chip / landscape side rails. All overlays + state views (resume banner, transport badge, loading, error, tier-limit) re-themed onto V2 tokens. Cubit interface untouched — 25 `PlayerCubit` tests still pass. |
| 2026-05-03 | **M6 landed — Player gestures + sheets.** `screen_brightness ^2.1.7` newly added. 5 bottom sheets under `features/player/presentation/sheets/` (Audio/Subs DefaultTabController, Speed presets, Sleep timer + auto-pause, Quality stub-disabled, Cast stub-disabled) — all consume the M1 `FluxBottomSheet` skeleton. `FluxPlayerControls` rewritten with full gesture pipeline: double-tap seek ±10 s + violet ripple, long-press 2× peek, vertical drag brightness (left half via `screen_brightness`) / volume (right half via `player.setVolume`) with centred drag-HUD pill, pinch fit toggle. Lock-mode chip replaced with press-and-hold-to-unlock 80×80 progress ring (1.2 s). Quick-action row's 6 previously-stub buttons now open their respective sheets. **Deferred:** horizontal-drag scrub (conflicts with the M7 drag-down-to-minimize gesture) and the larger ripple/animation polish (M14). |
| 2026-05-03 | **M7 landed — Mini-player + drag-down minimize.** `PlayerCubit` is now a `GetIt.lazySingleton` doubling as the `PlaybackProvider` per plan §9.2; refactored with `_disposeCurrentSession()` extraction + `dismiss()` for explicit teardown. New `FluxMiniPlayer` 64-px bar mounted in `MobileShell` above `FluxBottomTabs`, visible only on `PlayerReady`. New `PlayerScreen.resume()` constructor + `/player/resume` route for mini-player → fullscreen handoff. `_MinimizeHandle` at the top of the player drives a `Transform.translate`/`scale`/opacity drag-down dismissal with a 150-px threshold. 25 `PlayerCubit` tests still pass — singleton refactor preserved external behaviour. |
| 2026-05-03 | **M8 landed — Downloads + Profile + Notifications real-data wiring + log rotation.** Notifications now consume `/api/v1/notifications` via a new mobile `features/notifications/` repo + cubit + state mirroring desktop's REST-polling pattern (singleton-scoped so the live tail survives back-pops); both clients carry `// TODO(WS):` markers — true WS migration deferred until a shared HMAC-bearer wrapper exists. Screen rewritten with bucketed Today/Week/Earlier rendering, category→icon+color helpers, loading/failure/empty/retry views, tap-to-markRead. `MockNotification` removed. Downloads tab built from prototype: header + 6-px violet→cyan storage progress bar + violet-tinted DOWNLOADING cards + AVAILABLE OFFLINE flat rows + `FluxBottomSheet` action menu. `MockDownload` shape + 6 fixtures + storage constants added. Profile tab built: 64-px gradient avatar + crown PLUS pill + 3-stat row + 9 sectioned `FluxRow`s + red Sign out → confirm dialog → `cubit.dismiss` + `clearBearerToken` + `secureStorage.deleteAll` + redirect to `/connect`. Profile data hardcoded — `/api/v1/profile` is operator-only. **Log rotation:** 1634-line `AGENT_LOG.md` archived to `docs/logs/AGENT_LOG_archive_05.md`; fresh log seeded with summary + carry-forward M7 + M8 entry. |
| 2026-05-03 | **M9 landed — Theme cutover (the breaking PR for mobile).** Migrated 7 mobile call-sites + 1 desktop straggler (`apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart:1001`) off V1 tokens, then deleted them from `packages/fluxora_core/lib/constants/`. Removed 17 colors (primary/primaryVariant/accent/accentPurple/background/surface/surfaceRaised/surfaceMuted/textPrimary/textSecondary/textMuted/textDisabled/success/warning/error/info/brandGradient) and 11 typography styles (displayLg/displayMd/headingLg/headingMd/headingSm/bodyLg/bodyMd/bodySm/caption/label/mono). `apps/mobile/lib/shared/theme/app_theme.dart` body rewritten in-place onto V2 tokens — `AppTheme.dark` getter signature unchanged so consumers keep working. Tier-color reshuffle in `upgrade_screen.dart` (Pro `primary→violetDeep`, Ultimate `accentPurple→violet`) preserved the visible hierarchy after the V1→V2 collapse. `flutter analyze` clean × all 3 packages; 27 + 38 + 8 = 73 tests pass. |
| 2026-05-04 | **Phase A + B real-data backfill (out-of-plan).** Home Continue-watching rail wired to `GET /auth/clients/me/continue-watching` (mock fallback when empty); Library tab wired to real `LibraryRepository` (mock retired for that surface). Trending rail kept on mock pending the §17.2 trending-removal decision (which now supersedes this Phase C wiring). |
| 2026-05-04 | **QR-pairing scanner (out-of-plan, advances M12).** `mobile_scanner ^x` added; `pairing_screen.dart` extended with a "Scan QR to sign in" flow — scans the desktop's pair-code QR, decodes it, fills the bearer-pair form. Belongs to M12 onboarding revamp; landed early because pairing UX was blocking real-device testing. |
| 2026-05-04 | **Player polish — PIP + audio_service + bg toggle (out-of-plan).** `audio_service` registered as the audio session owner so music + video keep playing under the lockscreen; `media_kit` PIP wired on Android (iOS PIP still pending — see §17.3). User-facing "Background playback" toggle on Profile → Playback. Test count grew here as cubit + repo coverage expanded. |
| 2026-05-05 | **Seek-restart wire-up (out-of-plan).** `PlayerCubit.seekTo` splits in-player vs server-restart paths — within ±5 s the underlying `Player.seek` runs locally; outside the threshold a 300-ms-debounced `POST /seek` recreates the upstream segment. New `_SeekingOverlay` while the server transition lands. 12 new cubit tests around the threshold + debounce + cancellation paths. |
| 2026-05-07 | **Groups v2 mobile UX shipped (M4 + M6 + M8 of [`docs/10_planning/13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md)).** New `apps/mobile/lib/features/groups/` (repo + cubit + state + widgets) consumes `GET /auth/clients/me/visible-libraries` for a single-fetch payload of locked / unlocked / visible groups + libraries. Profile screen mounts a `GroupsSection` with three cards — Locked (PIN-required, opens `PinEntrySheet`), Unlocked (live grants with expiry + Lock action), Visible Libraries (the additive UNION of all reachable libraries). `PinEnrollmentSheet` covers per-client mode; both sheets reuse `FluxBottomSheet` and the `_kObviousPins` blocklist. 16 new cubit tests; suite 48 → 64 passing. **This work is genuinely out-of-plan** — Groups v2 is its own initiative and the rail/section here is referenced from the Groups v2 plan, not from the original mobile redesign milestones. |
| 2026-05-08 | **Audit + trending removed.** Plan re-read end-to-end against the codebase. Status banner refreshed (test count 27 → 64; later milestones acknowledged). Trending now / Trending searches dropped from §7 M3 + §14 Home + §14 Search; replacement strategies recorded in §17.2. New §17 "Audit findings + Improvised suggestions" added. Definition-of-done test count corrected. No M10–M14 milestone targets changed. Code-side rip-out of trending fixtures + rails + chips is left for the next mobile session (see §17.2 "Implementation handoff"). |
| 2026-05-08 | **Audit §17.3 #3 closed — sign-out revokes server-side.** New `DELETE /api/v1/auth/clients/me` bearer-validated route flips the calling client to `status='rejected'` + zeroes `auth_token` so the bearer stops authenticating immediately.  Mobile `_performSignOut` calls `AuthRepository.revokeMe()` before local teardown; failure is non-fatal.  Records a `client.revoke` activity event with `actor_kind='client'` (vs the operator-driven `'operator'`).  +4 server tests; server suite **652 → 656 passing**.  Audit §17.3 #2 also closed in this round as a doc-only update — Phase A + B backfill had already wired the per-paired-client profile end-to-end (the original audit finding was stale on the day it was written; the verification trail is logged at §17.3 #2). |
| 2026-05-08 | **M10 Group-Watch-modal slice landed — M10 milestone closed.** Third and last of M10's sub-slices.  New `apps/mobile/lib/features/group_watch/presentation/screens/group_watch_screen.dart` matches the prototype `GroupWatchScreen` (`docs/11_design/prototype/app/mobile/screens/extras.jsx` line 278) — `FluxAppBar "Group Watch"` + violet "Sync engine ships in v1.1" pill + 200-px hero card (deep-blue gradient + LIVE pulse-dot eyebrow + source title + "Static preview" subtitle) + "IN THE ROOM · 4" eyebrow + 4 mock person rows (gradient avatars + name + sub + greyed `Icons.chat_bubble_outline_rounded` chat icon) + Invite-link card with monospace placeholder URL + violet copy button (`Clipboard.setData` actually copies the placeholder; SnackBar surfaces "sync ships in v1.1") + bottom action row (red Leave button → `context.pop()` + violet gradient "Resume for everyone" `FluxButton` → SnackBar "playback resumes locally only").  Entry point: new `Group Watch` `ListTile` in the player chrome's overflow menu (`flux_player_controls.dart::_showOverflowMenu`) — `onGroupWatch: VoidCallback?` threads through `FluxPlayerControls` + `_VideoView` to `player_screen.dart`'s `BlocBuilder`, which fires `context.push(Routes.groupWatch, extra: fileName)`.  The empty-menu guard now fires only when **both** `canTonemap` and `canGroupWatch` are false.  Static fixtures (`_mockRoom`, `_mockInviteLink`) live until the sync engine ships in Phase 5+.  Note for future agents: "Group Watch" (this feature) and "Client Groups" / Groups v2 are **different**; the doc-comment header restates this so readers don't conflate them.  `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass. |
| 2026-05-08 | **M10 X-Ray-panel slice landed.** Second of M10's three sub-slices.  New `apps/mobile/lib/features/xray/presentation/screens/xray_screen.dart` matches the prototype `XRayScreen` (`docs/11_design/prototype/app/mobile/screens/extras.jsx` line 378) — `FluxAppBar` titled `"X-Ray · {title}"` + a small violet "Static preview" pill (live scene detection is v1.1) + "IN THIS SCENE · 3" eyebrow + 3 cast rows with circle-gradient avatars (Matthew McConaughey / Anne Hathaway / David Gyasi as Cooper / Brand / Romilly) + "TRIVIA" eyebrow + 2 trivia cards ("Did you know?" + "Soundtrack") with violet eyebrow + body copy.  Entry point: new `LucideIcons.scienceOutlined`-style icon chip in `_TopBar` of `flux_player_controls.dart` between the HDR badge and the PIP button — `onXRay: VoidCallback?` threads from `FluxPlayerControls` through `_VideoView` up to `player_screen.dart`'s `BlocBuilder`, which fires `context.push(Routes.xray, extra: fileName)`.  `XRayScreen` accepts `MediaFile? file` (preferred — populates the title via `file.title ?? file.name`) and a `String? title` fallback (used when only the player's `fileName: String` is in scope).  Route handler reads `state.extra` as either type.  Static fixtures live in `_mockCast` + `_mockTrivia` constants — when TMDB credits + scene-time cues land in v1.1 / Phase C, the body swaps without touching the route or entry-point wiring.  `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass. |
| 2026-05-08 | **M10 Offline-screen slice landed.** First of M10's three sub-slices.  New `apps/mobile/lib/features/offline/presentation/screens/offline_screen.dart` matches the prototype `EmptyOfflineScreen` (`docs/11_design/prototype/app/mobile/screens/extras.jsx` line 418) — 84-px violet-glow circle + `LucideIcons.wifiOff` (36 px) + "You're offline" displayV2 (22/800) + 280-px-max body quoting `serverName ?? 'your server'` + primary "Retry connection" `FluxButton` with `LucideIcons.refreshCw` icon.  `_onRetry` defaults to `context.canPop() ? context.pop() : context.go(Routes.home)` so the router's auth-gate redirect ([`_guardRedirect`](../../apps/mobile/lib/core/router/app_router.dart) line 192) lands the user appropriately.  New `Routes.offline = '/offline'`; the route reads `state.extra` as an optional server-name `String`.  Prototype's "Open downloads" secondary button intentionally not ported — Downloads tab is hidden in v1 (real-data backfill plan §5 row 4).  No live connectivity detector — `connectivity_plus` not in `pubspec.yaml`; v1.1 plug-in target.  `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass. |
| 2026-05-08 | **M11 — Beyond-video viewers landed.** New server endpoint `GET /api/v1/files/{file_id}/content` ([`apps/server/routers/files.py:162`](../../apps/server/routers/files.py#L162)) serves raw bytes with MIME-detected `Content-Type` (`mimetypes.guess_type` → `application/octet-stream` fallback), `Content-Disposition: attachment; filename={name}`, and `validate_token_or_local` auth.  Group visibility mirrors `GET /{file_id}` — bearer callers receive 404 (not 403) when the file's library is outside their content space, preventing id-enumeration of gated content.  Route placed **before** `/{file_id}` in the router so FastAPI doesn't accidentally match `"content"` as a `file_id` value.  +5 server tests in `tests/test_files.py` (happy path streams correct bytes + content-type + filename / 404 not-in-DB / 404 path missing on disk / 404 group-visibility deny / localhost-bypass), server suite **656 → 661 passing**.  New `MediaKind` enum + `MediaFileKind` extension on `MediaFile` in [`packages/fluxora_core/lib/entities/media_file.dart:51`](../../packages/fluxora_core/lib/entities/media_file.dart#L51) — pure extension, no codegen, derives video / photo / pdf / music / other from the file extension.  [`apps/mobile/lib/features/library/presentation/screens/files_screen.dart`](../../apps/mobile/lib/features/library/presentation/screens/files_screen.dart) rebuilt as a categorized horizontal-rail browser (sections: Videos / Photos / Documents / Music / Other files) routing per kind to `Routes.{player, photoViewer, docViewer, musicPlayer}`; "other" kinds open the system share sheet via `share_plus 12.x`'s new `SharePlus.instance.share(ShareParams(files: [XFile(path)]))` API.  3 new viewer screens at `apps/mobile/lib/features/viewer/presentation/screens/`: **`doc_viewer_screen.dart`** (`pdfx ^2.9.2` `PdfControllerPinch` over a temp-downloaded copy — pdfx 2.x has no network-loading API; same temp file is reused for the "Open in..." share action so no second download is required), **`photo_viewer_screen.dart`** (`photo_view ^0.15.0` over `NetworkImage(url, headers: {Authorization: Bearer …})` direct streaming — no temp download for viewing; "Open in..." downloads via `dart:io.HttpClient` + shares), **`music_player_screen.dart`** (`just_audio ^0.10.5` `AudioSource.uri` with bearer-token headers; vertical 280×280 album-art placeholder + scrubber + 64-px gradient play-pause; shuffle / prev / next / queue rendered but disabled — no queue in v1).  New `MusicPlayerCubit` ([`features/viewer/presentation/cubit/music_player_cubit.dart`](../../apps/mobile/lib/features/viewer/presentation/cubit/music_player_cubit.dart)) wraps `AudioPlayer` with sealed states (`Initial`/`Loading`/`Ready{position,duration,isPlaying,isBuffering}`/`Failure`), the `if (isClosed) return;` `emit` guard, and proper subscription teardown in `close()`.  Lockscreen `audio_service` integration for the music handler explicitly **deferred to v1.1** (documented in the cubit header) — the existing singleton `FluxoraAudioHandler` is owned by the video `PlayerCubit`, so a separate `MusicAudioHandler` is needed to avoid shared-state conflicts.  3 new routes in `app_router.dart` (`/doc-viewer` / `/photo-viewer` / `/music-player`, all consuming `state.extra as MediaFile`).  `path_provider ^2.1.5` promoted from transitive to direct dep for `getTemporaryDirectory()`.  `FilesCubit` also gains the `if (isClosed) return;` guard.  **One bug fix surfaced post-merge audit:** `files_screen.dart::_FileChip._openInExternal` was leaking the `HttpClient` if `getTemporaryDirectory()` or `pipe()` threw, and silently swallowed failures with no user feedback — fixed by wrapping in `try/finally` + capturing `ScaffoldMessenger` before async gaps + showing a SnackBar on failure (mirrors the doc/photo viewer pattern).  `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass. |
| 2026-05-08 | **Audit §17.3 #4/#5/#11 cleanup landed.** Three sharp-edges from the prior audit closed in one pass.  **#4 Continue-watching empty state:** `_CwRailEmpty` ([`apps/mobile/lib/features/home/presentation/screens/home_screen.dart:323`](../../apps/mobile/lib/features/home/presentation/screens/home_screen.dart#L323)) upgraded from a 2-line muted string to a full empty-state card — `FluxSectionHeader` (eyebrow "Pick up where you left off" + title "Continue watching") + `Icons.play_circle_outline` glyph + "Nothing in progress yet" headline + "Start a title and it'll show up here" subcopy + violet-tinted "Browse library" `TextButton` routing to `Routes.libraryWithFilter('movies')`.  Mock-data fallback gone.  **#5 Background gradient repaint:** `Positioned.fill(child: child)` swapped to `Positioned.fill(child: RepaintBoundary(child: child))` in [`background_gradient.dart:46`](../../apps/mobile/lib/shared/widgets/background_gradient.dart#L46) so the static two-radial backdrop never repaints when the routed child invalidates (player chrome / mini-player / scrubber / poster decode all benefit).  **#11 Cubit emit-after-close sweep:** `if (isClosed) return;` `emit` guard added to `ProfileCubit`, `ProfileStatsCubit`, `RecentCubit`, `ContinueWatchingCubit`, `NotificationsCubit`, `SearchCubit`, `PlayerCubit` — closes the navigate-back-mid-fetch crash class for the whole mobile cubit roster (`MobileGroupsCubit` had it from §17.3 fix; `DetailCubit` got it on 2026-05-08; `MusicPlayerCubit` + `FilesCubit` born with it at M11; `LibraryBloc` excluded — Bloc's `Emitter<S>` short-circuits natively).  `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass. |
| 2026-05-08 | **Trending rip-out landed.** Code follow-up to the audit-day decision. `MockData.trending` + `MockData.trendingSearches` deleted from `mock_data.dart`. `home_screen.dart`: `_MockRail` deleted; new `_BrowseStrip` + `_BrowseTile` widgets render a 4-up content-type strip (Movies / Shows / Music / Documents) under Continue-watching using `LucideIcons.{clapperboard,tv,music,fileText}` over the existing gradient placeholders; "Documents" maps to the `files` filter since v1 collapsed Documents into Files. `search_screen.dart`: "Trending searches" eyebrow + chip Wrap deleted; new "Browse — Jump into a category" chip group routes through `context.push(Routes.libraryWithFilter(...))`. `app_router.dart`: new `Routes.libraryWithFilter(String slug)` helper; library route builder now reads `state.uri.queryParameters['filter']` and passes it as `LibraryScreen.initialFilter`. `library_screen.dart`: `LibraryScreen` gains an `initialFilter` String? param; new `_filterFromSlug` maps slug → `_LibraryFilter` (`movies`/`shows`/`music`/`files`; else `all`). `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass; ~180 LoC delta net. Plan §17.2 / §17.4 / §7 M3 / status banner all flipped to "✅ landed". |

---

## 17. Audit findings + improvised suggestions (2026-05-08)

This section is the result of a full plan-vs-codebase audit. It captures the gap between what the plan describes and what shipped, and proposes the next moves.

### 17.1 What's actually shipped vs. what the plan tracks

| Area | Plan said | Reality (audit date) | Gap |
|---|---|---|---|
| Test count | 25 (D-of-D) / 27 (M0–M9 rows) | **64 passing** | Plan numbers stale — fixed in this audit. |
| M0–M9 (foundation through theme cutover) | ✅ landed 2026-05-03 | ✅ landed | None. |
| Phase A + B real-data backfill | not captured | landed 2026-05-04 | Now in changelog; does not need a milestone of its own. |
| QR pairing scanner | M12 scope | landed early 2026-05-04 | Advances M12; the rest of M12 (splash + signin + server-picker rebuild) still pending. |
| Player PIP + `audio_service` + bg toggle | M14 polish (implicit) | landed 2026-05-04 (Android PIP only) | Pulled forward to unblock real-device QA; iOS PIP still open — §17.3 #1. |
| Seek-restart | not captured (server-restart was a separate roadmap item) | landed 2026-05-05 | Belongs in §10 behaviors; recorded in changelog. |
| Groups v2 mobile UX (Locked / Unlocked / Visible cards + PIN sheets) | not captured (Groups v2 is its own plan) | landed 2026-05-07 | Cross-referenced from §1 / status banner; this plan does **not** own the Groups v2 milestones. |
| M10 X-Ray + Group Watch + Offline | pending | ✅ all three slices landed 2026-05-08 | Offline + X-Ray + Group Watch all shipped as UI shells per §1 row 4 (live connectivity detection / scene ML / multi-client sync are v1.1+).  Closed in changelog. |
| M11 Beyond-video viewers | pending | ✅ landed 2026-05-08 | New `GET /api/v1/files/{id}/content` endpoint + 5 server tests (suite 656 → 661); `MediaKind` enum on `MediaFile`; rebuilt files browser; 3 viewer screens (`doc_viewer` / `photo_viewer` / `music_player`); 5 new deps locked (`pdfx ^2.9.2`, `photo_view ^0.15.0`, `just_audio ^0.10.5`, `share_plus ^12.0.2`, `path_provider ^2.1.5`). Music lockscreen integration via a separate `MusicHandler` deferred to v1.1. |
| M12 Onboarding revamp | pending (QR scanner partly done) | partly landed | Splash + signin + server-picker rebuild still owed. |
| M13 Host-a-server shell | pending | pending | UI shell only; runtime is Phase 5+. |
| M14 Polish + a11y + golden tests | pending | pending | Final pass before "redesign done". |

### 17.2 Trending — removal + replacement ✅ landed 2026-05-08

**Decision (2026-05-08, owner directive):** drop "Trending now" rail (Home) and "Trending searches" chips (Search) from the design. **Why:** Fluxora is single-tenant — there is no cross-user popularity signal. The curator-managed alternative (operator picks "what's hot") is feature-creep we don't want before v1.

**Replacement on Home:** dropped rail #2; promoted a 4-up content-type quick-jump strip (Movies / Shows / Music / Documents) just under Continue-watching. Each tile routes to the matching Library filter. Re-uses content the prototype already plans further down the screen ("Your music", "Documents") so we lose no real surface — the strip consolidates the callouts into one navigation aid and removes the dead rail.

**Replacement on Search empty state:** dropped "Trending searches" chip group; kept "Recent searches" (real per-device data) and added a "Browse" chip group of content-type categories that route to the Library filter. Same justification as Home — real data only.

**What landed (2026-05-08):**
- `apps/mobile/lib/shared/data/mock_data.dart`: `MockData.trending` + `MockData.trendingSearches` deleted; doc-comment header updated.
- `apps/mobile/lib/features/home/presentation/screens/home_screen.dart`: `_MockRail` deleted; new `_BrowseStrip` + `_BrowseTile` + `_BrowseTileSpec` widgets render the 4-up strip with `LucideIcons.{clapperboard,tv,music,fileText}` over the existing gradient placeholders. "Documents" maps to `?filter=files` since v1 collapsed Documents into the Files type.
- `apps/mobile/lib/features/search/presentation/screens/search_screen.dart`: "Trending searches" `FluxSectionHeader` + Wrap dropped; new "Browse" `FluxSectionHeader` + `_browseFilters` chip group routes via `context.push(Routes.libraryWithFilter(spec.filter))`.
- `apps/mobile/lib/core/router/app_router.dart`: new `Routes.libraryWithFilter(String slug)` helper; library route builder now reads `state.uri.queryParameters['filter']` and passes it as `LibraryScreen.initialFilter`.
- `apps/mobile/lib/features/library/presentation/screens/library_screen.dart`: `LibraryScreen` accepts an `initialFilter` String param; new top-level `_filterFromSlug(String?)` maps slug → `_LibraryFilter` (`movies` / `shows` / `music` / `files`; anything else → `all`); `_LibraryBodyState._filter` now seeds from the slug.
- Verification: `flutter analyze` clean × `apps/mobile`; 64 mobile tests pass.

### 17.3 Sharp edges + improvised suggestions

These are improvements the audit surfaced. None of them are blockers; pick at the next session's discretion.

1. **iOS PIP is missing — known gap from the 2026-05-04 player polish.** `media_kit` uses MPV which doesn't bridge to `AVPictureInPictureController`. Two paths: (a) swap the player backend to AVKit on iOS only (heavy), or (b) build a custom `AVPlayerLayer` surface for iOS PIP and keep `media_kit` for Android + desktop (medium). Both are out-of-scope for the redesign cutover; capture as a separate ticket.
2. ~~**Profile data is hardcoded.**~~ ✅ closed 2026-05-08 — audit finding was stale.  Phase A + B real-data backfill (2026-05-04) had already wired the per-paired-client profile end-to-end: `GET /auth/clients/me` → `ClientMeResponse {id, display_name, email, platform, paired_at, last_seen, tier}` consumed by `ProfileCubit`; `GET /auth/clients/me/stats` → `ClientMeStatsResponse {hours, movies, shows}` consumed by `ProfileStatsCubit`.  Mobile `_AvatarBlock` reads `displayName` / `email` / `tier` straight from `ClientProfile`; stats row reads `hours` / `movies` / `shows` from `ProfileStatsLoaded`.  The audit's "operator `/api/v1/profile`" assumption was wrong — mobile never consumed that route.  Only `avatar_url` isn't supported and the screen falls back to computed initials over a violet→pink gradient circle, which is the v1 design (uploadable client avatars are a v1.1+ feature; not worth the file-storage scaffolding for v1 ship).
3. ~~**Sign-out flow does not revoke the bearer server-side.**~~ ✅ closed 2026-05-08.  New `DELETE /api/v1/auth/clients/me` self-revoke endpoint — bearer-only, validates the calling client, calls `auth_service.revoke_client(client_id)` (same teardown the operator-driven `DELETE /auth/revoke/{id}` performs: flips status to `rejected`, zeroes `auth_token`, drops `is_trusted`).  Records a `client.revoke` activity event with `actor_kind='client'` so the operator's Activity feed surfaces self-initiated sign-outs.  Mobile `_performSignOut` calls `AuthRepository.revokeMe()` BEFORE the local `clearBearerToken` + `secureStorage.deleteAll` — failure is non-fatal so a dead network can't trap the user on the screen.  4 new server tests in `test_auth.py` (happy path / token-invalidated-after / 401 without bearer / activity event recorded); server suite 652 → 656 passing.
4. ~~**Continue-watching rail has no empty state.**~~ ✅ closed 2026-05-08.  `_CwRailEmpty` upgraded from a 2-line muted string to a full empty-state card — eyebrow + title (`FluxSectionHeader`), `Icons.play_circle_outline` glyph, "Nothing in progress yet" headline, "Start a title and it'll show up here" subcopy, and a violet-tinted "Browse library" `TextButton` that routes to `Routes.libraryWithFilter('movies')`.  The mock-data fallback path is gone.
5. ~~**`background_gradient.dart` paints two `RadialGradient`s on every routed screen.**~~ ✅ closed 2026-05-08.  `Positioned.fill(child: child)` swapped to `Positioned.fill(child: RepaintBoundary(child: child))` so the static two-radial backdrop never repaints when the routed child invalidates (player chrome, mini-player, scrubber redraws).  One-line change.
6. ~~**`mobile_scanner` + `pdfx` + `photo_view` + `just_audio` + `audio_service` versions in §6 still say "check pub.dev at MX".**~~ ✅ closed 2026-05-08 alongside M11.  All five are now locked in §6: `mobile_scanner ^7.1.2` (M2), `audio_service ^0.18.18` (M14 player polish 2026-05-04), `just_audio ^0.10.5` (M11), `pdfx ^2.9.2` (M11), `photo_view ^0.15.0` (M11). Plus two newly-locked deps surfaced by M11: `share_plus ^12.0.2` and `path_provider ^2.1.5`.
7. **No goldens for the player overlay yet.** §14 promises 10 golden images at M14; the `golden_toolkit` 0.15.0 + `mocktail` infra already exists on desktop (M8 row in `current_status.md`). **Suggested fix:** at M14, port the same recipe — drop wrapping `MultiBlocProvider`, register mock repos in GetIt, then the screen's own `MultiBlocProvider.create` consumes them. Recipe documented in `apps/desktop/test/goldens/_README.md`.
8. **Notifications panel — 500-entry FIFO cap is mobile too?** Desktop's `NotificationsCubit.liveStream` caps `seen` set at 500. Mobile should mirror; verify on the next M8-area touch. (Plan didn't surface this; the audit did.)
9. **Sleep-timer "End of episode" + "Custom…" still stub-disabled.** Cheap to wire: "End of episode" needs the next-episode handoff (already planned in M10 for Group Watch hooks); "Custom" is just a `showTimePicker` returning a `Duration`. **Suggested fix:** lift "Custom" to live in a follow-up to M6.
10. **Groups M6 self-hide gap (FIXED 2026-05-08).** The original three-card layout (Locked / Unlocked / Visible Libraries) collapsed entirely when all three filtered lists were empty — and "Locked" only contained groups whose state was `requires_pin && !is_unlocked`.  A client in only the Public group (the default fresh-pair state) saw nothing.  Field report: "there is no way to see how many groups i am part of and where to enter pin?"  **Shipped fix:** consolidated Locked + Unlocked into a single "My groups (N)" card that always renders when the client is in any group; rows carry `LOCKED` / `UNLOCKED` / `OPEN` state badges; PIN entry sheet opens via tap on any Locked row.  Plan + canonical docs: [`docs/10_planning/13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md) §M6 UX revision 2026-05-08.
11. **`DetailCubit.emit` was unguarded against post-close (FIXED 2026-05-08).** Same field-log session surfaced a `Bad state: Cannot emit new states after calling close` from `DetailCubit.load` — the user navigated back from a Detail screen mid-fetch; cubit closed; in-flight `getFile()` resolved and `emit` raised.  **Shipped fix:** added the same `if (isClosed) return;` guard `MobileGroupsCubit.emit` already had.  ~~**Suggested follow-up:** sweep other mobile cubits for the same pattern (ProfileCubit, ProfileStatsCubit, RecentCubit, ContinueWatchingCubit, NotificationsCubit, SearchCubit) — each is one line.~~ ✅ sweep completed 2026-05-08: the `if (isClosed) return;` `emit` guard is now applied to `ProfileCubit`, `ProfileStatsCubit`, `RecentCubit`, `ContinueWatchingCubit`, `NotificationsCubit`, `SearchCubit`, and `PlayerCubit` — closes the navigate-back-mid-fetch crash class for the whole mobile cubit roster.  Plus `MusicPlayerCubit` and `FilesCubit` were born with the guard at M11.  `LibraryBloc` excluded by design — Bloc framework's `Emitter<S>` already short-circuits after `close()`.

### 17.4 Recommended next-mobile-session priorities

In order — pick one, ship it, log it:

1. ~~**Trending rip-out** (§17.2 implementation handoff).~~ ✅ landed 2026-05-08 (~180 LoC delta across 5 files, 64/64 tests still green).
2. ~~**M10 — X-Ray panel + Group Watch shell + Offline state.**~~ ✅ landed 2026-05-08 in three slices: Offline (`OfflineScreen` + `Routes.offline`), X-Ray (`XRayScreen` + `Routes.xray` + top-bar science-flask chip), Group Watch (`GroupWatchScreen` + `Routes.groupWatch` + overflow-menu entry).  All three ship as UI shells per decision §1 row 4 — live connectivity detection / scene ML / multi-client sync are v1.1+.
3. ~~**Profile real-data endpoint** (§17.3 #2).~~ ✅ already shipped 2026-05-04 in Phase A + B backfill — the audit was stale; mobile profile is real-data through `ProfileCubit` + `ProfileStatsCubit` (closed in §17.3 #2 with the verification trail).  No code work remaining here; only the `avatar_url` corner is open and that's a v1.1+ feature.
4. **iOS PIP** (§17.3 #1). Big enough that it's its own ticket — flag it but don't start until other items are ready.

~~Suggested pivots now that #1–#3 are closed: §17.3 #3 (sign-out doesn't revoke server-side — small + closes a real session-revocation gap), §17.3 #11 (cubit emit-after-close sweep across the remaining mobile cubits — mechanical one-liner each), or M11 (Beyond-video — files browser + PDF / photo / music viewers — much bigger).~~ All three landed 2026-05-08: §17.3 #3 (self-revoke endpoint + mobile call-site, +4 server tests), §17.3 #4/#5/#11 audit cleanup (CW empty state, RepaintBoundary, 7-cubit emit-guard sweep), and **M11 — Beyond-video viewers** (server `/content` endpoint + 5 tests, MediaKind enum, files browser rebuild, 3 viewer screens, 5 new deps).

5. **iOS PIP** (§17.3 #1) — still open. Big enough that it's its own ticket; the only remaining player-area gap.
6. **M12 — Onboarding revamp** — splash + signin (TOTP/QR/invite) + server picker rebuild. Plan-level next milestone.
7. **§17.3 #8** — verify mobile `NotificationsCubit.liveStream` mirrors desktop's 500-entry FIFO `seen` cap.
8. **§17.3 #9** — wire sleep-timer Custom + End-of-episode (cheap; one `showTimePicker` + reuse the M10 next-episode handoff).

After the next-priority items land, M12–M14 can resume in plan order.
