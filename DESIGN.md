---
version: v2
name: Fluxora Dark

colors:
  # Brand / Primary
  primary: "#A855F7"          # violet — CTAs, active nav, focus rings
  primary-deep: "#8B5CF6"     # violetDeep — gradient partner, button presses
  primary-tint: "#C4A8F5"     # violetTint — soft brand surfaces, muted highlights
  primary-soft: "#E9D5FF"     # violetSoft — text on violet-tinted backgrounds
  accent: "#22D3EE"           # cyan — connectivity states, secondary highlights
  accent-pink: "#EC4899"      # pink — music, decorative accents

  # Surfaces (glassmorphic over a dark purple-black root)
  bg-root: "#08061A"          # scaffold / page background
  surface-glass: "rgba(20,18,38,0.7)"   # cards, app bar, snackbars
  sidebar-glass: "rgba(13,11,28,0.7)"   # left rail
  titlebar-glass: "rgba(6,4,16,0.9)"    # window titlebar
  border-subtle: "rgba(255,255,255,0.06)"   # default borders, dividers
  border-hover: "rgba(168,85,247,0.4)"      # hovered / focused borders

  # Text
  on-bg-bright: "#F1F5F9"     # textBright — primary headings, brand surfaces
  on-bg: "#E2E8F0"            # textBody — body copy
  on-bg-muted: "#94A3B8"      # textMutedV2 — secondary text, table cells
  on-bg-dim: "#64748B"        # textDim — labels, captions, eyebrows
  on-bg-faint: "#475569"      # textFaint — disabled states

  # Semantic
  success: "#10B981"          # emerald — online clients, active streams
  warning: "#F59E0B"          # amber — idle, slow, throttled
  error: "#EF4444"            # red — failed streams, destructive
  info: "#3B82F6"             # blue — neutral notifications

  # Pill / chip backgrounds (translucent variants)
  pill-bg-purple: "rgba(168,85,247,0.16)"   # primary pill, nav-rail indicator
  pill-bg-success: "rgba(16,185,129,0.15)"
  pill-bg-warning: "rgba(245,158,11,0.15)"
  pill-bg-error: "rgba(239,68,68,0.15)"
  pill-bg-info: "rgba(59,130,246,0.15)"
  pill-bg-pink: "rgba(236,72,153,0.15)"
  pill-bg-neutral: "rgba(71,85,105,0.18)"

  # Gradient stops (use for logo mark, hero headings, premium CTAs)
  gradient-start: "#8B5CF6"   # violetDeep
  gradient-mid: "#A855F7"     # violet
  gradient-end: "#22D3EE"     # cyan

typography:
  display-v2:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.01em"
    color: on-bg-bright

  h1:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 700
    lineHeight: 1.3
    color: on-bg-bright

  h2:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.4
    color: on-bg-bright

  body:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.4
    color: on-bg

  body-small:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.4
    color: on-bg-muted

  caption:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: 500
    lineHeight: 1.4
    color: on-bg-muted

  micro:
    fontFamily: Inter
    fontSize: 10.5px
    fontWeight: 500
    lineHeight: 1.4
    color: on-bg-dim

  eyebrow:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0.14em"
    textTransform: uppercase
    color: on-bg-dim

  mono-body:
    fontFamily: "JetBrains Mono"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.4
    color: on-bg

  mono-caption:
    fontFamily: "JetBrains Mono"
    fontSize: 11px
    fontWeight: 500
    lineHeight: 1.4
    color: on-bg-muted

  mono-micro:
    fontFamily: "JetBrains Mono"
    fontSize: 10.5px
    fontWeight: 500
    lineHeight: 1.4
    color: on-bg-dim

rounded:
  xs: "6px"   # chips, small badges
  sm: "8px"   # buttons, inputs
  md: "10px"  # hover-tiles, quick-access cells
  lg: "12px"  # cards
  pill: "9999px"

spacing:
  s2: "2px"
  s4: "4px"
  s6: "6px"
  s8: "8px"
  s10: "10px"
  s11: "11px"
  s12: "12px"
  s14: "14px"
  s16: "16px"
  s18: "18px"
  s20: "20px"
  s22: "22px"
  s24: "24px"
  s28: "28px"
  s32: "32px"

elevation:
  none: "none"
  card-glow: "0 0 0 1px rgba(168,85,247,0.25), 0 0 24px rgba(168,85,247,0.10)"
  button-glow: "0 4px 12px rgba(139,92,246,0.3)"
  dot-glow: "0 0 8px <statusColor>"

