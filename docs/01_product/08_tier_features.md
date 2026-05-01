# Tier Feature Matrix

> **Category:** Product
> **Status:** Active — canonical source of truth for tier capabilities
> **Last Updated:** 2026-05-01

This is the **single source of truth** for what each subscription tier includes. Other docs (roadmap, monetization, upgrade UI strings, license-key tier codes) cross-reference this file and should not duplicate the matrix.

When you change anything in this doc, update:
- `apps/server/services/settings_service.py` → `TIER_STREAM_LIMITS` if concurrency caps change
- `apps/mobile/lib/features/upgrade/...UpgradeScreen` → if customer-facing copy changes
- `docs/01_product/05_monetization.md` → reference, not copy

---

## At a glance

| Tier | Price | Concurrent streams | Hardware encoding | Library size | Internet streaming | Multi-device pairing |
|------|-------|---------------------|-------------------|--------------|--------------------|----------------------|
| **Free** | $0 | 1 | ❌ Software only | Unlimited | ✅ (P2P only) | ✅ |
| **Plus** | $4.99/mo | 3 | ❌ Software only | Unlimited | ✅ | ✅ |
| **Pro** | $9.99/mo | 10 | ✅ NVENC / QSV / VAAPI | Unlimited | ✅ | ✅ |
| **Ultimate** | $19.99/mo | Unlimited | ✅ NVENC / QSV / VAAPI | Unlimited | ✅ | ✅ |

Annual prices: deferred. Currently monthly billing only via Polar.

---

## Detailed feature breakdown

### Streaming concurrency

The `max_concurrent_streams` value enforced by the server (`settings_service.get_max_concurrent_streams()`). When a client tries to start a stream and the limit is reached, the server returns `429 Too Many Requests`.

| Tier | Cap | Use case |
|------|-----|---------|
| Free | 1 | One device at a time. Suitable for personal use, single household member. |
| Plus | 3 | Small household — phone + tablet + TV simultaneously. |
| Pro | 10 | Power user, large household, family sharing. |
| Ultimate | 9999 (unbounded) | "Pretend it's infinite" — for users who never want to think about limits. |

### Hardware-accelerated transcoding

When enabled, FFmpeg uses GPU-accelerated encoders instead of CPU. Reduces CPU usage and enables higher concurrent stream counts on modest hardware.

| Encoder | Hardware required | Tier required |
|---------|-------------------|---------------|
| `libx264` | None (CPU) | All tiers |
| `h264_nvenc` | NVIDIA GPU (Pascal or newer) | Pro / Ultimate |
| `h264_qsv` | Intel CPU with iGPU and Quick Sync | Pro / Ultimate |
| `h264_vaapi` | Linux + supported GPU (AMD/Intel/NVIDIA) | Pro / Ultimate |

Selected via `transcoding_encoder` in `PATCH /api/v1/settings`. Validation rejects unknown encoders at the API boundary (Pydantic `Literal` type). The tier check is enforced by the server when starting a stream — see `ffmpeg_service.start_stream()`.

> **Tier-gating note:** the encoder field itself is *not* tier-gated in the API right now (any tier can save the setting), but the actual stream start will fall back to `libx264` if the saved encoder requires Pro+ and the current tier is below. Plan: add a hard 422 at PATCH time once the desktop UI surfaces this clearly. Tracked as TODO.

### Library size

No tier limit. The home server's disk space is the only ceiling. Mentioned here only because some streaming services pretend "library size" is a feature lever — for self-hosted Fluxora it's intentionally not.

### Internet streaming (WebRTC)

All tiers can stream over the internet via WebRTC P2P. The system tries direct → STUN → TURN (when configured); see [`docs/05_infrastructure/06_webrtc_and_turn.md`](../05_infrastructure/06_webrtc_and_turn.md).

If/when a hosted TURN service is offered (currently optional, owner self-hosts), it might become tier-gated to recover bandwidth costs. Not implemented today.

### Multi-device pairing

All tiers can pair multiple clients. The server stores each client's HMAC-hashed bearer token; there is no upper limit on paired devices. The concurrency cap above limits *active streams*, not paired devices.

---

## Free-tier intentional limitations

These are deliberate friction points to drive Plus/Pro upgrades. Document them here so future "fix" PRs don't accidentally remove them:

| Limitation | Rationale |
|-----------|-----------|
| 1 concurrent stream | Two phones in the same house collide → user feels the limit weekly without being blocked entirely |
| Software encoding only | NVENC/QSV/VAAPI is genuinely faster on weak hardware — gives Pro a tangible perf benefit |

These are **not** intended as friction points and should never be added:
- No watermark on free-tier streams
- No quality cap (free streams can be 4K if the hardware can transcode it)
- No ad insertion ever
- No telemetry / phoning home (Fluxora is local-first; that promise applies to all tiers)

---

## License key encoding

Tier is encoded in the license key 4-letter code:

| Tier | Code in key | Example |
|------|-------------|---------|
| Free | `FREE` | `FLUXORA-FREE-99991231-CAFE-12345678` |
| Plus | `PLUS` | `FLUXORA-PLUS-20270501-A0FE-83B12FCD` |
| Pro | `PRO` | `FLUXORA-PRO-20270501-B1FF-94C23EDA` |
| Ultimate | `ULTI` | `FLUXORA-ULTI-99991231-7B14-1F2E3D4C` |

Code (`ULTI`) is intentionally 4 chars to keep the format width-consistent in the Settings screen. Format details in [`docs/06_security/02_license_key_operations.md`](../06_security/02_license_key_operations.md).

---

## Customer-facing copy

When in doubt, use the tier names exactly as written:

> **Free** · **Plus** · **Pro** · **Ultimate**

Capitalized. No "Premium", no "Standard", no "Family Plan". The mobile `UpgradeScreen` is the canonical reference for marketing copy on each tier.

---

## Future tiers

If a new tier is ever added (e.g. "Family — $14.99/mo, 5 streams, multi-account"):

1. Update this doc with the new row.
2. Add the tier code to `services/license_service.py` (`_CODE_TO_TIER` and `_TIER_TO_CODE`).
3. Add to `services/settings_service.py` (`TIER_STREAM_LIMITS`).
4. Add a Polar product with `metadata.tier = <new_tier>`.
5. Update mobile `UpgradeScreen` and desktop tier picker.
6. Write a database migration if the `subscription_tier` `CHECK(...)` constraint needs to be widened.
7. Update [`docs/01_product/06_polar_product_setup.md`](./06_polar_product_setup.md).

That last point is the one most easily forgotten. The `CHECK(subscription_tier IN ('free','plus','pro','ultimate'))` constraint will reject the new tier silently in `PATCH /settings` until the migration is run.

---

## Cross-references

- [`docs/01_product/05_monetization.md`](./05_monetization.md) — pricing strategy, tier-fit thinking
- [`docs/01_product/06_polar_product_setup.md`](./06_polar_product_setup.md) — how each tier maps to a Polar product
- [`docs/06_security/02_license_key_operations.md`](../06_security/02_license_key_operations.md) — key issuance, format, rotation
- [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) — multi-tenant routing (v2) which may eventually become tier-gated
