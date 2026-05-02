# Design — Folder Index

This folder holds Fluxora's design assets, prototypes, and per-surface redesign plans. **The single source of truth for the design system itself is [`/DESIGN.md`](../../DESIGN.md) at the repo root.**

---

## Canonical sources

| What | Where |
|------|-------|
| **Design system spec** (colors, typography, components, do's/don'ts) | [`/DESIGN.md`](../../DESIGN.md) |
| **Visual prototype** (high-fidelity HTML/JSX bundle, all 50+ desktop + mobile artboards) | [`prototype/`](./prototype/) — open `Fluxora Desktop.html` or `Fluxora Mobile.html` in a browser |
| **Tokens (Flutter)** | [`/packages/fluxora_core/lib/constants/`](../../packages/fluxora_core/lib/constants/) — `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radii.dart`, `app_shadows.dart`, `app_gradients.dart` |
| **Tokens (web landing)** | [`/apps/web_landing/src/app/globals.css`](../../apps/web_landing/src/app/globals.css) — V2 mirror as CSS vars |
| **Brand assets (canonical masters)** | [`/assets/brand/`](../../assets/brand/) — wordmark, icon, brand sheet |

---

## Per-surface redesign plans

| Surface | Plan | Status |
|---------|------|--------|
| Desktop control panel | [`desktop_redesign_plan.md`](./desktop_redesign_plan.md) | M0–M9 + M9.5 theme cutover ✅ done; M10 (custom window chrome) open |
| Mobile Flutter app | [`mobile_redesign_plan.md`](./mobile_redesign_plan.md) | Plan locked; execution gate lifted 2026-05-03 — ready when scheduled |
| Web landing (`fluxora.marshalx.dev`) | [`web_landing_redesign_plan.md`](./web_landing_redesign_plan.md) | ✅ done 2026-05-02 |

---

## Reference imagery

| Folder | What |
|--------|------|
| [`ref images/brand/`](./ref%20images/brand/) | Wordmark / icon / brand-identity-sheet originals |
| [`ref images/desktop/`](./ref%20images/desktop/) | Annotated desktop screen mockups |
| [`ref images/mobile/`](./ref%20images/mobile/) | Annotated mobile screen mockups (incl. `mobile_player_with_legend.png`) |
| [`ref images/web/`](./ref%20images/web/) | Web landing reference mockups |

---

