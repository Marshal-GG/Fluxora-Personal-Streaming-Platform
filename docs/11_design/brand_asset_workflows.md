# Brand Asset Workflows

Practical recipes for turning brand-master files (under [`docs/11_design/ref images/brand/`](./ref%20images/brand/)) into the runtime assets that ship in [`/assets/`](../../assets/), [`packages/fluxora_core/assets/brand/`](../../packages/fluxora_core/assets/brand/), and [`apps/web_landing/public/brand/`](../../apps/web_landing/public/brand/).

**Rule of thumb:** masters are kept *unedited* in `docs/11_design/ref images/brand/`. Every glyph file under `/packages/fluxora_core/assets/brand/`, `/apps/web_landing/public/brand/`, and the README banner under `/assets/banners/` is a *derivative* — recompute, don't hand-edit.

> The `/assets/brand/` folder is the deliberate exception: those files are *renamed copies of the masters with the dark background intact*, used for marketing surfaces (brand sheet, banners) where the bg is wanted. The recipes below do not produce those — see §3 for the mapping.

---

## 1 · Brand glyphs — solid background → transparent PNG

This is the canonical recipe used to produce **every** transparent PNG of the icon and wordmark variants that the apps and web landing render at runtime.

### When to use this

The reference glyphs render the violet-cyan colours against an opaque coloured field (black for the dark variants). The Flutter `FluxoraMark` / `FluxoraWordmark` widgets, the web hero, the README banner, and any future surface need a transparent PNG so the glyph sits on whatever background the consumer owns. This recipe converts a master in one step without tracing or hand-masking.

### Input → output (canonical mapping, all derived from the same recipe)

| Master | Master mode + size | Output | Output mode + size | Lives in |
|---|---|---|---|---|
| `logo_icon_dark.png` | RGB · 1254 × 1254 | `logo-icon.png` | RGBA · 749 × 807 | `packages/fluxora_core/assets/brand/`, `apps/web_landing/public/brand/` |
| `logo_wordmark_dark.png` (stacked) | RGB · 1314 × 1197 | `logo-wordmark.png` | RGBA · 983 × 717 | `packages/fluxora_core/assets/brand/`, `apps/web_landing/public/brand/` |
| `logo_wordmark_horizontal_v2_dark.png` | RGB · 1983 × 793 | `logo-wordmark-h.png` | RGBA · 1687 × 295 | `packages/fluxora_core/assets/brand/`, `apps/web_landing/public/brand/` |
| `logo_wordmark_horizontal_v2_dark.png` *(same master, smaller output)* | RGB · 1983 × 793 | `wordmark-h.png` | RGBA · 1000 × 174 | `assets/banners/` (README hero) |

All four outputs share the same alpha-histogram signature (≈ 60-80 % transparent / ≈ 14-35 % opaque / **3-9 % anti-aliased mid-alpha edge pixels**). The mid-alpha proportion confirms the recipe wasn't a hard chroma-key — those produce a binary mask with ~0 % mid-alpha.

### Technique

**Luminosity-as-alpha** on a pure-black background. Treat the image's grayscale brightness as the alpha channel:
- Pure black areas → grayscale 0 → alpha 0 → transparent.
- Saturated brand-colour pixels → high luminosity → alpha ≈ 255 → opaque.
- Anti-aliased edge pixels → mid luminosity → mid alpha → smooth edges.

This is materially better than `-fuzz N% -transparent black` (hard chroma-key) on gradient logos because the chroma-key path produces a binary mask that strips edge anti-aliasing and leaves dark halo artefacts where the gradient approaches black.

### ImageMagick (single-asset one-liner)

Run this with `MASTER`, `OUTPUT`, and `WIDTH` substituted for the row you're regenerating from the table above.

```bash
magick "${MASTER}" \
  \( +clone -colorspace gray \) \
  -compose CopyOpacity -composite \
  -trim +repage \
  -resize "${WIDTH}x" \
  -strip \
  PNG32:"${OUTPUT}"
```

What each step does:

