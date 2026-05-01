# Domains & Subdomains

> **Category:** Infrastructure
> **Status:** Active — v1 routing proposed but not yet provisioned
> **Last Updated:** 2026-05-01

This doc is the canonical inventory of every domain and subdomain Fluxora uses or plans to use, what each is for, what infrastructure backs it, and what state it is in. Cross-link this whenever a new public-facing surface is introduced.

---

## Naming philosophy

| Decision | Rationale |
|----------|-----------|
| Use **`fluxora.marshalx.dev`** as the eTLD+1 | Owner already owns `marshalx.dev` and uses it for personal projects. No need to register a new TLD until there is signal it matters. |
| Use **subdomains, not paths**, for separating concerns (`api.`, `<user>.`, `turn.`) | DNS routing is free, fast, and out of the request path. Path-based routing requires an owned proxy (more infra, more failure surface — see [`03_public_routing.md`](./03_public_routing.md#why-path-based-routing-is-harder-than-it-sounds)). |
| Apex (`fluxora.marshalx.dev`) stays the **marketing landing page** | Static, public, low risk. Anything dynamic lives on a subdomain. |
| Subdomain proxy state controlled per-record | Apex must be **proxy off** (Firebase TLS); `api` and friends must be **proxy on** (Cloudflare Tunnel + DDoS protection). |
| Reserve a brand-clean fallback (`fluxora.cloud`) | Currently unregistered. If multi-tenant SaaS scales beyond a personal project, registering a dedicated TLD avoids the awkwardness of `<random-id>.fluxora.marshalx.dev`. Decision deferred until v2 ships and load is measured. |

---

## Live domains (in production today)

| Hostname | Purpose | Backed by | DNS provider | CF proxy | TLS issuer | Notes |
|----------|---------|-----------|--------------|----------|------------|-------|
| `fluxora.marshalx.dev` | Marketing landing page | Firebase Hosting (Next.js static export) | Cloudflare DNS | **OFF** | Let's Encrypt via Firebase | Proxy must be OFF — Firebase performs the TLS handshake directly to provision the cert. Turning proxy on breaks renewal. |
| `uat.fluxora.marshalx.dev` | UAT / staging landing page | Firebase Hosting (`uat` channel) | Cloudflare DNS | **OFF** | Let's Encrypt via Firebase | Same TLS constraint as apex. 30-day channel TTL, auto-renewed on every push to the `uat` branch. |
| `*.fluxora-streaming-platform.web.app` | Firebase auto-generated PR-preview channels | Firebase Hosting | Firebase | n/a | Firebase | Temporary URLs created per pull request, deleted when the PR closes. Not user-facing. |

Everything above is documented in [`docs/05_infrastructure/01_infrastructure.md`](./01_infrastructure.md#web-landing-page--firebase-hosting) — this section is the canonical pointer; deployment runbooks live there.

---

## Proposed — v1 (single-tenant home server tunnel)

Tracked in [`03_public_routing.md`](./03_public_routing.md). Not yet provisioned.

| Hostname | Purpose | Backed by | DNS provider | CF proxy | TLS issuer | State |
|----------|---------|-----------|--------------|----------|------------|-------|
| `api.fluxora.marshalx.dev` | Public entry to the home Fluxora server (REST + WS, control plane only — no media bandwidth) | Cloudflare Tunnel → home PC `:8080` | Cloudflare DNS | **ON** | Cloudflare-issued (Universal SSL) | Proposed |

CNAME target: `<tunnel-id>.cfargotunnel.com` (Cloudflare provides this when the tunnel is created).

---

## Proposed — v2 (multi-tenant)

Tracked in [`03_public_routing.md` § v2 — Multi-tenant rollout](./03_public_routing.md#v2--multi-tenant-rollout). Not yet started.

| Hostname pattern | Purpose | Backed by | DNS provider | CF proxy | TLS issuer | State |
|------------------|---------|-----------|--------------|----------|------------|-------|
| `*.fluxora.marshalx.dev` | Wildcard for per-user subdomains — `alice.fluxora.marshalx.dev`, `bob.fluxora.marshalx.dev`, etc. | Cloudflare for SaaS (Custom Hostnames API) → each user's own tunnel | Cloudflare DNS | **ON** | Cloudflare-issued | Proposed |
| `register.fluxora.marshalx.dev` *(tentative)* | Control-plane Worker for v2 signup, subdomain provisioning, heartbeat | Cloudflare Workers + D1 | Cloudflare DNS | **ON** | Cloudflare-issued | Proposed — could also live as a path on the apex (`fluxora.marshalx.dev/api/control/...`) if subdomain pollution is a concern |
| `status.fluxora.marshalx.dev` *(tentative)* | Public per-server tunnel-up/down status page | Cloudflare Workers (read-only D1 query) | Cloudflare DNS | **ON** | Cloudflare-issued | Proposed |

### Per-user subdomain reservation policy

- Default-issued: `<server_id>.fluxora.marshalx.dev` where `<server_id>` is derived from the license-key nonce (already unique).
- Vanity claim: Pro/Ultimate users can claim a friendly subdomain (e.g. `alice.fluxora.marshalx.dev`) on first registration if available.
- 90 days inactive → tunnel disabled, subdomain reserved for the original owner for another 6 months, then released back to the pool.
- Reserved words that cannot be issued as user subdomains: `api`, `register`, `status`, `turn`, `www`, `mail`, `admin`, `system`, `staff`, `support`, `help`, `docs`, `blog`, `app`, `cdn`, `static`. Maintain this list in the control-plane Worker config.

---

## Optional / deferred subdomains

Not on the roadmap, but pre-allocated mentally so they aren't claimed by typo'd user signups.

| Hostname | Intended purpose | Trigger to provision |
|----------|------------------|----------------------|
| `turn.fluxora.marshalx.dev` | Self-hosted TURN server for WebRTC fallback on symmetric NATs | When public STUN starts failing for a meaningful percentage of WAN connections, or when telemetry shows TURN demand. Add as a second `cloudflared` ingress. |
| `cdn.fluxora.marshalx.dev` | Static asset CDN if the landing page or in-app images get heavy enough to want a separate origin | When the marketing site exceeds Firebase's free tier or asset weight starts harming PageSpeed. Likely just a Cloudflare R2 + Pages combo, no Firebase. |
| `docs.fluxora.marshalx.dev` | If user-facing docs ever split out from the marketing site | When the public docs surface grows beyond a `/docs` route on the apex. |
| `webhook.fluxora.marshalx.dev` | If we ever need a payment-webhook endpoint that lives outside the home server (e.g. for hosted multi-tenant) | v2 multi-tenant only — currently Polar webhooks hit the home server directly via `api.fluxora.marshalx.dev/api/v1/webhook/polar`. |

---

## Brand-domain options (long-term, currently unregistered)

| Domain | Price tier (typical .com/.cloud/.io annual) | Use case | Decision state |
|--------|----------------------------------------------|----------|---------------|
| `fluxora.cloud` | ~$8–25/year | Drop-in replacement for `*.fluxora.marshalx.dev` once multi-tenant gets traction. Cleaner, less personal-feeling. | Considered — not registered. Decide during v2 launch retro. |
| `fluxora.app` | ~$12–18/year | Shorter, app-store-aligned. | Considered — not registered. |
| `fluxora.io` | ~$30–60/year | Tech-conventional. | Considered — not registered. |
| `fluxora.tv` | ~$25–40/year | Aligned with media-streaming brand. | Speculative. |

If/when a brand domain is registered, the migration plan is:
1. Set up the new domain in Cloudflare with the same wildcard + records.
2. Issue both old and new subdomains during a transition window (~3 months).
3. Server returns *both* `remote_url`s in `GET /info` during transition; clients prefer the new one.
4. After the window, drop the old domain from new pairings; existing clients keep working until they re-pair.

The server-supplied-URL design (decision **D1** in [`03_public_routing.md`](./03_public_routing.md#decisions-locked)) makes this migration cheap — no client rebuild required.

---

## DNS provider configuration notes

All domains/subdomains are managed in Cloudflare DNS for the `marshalx.dev` zone.

| Setting | Value | Why |
|---------|-------|-----|
| DNSSEC | Enabled | Prevents DNS hijacking; minor cost = none. |
| Proxy default for new records | OFF | Firebase + tunnels need explicit proxy decisions; safer to opt in than out. |
| TTL | Auto (Cloudflare-managed, ~5 min) | Lets us flip records quickly during incidents. |
| Email DMARC/SPF | Out of scope here — no Fluxora email yet | When email is added (e.g. `support@fluxora.marshalx.dev`), document SPF/DKIM/DMARC in this file. |

### Required Cloudflare API token scopes

When a control-plane Worker provisions per-user subdomains in v2, the API token must have:

- `Zone:Read` on the `marshalx.dev` zone
- `Zone:DNS:Edit` on the `marshalx.dev` zone
- `Zone:SSL:Edit` on the `marshalx.dev` zone (for Custom Hostnames cert provisioning)
- `Zone:Hostnames:Edit` on the `marshalx.dev` zone (Cloudflare for SaaS)

Token storage: `CLOUDFLARE_API_TOKEN` Worker secret, never in source.

---

## Status colour code (for status pages and the desktop control panel)

Used in `GET /api/v1/healthz` consumers and the public status page:

| Color | Meaning |
|-------|---------|
| 🟢 green | Tunnel up, recent heartbeat (<60s), last 10 probes succeeded |
| 🟡 yellow | Tunnel up, last heartbeat 60s–5m ago, OR ≥1 of last 10 probes failed |
| 🔴 red | Tunnel daemon unreachable for >5m, OR last 5 probes all failed |
| ⚪ gray | Tunnel never registered or paused by owner |

---

## Naming conventions (for any new subdomain)

When adding a new subdomain to this inventory:

1. **One-word lowercase**, hyphenated only if absolutely necessary (`api` ✓, `web-app` ✗ — prefer `webapp` or split functionality).
2. **Function-named, not implementation-named**: `api.` ✓, `cloudflared.` ✗ (the implementation may change; the function won't).
3. **No version numbers in hostnames** — `api.` not `api-v1.`. API versioning lives in the URL path (`/api/v1/...`), not the hostname.
4. **Reserved-word check** — confirm the new hostname isn't on the user-subdomain reserved list above.
5. **Document the proxy state, TLS issuer, and provisioning method** in the relevant table here before going live.
6. **Cross-link** in `docs/00_overview/README.md` if it's user-facing.

---

## Cross-references

- [`03_public_routing.md`](./03_public_routing.md) — full routing plan (v1 + v2), decisions, and rationale for the `api.` and `*.` subdomains
- [`01_infrastructure.md`](./01_infrastructure.md) — Firebase Hosting setup, custom domain configuration, CI/CD pipelines that touch `fluxora.marshalx.dev` and `uat.fluxora.marshalx.dev`
- [`02_polar_webhook_deployment.md`](./02_polar_webhook_deployment.md) — Polar webhook endpoint, currently hosted on the home server (will move to `api.fluxora.marshalx.dev/api/v1/webhook/polar` after v1 routing lands)
- [`docs/06_security/01_security.md`](../06_security/01_security.md) — TLS, header trust boundary, Cloudflare threat model
