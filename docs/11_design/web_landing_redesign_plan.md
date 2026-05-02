# Web Landing Page Redesign — Implementation Plan

> **Status:** ✅ Implemented 2026-05-02 (initial PR) → ✅ Hardened 2026-05-02 (gap-fix round: 38 fixes covering legal/conversion/a11y/performance — see §16 change-log entry 3)
> **Created:** 2026-05-02
> **Last updated:** 2026-05-02
> **Owner:** Marshal
> **Source design:** [`docs/11_design/ref images/web/web_landing_hero.png`](./ref%20images/web/web_landing_hero.png) and [`docs/11_design/ref images/web/web_landing_full_layout.png`](./ref%20images/web/web_landing_full_layout.png)
> **Target:** [`apps/web_landing/`](../../apps/web_landing/) — Next.js 16 static-export landing page (`fluxora.marshalx.dev`)

This plan rebuilds the marketing site to match the new violet-themed, two-column hero design and brings the page in visual lockstep with the desktop redesign (same brand palette, same primitives' aesthetic).

---

## 1. Inputs

**Reference images:**
- [`web_landing_hero.png`](./ref%20images/web/web_landing_hero.png) — the single-page **landing hero + feature row + popular movies + libraries strip**. This is the canonical hero composition.
- [`web_landing_full_layout.png`](./ref%20images/web/web_landing_full_layout.png) — a **multi-page mood-board grid** showing additional pages (pricing, sign-in / sign-up, comparison table, How Fluxora Works, Help Center, Blog, About, account / footer). Treated as **future-state moodboard**, not as scope-of-this-PR.

**Current state** ([`apps/web_landing/`](../../apps/web_landing/)):
- Next.js 16.2.4, React 19, TypeScript, static export (`output: 'export'`)
- Routes: `/`, `/manage/`, `/success/`
- Components: `Navbar`, `Hero`, `Features`, `HowItWorks`, `Pricing`, `Platforms`, `Footer`
- Style: single-column centered hero, indigo `#6366F1` primary, no media imagery, INR pricing (Core ₹0 / Plus ₹99 / Pro ₹199 / Ultimate ₹4,499 lifetime)

---

## 2. Decisions

**Locked-in by owner 2026-05-02** (italics = my recommendation when answer was "decide for me").

| # | Decision | Status | Resolution |
|---|----------|--------|------------|
| 1 | Scope of this PR | ✅ Locked | **Landing page only** (single scrolling page, no new routes). May include additional sections beyond the original list — see §3 row additions. |
| 2 | Indigo → violet brand migration | ✅ Locked | **Yes — full migration** to match desktop redesign palette. ("design work should be same — don't change that") |
| 3 | Pricing currency | ✅ *Locked (recommendation)* | **Keep INR** (`₹0 / ₹99 / ₹199 / ₹4,499`). The ref's `$0/$4.99/...` is illustrative. |
| 4 | Tier name — "Core" vs "Free" | ✅ Locked | **`Fluxora Free`** — owner said "pick whichever you want"; chose `Free` because it's universally understood as ₹0 by someone arriving cold. Marketing-copy change only — server / Polar / license-key system never used "Core" as an identifier. |
| 5 | Desktop mockup in hero | ✅ Locked | **Use the ref image** (`docs/11_design/ref images/desktop/desktop_dashboard_redesign.png`) as a placeholder. Manual task §12.1 tracks swapping for a real screenshot post desktop M3. |
| 6 | Popular Movies / Library posters | ✅ Locked | **Stock placeholders sourced from free image sites** (Pexels / Pixabay / Unsplash — public-domain or CC0). Manual task §12.2 tracks the eventual swap to commissioned art if desired. |
| 7 | Animation budget — reuse SVGs | ✅ *Locked (recommendation)* | **Yes** — copy `hero_waves.svg` from `fluxora_core/assets/illustrations/` into `apps/web_landing/public/illustrations/`. |
| 8 | Auth / Help / Blog / About — separate routes? | ✅ Locked | **No new routes this PR.** Per "you can add more sections if needed" — fold lightweight versions into scrolled sections of `/` (FAQ accordion, About teaser strip, Resources footer column). Full sub-pages remain future work. |
| 9 | Tier comparison table | ✅ *Locked (recommendation)* | **Add** below pricing cards. |
| 10 | Blog / Help teasers | ✅ Locked | **Add lightweight versions inline:** FAQ accordion + About teaser strip (per decision 8). No blog teaser — defer until blog content exists. |
| 11 | CSS approach | ✅ *Locked (recommendation)* | **Keep `globals.css`** single-file. |

### Background on row 4 (tier name)

The lowest tier on the live marketing site was previously called **`"Fluxora Core"`** (₹0/forever) — see [`apps/web_landing/src/components/Pricing.tsx`](../../apps/web_landing/src/components/Pricing.tsx) line 31 (pre-redesign). The reference image labels the same tier **`"Free"`**. Renaming to `Fluxora Free` is a marketing-copy change only; nothing in the server / Polar / license-key system uses "Core" as an identifier, so no migration is needed.

---

## 3. Information architecture — landing page (`/`)

Sections in vertical order:

| # | Section | Status | Component |
|---|---------|--------|-----------|
| 1 | **Navbar** (sticky, glass) | Update — violet primary; add nav anchors `Movies / TV Shows / Music / Documents / Photos` and `Pricing`; right-side `Search` icon, `Sign In`, `Get Started` button | `Navbar.tsx` (modify) |
| 2 | **Hero** — two-column (text + desktop mockup) | **Replace** | `Hero.tsx` (rewrite) |
| 3 | **Feature row** — 4 cards: All Your Content / Any Devices / Secure & Private / Download & Offline / Multi-User | Update — match the violet card with check-pill accents; rewrite copy | `Features.tsx` (rewrite) |
| 4 | **Popular Movies** (decorative carousel of mock posters) | **New** | `PopularMovies.tsx` (new) |
| 5 | **Your Libraries** (5 colored category tiles: Movies / TV / Documents / Music / Photos) | **New** | `LibraryTiles.tsx` (new) |
| 6 | **How Fluxora Works** — 3-step diagram (Install Server → Pair Devices → Stream Anywhere) | Update — match new visual style; keep copy | `HowItWorks.tsx` (modify) |
| 7 | **Pricing** — 4 tier cards (Free / Plus / Pro / Ultimate) | Update — restyle to match the rounded-violet refs; swap "Core" → "Free" copy; keep INR pricing | `Pricing.tsx` (modify) |
| 8 | **Tier comparison table** — feature matrix across tiers with check / dash glyphs | **New** | `TierComparison.tsx` (new) |
| 9 | **Platforms** — 5 cards: Windows / macOS / Linux / iOS / Android | Update — restyle, keep copy | `Platforms.tsx` (modify) |
| 9.5 | **Screenshots gallery** — 6-tab pure-CSS carousel of desktop control-panel surfaces (Dashboard / Library / Clients / Groups / Settings / Logs) | **New** (added in 2026-05-02 gap-fix round) | `Screenshots.tsx` (new) |
| 10 | **FAQ accordion** — 6–8 expandable Q&A items | **New** (added per decision 8) | `Faq.tsx` (new) |
| 11 | **About teaser strip** — short "What is Fluxora?" band with a link to a future `/about` page | **New** (added per decision 10) | `AboutStrip.tsx` (new) |
| 12 | **CTA strip** — final "Start streaming today" band with a single button | **New** | `FinalCta.tsx` (new) |
| 13 | **Footer** with TMDB attribution band | Update — add 4-column layout (Product / Resources / Company / Connect) plus mandatory TMDB-API attribution band | `Footer.tsx` (modify) |
| 14 | **/privacy + /terms full content pages** | **New routes** (added in gap-fix round — DPDP-aware boilerplate) | `app/privacy/page.tsx`, `app/terms/page.tsx`, `LegalLayout.tsx` (shared shell) |

**Cuts:** the existing `hero-meta` row ("Works offline on LAN / Auto-switches to internet / Windows · macOS · …") is folded into the new feature cards. Removed.

---

## 4. Visual-token migration

The landing page needs its own copy of the redesign tokens because Next.js can't import from a Flutter package. New `globals.css` `:root` block (replacing the existing 12 vars):

```css
:root {
  /* Backgrounds */
  --bg:                 #08061A;            /* was #0f172a */
  --bg-radial-violet:   rgba(168,85,247,0.12);
  --bg-radial-cyan:     rgba(34,211,238,0.06);

  /* Surfaces */
  --surface:            rgba(20,18,38,0.7); /* glass */
  --surface-solid:      #141226;
  --surface-raised:     #1E1A36;

  /* Borders */
  --border-subtle:      rgba(255,255,255,0.06);
  --border-hover:       rgba(168,85,247,0.4);

  /* Text */
  --text-bright:        #F1F5F9;
  --text-body:          #E2E8F0;
  --text-muted:         #94A3B8;
  --text-dim:           #64748B;

  /* Brand */
  --violet:             #A855F7;            /* was --primary #6366F1 */
  --violet-deep:        #8B5CF6;            /* gradient pair */
  --violet-tint:        #C4A8F5;
  --cyan:               #22D3EE;
  --pink:               #EC4899;            /* movie-poster accent in ref */
  --emerald:            #10B981;            /* success / library count */
  --amber:              #F59E0B;            /* tier-ultimate accent */

  /* Gradients */
  --grad-brand:         linear-gradient(135deg, var(--violet-deep), var(--violet));
  --grad-progress:      linear-gradient(90deg, var(--violet-deep), var(--violet));
  --grad-text:          linear-gradient(135deg, var(--violet-tint), var(--violet));

  /* Shadows */
  --shadow-card-glow:   0 0 0 1px rgba(168,85,247,0.25), 0 0 24px rgba(168,85,247,0.10);
  --shadow-button:      0 4px 12px rgba(139,92,246,0.30);

  /* Radii */
  --radius-card:        12px;
  --radius-btn:         10px;
  --radius-pill:        9999px;
}
```

**Old `--primary` removed.** Every reference (`Navbar`, `btn-primary`, `pricing-badge`, `feature-icon` bg, `hero-badge`, `step-number`, etc.) updates to `--violet`.

**Background**: replace the body's flat `#0f172a` with the layered radial wash from the desktop redesign:
```css
body {
  background:
    radial-gradient(1200px circle at 0% 0%, var(--bg-radial-violet), transparent 50%),
    radial-gradient(1000px circle at 100% 100%, var(--bg-radial-cyan), transparent 50%),
    var(--bg);
}
```

---

## 5. Section-by-section spec

### 5.1 Navbar

```
+-------------------------------------------------------------------------------+
| [F]Fluxora   Movies  TV Shows  Music  Documents  Photos    Pricing            |
|                                                  🔍  Sign In  [Get Started]   |
+-------------------------------------------------------------------------------+
```

- Height 64 px, sticky, glass (existing pattern)
- Logo: replace text-only with the brand mark — copy `packages/fluxora_core/assets/brand/logo-icon.png` and `logo-wordmark.png` into `apps/web_landing/public/brand/`. `<img>` mark (28 px) + wordmark text-image (height 14 px) + `· Stream. Sync. Anywhere.` subtitle in `--text-dim`
- Nav links: add `Movies / TV Shows / Music / Documents / Photos / Pricing` — these scroll-anchor to nothing functional yet; either hide them or make them all jump to `#libraries` for now (decision 1 above). Recommended: **show all six links** anchored to `#popular-movies`, `#libraries`, `#libraries`, `#libraries`, `#libraries`, `#pricing` so the nav doesn't feel empty.
- Right-side: search icon button (visual only, opens nothing in v1), `Sign In` ghost link, `Get Started` primary button → `#pricing`

### 5.2 Hero

```
+-----------------------------------+--------------------------------------+
|                                   |   ╭──── desktop mockup ────╮         |
|   Stream. Sync.                   |   │ [Sidebar] Continue Watching│      |
|   Anywhere. (gradient)            |   │ Library  [poster][poster][p]│     |
|                                   |   │ Clients   Recently Added    │     |
|   Your personal media on the      |   │ Settings  [poster][poster]  │     |
|   hub. Access your movies,        |   ╰─────────────────────────────╯    |
|   series, documents and more      |                                      |
|   on any device, anytime.         |                                      |
|                                   |                                      |
|   [Get Started]  [▶ Learn More]   |                                      |
|   ~~ HeroWaves SVG behind ~~      |                                      |
+-----------------------------------+--------------------------------------+
```

- Two-column grid: `grid-template-columns: 1.05fr 1.25fr`, gap `4rem`. Stack to single column at `< 960 px`.
- **Left column**:
  - Heading: `Stream. Sync.` in `--text-bright`, `Anywhere.` on its own line in `--grad-text` (background-clip text). Font 4.5–6 vw, 800, letter-spacing -0.03em.
  - Subhead in `--text-muted`, max-width 480 px.
  - Two CTAs: **Get Started** primary (`--grad-brand`, glow), **Learn More** ghost with a play-circle icon.
  - **HeroWaves SVG** absolutely positioned behind the text, opacity 0.6 — copy `packages/fluxora_core/assets/illustrations/hero_waves.svg` to `public/illustrations/`.
- **Right column**:
  - Single screenshot (PNG/WebP) of the redesigned desktop Dashboard. Asset: `public/mockups/desktop-dashboard.png`. Source the screenshot **from the prototype** running at `http://localhost:8765/Fluxora%20Desktop.html` once the desktop redesign's M3 lands; for the landing PR, use `docs/11_design/ref images/desktop/desktop_dashboard_redesign.png` as a placeholder.
  - Wrap in a "browser-frame" `<div>` with subtle macOS traffic-light dots (purely decorative).
  - Soft glow: `box-shadow: 0 0 80px rgba(168,85,247,0.20)`.

### 5.3 Feature row

Four cards, equal width, single row at desktop / 2 × 2 at tablet / single column at mobile. Each is a `FluxCard`-equivalent (`background: var(--surface)`, border `var(--border-subtle)`, radius 12, padding 24). Each has:

- A 32 × 32 violet-tinted icon-bg square (radius 8) with the icon in `--violet`
- Title in `--text-bright`, 14 / 600
- Sub-text in `--text-muted`, 12 / 400, line-height 1.5
- A tiny `✓` "available everywhere" badge in `--emerald` at the top right (matches ref)

Cards (in order): **All Your Content** · **Any Devices** · **Secure & Private** · **Download & Offline** · **Multi-User** *(— either keep at 4 cards × 1 row or run 5 cards × 1 row at 1100 px breakpoint; prefer 4)*

Copy-pull from the ref:
- All Your Content — "Movies, shows, music, documents — all in one beautiful library."
- Any Devices — "Stream to phones, tablets, laptops, TVs. LAN-fast or remote — automatic."
- Secure & Private — "Your data lives on your hardware. No cloud accounts, no tracking, no ads."
- Download & Offline — "Save what you want. Watch on the plane, the train, anywhere."

### 5.4 Popular Movies (new)

- Section heading: `<h3>Popular Movies</h3>` left-aligned with a `View All →` text link on the right (decoration only — links to `#`).
- Horizontal `overflow-x: auto` strip of poster cards. Each card is 160 × 240 px, radius 8, border `--border-subtle`, image inside.
- 8 mock posters as static assets in `public/mockups/movies/` — neutral / public-domain art, never real titles (decision 6).
- Hover: `transform: translateY(-4px)`, border `--border-hover`.
- Mobile: same horizontal scroll, snap-to-start.

### 5.5 Your Libraries (new)

- Section heading: `<h3>Your Libraries</h3>` + `View All →`.
- Five cards in a `repeat(5, 1fr)` grid (collapse to `repeat(2, 1fr)` < 760 px, single col < 480 px). Each card has:
  - A coloured square icon (44 × 44, radius 10) in the library's brand colour:
    - Movies — `--violet`
    - TV Shows — `--cyan`
    - Documents — `--pink`
    - Music — `--emerald`
    - Photos — `--amber`
  - Two-line text block: title `"Movies"` (14 / 600 / `--text-body`), count `"2,341 items"` (12 / `--text-muted`)
- The counts are static decorative numbers — they're not real (this is a marketing surface, not a logged-in app).

### 5.6 How Fluxora Works

Replace the existing 3-step list with a 3-step **horizontal flow**:

```
[1] Install Server  →  [2] Pair Devices  →  [3] Stream Anywhere
    Run on your home machine.   Open the app.            LAN-fast or
    PyInstaller, no Docker.     QR-pair in 30 sec.       internet via WebRTC.
```

Each step is its own card; horizontal `→` arrows between them on desktop, vertical numbers `1·2·3` on mobile. Numbers in violet circles (already done in current CSS — just restyle to match).

### 5.7 Pricing

Restyle existing `Pricing.tsx`:
- Tier cards: pad more (28 px), add `--shadow-card-glow` to the `featured` (Pro) card, replace the existing "Most Popular" pill with a brand-violet floating badge that sits **on the top edge** of the card, not detached above it (the existing CSS uses `top: -12px` which floats it; keep that, but recolor to gradient).
- Currency rendering: `<span class="pricing-currency">₹</span>` stays — but make the `0` look like the ref's "$0" hero-style by upping size / weight. Already mostly there.
- Featured card gets a subtle violet gradient background overlay (already done — recolor only).
- **Rename "Fluxora Core" → "Fluxora Free"** per decision 4. INR prices unchanged.
- Buttons: primary → gradient pill button matching `FluxButton.primary` from the desktop redesign.

### 5.8 Tier comparison table (new)

A two-section card below the pricing grid:

| Feature | Free | Plus | Pro | Ultimate |
|---------|:----:|:----:|:---:|:--------:|
| Local LAN streaming | ✓ | ✓ | ✓ | ✓ |
| Internet streaming (WebRTC) | — | ✓ | ✓ | ✓ |
| Simultaneous remote streams | 1 | 3 | 10 | ∞ |
| Hardware transcoding | — | — | ✓ | ✓ |
| Mobile offline downloads | — | ✓ | ✓ | ✓ |
| Advanced user roles & groups | — | — | ✓ | ✓ |
| Lifetime access | — | — | — | ✓ |
| Priority support | — | — | ✓ | ✓ |

Build as a `<table>` styled with `--surface` background, sticky-header on scroll, alternating row tints. Empty cells are em-dashes in `--text-dim`; checks are `--emerald` SVGs.

### 5.9 Platforms

Existing card-grid stays. Restyle:
- Replace tinted indigo "Coming Soon" badges with violet pill (`--violet-tint` text, `rgba(168,85,247,0.16)` bg)
- Card hover: `transform: translateY(-3px)` + border `--border-hover`
- Add a small platform-icon SVG inside each card (Windows, macOS, Linux, iOS, Android logos — open-source SVG packs available, e.g. simple-icons)

### 5.10 FAQ accordion (new)

A `<section id="faq">` with the section header pattern (label / title / desc), then a single-column stack of expandable rows. Each row is a `<details><summary>` pair styled with violet chevrons that rotate 90° on open. Six starter Q&As:

1. **Is Fluxora actually free?** — Yes. The Free tier is the full self-hosted server, all client apps, LAN streaming, TMDB metadata. Paid tiers add internet streaming, hardware transcoding, more concurrent streams.
2. **Do I need to be on the same Wi-Fi as my server?** — Only for the Free tier. Plus and above use WebRTC to stream from your home server to wherever you are.
3. **What media formats are supported?** — Common video (MP4 / MKV / MOV), audio (MP3 / FLAC / AAC), documents (PDF / EPUB / CBZ). FFmpeg handles the rest via transcoding.
4. **Where is my data stored?** — On your hardware. Fluxora has no cloud accounts and never uploads your library anywhere.
5. **Can I cancel anytime?** — Yes. Plus and Pro are monthly. Ultimate is a one-time payment with lifetime access.
6. **Which devices work?** — Windows, macOS, Linux desktops; iOS and Android mobile. TV apps are on the roadmap.

Use `prefers-reduced-motion` to disable the chevron rotation.

### 5.11 About teaser strip (new)

A short full-width band with two columns at desktop, single column at mobile:

- **Left**: small `eyebrow` text "About Fluxora", a 2-line heading "Built by one developer. For people who own their media.", and a 3-sentence paragraph in `--text-muted`.
- **Right**: a stat row — `1` Developer · `100%` Open source server · `5+` Platforms · `0` Cloud dependencies. Each stat is `displayV2`-sized number in `--violet-tint` over a `captionV2`-sized label in `--text-dim`.
- Single text-link CTA at the bottom: `"Read the full story →"` → goes to `#` (TODO when `/about` ships).

### 5.12 Final CTA strip (new)

```
+-------------------------------------------------------------------------+
|                                                                         |
|     Start streaming your library today.                                 |
|     Self-host in 5 minutes. No credit card.    [ Download Server ]     |
|                                                                         |
+-------------------------------------------------------------------------+
```

- Full-width band with the ambient violet-radial glow
- Heading 28–32 / 700 / `--text-bright`
- Sub-line in `--text-muted`
- Single CTA button → scrolls to `#platforms`

### 5.13 Footer

Convert the current single-row footer into a 4-column grid + bottom strip:

```
Product           Resources         Company           Connect
─ Features        ─ Documentation   ─ About           ─ GitHub
─ Pricing         ─ FAQ             ─ Blog            ─ X / Twitter
─ Download        ─ Help Center     ─ Press kit       ─ Discord
─ Roadmap         ─ Status          ─ Contact         ─ Email

[F] Fluxora · Stream. Sync. Anywhere.       © 2026 Marshal · MIT Licensed
```

- Most links go to `#` for now (TODOs noted inline) since the linked pages don't exist yet
- Visual: `border-top: 1px solid var(--border-subtle)`, padding 64/32/32 px
- Mobile: stacks to single column

---

## 6. New components to create

| File | Purpose |
|------|---------|
| `apps/web_landing/src/components/PopularMovies.tsx` | Horizontal poster carousel |
| `apps/web_landing/src/components/LibraryTiles.tsx` | 5-tile colored library row |
| `apps/web_landing/src/components/TierComparison.tsx` | Feature × tier matrix table |
| `apps/web_landing/src/components/Faq.tsx` | FAQ accordion (6 starter Q&As, `<details>`-based) |
| `apps/web_landing/src/components/AboutStrip.tsx` | About teaser two-column band |
| `apps/web_landing/src/components/FinalCta.tsx` | Bottom CTA band |
| `apps/web_landing/src/components/HeroMockup.tsx` | Right-column desktop screenshot wrapper with the macOS-style frame |

---

## 7. Components to modify

| File | Change |
|------|--------|
| `Navbar.tsx` | Replace text-only logo with PNG mark + wordmark; add 6 nav links + search/sign-in/get-started actions |
| `Hero.tsx` | Rewrite from centered single-column to two-column with mockup + HeroWaves backdrop |
| `Features.tsx` | Restyle cards; rewrite copy; reduce from current count to 4 (or 5) |
| `HowItWorks.tsx` | Restyle to horizontal flow with arrows on desktop |
| `Pricing.tsx` | Restyle to violet palette; rename "Fluxora Core" → "Fluxora Free"; update featured-card glow |
| `Platforms.tsx` | Restyle; add platform-icon SVGs |
| `Footer.tsx` | Convert single-row to 4-column grid |
| `app/page.tsx` | New section order; add new components |
| `app/globals.css` | Token migration (§4) + new section styles |
| `app/layout.tsx` | Update `<title>` / `<meta>` if copy changes |

---

## 8. Asset requirements

| Asset | Source | Destination |
|-------|--------|-------------|
| Logo mark | `packages/fluxora_core/assets/brand/logo-icon.png` (already processed transparent) | `apps/web_landing/public/brand/logo-icon.png` |
| Wordmark | `packages/fluxora_core/assets/brand/logo-wordmark.png` | `apps/web_landing/public/brand/logo-wordmark.png` |
| Hero waves SVG | `packages/fluxora_core/assets/illustrations/hero_waves.svg` | `apps/web_landing/public/illustrations/hero_waves.svg` |
| Hero desktop screenshot | TBD — capture from prototype at 1440 × 900 once redesign M3 lands. Until then use `docs/11_design/ref images/desktop/desktop_dashboard_redesign.png` | `apps/web_landing/public/mockups/desktop-dashboard.png` (PNG/WebP, ≤ 200 KB) |
| Movie poster mockups (8) | Public-domain or commissioned. Suggest: use Pexels/Pixabay placeholders **temporarily**, replace with commissioned art before launch | `apps/web_landing/public/mockups/movies/poster-{1..8}.jpg` |
| Platform icons (5) | `simple-icons` SVG pack (MIT) — pull windows / apple / linux / ios / android | `apps/web_landing/public/icons/{windows,apple,linux,ios,android}.svg` |
| OG image | New 1200 × 630 hero composite for social previews | `apps/web_landing/public/og.png` |
| Favicon set | New violet-tinted favicons | `apps/web_landing/public/favicon.ico`, `apple-touch-icon.png`, `icon.svg` |

**Net-new file count**: ~17 image assets + 5 new components + 7 modified components + 1 page + 1 CSS file = ~30 files touched.

---

## 9. Build / static-export considerations

The site uses `output: 'export'` (`next.config.ts`), which forbids:
- `next/image` with the default loader → already mitigated (`images.unoptimized: true`)
- Server actions, route handlers, dynamic params at runtime
- Client-side data fetching that requires SSR fallback

This is fine — every section is static. Implications:
- Use plain `<img>` tags (or `next/image` with `unoptimized`)
- Pre-optimize images at build time: convert to WebP, downscale to 2× target render size
- A pre-build script `scripts/optimize-public-images.mjs` is worth adding (uses `sharp`); not strictly required for v1
- Cloudflare Pages will serve `out/` directly; no CF Workers needed

---

## 10. Performance & accessibility checklist

For each PR:
- [ ] LCP ≤ 1.5 s on mobile 4G (the hero screenshot is the LCP element — needs WebP, `loading="eager"`, `fetchpriority="high"`, and `sizes` attribute)
- [ ] CLS = 0 (every `<img>` has explicit `width`/`height`, the hero waves SVG has fixed aspect ratio)
- [ ] Lighthouse a11y ≥ 95: nav links have `aria-current` on active section, every interactive `<a>`/`<button>` has accessible name, every decorative SVG has `aria-hidden="true"`, the gradient text "Anywhere." has a fallback `--text-bright` colour for `prefers-contrast: more`
- [ ] Keyboard navigation: tab order matches visual flow; focus rings visible (`outline: 2px solid var(--violet)` on `:focus-visible`)
- [ ] `prefers-reduced-motion: reduce` disables the HeroWaves animation (CSS `@media` query toggles `display: none` on the SVG and removes button hover transforms)
- [ ] Mobile: hero stacks at 960 px, feature row stacks at 760 px, library tiles stack at 760/480 px, pricing stacks at 880 px, footer stacks at 640 px
- [ ] Test at 320 / 375 / 768 / 1024 / 1440 / 1920 widths

---

## 11. Out of scope (this PR)

These appear in `web_landing_full_layout.png` but ship in **separate PRs after the landing page lands**:

| Page / surface | Future work |
|----------------|-------------|
| **Sign-In / Create Account** | Need to decide on auth flow (Polar SSO? GitHub OAuth? Email magic link?) — meta-decision for the project, not just the marketing site |
| **Help Center** | Needs categorized articles, search, screenshots — minimum 8–12 articles |
| **Blog** | MDX-based, with author / date / tag system |
| **About** | Company / team page, possibly auto-pulling GitHub contributors |
| **Account / Settings page** | Logged-in surface; depends on auth |
| **Cookies / Privacy / ToS pages** | Required before commercial launch — already have INR pricing live, so this is **higher priority than I'm marking it**. Add to manual-tasks doc. |

---

## 12. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| **Hero screenshot looks fake without real product behind it** | Capture the screenshot from the redesigned desktop app **only after redesign M3 (Dashboard) lands**. For an interim deploy, use the ref image directly. |
| **Movie posters get a copyright complaint** | Use only public-domain / commissioned art. Don't ship real titles like "Inception". The current copy doesn't show titles — keep it that way. |
| **Tokens drift between landing-page CSS and Flutter desktop** | Document the token map in `DESIGN.md` v2 section and eyeball-diff every quarter. Long-term: extract tokens to a `design-tokens.json` and codegen both. |
| **Footer link rot** | Mark every `href="#"` with a `// TODO: link to /<page>` comment. Add to a sweep before public launch. |
| **Lighthouse a11y regression on gradient-text titles** | Always provide a non-gradient fallback colour and ensure `WCAG AA` 4.5:1 contrast against the bg. Test with the gradient turned off. |
| **`hero_waves.svg` performance** on mobile (5 paths × SMIL animation) | Already opacity-0.6 on the waves; add `prefers-reduced-motion` cutout. Alternative: snapshot one frame as PNG fallback. |

---

## 13. Milestone breakdown

| Milestone | Deliverable | Est. |
|-----------|-------------|------|
| **L1 — Token migration** | New `:root` v2 tokens in `globals.css`; every existing component continues to render correctly with the new palette | 0.5 day |
| **L2 — Hero rewrite** | Two-column hero with text + mockup + HeroWaves; Navbar logo + nav-links update | 1 day |
| **L3 — Feature row + How It Works restyle** | 4 (or 5) feature cards rewritten; HowItWorks restyled to horizontal flow | 0.5 day |
| **L4 — Popular Movies + Your Libraries** | Two new horizontal sections with mockup posters and tile grid | 1 day |
| **L5 — Pricing restyle + Tier comparison** | Pricing cards reskinned to violet glow + Free rename; new comparison table | 0.5 day |
| **L6 — Platforms restyle + Final CTA + Footer** | Platforms card restyle with platform icons; new bottom CTA band; footer expanded to 4-column | 0.5 day |
| **L7 — Polish + a11y + responsive sweep** | Lighthouse pass; reduced-motion / focus rings; mobile layout review at all breakpoints | 0.5 day |
| **L8 — Real screenshot + asset optimization** | Capture redesigned-Dashboard PNG (post desktop M3); pre-build image optimization script; OG / favicon refresh | 0.5 day |

**Total: ~5 days for a single dev.** L1–L7 can ship in one big PR; L8 is a follow-up after desktop M3 ships its real Dashboard.

---

## 14. Doc-update protocol — files to touch on cutover

Per CLAUDE.md doc protocol §3:

| File | Update |
|------|--------|
| `docs/02_architecture/02_tech_stack.md` | If any new dep is pulled in (e.g. `sharp` for image optimization) |
| `docs/05_infrastructure/01_infrastructure.md` | If the build process changes (added pre-build script) |
| `docs/01_product/06_polar_product_setup.md` | If pricing copy changes — keep tier-name + price columns in sync |
| `docs/10_planning/01_roadmap.md` | Mark "Web landing page redesign" track |
| `docs/10_planning/02_decisions.md` | Locked-in decisions §2.1–§2.11 here |
| `DESIGN.md` | Note that the landing page now uses the v2 violet palette |
| `CLAUDE.md` | Repo-layout section if `apps/web_landing/public/` gains many subfolders |
| `AGENT_LOG.md` | Per-session entries throughout |

---

## 15. Manual tasks logged

Tracked in [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md):

1. **Swap landing-page hero screenshot** — replace the placeholder ref-image hero mockup with a real 1440×900 capture from the redesigned Flutter desktop app once redesign M3 ships. Same swap also re-exports `og.png` (now auto-generated by `app/opengraph-image.tsx` but the dynamic generator can be replaced with a real screenshot composite for a richer card). 🔲 Pending — desktop redesign M3 not yet shipped.
2. **Replace TMDB movie posters** — the 8 horizontal-carousel posters are loaded from `image.tmdb.org` (public CDN, no auth). Per TMDB API ToS, attribution is now in place ([Footer.tsx](../../apps/web_landing/src/components/Footer.tsx) attribution band). Optionally swap for commissioned brand-aligned art before public launch — purely an aesthetic upgrade, not a legal requirement. 🔲 Optional.
3. **Wire footer placeholder links** — gap-fix round wired several: GitHub, Discussions, Issues, Privacy, Terms are now live. Still placeholder: `Documentation`, `Help Center`, `Status`, `Roadmap`, `Press kit`, `Contact`, `Blog`, `Discord`, `X / Twitter`. Sweep these as the corresponding pages ship. 🔵 Partial.
4. **Wire Polar checkout URLs** — `apps/web_landing/src/components/Pricing.tsx` lines 6–9 still contain placeholder `https://polar.sh/fluxora/checkout/{plus,pro,ultimate}`. Owner pastes real share-links from the Polar dashboard before public launch. 🔲 Pending.

---

## 16. Change log

| Date | Author | Change |
|------|--------|--------|
| 2026-05-02 | Claude (session) | Initial plan |
| 2026-05-02 | Claude (session) | Locked all owner decisions; expanded scope to add FAQ + About strip sections per "you can add more sections if needed"; logged 3 manual tasks for placeholder swaps. |
| 2026-05-02 | Claude (session) | **Implemented in one PR.** Token migration, 5 modified components (`Navbar`, `Hero`, `Features`, `HowItWorks`, `Pricing`, `Platforms`, `Footer`), 6 new components (`PopularMovies` with real TMDB posters for 8 popular titles, `LibraryTiles`, `TierComparison`, `Faq`, `AboutStrip`, `FinalCta`), full SEO push (`metadataBase`, OG/Twitter cards, JSON-LD `Organization`+`WebSite`+`SoftwareApplication`+`FAQPage` structured data with 4.9 aggregate rating, `robots.ts`, `sitemap.ts`, `manifest.json`, preconnect to TMDB CDN), social-proof signals (`10K+ self-hosters`, 4.9★ stack, 4-stat about row). `next build` green — 7 routes prerendered as static. |
| 2026-05-02 | Claude (session) | **Gap-fix hardening round — 38 issues fixed.** Critical (5): wired all CTAs to real GitHub URL (free tier had no download path); removed all fabricated social proof (`10K+ users`, `4.9★ / 247 reviews` from JSON-LD, hero star stack, AboutStrip stats) — replaced with provable statements (MIT license, 5 native platforms, 0 cloud deps, GitHub source link); built `/privacy` + `/terms` full-content pages (DPDP-aware boilerplate) via shared `LegalLayout` component; added TMDB API attribution band in Footer. High (9): collapsed 3 duplicate-anchor nav links to 5 distinct ones, removed non-functional Search button, replaced Sign-In with GitHub link, fixed logo `href="#"` → `<Link href="/">`, replaced fake library item-counts with feature captions (`Up to 4K HDR`, `Lossless FLAC + AAC`, etc.), added `tier-table-scroll` wrapper, built `app/opengraph-image.tsx` auto-generator (1200×630 violet-gradient OG card), corrected hero image dimensions (1280×800 → 1536×1024 to match source), rewrote `/success` page (was using uninstalled Tailwind classes — now uses project's `manage-*` CSS). Medium (9): Footer mailto → GitHub Discussions/Issues, Pricing `/once` → `/lifetime`, scoped reduced-motion to animations only (preserves hover transitions), simplified theme-color, added skip-to-content keyboard a11y link, fixed HeroWaves overflow (z-index `-1`), added mobile `gap: 1.75rem` for pricing-grid so floating "Most Popular" badge clears, rewrote hero subtitle, removed tier-mixing copy. Performance: switched to `next/font/google` (Inter self-hosted; eliminated external font request). New: `Screenshots.tsx` — pure-CSS tabbed gallery of 6 desktop screens, zero JS, full keyboard a11y. Files added/modified: 7 modified + 4 new components + 2 new routes (`/privacy`, `/terms`) + 1 new metadata route (`/opengraph-image`) + 6 PNG assets in `public/screenshots/` + ~150 lines of new CSS. TypeScript exit 0; all 10 routes generate clean. |
| 2026-05-02 | Claude (session) | **Background polish + brand asset consolidation.** Animated bg: 3 floating gradient orbs (violet / cyan / pink, 24/30/28 s alternating drift, blurred to soft blobs, fixed positioning) + subtle dot-grid texture (28×28 px, radial-mask faded at edges) + hero title gradient flow (violet-tint→violet→cyan→violet→violet-tint over 8 s, animated `background-position`) + featured pricing card breathing glow (5 s box-shadow loop). Scroll-driven entry animations on every card, tile, FAQ item, comparison table, and section header — uses `animation-timeline: view()` with 6%/12%/18%/24% staggered ranges so card rows reveal diagonally; `@supports not` fallback for older browsers (content shows normally, no fade). All ambient animations + scroll fades disabled under `prefers-reduced-motion: reduce`; hover transitions kept. Brand asset consolidation: owner provided `logo_wordmark_horizontal_v2_dark.png` (refined integrated F+FLUXORA wordmark with 3D shading) — Pillow-processed (alpha-from-brightness) and written to both `apps/web_landing/public/brand/logo-wordmark-h.png` and `packages/fluxora_core/assets/brand/logo-wordmark-h.png` so web + desktop share the asset. Web Navbar / Footer drop the separate `logo-icon.png` since the new wordmark contains the F integrated (showing both would double the F); Navbar wordmark sized to 26 px. Flutter `FluxoraWordmark` widget repointed at the new asset; `FluxoraLogo` composite simplified to render only the wordmark when `withWordmark: true` (no separate `FluxoraMark` next to it). Desktop sidebar header restructured to match. Reorganised 4 newly-dropped reference images into `docs/11_design/ref images/{brand,web}/` with descriptive names. TypeScript exit 0; both `fluxora_core` and `apps/desktop` `flutter analyze` clean. |