components:
  button-primary:
    background: "linear-gradient(135deg, #8B5CF6, #A855F7)"
    color: "#F1F5F9"
    borderRadius: "8px"
    padding: "10px 20px"
    fontSize: "13px"
    fontWeight: "600"
    shadow: "0 4px 12px rgba(139,92,246,0.3)"

  button-secondary:
    background: "rgba(255,255,255,0.03)"
    color: "#E2E8F0"
    border: "1px solid rgba(255,255,255,0.06)"
    borderRadius: "8px"
    padding: "10px 20px"
    fontSize: "13px"
    fontWeight: "500"

  button-destructive:
    background: "rgba(239,68,68,0.10)"
    color: "#F87171"
    border: "1px solid rgba(239,68,68,0.3)"
    borderRadius: "8px"
    padding: "10px 20px"

  button-ghost:
    background: "transparent"
    color: "#94A3B8"
    borderRadius: "8px"
    padding: "8px 16px"
    fontSize: "13px"
    fontWeight: "500"
    hoverColor: "#F1F5F9"
    hoverBackground: "rgba(255,255,255,0.04)"

  card:
    background: "rgba(20,18,38,0.7)"
    border: "1px solid rgba(255,255,255,0.06)"
    borderRadius: "12px"
    padding: "14px"

  card-glow:
    background: "rgba(20,18,38,0.7)"
    border: "1px solid rgba(168,85,247,0.25)"
    borderRadius: "12px"
    shadow: "0 0 0 1px rgba(168,85,247,0.25), 0 0 24px rgba(168,85,247,0.10)"

  input:
    background: "rgba(255,255,255,0.04)"
    border: "1px solid rgba(255,255,255,0.06)"
    borderRadius: "10px"
    color: "#F1F5F9"
    padding: "10px 14px"
    fontSize: "13px"
    focusBorder: "rgba(168,85,247,0.4)"
    placeholderColor: "#64748B"

  badge:
    borderRadius: "9999px"
    padding: "3px 12px"
    fontSize: "11px"
    fontWeight: "600"

  badge-success:
    background: "rgba(16,185,129,0.15)"
    color: "#34D399"

  badge-warning:
    background: "rgba(245,158,11,0.15)"
    color: "#FBBF24"

  badge-error:
    background: "rgba(239,68,68,0.15)"
    color: "#F87171"

  badge-info:
    background: "rgba(59,130,246,0.15)"
    color: "#60A5FA"

  badge-streaming:
    background: "rgba(168,85,247,0.16)"
    color: "#C4A8F5"

  badge-neutral:
    background: "rgba(71,85,105,0.18)"
    color: "#94A3B8"

  sidebar:
    background: "rgba(13,11,28,0.7)"
    backdropFilter: "blur(20px)"
    width: "180px"
    borderRight: "1px solid rgba(255,255,255,0.06)"

  sidebar-item:
    padding: "10px 16px"
    fontSize: "13px"
    color: "#64748B"
    activeBackground: "rgba(168,85,247,0.16)"
    activeColor: "#A855F7"
    activeFontWeight: "600"
    hoverColor: "#F1F5F9"

  nav-logo:
    iconSize: "32px"
    iconBorderRadius: "8px"
    iconBackground: "linear-gradient(135deg, #8B5CF6, #A855F7)"
    fontSize: "15px"
    fontWeight: "700"
    color: "#F1F5F9"

  stat-card:
    background: "rgba(20,18,38,0.7)"
    border: "1px solid rgba(255,255,255,0.06)"
    borderRadius: "12px"
    padding: "14px"
    valueFontSize: "24px"
    valueFontWeight: "700"
    valueColor: "#F1F5F9"
    labelFontSize: "11px"
    labelColor: "#64748B"
    labelTransform: "uppercase"
    labelLetterSpacing: "0.14em"

  table:
    headerColor: "#64748B"
    headerFontSize: "11px"
    headerFontWeight: "600"
    headerTransform: "uppercase"
    headerLetterSpacing: "0.14em"
    rowBorderColor: "rgba(255,255,255,0.06)"
    cellColor: "#94A3B8"
    cellFontSize: "13px"
    padding: "10px 12px"
    primaryCellColor: "#F1F5F9"
    activeStreamColor: "#A855F7"

  progress-bar:
    height: "4px"
    background: "rgba(255,255,255,0.08)"
    fill: "linear-gradient(90deg, #8B5CF6, #A855F7)"
    borderRadius: "9999px"

  tooltip:
    background: "rgba(20,18,38,0.7)"
    color: "#F1F5F9"
    fontSize: "12px"
    padding: "6px 10px"
    borderRadius: "6px"
    border: "1px solid rgba(255,255,255,0.06)"

  status-dot:
    size: "8px"
    borderRadius: "50%"
    online: "#10B981"
    streaming: "#A855F7"
    idle: "#F59E0B"
    offline: "#475569"
    error: "#EF4444"
    glow: "0 0 8px <statusColor>"
---

# Fluxora Design System

