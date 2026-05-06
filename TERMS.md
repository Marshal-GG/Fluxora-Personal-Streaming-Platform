# Terms of Service

> **Effective:** 2026-05-06
> **Canonical version:** <https://fluxora.marshalx.dev/terms> (this file is the source of truth; the rendered Next.js page mirrors it).
> **Maintainer:** Marshalx — portfolio at <https://marshalx.dev>, GitHub `@Marshal-GG`
> **Contact:** `legal@fluxora.marshalx.dev` (preferred) · `marshalgcom@gmail.com` (fallback) · GitHub Issues tagged `terms`

---

## 0. Read this first

These Terms cover three different things, and which sections apply to you depends on which of them you're using:

| You are… | Sections that apply |
|----------|---------------------|
| Just visiting `fluxora.marshalx.dev` | §§1, 2, 4, 13–22 |
| Running the Fluxora server software (Free tier) | §§1, 2, 3, 4, 12, 13–22 + the [LICENSE](LICENSE) |
| Paying for Plus / Pro / Ultimate | All of the above + §§5–11 |
| Forking / contributing to the codebase | §§1, 2, 4, 12, 22 + the [LICENSE](LICENSE) + [CODE_OF_CONDUCT](CODE_OF_CONDUCT.md) |

The MIT License governs the **software**. These Terms govern the **service surface** — the marketing site, the paid-tier license-key issuance, and the use of Fluxora-controlled infrastructure. They do not modify the LICENSE.

---

## 1. Acceptance

You accept these Terms by:

- Visiting `fluxora.marshalx.dev` or any subdomain we control (passive acceptance — by browsing, you agree).
- Purchasing a paid tier (active acceptance — Polar's checkout requires you to confirm).
- Using a Fluxora license key in your self-hosted server.

If you do not agree, do not use the site, do not purchase a tier, and do not use a license key. The Free tier of the software is governed by the LICENSE alone — you can use it without agreeing to these Terms (though community spaces are still bound by the [Code of Conduct](CODE_OF_CONDUCT.md)).

You must be at least 18 years old, or the age of majority in your jurisdiction, to purchase a paid tier. The Free tier has no age requirement (we collect no data and run no account system).

---

## 2. Definitions

For the purposes of these Terms:

- **"Fluxora", "we", "us", "our"** — the Fluxora open-source project, maintained by Marshalx (portfolio at <https://marshalx.dev>) as an individual operator in Delhi, India. Not a registered legal entity.
- **"Site"** — the marketing site at `fluxora.marshalx.dev` and any other domain or subdomain operated by us (e.g., `fluxora.dev`).
- **"Software"** — the open-source code in the [Fluxora GitHub repository](https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform), including the server, desktop control panel, mobile clients, and shared core packages.
- **"Self-Hosted Server"** — a Fluxora server instance running on hardware controlled by an operator (not us).
- **"Operator"** — anyone who installs and runs a Self-Hosted Server. Operators are not our users in the SaaS sense; they are independent administrators of their own systems.
- **"Free", "Plus", "Pro", "Ultimate"** — the four tiers. Free needs no payment or license key. Plus, Pro, and Ultimate are paid tiers unlocked via license keys we issue after purchase.
- **"License Key"** — the HMAC-SHA256-signed string in the format `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>` issued after a successful Polar payment.
- **"Polar"** — Polar.sh, the third-party payment platform we use for paid-tier checkout. Polar uses Stripe as its underlying processor.
- **"Customer"** — an individual who has purchased a paid tier, identified by the email address on the Polar order.
- **"You", "your"** — the person reading these Terms. Context-dependent: a visitor, a contributor, a Customer, an Operator, etc.

---

## 3. The free tier and the open-source software

The Software is open-source under the **MIT License**. See [`LICENSE`](LICENSE).

You may, under that license:

- Run the Software for any purpose, personal or commercial.
- Read the source. Modify it. Redistribute it.
- Fork the repository. Build derivative works.
- Sell services around your fork.

Two clarifications, neither of which contradicts the MIT License:

- **Brand assets are not MIT-licensed.** The "Fluxora" name, the F lettermark, the gradient logos in `assets/brand/`, and the wordmark are reserved by the maintainer. If you distribute a fork or a derivative product, **rename it and replace the brand assets**. See §10. This is the same convention used by Firefox / Iceweasel, Chromium / Chrome, and most well-known open-source projects.
- **The license key system is part of the Software** and licensed under the MIT License. You are free to fork it. However, generating a Fluxora-formatted license key without a Polar payment, or distributing keys you obtained through your fork, is not a license violation but is — when used against `fluxora.marshalx.dev`'s issued keys — addressed under §6.4 (acceptable use) and §11 (termination of paid-tier access). Forks that issue their own keys with their own signing secret are fine; those are different keys.

The Free tier requires no account, no payment, no License Key, and no agreement beyond the LICENSE. You can install and run a Self-Hosted Server today and never interact with us.

---

## 4. The marketing site

When you use the Site, you may not:

- Attempt to break the Site (DDoS, exploit attempts, repeated invalid requests designed to exhaust resources). Note that "find a vulnerability and report it via the channel in [`SECURITY.md`](SECURITY.md)" is **not** a violation — that's actively encouraged.
- Scrape the Site at a rate or volume that materially burdens the host. Reasonable archival / mirroring is fine.
- Redistribute the Site's content (text, images, copy) as if it were your own. Quoting, citing, and linking are fine and welcome.

The Site provides product information, pricing, and links to the paid-tier checkout. The Site itself does not host user content; there are no user accounts on the Site, no comment system, and no upload surface.

---

## 5. Paid tiers

### 5.1 What you get

Plus, Pro, and Ultimate unlock additional capabilities via the License Key issued after payment:

| Tier | Price (INR) | Cycle | Key feature delta over Free |
|------|------------:|-------|---------------------------|
| **Plus** | ₹99 | Monthly | Full HLS + WebRTC internet streaming, TMDB-powered artwork, up to 3 simultaneous remote streams |
| **Pro** | ₹199 | Monthly | Everything in Plus + up to 10 simultaneous remote streams + priority support |
| **Ultimate** | ₹4,499 | One-time, lifetime | Everything in Pro + unlimited simultaneous streams + lifetime access |

The exact feature list per tier is shown on the [pricing section](https://fluxora.marshalx.dev/#pricing) of the Site. **The feature list at the time of your purchase is what you're entitled to.** If we add features later, they roll forward to existing customers at the same tier; if we ever remove features, existing customers retain the original feature set for the duration of their subscription (or for life, in Ultimate's case).

### 5.2 What "feature unlock" actually means

Fluxora's tier limits are enforced by the Self-Hosted Server reading your License Key locally. There is no online check, no usage telemetry, and no rate limiting from us.

The maintainer-controlled `/api/v1/orders` endpoint on your server can re-fetch your order list from Polar if you ever lose your key. Otherwise, once issued, the key is self-contained.

### 5.3 Billing & recurrence

- **Plus** and **Pro** are recurring monthly subscriptions billed in INR via Polar.
- **Ultimate** is a single one-time payment; no recurring charge.
- Polar handles the actual billing, including any local taxes (GST in India, VAT in EU, etc.). Stripe is the underlying payment processor.
- You may cancel a Plus or Pro subscription at any time via your Polar customer-portal link (delivered with your purchase confirmation) or by contacting us. Cancellation stops future charges. Past charges are non-refundable except as set out in §5.4.
- We do not offer pro-rated refunds for cancellations after the 14-day window. The license key continues to work until the end of the paid period.

### 5.4 Refund policy

- **First 14 days, no questions asked.** If you purchased within the last 14 days, file a [GitHub Issue](https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues) tagged `refund` or contact Polar support directly. We will refund 100% of the most recent charge.
- **After 14 days, refunds are at our discretion** — typically only granted for billing errors (you were charged twice, etc.) or for products that materially fail to deliver as described.
- **Ultimate refunds** follow the same 14-day rule as Plus / Pro. After 14 days, an Ultimate refund is granted only if a feature you purchased the tier specifically for is permanently broken and cannot be fixed within a reasonable time.

To request a refund, contact `legal@fluxora.marshalx.dev` or open a `refund`-tagged issue. Include your order ID. Polar processes the actual refund within 5–10 business days.

### 5.5 License key delivery

Your License Key is emailed to you within minutes of a successful Polar checkout. Check your spam folder if it doesn't arrive within 30 minutes.

If you don't receive the key:

- Check spam / promotions.
- Visit <https://fluxora.marshalx.dev/manage> and look up your order.
- Contact `support@fluxora.marshalx.dev` with your Polar order ID.

We will re-issue lost keys on request as long as the original purchase is verifiable. Re-issuance is a manual operator step and may take up to 7 days.

### 5.6 License key obligations

License Keys are personal and tied to your purchase. Specifically:

- **You may install your key on as many devices as you personally use.** Plex / Jellyfin's "household" model — same family, same physical residence — applies here too. We don't enforce technically; we trust you.
- **You may not** sell, lend, sub-license, or distribute your key to third parties outside your household.
- **You may not** publish your key to a public location (GitHub commit, paste site, Discord, etc.). Keys published publicly are presumed compromised and may be revoked.
- **Revocation.** If we discover a key has been distributed in violation of this section, we will revoke it. Revocation invalidates the key on next license check (if implemented in a future server release; currently keys are validated locally so revocation is honour-based until the upstream check ships).

The license key contains no personally-identifying data. It is an HMAC-SHA256 signature over `<TIER>-<EXPIRY>-<NONCE>` with our secret. Verifying or inspecting your own key is fine and supported.

---

## 6. Acceptable use

You may not use Fluxora — the Software, the Site, or a paid License Key — to:

1. **Distribute content you do not have the right to distribute.** Fluxora is a personal-use streaming product. It is not a piracy tool, and the maintainer has no view into what files you've indexed. But by using the Software you affirm that the media in your library is content you own a personal copy of, content you have a license to use, or content in the public domain. We do not police this; you indemnify us if you breach it (see §8).
2. **Circumvent DRM or copy-protection on third-party media.** The Software is not designed to and does not include DRM-circumvention tools. Using a separate tool to crack a Blu-ray and then streaming the result via Fluxora is your liability, not ours; do not do it on infrastructure that surfaces back to us (e.g., do not paste a stack trace involving DRM-stripped content into a public issue).
3. **Build a multi-tenant streaming service that resells Fluxora's capabilities.** The Software is licensed for self-hosted, single-tenant use. Operating a public Fluxora-as-a-Service that other people pay you to use, or running a "Fluxora hosting" business, requires a separate written agreement with us. Casual sharing within your household / friend group is fine and expected — that's the whole point.
4. **Reverse-engineer the License Key system to bypass tier limits**, generate counterfeit keys, modify the Software to ignore the key check, or distribute patches that do so. This is not a copyright-license violation (the MIT License permits modification), but it is a Terms violation specifically scoped to interactions with `fluxora.marshalx.dev`'s license-issuance system.
5. **Distribute child sexual abuse material, content depicting non-consensual acts, or content that's illegal under Indian law** (where the maintainer operates) via the Software. This is non-negotiable. We will cooperate with any law-enforcement inquiry.
6. **Harass, threaten, or impersonate** other contributors or users in any Fluxora-controlled space. See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
7. **Submit malicious content** (malware-laden uploads, phishing-link inserts in TMDB metadata fetches, etc.) targeting the Software or its operators.
8. **Use the Site or Software to send spam.** No outbound mail facility is exposed in the first place; this is a "don't even try" clause.

If you're not sure whether something is OK, ask first. We respond to questions sent to `legal@fluxora.marshalx.dev` within 7 days.

---

## 7. Disclaimer of warranties

THE SOFTWARE AND THE SITE ARE PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND ACCURACY OF DATA.

In particular:

- **Streaming reliability is not guaranteed.** WebRTC P2P depends on your network conditions, NAT type, ISP, and the responsiveness of any TURN relay you've configured. mDNS auto-discovery requires multicast, which some routers and corporate networks block.
- **Hardware encoding is not guaranteed.** NVENC / QuickSync / VAAPI / VideoToolbox availability depends on your GPU and drivers. The Software detects and falls back to software encoding (libx264) automatically; performance with software encoding is governed by your CPU, not by us.
- **TMDB metadata accuracy is not guaranteed.** TMDB is a community-edited database; mismatched titles, missing posters, and wrong years happen. The Software's title-cleanup heuristics handle common cases but cannot account for every filename pattern.
- **Backups are your responsibility.** The Software does not back up your media library, library index, or pairing tokens. If your hard drive dies, Fluxora cannot recover your data.

To the maximum extent permitted by law, we disclaim any warranty not expressly stated in this document.

---

## 8. Indemnification

You agree to indemnify, defend, and hold harmless the maintainer, contributors, and project from any claim, demand, loss, or expense (including reasonable attorneys' fees) arising from:

- Your use of the Software or Site in violation of these Terms.
- Your violation of any third party's rights, including intellectual-property rights, in connection with content you stream through your Self-Hosted Server.
- Your violation of any law or regulation.

This obligation survives termination of your use of the Software.

---

## 9. Limitation of liability

To the maximum extent permitted by law:

- Our **total cumulative liability** to you for any claim arising from or related to these Terms or the Software is limited to **the amount you paid us in the 12 months preceding the claim**, or **₹0 if you are a Free-tier user**. For Ultimate purchasers, that amount is ₹4,499.
- We are **not liable** for indirect, consequential, special, incidental, or exemplary damages, including (but not limited to) lost profits, lost revenue, business interruption, loss of data, loss of goodwill, or substitute-service costs, even if we have been advised of the possibility of such damages.
- Some jurisdictions do not allow exclusion of implied warranties or limitation of liability for consequential damages; in those jurisdictions, the limitations apply to the fullest extent permitted.

This limitation reflects the price you paid (₹0 to ₹4,499) and the open-source nature of the Software. If you require warranties beyond those stated here, do not use the Software in a critical-path business workflow.

---

## 10. Intellectual property

### 10.1 Software

The Software is licensed to you under the [MIT License](LICENSE). You receive the rights described there: use, copy, modify, merge, publish, distribute, sublicense, sell. The MIT License is the operative grant for software use; these Terms do not narrow it.

### 10.2 Brand

The "Fluxora" name and the brand assets — the F lettermark, the wordmark, gradient logos — are reserved by the maintainer. The MIT License does not grant rights to brand assets.

You may use the Fluxora name to:

- Refer to the project ("I use Fluxora" / "this is a Fluxora plugin").
- Link to it.
- Write a review or article.
- File a bug report or feature request.

You may not use the Fluxora name to:

- Brand a fork or derivative product. Rename your fork.
- Imply endorsement, affiliation, or partnership with us.
- Register Fluxora-named domains, social handles, or trademarks.

If you build a third-party product that integrates with Fluxora, you may use phrasing like "for Fluxora", "compatible with Fluxora", or "Fluxora plugin" — that's nominative use and is fine.

### 10.3 Documentation, content, brand assets

Documentation in the `docs/` directory, the marketing site copy, and brand artwork are © Marshalx, 2026. The MIT License does not cover them. Linking, quoting, and short citations are fine; wholesale republication is not.

### 10.4 Contributions

By submitting a pull request, issue, or other contribution, you license your contribution under the same MIT License that covers the Software. You retain copyright. You represent that you have the right to submit the contribution and that it does not infringe any third party's rights. There is no separate Contributor License Agreement; the MIT License is sufficient.

---

## 11. Termination

### 11.1 Termination by you

- **Free tier:** stop using the Software. There's nothing to terminate; we have no record of you.
- **Paid tier:** cancel via your Polar customer portal or by contacting us. Cancellation stops future charges. Your License Key continues to work for the remainder of the paid period.

### 11.2 Termination by us

We may terminate or suspend your paid-tier access for:

- Material breach of §6 (acceptable use), with notice and a 14-day cure period if the breach is curable.
- Non-payment (Polar handles this automatically — failed renewal terminates the recurring subscription).
- Required by law or court order.

If we terminate a paid tier for breach we cannot or will not cure, **we will refund the unused portion of the most recent monthly charge**. Ultimate purchasers terminated for breach are not refunded.

### 11.3 Effect of termination

- License Key validity ends at the end of the current paid period (or immediately, for breach-based termination).
- We do not delete your `polar_orders` row automatically — you can request deletion via [`PRIVACY.md`](PRIVACY.md) §8.
- Sections 7 (warranties), 8 (indemnification), 9 (liability), 10 (IP), 17 (governing law), and 18 (disputes) survive termination.

---

## 12. Third-party services and content

The Software optionally integrates with third-party services. Each is governed by its own terms; using these features means you accept those:

- **TMDB** (`api.themoviedb.org`) — operator-provided API key. Subject to TMDB's API Terms of Use. The operator's API key, not the maintainer's.
- **Cloudflare** (Tunnel + DNS-over-HTTPS) — operator-controlled tunnel, optional. Subject to Cloudflare's Self-Serve Subscription Agreement.
- **Polar** (paid-tier checkout) — Subject to Polar's Terms of Service.
- **Sentry** (error reporting, opt-in) — Subject to Sentry's Service Terms.

We are not responsible for the availability, accuracy, or behaviour of third-party services. Their downtime is not our breach.

---

## 13. Modifications to these Terms

We may update these Terms. Material changes will be:

1. Announced on the GitHub repository's release notes at least 14 days before they take effect.
2. Reflected by updating the "Effective" date at the top of this document.
3. Communicated by email to anyone with an active paid subscription, if the change affects their tier.

A "material change" is one that:

- Modifies pricing for an existing tier in a way that disadvantages existing customers (price increases on renewal — existing customers always have the option to cancel before the increase takes effect).
- Removes a feature you paid for. (Adding features is not material.)
- Changes refund / cancellation policy.
- Changes governing law or jurisdiction.
- Reduces our commitments or increases your obligations.

Cosmetic / clarifying edits don't count as material changes; we still note them in commit history but won't reset the 14-day clock.

If you object to a material change, you may cancel your paid subscription before the change takes effect and receive a refund of the unused portion of the most recent payment.

---

## 14. Force majeure

Neither party is liable for failure or delay in performance due to causes beyond reasonable control, including: natural disasters, war, civil unrest, terrorism, government action, internet-infrastructure outages, third-party service outages (Cloudflare, Polar, Stripe, GitHub), pandemic-related disruption, or labour disputes.

---

## 15. Severability

If any provision of these Terms is held invalid or unenforceable, the remaining provisions remain in full force and effect. The invalid provision will be replaced by a valid provision that most closely matches the intent of the original.

---

## 16. Entire agreement

These Terms, together with the [LICENSE](LICENSE), [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), constitute the entire agreement between you and us regarding your use of the Software and Site. Any prior agreement on the same subject is superseded.

No oral statement, sales pitch, marketing copy, or third-party representation modifies these Terms.

---

## 17. Governing law

These Terms are governed by the laws of the **Republic of India**, without regard to conflict-of-laws principles. The Indian Contract Act, 1872, the Information Technology Act, 2000, and the Digital Personal Data Protection Act, 2023 apply where relevant.

For paid-tier customers in the European Union, United Kingdom, or California, your local mandatory consumer-protection law applies in addition to Indian law and prevails to the extent of any conflict.

---

## 18. Dispute resolution

### 18.1 Informal resolution

Before filing any formal dispute, you agree to contact `legal@fluxora.marshalx.dev` and attempt to resolve the matter informally. Most disputes can be settled by email within 30 days.

### 18.2 Formal resolution

If informal resolution fails, disputes will be resolved as follows:

- **Indian customers and the Free tier worldwide:** in the courts of Delhi, India. You and we consent to the personal jurisdiction of those courts.
- **EU / UK customers:** at your election, in the courts of Delhi, India, or in the courts of your country of residence as required by EU consumer-protection law.
- **California customers:** at your election, in the courts of Delhi, India, or in the small-claims court of your county of residence for disputes within its jurisdictional limit.

### 18.3 Class-action waiver

To the maximum extent permitted by law, disputes will be brought individually, not as part of a class action, consolidated action, or representative proceeding.

---

## 19. Notices

Notices to us: email `legal@fluxora.marshalx.dev` (preferred) or `marshalgcom@gmail.com`.

Notices to you: email to the address on your Polar order, or — if you have not purchased a paid tier — by an update to these Terms (we have no other way to reach you).

---

## 20. Assignment

You may not assign these Terms or your paid-tier subscription to a third party without our written consent. We may assign these Terms in connection with a transfer of the project to a successor maintainer, in which case the successor inherits the obligations.

If the project is discontinued (the maintainer ceases to operate Fluxora):

- Plus and Pro recurring charges are stopped; no new charges occur.
- Already-issued License Keys continue to function (they are HMAC-signed and self-validating; no upstream check is required).
- Source code remains available under the MIT License at the GitHub repository or its mirrors.
- The marketing site may go offline; we will give 30 days' notice via the GitHub repository.

---

## 21. No waiver, no agency

Failure to enforce any provision is not a waiver of that provision. No agency, partnership, joint venture, or employment relationship is created by these Terms.

---

## 22. Contact

| Reason | Channel |
|--------|---------|
| Question about these Terms | `legal@fluxora.marshalx.dev` |
| Refund request | `legal@fluxora.marshalx.dev` or [GitHub Issue tagged `refund`](https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues) |
| License-key issue (lost / re-issue / suspected revoked) | `support@fluxora.marshalx.dev` |
| Privacy / data rights | `privacy@fluxora.marshalx.dev` (see [`PRIVACY.md`](PRIVACY.md)) |
| Security vulnerability | See [`SECURITY.md`](SECURITY.md) |
| Conduct issue | `conduct@fluxora.marshalx.dev` (see [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)) |
| Anything else | `marshalgcom@gmail.com` (the maintainer's personal address — last resort) |

---

## 23. Disclaimer

This document is written in plain language and reflects the actual operating practices of Fluxora as of the effective date. It is not legal advice. If you depend on Fluxora for a commercial workflow, or if your use case has specific regulatory obligations, consult a lawyer about whatever contract should sit alongside these Terms.

If a court of competent jurisdiction interprets a provision in a way materially different from our drafting intent, we will update the Terms to clarify rather than litigate the ambiguity.