| Step | Why |
|------|-----|
| `\( +clone -colorspace gray \)` | Stack a grayscale clone next to the original — that clone becomes the alpha mask. |
| `-compose CopyOpacity -composite` | Apply the grayscale clone as the alpha channel of the original. Black bg → 0; bright glyph → 255. |
| `-trim +repage` | Auto-crop the now-transparent padding around the glyph, then reset the canvas origin so coordinates start at 0,0. |
| `-resize "${WIDTH}x"` | Scale to `WIDTH` pixels wide preserving aspect; height is computed from the trimmed master's aspect. |
| `-strip` | Drop EXIF / colour-profile metadata (kills ICC profile bloat that confuses some web viewers). |
| `PNG32:` prefix | Force RGBA output; PNG24 would silently flatten the alpha. |

### Pillow batch script (regenerate every glyph at once)

Useful when you've updated a master and want to refresh every downstream asset in one shot, or when ImageMagick isn't available.

```python
"""Regenerate every transparent brand PNG from the masters."""
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[2]   # adjust if you move the script
MASTERS = REPO / "docs/11_design/ref images/brand"

# (master, target_width, output_paths)
JOBS = [
    (
        "logo_icon_dark.png",
        749,
        [
            "packages/fluxora_core/assets/brand/logo-icon.png",
            "apps/web_landing/public/brand/logo-icon.png",
        ],
    ),
    (
        "logo_wordmark_dark.png",
        983,
        [
            "packages/fluxora_core/assets/brand/logo-wordmark.png",
            "apps/web_landing/public/brand/logo-wordmark.png",
        ],
    ),
    (
        "logo_wordmark_horizontal_v2_dark.png",
        1687,
        [
            "packages/fluxora_core/assets/brand/logo-wordmark-h.png",
            "apps/web_landing/public/brand/logo-wordmark-h.png",
        ],
    ),
    (
        "logo_wordmark_horizontal_v2_dark.png",
        1000,
        ["assets/banners/wordmark-h.png"],
    ),
]


def luminosity_as_alpha(src_path: Path, target_w: int) -> Image.Image:
    src = Image.open(src_path).convert("RGB")
    # Grayscale of the original = alpha mask. Pure-black bg -> 0 -> transparent.
    src.putalpha(src.convert("L"))
    # Trim transparent padding (bbox is computed from the alpha channel).
    src = src.crop(src.getbbox())
    # Resize preserving aspect.
    target_h = round(src.height * target_w / src.width)
    return src.resize((target_w, target_h), Image.LANCZOS)


def main() -> None:
    for master_name, target_w, out_paths in JOBS:
        out_img = luminosity_as_alpha(MASTERS / master_name, target_w)
        for rel_path in out_paths:
            full = REPO / rel_path
            full.parent.mkdir(parents=True, exist_ok=True)
            out_img.save(full, "PNG", optimize=True)
            print(f"{master_name:46s} -> {rel_path}  ({out_img.size[0]}x{out_img.size[1]})")


if __name__ == "__main__":
    main()
```

### Verification

After regenerating, sanity-check each output against the canonical alpha signature:

```python
from PIL import Image

EXPECTED = {
    "assets/banners/wordmark-h.png": (1000, 174),
    "packages/fluxora_core/assets/brand/logo-icon.png": (749, 807),
    "packages/fluxora_core/assets/brand/logo-wordmark.png": (983, 717),
    "packages/fluxora_core/assets/brand/logo-wordmark-h.png": (1687, 295),
    "apps/web_landing/public/brand/logo-icon.png": (749, 807),
    "apps/web_landing/public/brand/logo-wordmark.png": (983, 717),
    "apps/web_landing/public/brand/logo-wordmark-h.png": (1687, 295),
}
for path, expected_size in EXPECTED.items():
    img = Image.open(path)
    assert img.mode == "RGBA", f"{path}: expected RGBA, got {img.mode}"
    assert img.size == expected_size, f"{path}: size {img.size} != {expected_size}"
    h = img.getchannel("A").histogram()
    t = sum(h)
    mid = t - h[0] - h[255]
    print(f"{path:62s}  T={h[0]/t:.0%} O={h[255]/t:.0%} aa={mid/t:.0%}")
```

Expected per-file ratios (fall in this band, exact numbers vary slightly with PIL vs ImageMagick due to interpolation differences):