> **Single source of truth.** This document is the **only** Fluxora design spec. It powers every Fluxora surface — desktop control panel, web landing page at [fluxora.marshalx.dev](https://fluxora.marshalx.dev), and the mobile Flutter app. Tokens live in [`packages/fluxora_core/lib/constants/app_colors.dart`](./packages/fluxora_core/lib/constants/app_colors.dart), [`app_typography.dart`](./packages/fluxora_core/lib/constants/app_typography.dart), `app_radii.dart`, `app_spacing.dart`, `app_shadows.dart`, `app_gradients.dart`. Web landing mirrors them as CSS vars in [`apps/web_landing/src/app/globals.css`](./apps/web_landing/src/app/globals.css).

## Overview

Fluxora is a **self-hosted hybrid media streaming platform** — the spiritual successor to Plex, rebuilt with a privacy-first, LAN-native philosophy. The interface must feel **powerful without being overwhelming**, projecting technical confidence while remaining approachable to non-developers who simply want to stream their personal media collection.

### Brand Personality
- **Dark-native** — The UI lives in the dark. Light mode is not in scope.
- **Glassmorphic** — Translucent surfaces float over a deep purple-black root, with violet accents and subtle backdrop blur. The aesthetic borrows from Linear, Apple's macOS Sonoma, and Plex's premium dark theme.
- **Precision & Control** — Users are managing servers, streams, and clients. The interface must surface data clearly without visual noise.
- **Understated Vibrancy** — Color is used deliberately: violet for primary actions, cyan for connectivity states, emerald for active/healthy, amber for idle/throttled.

### Design Tone
Calm authority. The interface should never feel chaotic. Information density is high but organized. Animations are subtle — they confirm actions, not distract from content.

---

## Colors

### Primary Palette

The primary brand colors communicate **action and identity**.

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#A855F7` | CTAs, active nav items, focus rings, progress fills, link text |
| `primary-deep` | `#8B5CF6` | Gradient endpoints, button-press states, primary shadows |
| `primary-tint` | `#C4A8F5` | Soft text on violet-tinted backgrounds (pill labels) |
| `primary-soft` | `#E9D5FF` | Brightest violet text — quality badges, brand-on-brand |
| `accent` | `#22D3EE` | LAN/Internet connectivity status, secondary highlights |
| `accent-pink` | `#EC4899` | Music app surfaces, decorative accents |

The brand gradient is: `linear-gradient(135deg, #8B5CF6, #A855F7, #22D3EE)`. Use for the logo mark, hero headings, primary CTAs, and premium tier callouts. **Never** use the gradient on body text.

### Surface Hierarchy

Two surface families:

**Translucent glass** — for on-page chrome that should pick up the bgRoot + radial-gradient backdrop:

| Token | Value | Usage |
|-------|-------|-------|
| `bg-root` | `#08061A` | Scaffold / page background — the deepest layer |
| `surface-glass` | `rgba(20,18,38,0.7)` | On-page glass cards (`FluxCard`, `FluxPoster` overlays) where the radial bg should bleed through |
| `sidebar-glass` | `rgba(13,11,28,0.7)` | Left rail (with `backdrop-filter: blur(20px)`) |
| `titlebar-glass` | `rgba(6,4,16,0.9)` | Window titlebar — slightly darker than sidebar |

**Opaque raised** — for floating chrome that mounts over everything else:

| Token | Value | Usage |
|-------|-------|-------|
| `bg-raised` | `#0F0C24` | Popup menus, dialog/sheet backgrounds, AppBar, SnackBar, Material `Card`, `InputDecoration.fillColor` — anywhere a translucent fill would let the page bleed through and read as "broken" rather than "glass" |

**Surface bands** — subtle overlays applied *inside* an existing `bg-raised` surface (typically a `FluxCard`) to render two visually-distinct stripes without spawning a second card or floating panel.  Pair `surface-band-high` (elevated stripe) with `surface-band-low` (depressed stripe) for a header / toolbar pattern: the URL row reads as raised chrome, the toolbar row reads as a tucked-under control surface, and the body of the card continues uninterrupted below.

| Token | Value | Usage |
|-------|-------|-------|
| `surface-band-high` | `rgba(255,255,255,0.024)` (`+2.4 % white`) | The lighter top stripe in a banded card header — e.g. the URL bar above the listing toolbar in the folder browser |
| `surface-band-low`  | `rgba(0,0,0,0.071)` (`+7 % black`) | The darker stripe immediately below — e.g. the listing toolbar / sort indicators row that sits between the URL bar and the scrollable body |

Originally introduced for the folder browser's URL + toolbar stack ([`apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart`](apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart)).  Both bands are deliberately *low contrast* — the goal is "I can see two distinct rows" not "two competing surfaces."  Use them only inside a `bg-raised` parent; on translucent glass surfaces the same RGBA reads as muddy because the underlying gradient bleeds through unblurred.

**Borders** (apply across both families):

| Token | Value | Usage |
|-------|-------|-------|
| `border-subtle` | `rgba(255,255,255,0.06)` | Default 1 px borders, dividers, table row separators |
| `border-hover` | `rgba(168,85,247,0.4)` | Focused inputs, hovered interactive cards |

**Rule**: floating chrome must commit to *real* glass (rgba + `BackdropFilter` blur) or *opaque* (`bg-raised`). Translucent fill **without** blur is a layout bug — the page bleeds through unblurred and reads as broken.

**Real-glass widgets** (rgba + blur) — already shipping:

| Widget | File | Blur σ |
|--------|------|--------|
| `FluxAppBar` | [`packages/fluxora_core/lib/widgets/flux_app_bar.dart`](packages/fluxora_core/lib/widgets/flux_app_bar.dart) | 20 |
| `FluxBottomTabs` | [`packages/fluxora_core/lib/widgets/flux_bottom_tabs.dart`](packages/fluxora_core/lib/widgets/flux_bottom_tabs.dart) | 20 |
| `FluxSidebar` | [`apps/desktop/lib/shared/widgets/flux_sidebar.dart`](apps/desktop/lib/shared/widgets/flux_sidebar.dart) | 20 |
| `FluxGlassDialog` (**canonical `AlertDialog` replacement** — never use Material `AlertDialog` for new code) | [`apps/desktop/lib/shared/widgets/flux_glass_dialog.dart`](apps/desktop/lib/shared/widgets/flux_glass_dialog.dart) | 20 |
| `FluxGlassMenu` (replaces `PopupMenuButton`) | [`apps/desktop/lib/shared/widgets/flux_glass_menu.dart`](apps/desktop/lib/shared/widgets/flux_glass_menu.dart) | 20 |
| `FluxGlassPopupSurface` (chrome-only primitive for custom popup content — column picker, autocomplete suggestion lists, sticky filter popovers; share the glass shell without inheriting `FluxGlassMenu`'s flat-select list shape) | [`apps/desktop/lib/shared/widgets/flux_glass_popup_surface.dart`](apps/desktop/lib/shared/widgets/flux_glass_popup_surface.dart) | 20 (configurable) |
| Command palette overlay | [`apps/desktop/lib/features/command_palette/presentation/widgets/command_palette_overlay.dart`](apps/desktop/lib/features/command_palette/presentation/widgets/command_palette_overlay.dart) | 8 |

**Opaque-raised widgets** (`bg-raised`, no blur) — for surfaces where blur isn't worth the GPU cost:
- Material `Card` theme default, `AppBar` theme default, `SnackBar` theme default, `InputDecoration.fillColor`. Widgets that opt into glass override these per-instance via `Material(color: transparent)` + their own `BackdropFilter`.

**`surface-glass` (rgba *without* blur)** is now scoped to one place: the in-flow `FluxCard` / `FluxPoster` overlay surfaces, where the rgba is read as "tinted overlay over the page's radial-gradient backdrop", not "glass". Anywhere else that uses `surface-glass` standalone is a bug — wrap it in `BackdropFilter` (real glass) or switch to `bg-raised` (opaque).

The scaffold should also have a **two-radial-gradient overlay** painted once globally:

```css
radial-gradient(120% 60% at 0% 0%, rgba(168,85,247,0.18), transparent 50%),
radial-gradient(100% 60% at 100% 100%, rgba(34,211,238,0.10), transparent 50%),
#08061A
```

In Flutter this is a `Stack` with two `RadialGradient` containers above a `ColoredBox(color: bgRoot)`.

### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `on-bg-bright` | `#F1F5F9` | Primary headings (h1, h2, display), values in stat cards |
| `on-bg` | `#E2E8F0` | Body text, button labels, primary table cells |
| `on-bg-muted` | `#94A3B8` | Secondary body text, table cell defaults |
| `on-bg-dim` | `#64748B` | Labels, captions, eyebrows, table headers |
| `on-bg-faint` | `#475569` | Disabled states, placeholder text |

### Semantic Colors

| Token | Hex | When to Use |
|-------|-----|-------------|
| `success` | `#10B981` | Online clients, active streams, successful operations |
| `warning` | `#F59E0B` | Idle clients, slow connections, degraded performance |
| `error` | `#EF4444` | Failed streams, errors, dangerous actions |
| `info` | `#3B82F6` | Informational states, neutral notifications |

For semantic badges, pair the color with a 12–18 % opacity background of the same hue (see `pill-bg-*` tokens above). Foreground text uses a slightly lighter shade than the base hue — e.g. `success` badge text is `#34D399`, not `#10B981`, for contrast over the tinted background.

### Accessibility

All primary text on its respective surface must meet **WCAG AA (4.5:1 contrast ratio)** minimum:
- `on-bg-bright` (#F1F5F9) on `bg-root` (#08061A): ✅ AAA
- `on-bg-muted` (#94A3B8) on `bg-root` (#08061A): ✅ AA
- `primary` (#A855F7) on `bg-root` (#08061A): ✅ AA for large text/icons
- **Never use `on-bg-dim` or `on-bg-faint` for body text** — only labels, captions, and disabled states.

---

## Typography

**Font family:** `Inter` (Google Fonts). **Mono family:** `JetBrains Mono` (for IPs, codecs, timestamps, file paths).

Typography is organized into a strict scale. Do not invent intermediate sizes.

### Scale

| Style | Size | Weight | Line | Tracking | Use Case |
|-------|------|--------|------|----------|----------|
| `display-v2` | 24 | 700 | 1.1 | -0.01em | Page heroes, primary stat values, hero numbers |
| `h1` | 18 | 700 | 1.3 | — | Subscription / billing card titles |
| `h2` | 14 | 600 | 1.4 | — | Section / card titles ("Server Information", "Quick Access") |
| `body` | 13 | 500 | 1.4 | — | Primary body text, nav labels, table cell values |
| `body-small` | 12 | 500 | 1.4 | — | Dense rows, label/value strings |
| `caption` | 11 | 500 | 1.4 | — | Captions, sub-labels |
| `micro` | 10.5 | 500 | 1.4 | — | Sidebar IP / "uptime" metadata |
| `eyebrow` | 11 | 600 | 1.4 | 0.14em / UPPERCASE | Section eyebrows ("SYSTEM STATUS"), table headers |
| `mono-body` | 12 | 500 | 1.4 | — | IPs, codecs, technical strings |
| `mono-caption` | 11 | 500 | 1.4 | — | Compact mono — small log lines, stream IDs |
| `mono-micro` | 10.5 | 500 | 1.4 | — | Timestamps in dense log views |

### Rules
- **Never** use raw `px` values outside this scale in components. Half-pixel sizes (10.5) render fine; do not round them.
- `eyebrow` and any other UPPERCASE label must use `letter-spacing: 0.14em`.
- IP addresses, API tokens, file paths, codecs, and timestamps must always use the `mono-*` family.
- Stat card values use `display-v2` (24/700) for the value and `eyebrow` for the label.
- Table headers use `eyebrow` (11/600 UPPERCASE), not body weights.

---

## Layout

### Grid System
- **Desktop control panel:** Sidebar (180 px fixed) + main content area (fluid)
- **Mobile client (Flutter):** Single-column, bottom navigation, full-width cards
- **Content max-width:** `1200 px` centered in the main area for wide screens
- **Minimum window size (desktop):** 1200×720; below that the sidebar collapses

### Spacing Scale
All spacing comes from the locked set: 2, 4, 6, 8, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32. **Anything outside this set is a typo.**

| Context | Spacing |
|---------|---------|
| Internal card padding | `s14` (14 px) |
| Between cards in a grid | `s12` (12 px) |
| Between section headings and content | `s24` (24 px) |
| Sidebar item padding | `10 16` |
| Page content padding | `s22` (22 px) |
| Stat card gap | `s12` (12 px) |

### Stat Card Grid
Stat cards always appear in a **4-column grid** on desktop, collapsing to 2-column on tablet and 1-column on mobile.

### Library Grid
Library cards appear in a **3-column grid** on desktop, 2-column on tablet, 1-column on mobile.

---

## Elevation & Depth

The system uses **glass-on-gradient depth**:

1. **Layer 0 — Root:** `bg-root` (`#08061A`) + the global radial-gradient overlay
2. **Layer 1 — Glass surfaces:** `surface-glass` / `sidebar-glass` / `titlebar-glass` — translucent panes with `backdrop-filter: blur(20px)` on top of Layer 0
3. **Layer 2 — Glow/border emphasis:** A 1 px violet inner border (`rgba(168,85,247,0.25)`) plus a soft violet outer glow (`rgba(168,85,247,0.10)` at 24 px blur) — used for `card-glow`, focused inputs, hovered interactive cards

### Shadows
- **Cards at rest:** no drop shadow — `border-subtle` defines boundaries.
- **Glowing cards (`card-glow`):** `0 0 0 1px rgba(168,85,247,0.25), 0 0 24px rgba(168,85,247,0.10)` — used for the "active session" card, focused stat card, premium tier highlight.
- **Primary CTA glow (`button-glow`):** `0 4px 12px rgba(139,92,246,0.3)` — used for `button-primary` and the player play-button.
- **Status dot glow (`dot-glow`):** `0 0 8px <statusColor>` — applied to live `status-dot` for online/active/streaming.
- **Do not** use white or neutral drop shadows — they break the violet aesthetic. All shadows are violet-toned glows.

---

## Shapes

| Token | Value | Used For |
|-------|-------|----------|
| `rounded-xs` | `6px` | Chips, small badges |
| `rounded-sm` | `8px` | Buttons, inputs, small icon buttons |
| `rounded-md` | `10px` | Hover-tiles, quick-access cells, sleeve inputs |
| `rounded-lg` | `12px` | Primary cards, modals, library thumbnails, raised cards |
| `rounded-pill` | `9999px` | Status badges, avatar circles, pill labels, progress fills |

### Logo Mark
The Fluxora logo icon is always a square with `rounded-sm` (8 px) and the brand gradient background: `linear-gradient(135deg, #8B5CF6, #A855F7)`. The letter "F" inside is white, `font-weight: 800`, `font-size: 16px`.

---

## Components

### Buttons

Four variants — use the right one for the context.

**Primary** — single most important action on a screen ("Add Library", "Connect Client"):
```
background: linear-gradient(135deg, #8B5CF6, #A855F7)
color: #F1F5F9
border-radius: 8px
padding: 10px 20px
font-size: 13px / font-weight: 600
shadow: 0 4px 12px rgba(139,92,246,0.3)
```

**Secondary** — secondary actions alongside primary ("Cancel", "Edit"):
```
background: rgba(255,255,255,0.03)
border: 1px solid rgba(255,255,255,0.06)
color: #E2E8F0
border-radius: 8px
padding: 10px 20px
font-size: 13px / font-weight: 500
```

**Destructive** — irreversible actions ("Delete", "Stop server"):
```
background: rgba(239,68,68,0.10)
border: 1px solid rgba(239,68,68,0.3)
color: #F87171
border-radius: 8px
padding: 10px 20px
```

**Ghost** — tertiary/contextual ("View Logs", "Details"):
```
background: transparent
color: #94A3B8
border-radius: 8px
padding: 8px 16px
hover → color: #F1F5F9, background: rgba(255,255,255,0.04)
```

**Back navigation (sub-page chevron)** — paired with [`PageHeader.onBack`](apps/desktop/lib/shared/widgets/page_header.dart) at the top of every sub-page (folder browser, encoder settings, transcoding detail, etc.).  Top-level destinations (Dashboard, Library list, Activity) leave `onBack` null and skip the chevron.

```
shape: 36×36 square, border-radius 8px
icon: arrow_back_rounded 18px, color textBright
(rest):  fill rgba(255,255,255,0.03), border rgba(255,255,255,0.08)
(hover): fill rgba(168,85,247,0.10), border rgba(168,85,247,0.40)
animated: 120ms color transitions via AnimatedContainer

a11y: Semantics(button: true, label: 'Back') + Tooltip('Back', wait 350ms)
```

**Mounted guard.** `MouseRegion.onExit` can fire mid-route-transition after the back button's state has been disposed (because the back button itself triggered that transition).  Every `setState` inside the button's hover handlers must check `if (!mounted) return;` first — same pattern used across the codebase's hover-state widgets.  Skipping the guard surfaces as a "setState called after dispose" exception in the console.

Pages get the back chevron + behaviour for free by passing `onBack:` to `PageHeader` — don't reach for `_BackButton` directly (it's private inside `page_header.dart`).  Pages that route back to a known top-level destination should fall back via `context.canPop() ? context.pop() : context.go(Routes.<destination>)` so a deep-link hit (no router history) still has a destination.

### Inputs

```
background: rgba(255,255,255,0.04)
border: 1px solid rgba(255,255,255,0.06)
border-radius: 10px
color: #F1F5F9
padding: 10px 14px
font-size: 13px
placeholder-color: #64748B
focus → border: rgba(168,85,247,0.4)
```

### Cards

**Standard Card** — static information display:
```
background: rgba(20,18,38,0.7)
border: 1px solid rgba(255,255,255,0.06)
border-radius: 12px
padding: 14px
```

**Glow Card** — emphasized / active sessions / premium highlights:
```
background: rgba(20,18,38,0.7)
border: 1px solid rgba(168,85,247,0.25)
border-radius: 12px
shadow: 0 0 0 1px rgba(168,85,247,0.25), 0 0 24px rgba(168,85,247,0.10)
```

**Interactive Card** — clickable items (library cards, media items):
```
base: standard card
hover → border-color: rgba(168,85,247,0.4), shadow: 0 0 24px rgba(168,85,247,0.15)
transition: all 150ms ease
```

### Status Badges

Pill-shaped (`rounded-pill`). Foreground is a lighter shade of the base hue for contrast over the tinted background.

| State | Background | Text |
|-------|------------|------|
| Online / Success | `rgba(16,185,129,0.15)` | `#34D399` |
| Idle / Warning | `rgba(245,158,11,0.15)` | `#FBBF24` |
| Offline / Neutral | `rgba(71,85,105,0.18)` | `#94A3B8` |
| Streaming | `rgba(168,85,247,0.16)` | `#C4A8F5` |
| Error | `rgba(239,68,68,0.15)` | `#F87171` |
| Info | `rgba(59,130,246,0.15)` | `#60A5FA` |

### Sidebar Navigation

```
width: 180px
background: rgba(13,11,28,0.7)
backdrop-filter: blur(20px)
border-right: 1px solid rgba(255,255,255,0.06)

item:
  padding: 10px 16px
  font-size: 13px
  color: #64748B
  icon + label gap: 10px

item (active):
  background: rgba(168,85,247,0.16)   ← violet pill indicator, NOT slate fill
  color: #A855F7
  font-weight: 600

item (hover):
  color: #F1F5F9
  background: rgba(255,255,255,0.04)
```

The sidebar always contains, from top to bottom:
1. Logo bar (logo icon + wordmark)
2. Navigation items
3. (Spacer — flex-grow)
4. Server status block (server state, LAN IP, storage bar)

### Stat Cards

Four-across grid, always at the top of dashboard-style screens.

```
background: rgba(20,18,38,0.7)
border: 1px solid rgba(255,255,255,0.06)
border-radius: 12px
padding: 14px

value: 24px / 700 / #F1F5F9       (display-v2)
label: 11px / 600 / #64748B       (eyebrow, UPPERCASE, 0.14em)
delta: 11px / #34D399 (positive) or #94A3B8 (neutral)
```

### Tables

```
header: 11px / 600 / UPPERCASE / 0.14em / #64748B  (eyebrow)
header border-bottom: 1px solid rgba(255,255,255,0.06)
cell: 13px / 500 / #94A3B8                          (body, default-muted)
row border-bottom: 1px solid rgba(255,255,255,0.06)
padding per cell: 10px 12px

Primary text in a row (e.g., client name): #F1F5F9 / 500
Active stream column: #A855F7
```

### Flat data list rows (folder browser, future Sessions / Logs / file lists)

A lighter alternative to the bordered `Tables` treatment above for **dense data lists** where the operator scans many rows quickly and inter-row dividers add visual noise.  Established for the desktop folder browser ([`apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart`](apps/desktop/lib/features/library/presentation/screens/library_files_screen.dart)); reuse anywhere you'd otherwise reach for a Material `DataTable` row.

```
row: padding (8/12/16) per density × 12px horizontal, transparent fill, NO border, NO rounded corners
row separator: none (omit ListView.separated separators or use SizedBox.shrink)
row (hover):   background rgba(255,255,255,0.03), text #E2E8F0
row (selected): background rgba(168,85,247,0.08), text #E9D5FF
row (selected + hover): background rgba(168,85,247,0.12)

Column dividers (body): invisible 9px SizedBox spacers — present only so
header `_ResizableColumnDivider` boundaries line up pixel-for-pixel with
body cells; nothing is painted between body cells.
```

**Numeric column alignment.** Cells in columns whose content reads as a number — sizes, modified timestamps, durations, dimensions — right-align both the text (`textAlign: TextAlign.right`) and the cell box (`Align(alignment: Alignment.centerRight)`).  The units digit then stacks vertically across rows, which is the Windows Explorer convention every operator expects from a data table.  **Header labels stay LEFT-aligned** even in numeric columns — header reads as a label / sort affordance, not as a value.

**Empty cells render as `''`** rather than em-dash / `—` / `N/A`.  Most file rows have no value for several columns (durations on a PDF, dimensions on an audio file) and a sea of em-dashes is noisier than blank space.

**MouseRegion guard.** `onEnter`/`onExit` callbacks must check `if (!_hovered) setState(...)` before flipping the hover bool — Flutter fires identical hover events when sibling widgets rebuild mid-frame, and unguarded `setState`s churn the build phase for nothing.

**Reusable widget:** `FluxListRow` is not yet extracted because the row's tap / double-tap / selection / context-menu behaviour is too tightly coupled to per-screen state.  Three similar rows beats a premature abstraction here; copy the pattern + tints rather than reaching for a shared widget.

### Header band + column-reorder affordances (data lists)

When using the flat-row treatment above, the header gets a **separate visual treatment** so it reads as fixed chrome and not as another row.

```
header row: padding 0 (cells own their own vertical padding via AnimatedContainer)
header padding (outer): horizontal 12 only
header cell padding (inner): vertical 6
header cell at rest: transparent fill, label #94A3B8 / 12px / 500
header cell (hover): rgba(168,85,247,0.05) fill, AnimatedContainer 120ms transition
header cell (drag source while reordering): rgba(168,85,247,0.10) fill + 1px violet border, 55 % opacity
column divider (header): 9px-wide hit zone over a 1px line, violet 2px line on hover/drag
trailing column divider: present after the last header cell so the rightmost column has a resize handle
                        and the header row visually closes (doesn't trail off into empty space)
```

**Anti-pattern: `crossAxisAlignment: stretch` on the header `Row` inside an unbounded-height parent.** Visually identical to `center` because every cell has the same intrinsic height anyway, but `stretch` with infinite max-height leaves Draggable / AnimatedContainer descendants' intrinsic-height path inconsistent across layout passes.  A `RenderRepaintBoundary` inside the implicit ListView / Scrollbar chain ends up `NEEDS-PAINT` without a settled size every frame, the paint-time throw leaves Flutter's `_debugDuringDeviceUpdate` re-entrancy flag stuck, and the mouse_tracker assertion at `mouse_tracker.dart:199` then fires at ~1 Hz forever.  **Use `center` (the default), not `stretch`** — see `_SortableColumnHeaderRow` in the folder browser.

### Resizable column divider (data tables)

Established as `FluxResizableColumnDivider<T>` + `FluxColumnSpacer` ([`apps/desktop/lib/shared/widgets/flux_resizable_column_divider.dart`](apps/desktop/lib/shared/widgets/flux_resizable_column_divider.dart)).  Powers the column resize handles on both the folder browser AND the Clients table — the visual + drag behaviour is identical; only the column-identifier type and the backing width store differ per caller.

```
outer slot: 9px (`kFluxColumnDividerWidth`) — header divider + body spacer share this
inner line: 1px tall × 16px high, centered, color `border-subtle`
inner line (hover/drag): 2px tall × 16px high, color `primary` (violet)
cursor (hover): SystemMouseCursors.resizeLeftRight
drag axis: horizontal
drag math: newWidth = dragStartWidth + details.localPosition.dx
clamping: caller's responsibility (typically 80–480 px)
```

**Drag widens the LEFT column** — the column whose RIGHT edge this divider draws.  Windows Explorer convention.

**State is caller-owned.** The widget exposes two callbacks — `readWidth: double Function(T)` + `writeWidth: void Function(T, double)` — so callers plug in any backing store: a module-level `Map<T, double>` (Clients screen), a `SecureStorage` JSON blob (folder browser), or anything else.  The caller is also responsible for triggering rebuilds when widths change (typically a `ValueNotifier<int>` ticked from inside `writeWidth`, then `ListenableBuilder`/`addListener` against it from the header + each body row).

**Body alignment.** Body rows pair each `FluxResizableColumnDivider` in the header with one `FluxColumnSpacer` between body cells — an invisible 9-px `SizedBox` that reserves the same horizontal slot the header divider occupies so body cells line up pixel-for-pixel with the resize handles.

**Trailing divider.** Always include one `FluxResizableColumnDivider` AFTER the last header cell so the rightmost column has its own resize handle and the header row visually closes (doesn't trail off into empty space).  Body rows mirror this with a trailing `FluxColumnSpacer`.

**Total table width** = `2 * 18` (outer horizontal padding) + `N * 9` (N inter-column dividers + 1 trailing) + sum of column widths.  When this exceeds the viewport, wrap the header + listing in a shared `ScrollController` + `Scrollbar` + horizontal `SingleChildScrollView(SizedBox(width: totalTableWidth))` so header + body scroll in lockstep.  The pagination footer (if any) belongs OUTSIDE this horizontal scroll wrapper so it stays pinned to the card width — putting it inside causes the footer to stretch + scroll with the resized table, which reads as a bug.

### Toolbar pill button (filter / sort summary chips)

Established as `FluxToolbarPillButton` ([`apps/desktop/lib/shared/widgets/flux_toolbar_pill_button.dart`](apps/desktop/lib/shared/widgets/flux_toolbar_pill_button.dart)).  A rounded pill that summarises the current state of a multi-axis filter / sort group + opens a sticky popup on tap.

```
height: 26px (tuned to read as a peer of 28px toolbar icon buttons)
padding: 0 10px
shape: borderRadius 999px (fully rounded)
content: leading icon (12px) + label (Inter 11.5/500) + trailing caret (14px)

(rest):    border `border-subtle`, fill `bg-raised` (opaque dark — same as view-mode toggle + search input on data toolbars), fg `on-bg-muted`
(hover):   border `border-subtle`, fill `bg-raised + 8 % white overlay`, fg `on-bg`
(active):  border rgba(168,85,247,0.30), fill rgba(168,85,247,0.14), fg `primary-soft`, weight 600
animated: 120ms color transitions via AnimatedContainer
```

Active means "the caller's underlying state has a non-default value" — e.g. `Filter` at rest becomes `Filter: Videos · Indexed` once a kind filter + the indexed-only toggle are both set.  Multi-axis state collapses into one summary string so the operator sees what's applied at a glance without expanding the popup.

**Popup body** is caller-provided via a `popupBuilder` callback that receives the `LayerLink` to follow, a `dismiss` callback to wire into `TapRegion.onTapOutside`, and a `groupId` to attach to the popup's `TapRegion(groupId: …)`.  The trigger pill internally wears the same `groupId`, so a click on the trigger while the popup is open counts as INSIDE the tap group rather than outside — without sharing the id, the click would fire `onTapOutside` on pointer-down (popup hides) and the trigger's `onTap` on pointer-up (popup re-opens), making the trigger feel like it only ever opens the popup.  Anchor the popup with `CompositedTransformFollower` — `targetAnchor: bottomRight, followerAnchor: topRight, offset: Offset(0, 6)` right-aligns the popup to a trigger sitting on the right side of the toolbar so it extends DOWN+LEFT and stays on-screen.  Mirror the anchors for a left-side trigger.

**Shape variants.** `height` (default 26 px) + `borderRadius` (default fully-rounded `height/2`) are both parameterised:

| Shape | Use for |
|-------|---------|
| 26 px tall, fully-rounded pill (default) | Folder browser's Filter pill — sits next to 28 px icon buttons in a compact toolbar |
| 32 px tall, `BorderRadius.circular(7)` rounded-rectangle | Data-toolbar screens (Clients) — sits next to a search-box-style input so the pill reads as a peer of the input field, not as a floating chip |

### Filter pill (single-axis radio-group filter)

Established as `FluxFilterPill<T>` ([`apps/desktop/lib/shared/widgets/flux_filter_pill.dart`](apps/desktop/lib/shared/widgets/flux_filter_pill.dart)).  The single-axis assembly of `FluxToolbarPillButton` + glass popup + `FluxPopupRow.singleSelect` rows — what you want when the popup is just a flat radio group, no toggles or section headings.

```dart
FluxFilterPill<String>(
  leadingIcon: Icons.adjust_rounded,
  summary: status == 'All' ? 'All Status' : status,
  options: const ['All', 'Online', 'Pending', 'Revoked'],
  selected: status,
  optionIcon: (s) => /* per-option glyph */,
  optionLabel: (s) => s,
  isActive: status != 'All',
  onSelected: (v) => setState(() => status = v),
)
```

Defaults match the data-toolbar shape (32 px tall, `BorderRadius.circular(7)`, popup width 200, anchored to the LEFT of the trigger).  Override `popupAnchor: FluxFilterPillPopupAnchor.right` when the pill sits on the RIGHT side of the toolbar so the popup extends DOWN+LEFT and stays on-screen.

**Pick the right widget for the filter popup:**

| Pattern | Use |
|---------|-----|
| Single-axis radio group (Sort, Status, Device, Kind) — popup is a flat list of options | `FluxFilterPill<T>` |
| Multi-axis filter (single-select rows + boolean toggles + section headings + dividers) | Compose `FluxToolbarPillButton` + `FluxGlassPopupSurface` + `FluxPopupRow.{singleSelect,toggle}` directly.  Folder browser's Filter button is the canonical example. |

### Glass popup rows (filter / sort / picker bodies)

Established as `FluxPopupRow` ([`apps/desktop/lib/shared/widgets/flux_popup_row.dart`](apps/desktop/lib/shared/widgets/flux_popup_row.dart)).  Single row inside a glass popup — leading icon + label + trailing glyph, with the same hover + active tints used by the toolbar pill button's active state.

```
row padding: 8 vertical × 12 horizontal
row layout: icon (14px) + 10px gap + Expanded(label, Inter 12.5/500) + trailing widget
(rest):    transparent fill, fg `on-bg-muted`
(hover):   fill rgba(255,255,255,0.03), fg `on-bg`
(active):  fill rgba(168,85,247,0.10), fg `primary-soft`, weight 600
```

Two named constructors cover the standard treatments:

| Constructor | Trailing slot | Use for |
|-------------|---------------|---------|
| `FluxPopupRow.singleSelect(...)` | `check_rounded` (14 px, `primary-soft`) when active, blank 14 px otherwise | Radio-group rows — Filter kind, Sort key, view-mode picker |
| `FluxPopupRow.toggle(...)`       | `check_box_rounded` / `check_box_outline_blank_rounded`, colour-matches the row foreground | Boolean preference rows — Indexed only, Show hidden |

Both share the same hover + active treatment so the popup reads as one cohesive list even when single-select rows + toggle rows are stacked under a divider in the same body.  See `_BrowseFilterButton` in the folder browser for the canonical assembly: a 'SHOW' eyebrow heading, single-select kind rows, divider, indexed-only toggle row.

### Soft-refresh strip (background fetch indicator)

Established as `FluxRefreshIndicatorStrip` ([`apps/desktop/lib/shared/widgets/flux_refresh_indicator_strip.dart`](apps/desktop/lib/shared/widgets/flux_refresh_indicator_strip.dart)).  A 2-px indeterminate violet bar pinned to the top of a listing area while a background fetch is in flight.  Pairs with a "stale-while-revalidate" cubit that emits the existing loaded state with a `refreshing: true` flag (instead of flipping back to `*Loading`) so the chrome stays mounted.

```
height: 2px
fill (refreshing): indeterminate LinearProgressIndicator on transparent track, valueColor = `primary`
fill (idle):       SizedBox.shrink — slot collapses, parent column doesn't reserve dead space
```

Mount it inside the listing's outer `Stack` at `Positioned(top: 0, left: 0, right: 0)` so it floats over the listing without consuming vertical layout space.  Gate it via `BlocBuilder.buildWhen` so the strip only rebuilds when the refreshing flag actually flips.

### Progress Bars

```
track: rgba(255,255,255,0.08)
fill: linear-gradient(90deg, #8B5CF6, #A855F7)
height: 4px
border-radius: 9999px
```

### Tabs

```
container: background rgba(255,255,255,0.04), border-radius 10px, padding 4px
tab: 6px 16px, font-size 13px, font-weight 500, color #64748B
tab (active): background rgba(168,85,247,0.16), color #A855F7, border-radius 8px
```

### Tooltips

```
background: rgba(20,18,38,0.7)
backdrop-filter: blur(20px)
border: 1px solid rgba(255,255,255,0.06)
color: #F1F5F9
font-size: 12px
padding: 6px 10px
border-radius: 6px
```

---

## Pricing Tier Visual Identity

Each subscription tier has a distinct icon/color identity:

| Tier | Color | Icon | Accent |
|------|-------|------|--------|
| Free | Neutral (`rgba(71,85,105,0.18)`) | 🆓 | `#94A3B8` |
| Plus | Brand (violet gradient) | ⚡ | `#A855F7` |
| Pro | Warm (amber→red) | 👑 | `#F59E0B` |
| Ultimate | Cool (violet→cyan) | 💎 | `#22D3EE` |

The "Most Popular" badge on the Plus tier uses: `background: linear-gradient(135deg, #8B5CF6, #A855F7)`, `color: #F1F5F9`, positioned as an absolute pill above the card.

---

## Do's and Don'ts

### ✅ Do
- Use `rounded-lg` (12 px) for all primary cards and containers.
- Use `rounded-pill` for all status badges and pill labels.
- Use the brand gradient **only** for the logo, primary CTAs, and the main heading on the landing/onboarding screen.
- Ensure all IP addresses, file paths, codecs, and technical strings use the `mono-*` family.
- Use a `1px solid border-subtle` on all cards at rest — no shadow.
- Use `card-glow` (violet inner border + outer glow) on emphasized cards (active session, focused stat, premium highlight).
- Show streaming status with the `success` (#10B981) color and a subtle `dot-glow`.
- Keep the sidebar at exactly `180 px` — no wider.
- Keep all icon sizes consistent: `16 px` for inline nav icons, `22 px` for default action icons, `36 px` for feature icons.
- Use `eyebrow` (11/600/UPPERCASE/0.14em) for table headers and section labels.

### ❌ Don't
- Don't use the brand gradient as a text color on body copy — only on display headings.
- Don't use arbitrary border-radius values outside the defined scale.
- Don't use white or neutral-toned drop shadows — only violet-toned glows.
- Don't add a light mode — the dark theme is the only supported mode.
- Don't mix status badge colors outside the defined set (success / warning / error / info / streaming / neutral).
- Don't use `font-weight: 400` for headings — use `600` or `700`.
- Don't use multiple CTA buttons of the same variant in a single view — establish clear hierarchy.
- Don't use raw pixel values for spacing outside the locked spacing set.
- Don't place gradient backgrounds behind text unless there is sufficient contrast (`on-bg-bright` minimum).
- Don't use animation duration longer than `300 ms` for micro-interactions.
- Don't introduce solid slate surfaces — use `surface-glass` over `bg-root`. The palette has no slate; if you find yourself reaching for an off-system color, stop and pick from §Colors.
