---
version: alpha
name: Fluxora Dark

colors:
  # Brand / Primary
  primary: "#6366F1"
  primary-variant: "#8B5CF6"
  accent: "#22D3EE"
  accent-purple: "#A855F7"

  # Surfaces
  background: "#0F172A"
  surface: "#1E293B"
  surface-raised: "#334155"
  surface-muted: "#475569"

  # Text
  on-background: "#E2E8F0"
  on-surface: "#94A3B8"
  on-surface-muted: "#64748B"
  on-surface-disabled: "#475569"

  # Semantic
  success: "#22C55E"
  warning: "#F59E0B"
  error: "#EF4444"
  info: "#3B82F6"

  # Semantic surfaces (tinted backgrounds)
  success-surface: "rgba(34, 197, 94, 0.12)"
  warning-surface: "rgba(245, 158, 11, 0.12)"
  error-surface: "rgba(239, 68, 68, 0.12)"

  # Gradient stops
  gradient-start: "#6366F1"
  gradient-mid: "#8B5CF6"
  gradient-end: "#22D3EE"

typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.02em"

  display-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "-0.01em"

  heading-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.3

  heading-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.4

  heading-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0.08em"
    textTransform: uppercase

  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.6

  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.6

  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.5

  caption:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.4
    color: "#64748B"

  label:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: "0.1em"
    textTransform: uppercase

  mono:
    fontFamily: "JetBrains Mono, Fira Code, monospace"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.6

rounded:
  none: "0px"
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "12px"
  xl: "16px"
  xxl: "24px"
  full: "9999px"

spacing:
  "1": "4px"
  "2": "8px"
  "3": "12px"
  "4": "16px"
  "5": "20px"
  "6": "24px"
  "8": "32px"
  "10": "40px"
  "12": "48px"
  "16": "64px"
  "20": "80px"

elevation:
  none: "none"
  sm: "0 1px 3px rgba(0,0,0,0.3)"
  md: "0 4px 12px rgba(0,0,0,0.4)"
  lg: "0 8px 24px rgba(0,0,0,0.5)"
  glow-primary: "0 0 24px rgba(99, 102, 241, 0.25)"
  glow-accent: "0 0 20px rgba(34, 211, 238, 0.2)"

components:
  button-primary:
    background: "#6366F1"
    color: "#FFFFFF"
    borderRadius: "8px"
    padding: "10px 20px"
    fontSize: "14px"
    fontWeight: "600"
    hoverBackground: "#4F46E5"
    activeBackground: "#4338CA"

  button-secondary:
    background: "transparent"
    color: "#E2E8F0"
    border: "1px solid #334155"
    borderRadius: "8px"
    padding: "10px 20px"
    fontSize: "14px"
    fontWeight: "500"
    hoverBackground: "#1E293B"

  button-ghost:
    background: "transparent"
    color: "#94A3B8"
    borderRadius: "8px"
    padding: "8px 16px"
    fontSize: "14px"
    fontWeight: "500"
    hoverColor: "#E2E8F0"
    hoverBackground: "#1E293B"

  card:
    background: "#1E293B"
    border: "1px solid #334155"
    borderRadius: "12px"
    padding: "20px"

  card-interactive:
    background: "#1E293B"
    border: "1px solid #334155"
    borderRadius: "12px"
    hoverBorder: "#6366F1"
    hoverShadow: "0 0 24px rgba(99, 102, 241, 0.2)"
    transition: "all 150ms ease"

  input:
    background: "#0F172A"
    border: "1px solid #334155"
    borderRadius: "8px"
    color: "#E2E8F0"
    padding: "10px 14px"
    fontSize: "14px"
    focusBorder: "#6366F1"
    focusShadow: "0 0 0 3px rgba(99, 102, 241, 0.2)"
    placeholderColor: "#475569"

  badge:
    borderRadius: "9999px"
    padding: "3px 12px"
    fontSize: "11px"
    fontWeight: "600"

  badge-success:
    background: "rgba(34, 197, 94, 0.15)"
    color: "#22C55E"

  badge-warning:
    background: "rgba(245, 158, 11, 0.15)"
    color: "#F59E0B"

  badge-error:
    background: "rgba(239, 68, 68, 0.15)"
    color: "#EF4444"

  badge-neutral:
    background: "rgba(71, 85, 105, 0.15)"
    color: "#64748B"

  sidebar:
    background: "#1E293B"
    width: "180px"
    borderRight: "1px solid #334155"

  sidebar-item:
    padding: "10px 16px"
    fontSize: "13px"
    color: "#64748B"
    borderRadius: "0"
    activeBackground: "#334155"
    activeColor: "#E2E8F0"
    hoverColor: "#E2E8F0"

  nav-logo:
    iconSize: "32px"
    iconBorderRadius: "8px"
    iconBackground: "linear-gradient(135deg, #6366F1, #8B5CF6)"
    fontSize: "15px"
    fontWeight: "700"

  stat-card:
    background: "#0F172A"
    border: "1px solid #334155"
    borderRadius: "10px"
    padding: "16px"
    valueFontSize: "24px"
    valueFontWeight: "700"
    labelFontSize: "12px"
    labelColor: "#64748B"

  table:
    headerColor: "#64748B"
    headerFontSize: "13px"
    headerFontWeight: "500"
    rowBorderColor: "#1E293B"
    cellColor: "#94A3B8"
    cellFontSize: "13px"
    padding: "10px 12px"

  progress-bar:
    height: "4px"
    background: "#334155"
    fill: "#6366F1"
    borderRadius: "4px"

  tooltip:
    background: "#334155"
    color: "#E2E8F0"
    fontSize: "12px"
    padding: "6px 10px"
    borderRadius: "6px"

  status-dot:
    size: "8px"
    borderRadius: "50%"
    online: "#22C55E"
    idle: "#F59E0B"
    offline: "#475569"
