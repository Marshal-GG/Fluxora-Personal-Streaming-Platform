# Fluxora — Brand & Marketing Assets

Canonical store for Fluxora's visual identity. **This is the source of truth.** Runtime copies in `apps/web_landing/public/brand/` and `packages/fluxora_core/assets/brand/` are mirrored derivatives — when you update something here, sync the corresponding runtime copy.

## Layout

| Folder | Contents |
|--------|----------|
| `brand/` | Master logo, wordmark and identity files (high-res PNG) |
| `banners/` | README hero, section dividers, GitHub social banners |
| `icons/` | Animated section icons used in `README.md` |
| `screenshots/` | Marketing screenshots (populated post-Desktop M3) |

## Where each consumer pulls from

| Consumer | Runtime location | Sync flow |
|----------|------------------|-----------|
| Mobile + Desktop (Flutter) | `packages/fluxora_core/assets/brand/` | Re-export from `assets/brand/` (Pillow alpha-from-brightness, kebab-case names) when masters change |
| Web landing (Next.js) | `apps/web_landing/public/brand/` | Same processing, same naming. Static-export bundles whatever is in `public/`. |
| Desktop Windows runner (icon) | `apps/desktop/windows/runner/resources/app_icon.ico` | Copy `assets/brand/app_icon.ico` over it. The master is regenerated from `logo-icon.png` via Pillow (10 sizes embedded: 16/20/24/32/40/48/64/96/128/256, alpha-from-brightness). The Win32 runner's `Runner.rc` references the runtime path directly — keep the filename unchanged. |
| README (this repo) | `assets/banners/`, `assets/icons/` | Used directly via relative paths. GitHub serves these through its image proxy. |

Why duplicate? Flutter `pubspec.yaml` and Next.js `public/` can only bundle assets co-located with the app. Single-source rendering across all three would require a build step we haven't introduced. Treat the runtime copies as compiled artifacts.

## Reference originals

The original ChatGPT-export PNGs the masters were derived from live in [`docs/11_design/ref images/brand/`](../docs/11_design/ref%20images/brand/). Don't touch those — they're frozen reference. Re-process from `assets/brand/` going forward.