| File | T (transparent) | O (opaque) | aa (anti-aliased) |
|---|---|---|---|
| `logo-icon.png` | ~59 % | ~35 % | ~7 % |
| `logo-wordmark.png` (stacked) | ~80 % | ~18 % | ~3 % |
| `logo-wordmark-h.png` (runtime) | ~79 % | ~17 % | ~4 % |
| `wordmark-h.png` (banner) | ~77 % | ~14 % | ~9 % |

The mid-alpha ratio scales inversely with image resolution — higher-res outputs have proportionally fewer edge pixels relative to total area. **A binary alpha (≈ 0 % mid-alpha) means you used a chroma-key fallback by mistake — re-run with the luminosity recipe.**

### When this recipe doesn't apply

- **Light-variant master** on a near-white background — luminosity-as-alpha would invert the result (mark the bg as opaque). Either feed an inverted grayscale clone into `CopyOpacity`, or add `-channel A -negate` after the composite.
- **Photographic backgrounds** (gradients, noise, hero images) — luminosity won't separate the foreground cleanly. Use `rembg` or hand-mask in GIMP / Photoshop, then trim + resize as above.
- **Master that's already RGBA** — skip the alpha step, just `-trim` and `-resize`.
- **Marketing-style usage where the dark bg is wanted** — don't process at all. Use the `/assets/brand/*.png` copies directly (see §3); those preserve the master's bg.

---

## 2 · Where the runtime mirrors come from

Every transparent glyph PNG ships in **two** runtime locations: `packages/fluxora_core/assets/brand/` (consumed by Flutter via `FluxoraMark` / `FluxoraWordmark`) and `apps/web_landing/public/brand/` (consumed by the Next.js landing site). Today these two locations are **bytes-identical** — the script in §1 writes to both in the same loop, which is the canonical sync.

If you regenerate just one, the other will drift. Either run the full §1 batch script, or copy the regenerated file into both locations manually before committing. There is no automated CI check — a future improvement would be a pre-commit hook that diffs the pair.

---

## 3 · Where derivatives live (full asset map)

| Logical asset | Master | Marketing copy<br>(`/assets/brand/`,<br>**bg preserved**) | README banner<br>(`/assets/banners/`,<br>**bg removed**) | Runtime mirror<br>(`/packages/fluxora_core/assets/brand/`<br>+ `/apps/web_landing/public/brand/`,<br>**bg removed**) |
|---|---|---|---|---|
| Icon | `logo_icon_dark.png` (1254 × 1254) | `logo-icon.png` (1254 × 1254) | — | `logo-icon.png` (749 × 807) |
| Stacked wordmark | `logo_wordmark_dark.png` (1314 × 1197) | `logo-wordmark-stacked.png` (1314 × 1197) | — | `logo-wordmark.png` (983 × 717) |
| Horizontal wordmark | `logo_wordmark_horizontal_v2_dark.png` (1983 × 793) | `logo-wordmark-h.png` (1983 × 793) | `wordmark-h.png` (1000 × 174) | `logo-wordmark-h.png` (1687 × 295) |
| Horizontal wordmark v1 (legacy) | `logo_wordmark_horizontal_dark.png` (2073 × 758) | `logo-wordmark-h-v1.png` (2073 × 758) | — | — |
| Brand banner (h) | `brand_banner_horizontal.png` (1536 × 1024) | `brand-banner-h.png` (1536 × 1024) | — | — |
| Brand banner (v) | `brand_banner_vertical.png` (1024 × 1536) | `brand-banner-v.png` (1024 × 1536) | — | — |
| Brand identity sheet | `brand_identity.png` (1536 × 1024) | `brand-identity-sheet.png` (1536 × 1024) | — | — |
| Windows runner icon | `logo_icon_dark.png` | — | — | `apps/desktop/windows/runner/resources/app_icon.ico` (multi-size .ico — see §4) |
| README hero banner | hand-authored | `assets/banners/readme_hero.svg` (1200 × 320, animated) | — | — |
| README section dividers | hand-authored | `assets/banners/divider.svg` (animated) + `section-divider.svg` (static) | — | — |
| Section icons (7) | hand-authored from Lucide path data | `assets/icons/icon-{docs,features,quick-start,roadmap,stack,tiers,why}.svg` | — | — |