---

# Fluxora Design System

## Overview

Fluxora is a **self-hosted hybrid media streaming platform** — the spiritual successor to Plex, rebuilt with a privacy-first, LAN-native philosophy. The interface must feel **powerful without being overwhelming**, projecting technical confidence while remaining approachable to non-developers who simply want to stream their personal media collection.

### Brand Personality
- **Dark-native** — The UI lives in the dark. Light mode is not part of the v1 scope.
- **Precision & Control** — Users are managing servers, streams, and clients. The interface must surface data clearly without visual noise.
- **Modern Streaming Aesthetic** — Inspired by the premium feel of Linear, Vercel, and Plex's Dark theme.
- **Understated Vibrancy** — Color is used deliberately: indigo/violet for primary actions, cyan for connectivity states, green for active/healthy.

### Design Tone
Calm authority. The interface should never feel chaotic. Information density is high but organized. Animations are subtle — they confirm actions, not distract from content.

---

## Colors

### Primary Palette

The primary brand colors communicate **action and identity**.

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#6366F1` | CTAs, active nav items, focus rings, progress bars |
| `primary-variant` | `#8B5CF6` | Gradient endpoints, hover states on primary elements |
| `accent` | `#22D3EE` | LAN/Internet connectivity status, highlight badges |
| `accent-purple` | `#A855F7` | Decorative gradients, tier badges |

The brand gradient is: `linear-gradient(135deg, #6366F1, #8B5CF6, #22D3EE)`. Use for logo marks, hero headings, and premium tier callouts. **Never** use the gradient on body text.

### Surface Hierarchy

Surfaces create a sense of **depth and layering** in the dark theme.

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#0F172A` | Page background, deepest layer (stat cards inset against surface) |
| `surface` | `#1E293B` | Cards, sidebar, modals — the primary container surface |
| `surface-raised` | `#334155` | Table row hover, active nav, input borders, dividers |
| `surface-muted` | `#475569` | Disabled borders, secondary dividers |

### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `on-background` | `#E2E8F0` | Primary headings and body text |
| `on-surface` | `#94A3B8` | Secondary body text, table cells |
| `on-surface-muted` | `#64748B` | Labels, metadata, captions, placeholder text |
| `on-surface-disabled` | `#475569` | Disabled states |

### Semantic Colors

Semantic colors communicate **system status and feedback**. Use them consistently.

| Token | Hex | When to Use |
|-------|-----|-------------|
| `success` | `#22C55E` | Online clients, active streams, successful operations |
| `warning` | `#F59E0B` | Idle clients, slow connections, degraded performance |
| `error` | `#EF4444` | Failed streams, errors, dangerous actions |
| `info` | `#3B82F6` | Informational states, neutral notifications |

For semantic badges, pair the color with a 12–15% opacity background of the same hue.

### Accessibility

