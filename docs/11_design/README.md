# Design & UI Concepts

> **Category:** Design  
> **Status:** Concept Phase — 2026-04-27

---

## Brand Summary

| Property | Value |
|----------|-------|
| **Tagline** | Stream. Sync. Anywhere. |
| **Brand Essence** | Fast · Connected · Secure |
| **Tone of Voice** | Modern · Confident · Friendly · Innovative |
| **Primary Font** | Inter (Regular / Medium / Semi Bold / Bold) |
| **Theme** | Dark mode first |

---

## Color Palette

### Primary
| Swatch | Hex | Usage |
|--------|-----|-------|
| Indigo | `#6366F1` | Primary brand, buttons |
| Violet | `#8B5CF6` | Gradients, accents |
| Cyan | `#22D3EE` | Highlights, LAN status |
| Purple | `#A855F7` | Logo gradient end |

### Neutrals
| Hex | Usage |
|-----|-------|
| `#0F172A` | App background |
| `#1E293B` | Sidebar, cards |
| `#334155` | Card borders |
| `#475569` | Secondary text |
| `#64748B` | Muted text |
| `#E2E8F0` | Primary text |

### Semantic
| Hex | Usage |
|-----|-------|
| `#22C55E` | Online, active, success |
| `#F59E0B` | Warning, idle, amber |
| `#EF4444` | Error, danger, block |
| `#3B82F6` | Info, internet mode |
| `#8B5CF6` | Pro, premium |

---

## Logo Concept

```
F  +  ≋  +  ▶  =  [Fluxora F mark]
(letter) (wave/flow) (play) = combined mark
```

Gradient direction: Indigo → Purple → Cyan (top-left to bottom-right)

---

## Screens Designed

| Screen | File |
|--------|------|
| Subscription / Pricing | [design_reference.html](./design_reference.html) |
| Library Manager | [design_reference.html](./design_reference.html) |
| Clients Manager | [design_reference.html](./design_reference.html) |
| Groups Manager | [design_reference.html](./design_reference.html) |
| Brand Identity Sheet | [design_reference.html](./design_reference.html) |

---

## Navigation Structure (Control Panel)

```
Sidebar:
├── Dashboard
├── Library
├── Clients
├── Groups
├── Activity
├── Transcoding
├── Logs
└── Settings

Bottom (Sidebar):
├── System Status (Server Running indicator)
├── LAN Mode (IP shown)
├── Internet Access (Connected)
└── User Account
```

---

## Pricing Tiers (from concept)

| Tier | Price | Clients | Quality | Key Features |
|------|-------|---------|---------|-------------|
| Free | $0/mo | 2 | 1080p | LAN only, 5 libraries |
| Plus ⚡ | $4.99/mo | 5 | 1080p HD | Internet streaming, hardware transcoding, 50 libraries |
| Pro 👑 | $9.99/mo | 20 | 4K Ultra HD | Advanced transcoding, unlimited libraries, priority support |
| Ultimate 💎 | $19.99/mo | Unlimited | 4K + HDR | AI transcoding, advanced roles, real-time sync, dedicated support |

> **Interactive HTML reference:** See `design_reference.html` for full UI recreation.
