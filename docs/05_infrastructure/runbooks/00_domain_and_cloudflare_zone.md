# Runbook: Domain registration + Cloudflare zone setup

> **What:** Step 0 for any project. Get a domain, put it on Cloudflare DNS, with sane defaults that the other runbooks assume.
> **Estimated time:** 30 minutes if buying a fresh domain. 1–24 hours if transferring (DNS propagation lag).

| Placeholder | Example |
|-------------|---------|
| `<APEX>` | `example.dev` |

---

## Step 1 — Pick a registrar

**Cloudflare Registrar (recommended if available).** Sells domains at registry cost — no markup, no upsells. Domain auto-renews, transfers in/out are free. Limited TLD selection (`.com`, `.dev`, `.io`, `.app`, etc.) but covers most needs. Only available if Cloudflare is set up in your country. Single-step zone integration: domain auto-uses Cloudflare nameservers.

**Alternatives** if Cloudflare Registrar doesn't sell the TLD you want, or Cloudflare Registrar isn't available in your region:

| Registrar | Why pick | Why skip |
|-----------|---------|---------|
| Namecheap | Cheap, decent UI, free WHOIS privacy | Upsells at checkout, support is mediocre |
| Porkbun | Cheapest first-year prices, transparent | Smaller TLD selection |
| Hover | Clean UI, no upsells | Pricier than alternatives |
| GoDaddy | Avoid | Aggressive upsells, lock-in tactics |

For non-Cloudflare registrars, you'll **delegate DNS to Cloudflare** in step 3 — domain registration and DNS hosting are separate concerns.

---

## Step 2 — Buy the domain

Whatever registrar you pick:

- **WHOIS privacy: ON.** Hides your name + address from public WHOIS lookups.
- **Auto-renew: ON.** Losing a domain because you forgot to renew is a self-own.
- **Skip add-ons.** No "premium SSL", no "professional email", no "site builder" — you don't need any of these.
- **Lock domain transfers.** Most registrars enable this by default; verify.

For Cloudflare Registrar specifically: skip steps 3 and 4 below — your domain is already on Cloudflare DNS automatically.

---

## Step 3 — Delegate DNS to Cloudflare (non-Cloudflare registrars only)

1. Sign up at [cloudflare.com](https://cloudflare.com) (free plan)
2. **Add a Site** → enter `<APEX>`
3. Choose the **Free** plan
4. Cloudflare scans your existing DNS records (carry over any records the registrar set up by default — usually none for a fresh domain)
5. Cloudflare gives you 2 nameservers like `ns1.cloudflare.com` and `ns2.cloudflare.com`
6. Go back to your registrar's dashboard, find "Nameservers" or "DNS settings"
7. Replace the registrar's default nameservers with the Cloudflare ones
8. Save

Propagation takes 1–24 hours. Cloudflare emails you when the zone is active.

---

## Step 4 — Set zone defaults

After the zone is active in Cloudflare:

### DNSSEC: enable

Cloudflare → `<APEX>` → DNS → Settings → **DNSSEC** → Enable. Cloudflare gives you a DS record. Add it at your registrar (most have a "DNSSEC" or "DS records" panel).

DNSSEC prevents DNS hijacking attacks. Costs nothing, breaks nothing, take 5 minutes to set up.

### SSL/TLS mode: Full (Strict)

Cloudflare → `<APEX>` → SSL/TLS → Overview → **Full (strict)**.

- "Off" — no SSL. Don't.
- "Flexible" — encrypt only between client and Cloudflare; origin sees plain HTTP. Use for legacy origins that can't do HTTPS.
- "Full" — encrypt to origin, but accept self-signed origin certs.
- "Full (strict)" — encrypt to origin, require valid origin cert. The right answer for any new setup.

For Cloudflare Tunnel hostnames this doesn't matter (cloudflared establishes the connection itself), but it matters for any other proxied record.

### Always Use HTTPS: on

Cloudflare → `<APEX>` → SSL/TLS → Edge Certificates → **Always Use HTTPS** → On. Auto-redirects HTTP to HTTPS at the edge.

### Minimum TLS version: 1.2

Same page → **Minimum TLS Version** → 1.2 (or 1.3 if you don't need to support ancient clients).

### HSTS: enable cautiously

Same page → HTTP Strict Transport Security. Tells browsers to always use HTTPS for your domain, even if a user types `http://`. Only enable once you're certain you'll never need plain HTTP — once enabled, it's hard to undo because browsers cache the policy. Defer until production launch.

---

## Step 5 — Email forwarding (optional but recommended)

Even if you don't run an email service, you want `you@<APEX>` to work for things like cert-renewal notifications, abuse complaints, and registrar contact.

**Cloudflare Email Routing** does this for free:

1. Cloudflare → `<APEX>` → Email → Email Routing → Get Started
2. Add a destination address (your real personal email)
3. Add catch-all rule: forward `*@<APEX>` to your destination
4. Cloudflare auto-adds the MX records

Now any `anything@<APEX>` ends up in your real inbox without you operating an email server.

---

## Step 6 — Verify the zone

```bash
dig +short NS <APEX>            # should list Cloudflare nameservers
dig +short DS <APEX>            # should show DNSSEC delegation
dig +short A <APEX>             # nothing yet — that's fine
```

You're now ready to add records. The other runbooks pick up here:

- [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md) — adds CNAMEs for self-hosted services
- [`02_firebase_static_hosting.md`](./02_firebase_static_hosting.md) — adds A records for static sites

---

## Reserved subdomain conventions

While the zone is empty, decide what subdomains you'll use. Add to your project's docs (Fluxora has [`docs/05_infrastructure/04_domains_and_subdomains.md`](../04_domains_and_subdomains.md)):

| Pattern | Use |
|---------|-----|
| `<APEX>` | Marketing landing page or apex redirect |
| `www.<APEX>` | Apex alias / redirect to canonical apex |
| `app.<APEX>` or `<APP_NAME>.<APEX>` | Web app (if any) |
| `<APP_NAME>-api.<APEX>` | Public API (single-level, hyphenated for Universal SSL) |
| `<APP_NAME>-uat.<APEX>` | UAT |
| `docs.<APEX>` | Documentation site (if separate) |
| `status.<APEX>` | Status page |

Avoid two-level subdomains for anything that needs a TLS cert via Cloudflare's Universal SSL — they need the paid Advanced Certificate Manager. See [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md#hostname-depth-rule-read-this-first).

---

## Cost

| Item | Typical cost |
|------|--------------|
| `.com` domain (Cloudflare Registrar) | ~$10/year |
| `.dev` domain | ~$12/year |
| `.app` domain | ~$15/year |
| `.io` domain | ~$30–60/year |
| Cloudflare DNS | $0 |
| Cloudflare Email Routing | $0 |
| DNSSEC | $0 |
| Universal SSL | $0 (apex + 1 level only — see depth rule) |

Total recurring for the whole zone setup: just the domain renewal.
