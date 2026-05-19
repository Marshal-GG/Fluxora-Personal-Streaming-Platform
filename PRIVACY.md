# Privacy Policy

> **Effective:** 2026-05-06
> **Canonical version:** <https://fluxora.marshalx.dev/privacy> (this file is the source of truth; the rendered Next.js page mirrors it).
> **Maintainer:** Marshalx — portfolio at <https://marshalx.dev>, GitHub `@Marshal-GG`
> **Contact:** `privacy@fluxora.marshalx.dev` (preferred) · `marshalgcom@gmail.com` (fallback) · GitHub Issues tagged `privacy`

---

## 1. Why this policy exists

Fluxora is a **self-hosted** media streaming product. Most of what people call "user data" in a typical SaaS context — your media files, library index, watch history, paired-device tokens, preferences — lives on hardware **you own and control**. None of it touches Fluxora-controlled systems.

This policy covers the narrow surface where data does flow through systems we control:

1. The marketing site `fluxora.marshalx.dev` (and any subdomains under `fluxora.dev` / `fluxora.marshalx.dev`).
2. The paid-tier purchase + license-delivery path, which routes through Polar.
3. Any opt-in integrations the operator turns on (e.g., Sentry error reporting).

If you're using Free tier and never visit the website, **we have no data about you** and this document is mostly moot. Read on if you've bought a paid tier, visit the site, or run the server in a configuration that opts into outbound integrations.

This policy is written under and complies with the spirit of the EU **General Data Protection Regulation** (GDPR), the **California Consumer Privacy Act / CPRA**, and India's **Digital Personal Data Protection Act, 2023**. We are a small project — if any specific provision applies and you think we've missed it, file a GitHub issue and we'll fix it. We will not stonewall on legalistic grounds.

---

## 2. Who is responsible for your data ("data controller")

For data we collect:

- **Maintainer:** Marshalx, individual operator, India (Delhi).
- **Contact for privacy matters:** `privacy@fluxora.marshalx.dev` or `marshalgcom@gmail.com`.

Fluxora is not a registered legal entity. There is no Data Protection Officer — the maintainer reads every privacy email personally.

For data the operator collects on their own self-hosted server: **the operator is the controller** of any data their paired clients send to their server. Fluxora the project provides the software; we are not a controller or processor of the operator's media library. If you stream media to a friend's Fluxora server, your privacy questions are between you and that operator.

---

## 3. What data we actually collect (controller scope)

This list is exhaustive. If a category isn't here, we don't collect it.

### 3.1 Marketing site (`fluxora.marshalx.dev`)

The marketing site is a static export served by **Cloudflare Pages**. The site itself runs no analytics, sets no cookies, embeds no tracking pixels, includes no third-party JavaScript beyond what Next.js statically inlines.

What Cloudflare may collect on our behalf, as the CDN host:

- Your IP address (used for geo-routing and DDoS protection)
- Your user-agent string (browser identification)
- The request method, path, and timestamp
- HTTP referrer (if your browser sends one)

