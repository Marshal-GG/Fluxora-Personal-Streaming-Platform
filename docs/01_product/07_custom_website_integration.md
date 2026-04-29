# Custom Website Integration Guide

This document explains how to use your own website (`fluxora.marshalx.dev`) as the Fluxora
marketing and purchase entry-point while keeping the existing backend monetization logic
(`apps/server`) intact.

The architecture is fully **decoupled**: the website contains no payment logic — it simply
links to Polar.sh checkout pages and your server handles everything else via webhooks.

---

## 1. Link Your Pricing Buttons

In `apps/web_landing/src/components/Pricing.tsx`, the checkout URLs are stored in the
`CHECKOUT` constant at the top of the file:

```ts
const CHECKOUT = {
  plus:     'https://polar.sh/fluxora/checkout/plus',      // TODO: replace
  pro:      'https://polar.sh/fluxora/checkout/pro',       // TODO: replace
  ultimate: 'https://polar.sh/fluxora/checkout/ultimate',  // TODO: replace
} as const
```

**How to get the real URLs:**

1. Go to your [Polar.sh Dashboard](https://polar.sh/dashboard).
2. Navigate to **Products**.
3. For each product (Plus → `tier=plus`, Pro → `tier=pro`, Ultimate → `tier=ultimate`),
   click **Share** and copy the **Checkout URL**.
4. Paste each URL into the corresponding key in `CHECKOUT`.

> **Tip:** Polar supports an inline checkout modal overlay so users never leave your site.
> See [Polar Embedded Checkout docs](https://docs.polar.sh/checkout/embed) if you want
> this in a future iteration.

---

## 2. Configure the Success Redirect

After a successful payment, Polar will redirect the customer back to your site.

**In your Polar dashboard**, for each product:

1. Open the product settings.
2. Set **Success URL** to:
   ```
   https://fluxora.marshalx.dev/success
   ```

The success page is already implemented at `apps/web_landing/src/app/success/page.tsx`.
It tells the customer:
- Check your email for your license key.
- Open the **Fluxora Desktop Control Panel** → **Settings → License** and paste the key.

---

## 3. Connect the Webhook (Critical)

The Fluxora server at `apps/server` generates and stores the license key when it receives
a `POST /api/v1/webhook/polar` event from Polar. Without this, **no license key is issued**.

**Requirements:**
- The Fluxora server (`apps/server`) runs **locally on your machine** — it has no fixed public
  domain. You must expose it via a tunnel or VPS to receive webhooks from Polar.
- The environment variable `POLAR_WEBHOOK_SECRET` must be set in
  `C:\Users\marsh\AppData\Roaming\Fluxora\.env` to the secret copied from the Polar dashboard.

**For local development and testing (smee.io tunnel):**

The project uses [smee.io](https://smee.io/) as a relay because it handles NAT/firewall
issues reliably. The dev channel is already configured:

1. Start your local Fluxora server on `127.0.0.1:8080`.
2. In a separate terminal, run:
   ```bash
   npx smee-client --url https://smee.io/WkO5Z0u3uE5cM0d --target http://127.0.0.1:8080/api/v1/webhook/polar
   ```
3. In **Polar Dashboard → Settings → Webhooks**, set the endpoint URL to:
   ```
   https://smee.io/WkO5Z0u3uE5cM0d
   ```
4. Subscribe to the **`order.paid`** event.
5. Copy the **Webhook Secret** from Polar and set it in your `.env`:
   ```env
   POLAR_WEBHOOK_SECRET=your_secret_here
   ```
6. Restart the server so it loads the new secret.

**For production (permanent public URL):**

When you're ready for live payments, expose the server using one of:
- A VPS with a reverse proxy (nginx → `127.0.0.1:8080`) and a domain of your choice.
- A persistent tunnel service (e.g., Cloudflare Tunnel, ngrok paid).

Update the Polar webhook endpoint URL in the dashboard to your new public address:
```
https://your-public-domain.com/api/v1/webhook/polar
```

**What happens on a successful payment:**

```
Customer pays → Polar fires order.paid →
Server verifies HMAC-SHA256 signature (Standard Webhooks format) →
Checks polar_orders table for idempotency →
Reads product.metadata.tier (must be plus | pro | ultimate) →
Calls license_service.generate_key(tier, days) →
Stores key in polar_orders table →
Returns HTTP 200 to Polar
```

The server **never** logs or echoes the license key in its response. It is stored in SQLite
for owner retrieval only.

---

## 4. Product Metadata (Mandatory)

The server reads `product.metadata.tier` from the Polar webhook payload to decide which
license key to generate. The tier values **must match exactly**:

| Product          | Metadata key | Metadata value |
|------------------|-------------|----------------|
| Fluxora Plus     | `tier`      | `plus`         |
| Fluxora Pro      | `tier`      | `pro`          |
| Fluxora Ultimate | `tier`      | `ultimate`     |

If the `tier` value is missing or wrong, the server logs a warning and returns HTTP 400.
See `apps/server/services/webhook_service.py` → `_POLAR_TIER_MAP` and `_extract_tier()`.

---

## 5. Subscription Management Portal

Customers who need to cancel, change payment method, or view invoices use the Polar
customer portal.

Your website already has a branded gateway page at `/manage`
(`apps/web_landing/src/app/manage/page.tsx`) that links to:

```
https://polar.sh/fluxora/portal
```

This page is linked from the site footer. You can also set a **custom portal domain** in
Polar Dashboard → **Settings → Storefront** (e.g., `billing.fluxora.dev`). If you do,
update the `href` in `manage/page.tsx` to match.

---

## 6. License Key Delivery

Once the webhook processes successfully, the license key is stored in the `polar_orders`
SQLite table on the server. Current delivery path:

1. **Email (pending):** Automated SMTP/SendGrid email to the customer is not yet implemented.
   The success page tells the customer to expect an email — you currently need to retrieve
   the key from the `polar_orders` table manually and send it.
2. **Owner retrieval (next step):** A secure localhost-only screen in the Desktop Control Panel
   to let the owner look up and copy generated keys for customers. This is the **Priority 1
   next step** from the roadmap.

---

## Summary — Links to Configure

| What                  | Where to set it                   | Value                                                       |
|-----------------------|-----------------------------------|-------------------------------------------------------------|
| Pricing buttons       | `Pricing.tsx → CHECKOUT`          | Your real Polar checkout URLs (one per product)             |
| Post-payment redirect | Polar product settings            | `https://fluxora.marshalx.dev/success`                      |
| Webhook (dev)         | Polar → Settings → Webhooks       | `https://smee.io/WkO5Z0u3uE5cM0d`                          |
| Webhook (production)  | Polar → Settings → Webhooks       | `https://your-public-domain.com/api/v1/webhook/polar`       |
| Webhook secret        | `C:\Users\marsh\AppData\Roaming\Fluxora\.env` | `POLAR_WEBHOOK_SECRET=your_secret_here`         |
| Subscription portal   | Footer → `/manage` page           | `https://polar.sh/fluxora/portal`                           |
