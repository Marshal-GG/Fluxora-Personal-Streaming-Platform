# Polar Webhook Configuration

> **Category:** Infrastructure  
> **Status:** Active - Updated 2026-04-29  
> **Scope:** Phase 4 server-side payment webhook setup

---

## Current Architecture

Fluxora core streaming remains self-hosted: the user's server, media files, and SQLite database live on the user's machine.

The Phase 4 payment webhook currently lives in `apps/server` at:

```text
POST /api/v1/webhook/polar
```

The endpoint verifies Polar Standard Webhooks headers before parsing JSON, then issues a Fluxora license key for paid orders. It stores only:

```text
order_id, tier, license_key, processed_at
```

It does not store customer email, log license keys, or return license keys in webhook responses.

---

## Required Product Metadata

Create one Polar product per paid tier and set a product metadata key named `tier`.

| Fluxora tier | Suggested price | Polar `metadata.tier` |
|--------------|-----------------|-----------------------|
| Plus | $4.99/month | `plus` |
| Pro | $9.99/month | `pro` |
| Ultimate | $19.99/month | `ultimate` |

The webhook ignores products without a recognized `metadata.tier`.

---

## Required Webhook Events

Subscribe the Polar endpoint to:

| Event | Required | Behavior |
|-------|----------|----------|
| `order.paid` | Yes | Safe point for license issuance |
| `order.created` | Optional | Processed only if the payload is already marked paid |

Use Polar's raw JSON delivery format.

---

## Required Environment

Set these in the server data-dir `.env` file:

```dotenv
TOKEN_HMAC_KEY=<existing server token HMAC key>
FLUXORA_LICENSE_SECRET=<hex or random high-entropy signing secret>
POLAR_WEBHOOK_SECRET=<secret from Polar endpoint or Polar CLI>
```

`FLUXORA_LICENSE_SECRET` signs Fluxora license keys. `POLAR_WEBHOOK_SECRET` verifies incoming Polar webhook deliveries. They must not be the same value.

---

## Local Testing

Preferred local workflow:

1. Start the server.
2. Use Polar CLI or a tunnel to expose the webhook endpoint.
3. Copy the CLI/tunnel webhook secret into the server `.env` as `POLAR_WEBHOOK_SECRET`.
4. Trigger a sandbox `order.paid` event.
5. Verify a row appears in `polar_orders`.

Example endpoint target:

```text
http://localhost:8000/api/v1/webhook/polar
```

If using a tunnel, the public URL should preserve the same path:

```text
https://<tunnel-host>/api/v1/webhook/polar
```

---

## Production Status

Server-side issuance is implemented, but Phase 4 is not fully live until a delivery or retrieval flow exists.

Open production questions:

- Should Fluxora run a dedicated central license-issuer deployment for public sales?
- Should generated keys be delivered through Polar benefits/license APIs, transactional email, or owner-mediated desktop retrieval?
- Should `apps/server` be split so a webhook-only deployment does not include media-streaming responsibilities?

Until those are answered, do not document Phase 4 as fully live. The current safe state is: Polar can trigger signed key generation, and the generated keys are stored server-side for a future retrieval/delivery flow.