We never see this data in identifiable form. Cloudflare retains its edge logs per its own policy — see [Cloudflare's privacy policy](https://www.cloudflare.com/privacypolicy/). You can opt out of additional Cloudflare profiling under their privacy controls.

We do **not** receive Cloudflare Analytics. We do not log IPs server-side. We do not store anything keyed to a visitor identity from the marketing site.

### 3.2 Paid-tier purchases (Polar.sh)

When you purchase Fluxora Plus, Pro, or Ultimate via Polar:

**What Polar collects** (Polar is the controller of this data, Stripe is the processor):
- Your email address.
- Your billing address (for tax compliance — GST in India, sales tax / VAT elsewhere).
- Your payment method details (card number, billing details). These never touch Fluxora.
- The Polar order ID and the items purchased.

See Polar's privacy policy at <https://polar.sh/legal/privacy> for their full list.

**What Polar shares back to Fluxora's webhook** (this is what *we* see):
- The Polar order ID (UUID).
- Your email address.
- The product purchased (which maps to a tier: `plus` / `pro` / `ultimate`).
- The order's `processed_at` timestamp.

**What Fluxora stores** in our `polar_orders` SQLite table (`apps/server/database/migrations/008_polar_orders.sql` + `009_order_customer_email.sql`):

| Column | Purpose | Retention |
|--------|---------|-----------|
| `order_id` | Idempotency — prevents double-issuing a license key on webhook retry | Indefinite while the maintainer-side database exists |
| `customer_email` | Re-issue your license key if you lose it (manual operator lookup) | Same |
| `tier` | Which license-key shape was issued | Same |
| `license_key` | The key we generated and emailed you. HMAC-signed, not encrypted. | Same |
| `processed_at` | Audit + duplicate detection | Same |

We do **not** store: card numbers, CVV, billing addresses, IP addresses, payment-method tokens, Polar customer IDs beyond the order ID.

We do **not** market to you. The email address is used to deliver your license key once, and to re-deliver it if you lose it. There is no opt-in marketing list. There is no newsletter. We will not send unsolicited mail.

### 3.3 The self-hosted server (operator side)

This section is informational — it describes data **on your own hardware that we never see**. You're the controller for your own server.

The Fluxora server stores in its local SQLite database (`~/.fluxora/fluxora.db` or platform equivalent):

- Your media library index — file paths, sizes, codecs (FFprobe-derived), TMDB-matched titles + poster URLs.
- Paired client records — device ID (UUID), device name (e.g. "Pixel 8 Pro"), platform, last-seen timestamp, last-seen IP (LAN address; tunneled requests record loopback), HMAC-SHA256 hash of the bearer token (never the raw token).
- Stream-session history — which device played what and when, last resume position, encoder used.
- Operator settings — server name, transcoding preferences, optional TMDB API key, optional license key, optional public URL override.
- Notifications + activity events generated by your server's operations.

**None of this leaves your hardware unless you explicitly opt in.** Specifically:

- Pairing requests + token issuance: never touch us.
- Streaming over LAN: never touches us.
- Streaming over the internet via WebRTC: P2P between your devices and your server; transit through STUN/TURN if a TURN relay is configured; we never proxy.
- Streaming over the internet via Cloudflare Tunnel: HLS segments are blocked on the public ingress (`HLSBlockOverTunnelMiddleware`) — only API + WebRTC signalling reach the public tunnel. Cloudflare sees the encrypted TLS traffic but not the contents of media.
- Watch history, library index, settings: stay on your machine.

### 3.4 Third-party services your server may contact (operator-controlled)

The operator's server may contact these services depending on configuration:

| Service | When | What it sees |
|---------|------|--------------|
| **TMDB** (`api.themoviedb.org`) | When the operator has set a TMDB API key and library scan / Rescan TMDB is run | The filename or cleaned title of each media file. No identity, no credentials. |
| **TMDB** (image CDN — `image.tmdb.org` or operator's Cloudflare Worker proxy) | When Fluxora desktop / mobile fetches poster art | The poster path (e.g. `/wXxQQqfopK1JYmYsoJJl1uMPmbF.jpg`) — no identity. |
| **Cloudflare DoH** (`https://1.1.1.1/dns-query`) | When the operator's ISP hijacks DNS for `api.themoviedb.org` and Fluxora falls back to DNS-over-HTTPS to resolve the real IP | The hostname being resolved. See `docs/05_infrastructure/runbooks/12_tmdb_proxy_worker.md` for the full ISP-block workaround. |
| **Cloudflare** (`www.cloudflare.com/ips-v4` and `/ips-v6`) | At server startup, to refresh the list of Cloudflare CIDR ranges used by `RealIPMiddleware` to identify tunneled requests | The fact that a Fluxora instance started up. No identity. |
| **Polar** (`api.polar.sh`) | Only on the maintainer-side webhook path during the purchase flow. The operator's server **never** reaches out to Polar. | N/A — operator's server doesn't talk to Polar at all. |
| **Sentry** (`sentry.io`) | Only if the operator sets `FLUXORA_SENTRY_DSN`. Off by default. | Stack traces, request paths, exception messages. Sensitive fields are redacted before send. |

We do not insert any tracking or telemetry beyond the above. We have never operated a "phone home" check.

### 3.5 Sentry error reporting (opt-in)

If the operator opts in by setting `FLUXORA_SENTRY_DSN` to their own Sentry project's DSN:

- Unhandled exceptions on the server are sent to **the operator's own Sentry project**.
- Stack traces include filenames, function names, line numbers, local variable values *unless* explicitly redacted.
- Bearer tokens, license keys, file paths under `~`, customer emails, and `tmdb_api_key` are scrubbed by the redaction layer in `apps/server/sentry_init.py` before send.
- The DSN belongs to the operator. We do not run a Sentry project that aggregates everyone's errors. The maintainer never sees an operator's Sentry data.

If you're concerned about leakage, leave it off. It's off by default.

---

## 4. What we explicitly do not do

This is not boilerplate — these are the specific behaviours we've decided not to engage in:

- **No third-party analytics** (Google Analytics, Plausible, Fathom, Amplitude, Mixpanel, Heap, Posthog, etc.) on the marketing site or the desktop / mobile clients.
- **No behavioural cookies** on the marketing site. (Polar's checkout sets its own session cookies during payment — those are Polar's, scoped to `polar.sh`.)
- **No fingerprinting.** No canvas fingerprinting, font enumeration, WebGL fingerprinting, audio fingerprinting, etc.
- **No cross-site trackers, pixels, or beacons.**
- **No "phone home" telemetry** from the server, mobile, or desktop. No heartbeat to a Fluxora-controlled host. No update check that pings us.
- **No data sales, sharing, or rentals.** We have not entered any data-sharing agreement. We will not in the future without changing this policy first.
- **No advertising.** No ad networks, no first-party ads, no sponsored content.
- **No use of your media library content** for any purpose. We have no access to it. If we did, we wouldn't use it.
- **No marketing emails.** The only email we'll ever send to a customer is the license-key delivery (and a single re-issue email if you ask for one). No "newsletter" flag exists in our database.
- **No machine-learning training on customer data.** Self-evident given we don't have customer data, but stated explicitly because it's a question that comes up.
- **No account creation requirement** for the Free tier. There's no Fluxora account system. License keys are tied to a Polar order, not a Fluxora user.

---

## 5. Cookies & local storage

### Marketing site

- **Zero cookies.** The site is a static export with no session state.
- **Zero `localStorage` / `sessionStorage` writes.** Inspect with DevTools to confirm.

### Polar checkout (third-party iframe / redirect)

- Polar's checkout pages set their own cookies for session, fraud detection, and post-payment redirect. These are scoped to `polar.sh` and `*.stripe.com`, not to `fluxora.marshalx.dev`. Their lifecycle is governed by [Polar's cookie policy](https://polar.sh/legal/privacy).

### Self-hosted server

- The Fluxora server uses **HMAC-SHA256-hashed bearer tokens** stored in its local SQLite database, plus opaque session identifiers in `flutter_secure_storage` on paired clients.
- These are functional credentials, not tracking cookies. They are scoped to the server you paired with and never sent to fluxora.marshalx.dev or to the maintainer.

---

## 6. Data retention

| Data | Where | Retention |
|------|-------|-----------|
| Marketing site logs | Cloudflare Pages | Per Cloudflare's standard retention (typically days to weeks for raw logs). We do not export or aggregate. |
| `polar_orders` table (license key + email) | Maintainer-controlled SQLite | Indefinite while the maintainer continues to operate. Deleted on request — see §8. |
| Polar's own customer record | Polar / Stripe | Per Polar's policy. They retain payment records as long as required by Indian / EU / US tax law (typically 7 years for invoicing). |
| Sentry error reports (if you opted in) | Your own Sentry project | Per your project's retention setting. The maintainer has no access. |

If the maintainer ever ceases to operate, the customer-email + license-key table will be deleted within 90 days. Your already-issued license key will continue to work — it's a self-contained HMAC-signed token, not a database lookup.

---

## 7. Data security

We protect what we hold using the following controls. These are real implementations, not aspirational:

- **License-key signing key** is stored in `~/.fluxora/config.json` with file-system permissions and never logged. Validation is local — no key check ever leaves the maintainer's machine.
- **Polar webhook verification** uses the Standard-Webhooks signature scheme. Replay attacks are prevented by an idempotency table on `order_id`.
- **Admin endpoints** are localhost-only via `require_local_caller`, which rejects loopback callers carrying `CF-Connecting-IP` (so a tunneled request cannot impersonate localhost).
- **HLS media segments** are blocked on the public Cloudflare Tunnel ingress by `HLSBlockOverTunnelMiddleware` — your media never traverses the public internet via the tunnel.

For the marketing site:

- TLS 1.2+ enforced by Cloudflare Pages.
- HSTS preloaded.
- No mixed content, no third-party JS, no inline event handlers.

For paid-tier delivery:

- Polar / Stripe handle all PCI-scope. Card details never touch our infrastructure.

If you find a vulnerability in any of these controls, see [`SECURITY.md`](SECURITY.md).

---

## 8. Your rights

These rights apply globally, but the legal basis varies by your jurisdiction (GDPR for EU/UK, CPRA for California, DPDP Act for India, etc.). Where the law gives you a stronger right, that one applies.

| Right | What it means | How to exercise |
|-------|---------------|-----------------|
| **Access** | Get a copy of any data we hold about you. | Email `privacy@fluxora.marshalx.dev` from the address on the order. We'll reply with the row from `polar_orders` keyed to your email. |
| **Correction** | Fix incorrect data. | Same channel. The most common case is a typo in your email address — we'll update + re-send the license key. |
| **Deletion** | Have your data deleted. | Same channel. Within 30 days we delete the `polar_orders` row, the customer-email field, and any backups containing it. Your license key remains valid (it's HMAC-signed, not DB-looked-up). Polar retains its payment record per its own policy. |
| **Portability** | Get your data in a machine-readable format. | Same channel. We'll send a JSON export. |
| **Objection / restriction** | Stop processing. | Same channel. We'll restrict to "legal hold only" pending dispute resolution if applicable. |
| **Withdraw consent** | Opt out of any optional processing. | The only optional processing is your operator-side Sentry opt-in, which you can revoke by unsetting `FLUXORA_SENTRY_DSN` and restarting the server. |
| **Lodge a complaint** | Take it to a regulator. | EU: your local data-protection authority. UK: ICO. India: Data Protection Board (once operational under DPDP). California: California Privacy Protection Agency. |

We will respond to any rights request within **30 days** (often sooner — the maintainer reads `privacy@fluxora.marshalx.dev` daily). If a request is unusual or requires identity verification, we may ask for confirmation that the requester is the same person as the email-on-file holder.

We will not retaliate for a rights request. Exercising your rights does not affect your ability to use Fluxora or your already-issued license key.

---

## 9. Children's privacy

Fluxora is not directed at children under 13 (or the equivalent age of digital consent in your jurisdiction — 16 in some EU states, 18 in some Indian rule-sets). The Free tier requires no account and no age verification, so we collect nothing from children any more than from adults; the paid-tier path goes through Polar and inherits Polar's age requirements.

If you're a parent and discover your child has purchased a paid tier on a card you control, contact `privacy@fluxora.marshalx.dev` and we'll refund + delete the record.

---

## 10. International transfers

Data flows in the paid-tier path:

- **Visitor browser → Cloudflare edge** (anywhere globally; Cloudflare's anycast routing).
- **Cloudflare edge → Polar checkout** (Polar's infrastructure — primarily US-based via Stripe).
- **Polar webhook → Fluxora server** (the maintainer's machine in India).
- **Fluxora server → customer email** (via the maintainer's outbound SMTP, currently a Polar-mediated email; potentially via SES or Postmark in future — same data scope).

If you are in the EU/UK, your data is processed under the GDPR's standard contractual clauses where applicable. Polar maintains its own SCCs with Stripe.

If you are in India, processing is governed by the Digital Personal Data Protection Act, 2023, with the maintainer as data fiduciary.

---

## 11. Changes to this policy

We don't change privacy policies casually. Material changes will be:

1. Announced on the GitHub repository's release notes at least 14 days before they take effect.
2. Reflected by updating the "Effective" date at the top of this document.
3. Communicated by email to anyone with an active paid subscription, if the change affects how their data is handled.

A material change is one that:

- Adds a new data category we collect.
- Adds a new third-party processor or recipient.
- Changes retention periods.
- Reduces your rights or our commitments.

Cosmetic / clarifying edits (typo fixes, restructuring without semantic change) don't count as material changes; we still note them in commit history but won't reset the 14-day clock.

---

## 12. Contact

| Reason | Channel |
|--------|---------|
| Privacy rights request (access / deletion / etc.) | `privacy@fluxora.marshalx.dev` |
| Security vulnerability | See [`SECURITY.md`](SECURITY.md) — separate channel for separate triage |
| General questions about this policy | `privacy@fluxora.marshalx.dev` or a [GitHub Discussion](https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/discussions) tagged `privacy` |
| Complaint about how a request was handled | `marshalgcom@gmail.com` (the maintainer's personal address — escalation path) |

The maintainer is the only person who reads any of these channels. There is no support team. Replies come within 7 days, usually within 72 hours.

---

## 13. Disclaimer

This policy describes Fluxora's actual data practices in plain language. It is not a legal opinion or contract drafted by counsel. If you operate a Fluxora server commercially, or if your use case has specific regulatory obligations (HIPAA, PCI, etc.), consult a lawyer for whatever obligations sit alongside this policy.

If you spot something in this document that's wrong (a service we no longer use, a data flow that's been deprecated, etc.), file an issue. Privacy claims that don't match implementation are bugs; we treat them as such.