**Important nuance:** the `/assets/brand/*.png` files are *direct copies of the masters* (kebab-case rename only — no bg removal, no resize). Per [`/assets/brand/README.md`](../../assets/brand/README.md), this folder targets brand-sheet / press / marketing surfaces where the dark bg is intended. Don't run the §1 recipe on these — they're not derivatives of the transparent runtime mirrors, they're a parallel marketing-only output of the master.

---

## 4 · Windows app icon — multi-size `.ico`

Windows reads the runner's icon from `apps/desktop/windows/runner/resources/app_icon.ico` (referenced by `Runner.rc`) and shows it in the taskbar, Alt-Tab, the start menu, the title bar, and Aero Peek thumbnail. Different surfaces pick different sizes from the multi-image `.ico`, so we ship 10 sizes in one file.

### Input → output

| Master | Output | Format | Sizes embedded |
|---|---|---|---|
| `assets/brand/logo-icon.png` (RGB · 1254 × 1254) | `assets/brand/app_icon.ico` (master) + `apps/desktop/windows/runner/resources/app_icon.ico` (bytes-identical runtime copy) | Multi-image ICO, 32 bpp, PNG-compressed entries | 16, 20, 24, 32, 40, 48, 64, 96, 128, 256 |

The runtime copy at `apps/desktop/windows/runner/resources/app_icon.ico` is referenced by `Runner.rc` and **cannot be moved** without editing the `.rc` file.

### Technique

Same luminosity-as-alpha bg removal as §1, **plus an 8 % margin re-paste before encoding to ICO**. The margin step is the load-bearing UX choice: without it the glyph fills only ≈ 59 % of the canvas and the rendered icon looks visibly smaller than peer Windows apps in the taskbar / Alt-Tab strip; with 8 % margin the fill hits ≈ 84 %, which matches the visual density of Material / Office / browser icons.

Pillow's native ICO writer is the right tool — `Image.save(path, format="ICO", sizes=[...])` produces 32 bpp PNG-compressed entries by default. Don't reach for ImageMagick here: its default ICO encoder writes BMP/DIB at large sizes, which makes the file ~3× bigger and slightly worse-looking at 256 × 256. Confirmed by inspecting `app_icon.ico`'s container — every entry's payload starts with `\x89PNG`, not a DIB header.

### Pillow recipe

```python
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[2]   # adjust if you move the script
SRC = REPO / "assets/brand/logo-icon.png"     # bg-preserved master copy

OUTPUTS = [
    REPO / "assets/brand/app_icon.ico",                                     # master
    REPO / "apps/desktop/windows/runner/resources/app_icon.ico",            # runtime
]
SIZES = [(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48),
         (64, 64), (96, 96), (128, 128), (256, 256)]
MARGIN = 0.08   # 8% — pushes glyph fill from ~59% to ~84% of canvas

# 1. Luminosity-as-alpha + tight-crop (same as §1)
src = Image.open(SRC).convert("RGB")
src.putalpha(src.convert("L"))
glyph = src.crop(src.getbbox())

# 2. Re-paste onto a fresh square canvas with 8% margin
side = max(glyph.size)
canvas_side = round(side / (1 - 2 * MARGIN))
canvas = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
offset = ((canvas_side - glyph.width) // 2, (canvas_side - glyph.height) // 2)
canvas.paste(glyph, offset, glyph)

# 3. Save as multi-size ICO. PIL handles the per-size LANCZOS resample internally.
for out in OUTPUTS:
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, format="ICO", sizes=SIZES)
    print(f"wrote {out}  ({out.stat().st_size:,} B)")
```

### Verification

```python
import struct
from pathlib import Path

EXPECTED_SIZES = {16, 20, 24, 32, 40, 48, 64, 96, 128, 256}

for path in [
    Path("assets/brand/app_icon.ico"),
    Path("apps/desktop/windows/runner/resources/app_icon.ico"),
]:
    data = path.read_bytes()
    _, ico_type, count = struct.unpack("<HHH", data[:6])
    assert ico_type == 1, f"{path}: not an ICO file"
    sizes = set()
    for i in range(count):
        w, h, *_, offset = struct.unpack(
            "<BBBBHHII", data[6 + i*16 : 6 + (i+1)*16]
        )
        sizes.add((256 if w == 0 else w))
        # Each embedded image must start with the PNG signature, not a BMP DIB.
        assert data[offset:offset+8] == b"\x89PNG\r\n\x1a\n", \
            f"{path}: entry {i} ({w}x{h}) is BMP-encoded, not PNG — file is too big"
    assert sizes == EXPECTED_SIZES, f"{path}: sizes {sizes} != {EXPECTED_SIZES}"
    print(f"OK {path} — {count} entries, all PNG-encoded, sizes {sorted(sizes)}")

# The two .ico files must be bytes-identical (the runtime copy is just a copy).
master = Path("assets/brand/app_icon.ico").read_bytes()
runtime = Path("apps/desktop/windows/runner/resources/app_icon.ico").read_bytes()
assert master == runtime, "master and runtime .ico drifted — re-run the recipe"
```

