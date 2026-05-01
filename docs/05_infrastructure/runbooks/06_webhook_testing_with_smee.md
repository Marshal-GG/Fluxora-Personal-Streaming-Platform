# Runbook: Testing inbound webhooks locally with smee.io

> **What:** Pattern for receiving webhooks from third-party services (Polar, Stripe, GitHub, Slack, etc.) on your laptop while developing. The third party can't reach `localhost:8080` directly — smee.io bridges that gap for free.
> **Estimated time:** 5 minutes to set up.

---

## Why this is hard without a tool

Webhooks are HTTP POSTs from a third party (your payment provider, GitHub, etc.) to a URL **you specify**. The webhook source has to be able to reach that URL. Your laptop on home Wi-Fi behind NAT can't be reached from the public internet — there's no static IP, no port forwarding.

Three options to bridge:

| Option | Cost | Setup | Best for |
|--------|------|-------|----------|
| **smee.io** | Free | 30 seconds | Inbound webhooks during dev — this runbook |
| **ngrok** | Free tier limited; $8/mo | 1 minute | When you also need a public HTTPS URL for browser testing |
| **Cloudflare Tunnel** | Free | 30 minutes | Production-grade public URL — overkill for dev |

For dev-only webhook testing, **smee.io is the right choice** because:
- Zero account, zero install
- Works on any platform
- You get a URL like `https://smee.io/abc123` that's stable for the channel's lifetime
- Already used in this project for Polar webhooks (see [`docs/09_backend/02_polar_webhooks.md`](../../09_backend/02_polar_webhooks.md))

---

## How smee.io works

```
┌────────────────────┐                 ┌──────────────┐                 ┌──────────────┐
│ Webhook source     │  POST webhook  │  smee.io     │  forwards over  │  Your laptop │
│ (Polar / Stripe /  │ ──────────────▶│  channel     │ ─server-sent───▶│  smee client │
│  GitHub / etc.)    │                │  endpoint    │ events (SSE)    │  (Node.js)   │
└────────────────────┘                 └──────────────┘                 └──────────────┘
                                                                              │
                                                                              ▼
                                                                    ┌──────────────────┐
                                                                    │ Your local server│
                                                                    │ http://127.0.0.1:│
                                                                    │ 8080/webhook/... │
                                                                    └──────────────────┘
```

The smee client opens a long-lived SSE connection to smee.io and forwards each received POST to your local URL. Bidirectional flow, but only one direction matters for webhook testing.

---

## Step 1 — Create a smee.io channel

Visit [https://smee.io](https://smee.io) → click **Start a new channel**. The page reloads at `https://smee.io/<some-id>`. Bookmark this URL — it's your channel.

Channels are public and free. They have no auth — anyone who knows the URL can POST to it. But:
- The URL is unguessable (8+ random chars)
- The channel only forwards to whoever's running the smee client connected to it
- Smee retains logs publicly on the channel page so you can see what's been received

For dev work that's fine. **Do not use smee for production webhook delivery** — switch to a real tunnel (Cloudflare Tunnel, [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md)) before going live.

---

## Step 2 — Install the smee client

```bash
npm install -g smee-client
```

Or run it ad-hoc without installing:

```bash
npx smee-client --url https://smee.io/<your-channel-id> --target http://127.0.0.1:8080/api/v1/webhook/polar
```

That single command:
- Connects to your smee.io channel
- Forwards each received POST to `http://127.0.0.1:8080/api/v1/webhook/polar`
- Prints each delivery to stdout

Leave it running in a terminal during webhook dev work.

---

## Step 3 — Configure the webhook source

In whatever third-party tool sends the webhooks, set the webhook URL to **the smee.io channel URL** (not your localhost — they can't reach that).

| Provider | Where to configure |
|----------|-------------------|
| Polar.sh | Dashboard → Webhooks → Add endpoint → URL: `https://smee.io/<channel-id>` |
| Stripe | Dashboard → Developers → Webhooks → Add endpoint → URL: smee URL |
| GitHub repo | Settings → Webhooks → Add webhook → Payload URL: smee URL |
| Slack | App config → Event Subscriptions → Request URL: smee URL |

Most providers also let you generate test events — use that to verify the round-trip without waiting for a real event.

---

## Step 4 — Verify the round-trip

In your local server's logs, you should see the request arrive (status, headers, body) within a couple of seconds of the source dispatching it.

If it doesn't arrive:

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Smee client says "connected" but no deliveries | Webhook source is misconfigured (wrong URL, wrong event type) | Re-check provider config. Send a test event from the provider's dashboard |
| Smee client logs `429` from your local server | Rate limiter rejecting | Local server needs to allow smee's request |
| Smee client logs `403` | Signature validation failing | Webhook secret on local server doesn't match what's in the provider's dashboard. See [`05_secrets_management.md`](./05_secrets_management.md) |
| `connection refused` | Local server isn't running on the target port | Start the server, or correct the `--target` flag |

The provider's webhook dashboard usually also shows delivery status and the response your endpoint returned. Use both views together.

---

## Step 5 — Make signature validation work

Real webhook providers sign their payloads — your endpoint should reject any request whose signature doesn't match. The signature is computed over the **raw request body**, so middleware that buffers/parses the body before signature validation will fail.

For Fluxora's pattern (Polar Standard Webhooks), the local server uses the same `POLAR_WEBHOOK_SECRET` as production — no smee-specific config. Smee just forwards bytes verbatim, signature included.

**If you change the webhook secret in the provider's dashboard, restart your local server** to pick up the new value (or set up hot-reload of `.env`).

---

## Step 6 — Production cutover

Once you ship to production, replace the smee URL with your real public webhook URL:

```
Provider config:
  Dev:        https://smee.io/<channel-id>
  Production: https://<your-tunnel-or-domain>/webhook/<provider>
```

For Fluxora: production webhooks hit `https://fluxora-api.marshalx.dev/api/v1/webhook/polar` (the Cloudflare Tunnel from [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md)).

Most providers support multiple endpoints simultaneously, so you can keep the smee channel for dev events while production fires to the real URL. Use environment-scoped product configs in the provider (e.g. Polar's "test mode" vs "live mode") to keep test events going to smee and real ones going to prod.

---

## Limitations

- **Public channel.** Anyone with the smee URL can POST to it. Keep the URL out of public commits.
- **Latency.** Smee adds 50–500ms over a direct connection. Not suitable for latency-sensitive flows.
- **No retention guarantee.** Smee's free service can disappear at any time. Don't rely on it for anything but local dev.
- **Sequential delivery.** A burst of 100 webhooks arrives sequentially via SSE — if your local handler is slow, smee buffers them but doesn't parallelize.

---

## Cross-references

- **Fluxora's Polar webhook deployment notes:** [`docs/05_infrastructure/02_polar_webhook_deployment.md`](../02_polar_webhook_deployment.md)
- **Polar implementation specifics:** [`docs/09_backend/02_polar_webhooks.md`](../../09_backend/02_polar_webhooks.md)
- **Production webhook routing:** [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md)
- **Where the webhook secret lives:** [`05_secrets_management.md`](./05_secrets_management.md)