All primary text on its respective surface must meet **WCAG AA (4.5:1 contrast ratio)** minimum:
- `on-background` (#E2E8F0) on `background` (#0F172A): ✅ passes
- `on-surface` (#94A3B8) on `surface` (#1E293B): ✅ passes
- `primary` (#6366F1) on `background` (#0F172A): ✅ passes for large text/icons

---

## Typography

**Font family:** `Inter` (from Google Fonts). Import at the earliest point in the application.

Typography is organized into a strict scale. Do not invent intermediate sizes.

### Scale

| Style | Size | Weight | Use Case |
|-------|------|--------|----------|
| `display-lg` | 32px | 700 | Page heroes, onboarding headings |
| `display-md` | 24px | 700 | Section titles within a hero |
| `heading-lg` | 20px | 600 | In-page screen titles (e.g., "Clients") |
| `heading-md` | 16px | 600 | Card headings, modal titles |
| `heading-sm` | 13px | 500 | Section labels (uppercase, tracked) |
| `body-lg` | 16px | 400 | Introductory paragraphs |
| `body-md` | 14px | 400 | Standard body copy, table content |
| `body-sm` | 13px | 400 | Sidebar items, compact lists |
| `caption` | 12px | 400 | Metadata, timestamps, file counts |
| `label` | 11px | 500 | All-caps labels (uppercase, tracked) |
| `mono` | 13px | 400 | IP addresses, file paths, code, tokens |

### Rules
- **Never** use raw `px` values outside this scale in components.
- `heading-sm` and `label` should always be rendered in `uppercase` with `letter-spacing: 0.08em` or `0.1em`.
- IP addresses, API tokens, and file paths must always use `mono`.
- Numbers in stat cards use `display-md` (24px/700) for the value and `caption` for the label.

---

## Layout

### Grid System
- **Desktop control panel (PC):** Sidebar (180px fixed) + main content area (fluid)
- **Mobile client (Flutter):** Single-column, bottom navigation, full-width cards
- **Content max-width:** `1200px` centered in the main area for wide screens

### Spacing Scale
All spacing must be a multiple of **4px**. Use the spacing tokens (1=4px, 2=8px, 4=16px, etc.).

| Context | Spacing |
|---------|---------|
| Between section headings and content | `spacing-6` (24px) |
| Between cards in a grid | `spacing-3` (12px) |
| Internal card padding | `spacing-5` (20px) |
| Sidebar item padding | `10px 16px` |
| Page content padding | `spacing-6` (24px) |
| Stat card gap | `spacing-3` (12px) |

### Stat Card Grid
Stat cards always appear in a **4-column grid** on desktop, collapsing to 2-column on tablet and 1-column on mobile.

### Library Grid
Library cards appear in a **3-column grid** on desktop, 2-column on tablet, 1-column on mobile.

---

## Elevation & Depth

Fluxora uses **three-layer depth**:

1. **Layer 0 — Base:** `background` (#0F172A) — page background, inset elements like stat cards
2. **Layer 1 — Surface:** `surface` (#1E293B) — primary containers: cards, sidebar, modals
3. **Layer 2 — Raised:** `surface-raised` (#334155) — interactive hover states, dropdowns, tooltips

### Shadows
- Cards at rest: **no shadow** — borders define boundaries at `border: 1px solid #334155`.
- Interactive cards on hover: `glow-primary` — `0 0 24px rgba(99, 102, 241, 0.25)`. Pair with border color change to `primary`.
- Modals and overlays: `elevation-lg` — `0 8px 24px rgba(0,0,0,0.5)`.
- Do **not** use white-toned shadows. All shadows must be dark or colored glows.

### Status Glow
When a client is streaming (`success`), the status indicator may use a subtle `0 0 8px rgba(34, 197, 94, 0.5)` glow effect to communicate live activity.

---

## Shapes

All shapes follow a **consistent border-radius scale**. Do not mix arbitrary values.

| Token | Value | Used For |
|-------|-------|----------|
| `rounded-none` | `0px` | Table row backgrounds, sidebar active state |
| `rounded-xs` | `4px` | Progress bars, small UI chips |
| `rounded-sm` | `6px` | Tooltips, small badges |
| `rounded-md` | `8px` | Buttons, inputs, small cards, nav logo icon |
| `rounded-lg` | `12px` | Primary cards, modals, library thumbnails |
| `rounded-xl` | `16px` | Large feature cards, pricing tier cards |
| `rounded-full` | `9999px` | Status badges, avatar circles, pill labels |

### Logo Mark
The Fluxora logo icon is always a square with `rounded-md` (8px) and the brand gradient background: `linear-gradient(135deg, #6366F1, #8B5CF6)`. The letter "F" inside is white, `font-weight: 800`, `font-size: 16px`.

---

## Components

### Buttons

Three variants — use the right one for the context.

**Primary:** For the single most important action on a screen (e.g., "Add Library", "Connect Client").
```
background: #6366F1
color: white
border-radius: 8px
padding: 10px 20px
font-size: 14px / font-weight: 600
hover → background: #4F46E5
```

**Secondary:** For secondary actions alongside a primary button (e.g., "Cancel", "Edit").
```
background: transparent
border: 1px solid #334155
color: #E2E8F0
hover → background: #1E293B
```

**Ghost:** For tertiary/contextual actions within cards or tables (e.g., "View Logs", "Details").
```
background: transparent
color: #94A3B8
hover → color: #E2E8F0, background: #1E293B
```

### Inputs

All inputs share a common foundation:
```
background: #0F172A
border: 1px solid #334155
border-radius: 8px
color: #E2E8F0
padding: 10px 14px
placeholder-color: #475569
focus → border: #6366F1, box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.2)
```

### Cards

**Standard Card** — for static information display:
```
background: #1E293B
border: 1px solid #334155
border-radius: 12px
padding: 20px
```

**Interactive Card** — for clickable items (library cards, media items):
```
background: #1E293B
border: 1px solid #334155
border-radius: 12px
hover → border-color: #6366F1, box-shadow: 0 0 24px rgba(99, 102, 241, 0.2)
transition: all 150ms ease
```

### Status Badges

Badges communicate client/stream status. They are always pill-shaped (`rounded-full`).

| State | Background | Text |
|-------|------------|------|
| Online | `rgba(34,197,94,0.15)` | `#22C55E` |
| Idle | `rgba(245,158,11,0.15)` | `#F59E0B` |
| Offline | `rgba(71,85,105,0.15)` | `#64748B` |
| Streaming | `rgba(99,102,241,0.15)` | `#6366F1` |

### Sidebar Navigation

```
width: 180px
background: #1E293B
border-right: 1px solid #334155

item:
  padding: 10px 16px
  font-size: 13px
  color: #64748B
  icon + label gap: 10px

item (active):
  background: #334155
  color: #E2E8F0

item (hover):
  color: #E2E8F0
```

The sidebar always contains, from top to bottom:
1. Logo bar (logo icon + wordmark)
2. Navigation items
3. (Spacer — flex-grow)
4. Server status block (server state, LAN IP, storage bar)

### Stat Cards

Four-across grid, always at the top of dashboard-style screens.

```
background: #0F172A  (inset, one layer below the page surface)
border: 1px solid #334155
border-radius: 10px
padding: 16px

value: 24px / 700 / #E2E8F0
label: 12px / 400 / #64748B  (below value)
delta: 11px / #22C55E (for positive change) or #64748B (neutral)
```

### Tables

```
header: 13px / 500 / #64748B
header border-bottom: 1px solid #334155
cell: 13px / 400 / #94A3B8
row border-bottom: 1px solid #1E293B
padding per cell: 10px 12px

Primary text in a row (e.g., client name): #E2E8F0 / 500
Active stream column: #6366F1
```

### Progress Bars

```
track: #334155
fill: #6366F1
height: 4px
border-radius: 4px
```

### Tabs

```
container: background #0F172A, border-radius 8px, padding 4px
tab: 6px 16px, font-size 13px, font-weight 500, color #64748B
tab (active): background #1E293B, color #E2E8F0, border-radius 6px
```

---

## Pricing Tier Visual Identity

Each subscription tier has a distinct icon/color identity:

| Tier | Color | Icon | Accent |
|------|-------|------|--------|
| Free | Neutral (#1E293B) | 🆓 | `#64748B` |
| Plus | Brand (`primary` gradient) | ⚡ | `#6366F1` |
| Pro | Warm (amber→red) | 👑 | `#F59E0B` |
| Ultimate | Cool (violet→cyan) | 💎 | `#22D3EE` |

The "Most Popular" badge on the Plus tier uses: `background: #6366F1`, `color: white`, positioned as an absolute pill above the card.

---

## Do's and Don'ts

### ✅ Do
- Use `rounded-lg` (12px) for all primary cards and containers.
- Use `rounded-full` for all status badges and pill labels.
- Use the brand gradient **only** for the logo, premium callouts, and the main heading on the landing/onboarding screen.
- Ensure all IP addresses, file paths, and technical strings use the `mono` font.
- Use a `1px solid #334155` border on all cards at rest — no shadow.
- Use a `glow-primary` shadow + `#6366F1` border on interactive cards when hovered.
- Show streaming status with the `success` (#22C55E) color and a subtle glow.
- Keep the sidebar at exactly `180px` — no wider.
- Keep all icon sizes consistent: `16px` for inline nav icons, `24px` for action icons, `36px` for feature icons.

### ❌ Don't
- Don't use the brand gradient as a text color on body copy — only on display headings.
- Don't use arbitrary border-radius values outside the defined scale.
- Don't use white or light-toned shadows — they break the dark theme aesthetic.
- Don't add a light mode — the dark theme is the only supported mode for v1.
- Don't mix status badge colors outside the defined set (success/warning/error/neutral/streaming).
- Don't use `font-weight: 400` for headings — use `600` or `700`.
- Don't use multiple CTA buttons of the same variant in a single view — establish clear hierarchy.
- Don't use raw pixel values for spacing outside the defined 4px-scale tokens.
- Don't place brand gradient backgrounds behind text unless there is sufficient contrast.
- Don't use any animation duration longer than `300ms` for micro-interactions.