A healthy file weighs roughly **55 KB** (the 256 × 256 PNG entry alone is ~28 KB, ~half the file). If you see ~150 KB+ that's the ImageMagick-default BMP/DIB encoding for the big sizes — switch to Pillow.

### When the icon master changes

Re-run the §4 recipe — that's the single source of truth. **Don't** edit either `.ico` file by hand, and don't extract a single PNG from one of them and treat that as the new master; the alpha-from-brightness step needs to start from the bg-preserved `assets/brand/logo-icon.png`.

---

## 5 · Hand-authored SVGs — section icons + dividers

These are *source files*, not derivatives — you edit them directly. Documented here so future authors follow the existing visual language instead of inventing a new one per icon.

### 5.1 · Section icons (`assets/icons/icon-*.svg`)

Seven 22 × 22 line icons used as section markers in the README and (eventually) in design surfaces that need a violet glyph. All follow the same template:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22">
  <defs>
    <style>
      @keyframes pulse { 0%,100%{opacity:.7;filter:drop-shadow(0 0 2px #A855F7)} 50%{opacity:1;filter:drop-shadow(0 0 6px #A855F7)} }
      .ic { animation: pulse 2.5s ease-in-out infinite; }
    </style>
  </defs>
  <g class="ic" fill="none" stroke="#A855F7" stroke-width="1.6"
     stroke-linecap="round" stroke-linejoin="round">
    <!-- icon-specific path data goes here -->
  </g>
</svg>
```

Constants that should not change between icons:
- `viewBox="0 0 22 22"` + `width=22` + `height=22` — fixed canvas, all icons are visually balanced at this size.
- Stroke `#A855F7` (violet primary), `stroke-width="1.6"`, `stroke-linecap="round"`, `stroke-linejoin="round"`.
- 2.5 s `pulse` keyframe animation that drives both `opacity` and `drop-shadow` glow radius.
- `fill="none"` — line-only, no fills.

The path data inside the `<g class="ic">` is the only thing that varies. Authoring flow when adding a new icon:

1. Pick a [Lucide icon](https://lucide.dev/icons/) whose semantic matches the README section. Lucide is ISC-licensed and ships clean 24 × 24 line geometry — perfect base.
2. Copy its `<path>` / `<line>` / `<polyline>` elements out of the Lucide SVG.
3. Paste inside the `<g class="ic">` block of a fresh icon file. **Don't** copy Lucide's outer `<svg>` wrapper or its stroke attributes — those would override the project shell's pulse animation and stroke styling.
4. Visually scale: Lucide's path data is authored against a 24 × 24 viewBox. Our icons use 22 × 22 — Lucide paths render slightly oversized but usually acceptable. If an icon clips, divide each path coordinate by 24/22 ≈ 1.091, or wrap the `<g>` in a `<g transform="scale(0.917)">`.
5. Save as `assets/icons/icon-<name>.svg`.

### 5.2 · README dividers (`assets/banners/divider.svg`, `section-divider.svg`)

Two complementary divider SVGs, both hand-written:

| File | Size | Purpose |
|------|------|---------|
| `section-divider.svg` | 900 × 3 | Static violet → cyan gradient that fades at both edges. Drops in directly under `<h3>` headers. No animations. |
| `divider.svg` | 1200 × 16 (preserveAspectRatio="none") | Animated full-width divider — thin horizontal line + a violet → cyan highlight that drifts left → right every 8 s + a centred pulsing dot. Reusable between any README sections. |

The file headers explain composition; the path / gradient data is the only thing to edit. If you add a third divider variant, follow the same pattern — keep the gradient palette anchored to violet → cyan and the SMIL period in the 4-12 s range so multiple dividers on the same README page don't fight each other for attention.

---

## 6 · README hero — animated SVG with embedded base64 wordmark

`assets/banners/readme_hero.svg` is the headline banner that renders above `# Fluxora` in the README. It's a 1200 × 320 SVG with 12 SMIL animations and a base64-embedded copy of the horizontal wordmark.

### Why base64-embed the wordmark instead of `<image href="../wordmark-h.png">`

GitHub serves user-uploaded README content through a sandboxing image proxy (`camo`). The proxy:
- **Allows** SVG files served directly as `<img src="…/readme_hero.svg">` from the README, including their SMIL animations.
- **Strips** external `<image href="…">` references inside an SVG — those would normally pull a separate file at render time, but the sandbox cancels the request to prevent the SVG from leaking the viewer's IP to a third-party host.

So an SVG that does `<image href="../wordmark-h.png">` renders with a blank space where the wordmark should be — only on GitHub. Workaround: embed the PNG as a base64 data URI inside the SVG, so the wordmark bytes ride along with the SVG itself and there's nothing for the sandbox to strip.

### Recipe — re-embed the wordmark when it changes

When `assets/banners/wordmark-h.png` is regenerated by §1, the hero needs to re-pick up the new bytes. Pillow handles the base64 step:

```python
import base64
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]   # adjust if you move the script
SRC_PNG = REPO / "assets/banners/wordmark-h.png"
HERO    = REPO / "assets/banners/readme_hero.svg"

# Encode the PNG as base64 (utf-8 string for inlining into XML).
encoded = base64.b64encode(SRC_PNG.read_bytes()).decode("ascii")
data_uri = f"data:image/png;base64,{encoded}"

# Locate the existing <image href="data:image/png;base64,...">
# and rewrite the href value. Quote-handling matters: the SVG uses
# href="data:image/png;base64,XXXX" (double quotes, no whitespace
# in the value).
import re
text = HERO.read_text(encoding="utf-8")
new_text, count = re.subn(
    r'(href=")data:image/png;base64,[^"]+(")',
    lambda m: f'{m.group(1)}{data_uri}{m.group(2)}',
    text,
)
assert count == 1, f"expected exactly 1 base64 wordmark href in {HERO}, found {count}"
HERO.write_text(new_text, encoding="utf-8")
print(f"re-embedded {len(encoded):,} chars of base64 ({SRC_PNG.stat().st_size:,} B PNG)")
```

The regex is anchored to `<image href="data:image/png;base64,…">` exactly (one occurrence, no nested quotes) — the assert tripping means the SVG has been hand-edited to use a different attribute pattern and the regex needs to follow.

### Verification

```python
import re
from pathlib import Path
hero = Path("assets/banners/readme_hero.svg").read_text(encoding="utf-8")
n = len(re.findall(r'href="data:image/png;base64,', hero))
assert n == 1, f"expected 1 base64 image href, found {n}"
# File should weigh in around 200-220 KB; if it's much smaller the wordmark
# wasn't re-embedded; if much larger the SVG accumulated stale base64 blobs.
print(f"hero is {Path('assets/banners/readme_hero.svg').stat().st_size:,} B")
```

A healthy hero is ~210 KB. ~50 KB or less means the base64 step didn't run; ~400 KB+ means the previous wordmark embed wasn't replaced and you've doubled-up.

### When the hero structure changes

The 12 SMIL animations + the gradients + the layered composition (back-to-front: starfield → orbits → wordmark → tagline) are hand-written. Edit the SVG directly. The base64 embed is the only piece that's recomputed by a script.

---

## 7 · Future workflows to document here

When you build a new brand-asset recipe, add a numbered section. Candidates:

- **iOS / Android app icons** when those land in the mobile build (likely a `flutter_launcher_icons` pipeline keyed off `assets/brand/logo-icon.png`).
- **macOS `.icns`** when the Mac build is a v1 target.
- **Linux desktop icon** (`.desktop` + PNG hierarchy at `/usr/share/icons/hicolor/<size>/apps/`).
- **Browser favicon set** — `apps/web_landing/public/` already has `favicon.ico`; if we move to a multi-format set (favicon.svg + apple-touch-icon + manifest icons), document that pipeline.
