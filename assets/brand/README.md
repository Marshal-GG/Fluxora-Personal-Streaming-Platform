# Fluxora — Brand Masters

High-resolution source files. These are the **canonical** logo and identity assets — everything downstream (app icons, web favicons, README banners) is derived from them.

## Files

| File | Use |
|------|-----|
| `logo-wordmark-h.png` | **Primary brand asset.** Integrated horizontal wordmark (3D-style F + FLUXORA letters in one image). The default for app bars, navbars, footers, and the README hero. Source: original ChatGPT-export `logo_wordmark_horizontal_v2_dark.png` (preserved in [`docs/11_design/ref images/brand/`](../../docs/11_design/ref%20images/brand/)) |
| `logo-wordmark-h-v1.png` | Wordmark v1 — kept for reference only. Don't use in new surfaces |
| `logo-wordmark-stacked.png` | Stacked wordmark (F above FLUXORA). Reserved for square slots |
| `logo-icon.png` | Standalone F lettermark. Use when text accompanies elsewhere (favicon, app icon, square avatar) |
| `brand-banner-h.png` | Marketing banner — wide format, social cards, GitHub repo header |
| `brand-banner-v.png` | Marketing banner — vertical/portrait, mobile heroes |
| `brand-identity-sheet.png` | Identity sheet (logo construction, colors, typography). Reference, not for shipping |

## Brand colors

| Token | Hex | Use |
|-------|-----|-----|
| Violet primary | `#A855F7` | Primary brand color. CTAs, links, focus states |
| Violet light | `#C4A8F5` | Wordmark gradient stop, soft accents |
| Violet deep | `#8B5CF6` | Hover states, secondary accents |
| Cyan accent | `#22D3EE` | Secondary brand color. Highlights, "live" indicators |
| Background base | `#0d0a1f` | Dark backgrounds (banners, hero sections) |
| Background deep | `#08061a` | Background gradient end |

## Do

- Use the wordmark on dark backgrounds (`#0d0a1f` or darker). Built for it.
- Pair with violet→cyan gradients when adding accent / glow.
- Keep clear-space ≥ 1× the F-mark height around the wordmark.

## Don't

- Don't combine `logo-icon.png` + `logo-wordmark-*.png` side-by-side — the wordmark already contains the F, you'll show it twice.
- Don't recolour the wordmark. If you need a single-tone variant, ask before generating one.
- Don't render on a light background without a dark plate behind it. The wordmark is built dark-on-dark.
- Don't downscale below 200px wide — anti-aliasing breaks.

## Processing

Runtime copies under `packages/fluxora_core/assets/brand/` and `apps/web_landing/public/brand/` are alpha-processed with Pillow (alpha-from-brightness) so the original solid-black backdrop becomes transparent while the gradient anti-aliasing is preserved. When you update a master here, re-run the processing for both runtime copies to keep them in sync.
