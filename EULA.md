# Fluxora — End User License Agreement (EULA)

> **Effective:** 2026-05-20
> **Version:** 1.0
> **Canonical version:** <https://fluxora.marshalx.dev/eula> (this file is the source of truth; the rendered page mirrors it).
> **Licensor:** Marshalx — portfolio at <https://marshalx.dev>, GitHub `@Marshal-GG`
> **Contact:** `legal@fluxora.marshalx.dev` (preferred) · `marshalgcom@gmail.com` (fallback)

---

## 0. Read this first

This End User License Agreement ("**EULA**") is the contract between you and Marshalx for the **Fluxora software itself** — the server binary, the desktop control panel, the mobile clients, and the shared core packages bundled with each install. By installing or using any part of the Software, you accept this EULA.

This EULA is a sibling of, not subordinate to, the Fluxora [Terms of Service](TERMS.md) ("**TERMS**"). TERMS governs the *service surface around the software* — the marketing site at `fluxora.marshalx.dev`, the brand, the paid-tier issuance flow, and the support channels. This EULA governs *the software itself* — what you may and may not do with the binary you installed on your hardware. Neither document modifies the other; both apply where their scopes overlap.

If you do not agree to this EULA, do not install or use the Software. Uninstalling the Software at any time ends your obligations under §§ 2, 3, 5, and 6 going forward; §§ 4, 8, 9, 10, and 13 survive termination by their terms.

---

## 1. Definitions

Terms shared with TERMS carry the same meaning here unless explicitly redefined. The definitions that matter for this EULA are:

- **"Software"** — the proprietary Fluxora binary distribution, in any form delivered by the Licensor: the server, the desktop control panel, the mobile clients, and any shared core packages bundled with the install. Includes any updates, patches, or replacement builds delivered under the same name.
- **"Server"** — the Fluxora server component, running on hardware controlled by the user. The Server is the licensed component; License Keys activate features on it.
- **"Client"** — the Fluxora desktop control panel and the Fluxora mobile applications for iOS and Android. Clients pair with one or more Servers and are pure consumers; they do not accept License Keys and do not enforce tier limits independently.
- **"Licensor"** — Marshalx, individual operator in Delhi, India, the holder of all rights in the Software.
- **"You"** — the natural person or single legal entity installing or using the Software.
- **"License Key"** — the HMAC-SHA256-signed string in the format `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>` issued after a successful paid-tier purchase, as described in TERMS § 5.2 and § 5.3. Free tier requires no License Key.
- **"Tier"** — one of Free, Plus, Pro, or Ultimate, each defining a feature ceiling and a concurrent-stream cap. Tier definitions live in TERMS § 5.1.
- **"Household"** — your immediate family or the people sharing your primary physical residence. A reasonable plain-English reading applies; the Licensor does not technically enforce the household boundary and trusts you to interpret it honestly.
- **"Authorised Use"** — any use of the Software that is permitted by § 2 of this EULA and not prohibited by § 3.

---

## 2. Grant of license

### 2.1 Server software grant

Subject to your compliance with this EULA, the Licensor grants you a **non-exclusive, non-transferable, revocable, royalty-free** licence to install and run the Server on hardware you own or directly control, for any lawful personal or commercial purpose, including home, family, small office, and self-employed business use.

The Server runs at the Free tier by default. Activating a License Key in the Server's settings unlocks the tier the key encodes.

### 2.2 Client software grant

The Licensor grants every person a **separate, perpetual, royalty-free, non-exclusive** licence to download, install, and use the Clients (desktop control panel and mobile applications) on any number of devices, for the purpose of pairing with and consuming media from any compatible Server.

The Clients require no License Key. No purchase is necessary to install or use a Client. Anyone may install a Client; anyone may use a Client to pair with any Server that accepts their pairing request.

### 2.3 Tier-bound feature ceiling

The feature surface you may exercise on the Server is bound by the active License Key:

- With no key activated, the Server runs at the Free tier and exposes only Free-tier features.
- With a Plus, Pro, or Ultimate key activated, the Server exposes the features for that tier.
- Tier definitions, feature lists, and concurrent-stream caps are set out in TERMS § 5.1 and on the [pricing section](https://fluxora.marshalx.dev/#pricing) of the marketing site.

**One License Key authorises one Server. An unlimited number of devices may pair with that Server, regardless of tier. The tier governs the number of simultaneous streams the Server will open, not the number of devices that may pair.**

### 2.4 Personal and commercial use both permitted

This licence covers personal use, family use, household sharing, small-office use, and commercial use within a single organisation. A solo professional running the Server on a workstation to stream their own work archive is fine. A small business running the Server on an office NAS to make training material available to its employees is fine.

What is **not** covered by this grant is reselling Software-derived service to third parties; see § 3.2 and TERMS § 6.3.

### 2.5 Term and scope of the grant

The grant in § 2.1 is:

- **Non-exclusive** — others receive the same licence on the same terms.
- **Non-transferable** — you may not assign the licence to another party, except as part of a sale of all the hardware on which the Server is installed to a single buyer who accepts this EULA.
- **Revocable on breach** — material breach of § 3 ends the grant, as set out in § 7.
- **Time-bound for paid tiers** — paid-tier feature unlock lasts as long as the active License Key is valid. The grant of the underlying binary itself is **not** time-bound: when a paid tier ends, the Server reverts to the Free tier and keeps functioning indefinitely.
- **Perpetual for the Free tier** — the Free-tier grant has no expiry. Once you have installed the Software, you may keep running it on your hardware for as long as you wish.

---

## 3. Restrictions

You may not do any of the following, except where the right to do so is granted by mandatory local law (for example, EU Directive 2009/24/EC Article 6 on interoperability) and only to the extent that mandatory law overrides this EULA.

### 3.1 No reverse engineering

You may not reverse-engineer, decompile, disassemble, or otherwise attempt to derive the source code, object code, or internal data structures of the Software. You may not attempt to recover the signing secret used to validate License Keys or to forge a key that the Server would accept.

If your jurisdiction grants you a non-waivable right to reverse-engineer for interoperability with software you have written, you may exercise that right strictly to the extent required by that statute, and you must give the Licensor a written request for the interoperability information first; the Licensor will respond within 30 days.

### 3.2 No redistribution, sublicensing, rental, or as-a-service hosting

You may not:

- Redistribute the Software in original or modified form, whether for fee or free of charge.
- Sublicense, lease, rent, lend, sell, or assign the Software or any portion of it to third parties.
- Operate the Software as a multi-tenant streaming service that other people pay you to access. Hosting a Server for your household, your extended family, or a friend group is the intended use and is fine; running a "Fluxora-as-a-Service" business that resells Server capacity to unrelated third parties requires a separate written agreement with the Licensor.

### 3.3 No tampering with license-key enforcement

You may not modify, patch, hook, intercept, or otherwise interfere with the components of the Software that read, validate, or enforce a License Key, tier ceiling, or concurrent-stream cap. You may not distribute or use tools, patches, or instructions whose purpose is to bypass those checks.

You may inspect your own License Key (it is an HMAC-SHA256 signature over `<TIER>-<EXPIRY>-<NONCE>` and contains no personally-identifying data) and verify the signature mathematically. That is not circumvention; it is supported and welcome.

### 3.4 No asset extraction for redistribution

You may not extract, repackage, or redistribute the Software's embedded brand assets (logos, lettermarks, icons), audio/visual resources, user-interface artwork, or bundled documentation as if they were your own work. Brand assets are reserved separately under TERMS § 10.2.

### 3.5 No public publication of License Keys

You may not publish a paid-tier License Key in a public location — including but not limited to public Git commits, paste sites, Discord servers, gist URLs, screenshots posted to social media, or product reviews. Keys published publicly are presumed compromised and may be revoked at the Licensor's discretion (cross-reference TERMS § 5.7 and § 11.2).

This is separate from the household-sharing rule: telling a family member who shares your home what your key is, is fine. Posting it where a stranger can find it is not.

### 3.6 No unlawful or harmful use

You may not use the Software:

- To violate any applicable law, regulation, or court order.
- To produce, store, transmit, or stream content depicting minors in a sexual context.
- To distribute content you do not have the legal right to distribute (cross-reference TERMS § 6.1).
- To target the Software, its update channel, or the Licensor's infrastructure with malicious traffic, exploit attempts, or denial-of-service attacks.

These restrictions are non-negotiable and survive termination by their terms.

---

## 4. Intellectual property

### 4.1 Ownership of the Software

The Software is licensed, not sold. All right, title, and interest in and to the Software — including all copyrights, trademarks, trade secrets, patents, and other intellectual-property rights — remain with the Licensor. This EULA does not grant you any ownership interest in the Software, nor any right to the source code.

You retain ownership of all media files, library metadata, configuration, and other content you place on or generate with your Server. The Software's licence covers the Software itself, not your data.

### 4.2 Brand assets

The "Fluxora" name, the F lettermark, the wordmark, gradient logos, marketing imagery in `assets/brand/`, and related trade dress are reserved by the Licensor and are **not** licensed to you by this EULA. Your right to refer to the project by name, link to it, write about it, or build interoperable accessories described as "for Fluxora" is governed by TERMS § 10.2 — read that section to understand what nominative use is permitted.

### 4.3 Third-party components

The Software ships with third-party libraries (including but not limited to FFmpeg, libmpv, Media3, and others) each governed by its own licence. The full attribution and licence list is in the [`NOTICE`](NOTICE) file distributed with the Software. Your use of those components is subject to their respective licences in addition to this EULA. Nothing in this EULA narrows or expands the rights granted to you by those third-party licences for those components in isolation.

---

## 5. License Keys

### 5.1 Server-scoped, not user- or device-scoped

A License Key authorises **one Server**. It is not tied to a user account, a device fingerprint, or a hardware ID. There is no per-seat counter. Once activated on a Server, the key governs everything that Server does for every device paired with it.

### 5.2 Concurrent-stream cap is the primary discriminator

The tier encoded in your License Key determines the **concurrent-stream cap** — the number of simultaneous playback sessions the Server will open before refusing additional starts. Pairing is unlimited at every tier; only simultaneous streaming is capped. Pricing-page tier definitions in TERMS § 5.1 set out the current caps.

### 5.3 Self-validating, no phone-home

The Software validates License Keys entirely on the user's machine using HMAC-SHA256 signature verification. After the one-time Polar redemption at the moment of purchase, the Software makes no network call to validate, refresh, or report on License Key usage. Users may verify this with `Wireshark`, `tcpdump`, or any network-monitoring tool of their choice.

### 5.4 Verification welcome — no silent phone-home

The Licensor's commitment is **no silent phone-home**, enforced by these rules:

- The Software contains **no silent telemetry**. The Licensor will not add a call that reports usage, library contents, watch activity, paired-device counts, or any other operational data back to the Licensor or any third party operated on the Licensor's behalf without first (i) documenting it in this Section, (ii) defaulting it to off where it touches your data, and (iii) announcing the change under §12 (Changes to this EULA).
- The Software contains **no remote-disable mechanism, no remote kill switch, and no upstream "is this key still valid" probe** that the Licensor could use to deactivate an installed Server. This commitment is structural — see §7.4 (Continuity) — and will not be weakened by any future change.
- **The current outbound network calls the Server makes** are: (a) optional TMDB metadata fetches using your own API key, when you enable that feature; (b) optional Cloudflare Tunnel traffic, when you configure that integration; (c) optional Sentry error reporting, only if you explicitly opt in; (d) the one-time Polar key-redemption handshake at the moment a paid key is first activated; (e) the operator-initiated `/api/v1/orders` re-fetch from Polar when you manually click "Re-fetch order from Polar" in the Server's settings UI to recover a lost key. This list reflects the Software as of the Effective date of this EULA.
- **If new outbound calls are added in a future version** — for example, an opt-in usage-analytics signal that helps the Licensor understand which features are used, push notifications routed through a third-party service (e.g. Firebase Cloud Messaging) so a mobile client gets a "stream started" alert, an update-availability channel that tells the Server a new release exists, or per-device settings sync — each one will be added to the list above, default to off where it touches your data, and be announced under §12. Adding such calls is a permitted product change; doing so silently is not.

You may verify the current list above by network-monitoring the Software for as long as you like. If you ever observe an outbound call from the Server binary that is not in the list above and that was not announced under §12, please report it via `security@fluxora.marshalx.dev` — it is either a bug or a regression and will be fixed.

### 5.5 Household sharing permitted; multi-server activation prohibited

One License Key activates one Server. Within the Household that owns that Server, any number of family members may pair their personal devices (phones, tablets, laptops, TVs) and stream within the tier's concurrent-stream cap. The Licensor does not technically enforce the household boundary and trusts you to interpret it honestly.

You may **not** use one License Key to activate two or more Servers in parallel. Migrating a key to a new Server (you replaced the home machine, you moved house, the previous machine died) is fine and supported — deactivate the key on the old Server first.

### 5.6 Lost or stolen keys

If you lose your License Key — your email is gone, the activation screen is gone, you reformatted the machine without exporting it — the Licensor will re-issue the key once per calendar year per Customer, free of charge, on receipt of a verifiable purchase reference (Polar order ID, the email address used at checkout, or a Polar receipt). Re-issuance requests go to `legal@fluxora.marshalx.dev`.

If your key is stolen — you discover someone is using it on a Server you do not own, or you accidentally published it publicly — contact the Licensor at the same address and the key will be revoked and replaced. Revocation is honour-based for already-installed Servers because no upstream check runs; the replacement key takes effect on the next activation.

---

## 6. Updates and support

### 6.1 Updates are optional

The Licensor may release updates to the Software — bug fixes, security patches, feature additions. The Licensor may make updates available via the marketing site, GitHub Releases, or any equivalent channel.

You are not obligated to install any update. The Server you have already installed continues to function under this EULA whether or not you ever update it.

Where this EULA changes between releases, the new EULA applies only to the version you install going forward (§ 12).

### 6.2 Support is tier-dependent

Support effort is set by the Customer's tier:

- **Free tier:** best-effort community support via the showcase repository's Issues and Discussions, plus the public documentation. No private support channel is guaranteed.
- **Plus tier:** the same plus priority handling of issues you file.
- **Pro and Ultimate tiers:** priority support per TERMS § 5.1, including response targets where the Licensor has committed to them publicly.

The Licensor does not commit to a fix within any specific timeframe at any tier. Where time-bound service-level agreements exist, they are published on the marketing site and incorporated into your purchase by reference, not by this EULA.

### 6.3 Security updates

The Licensor will issue security updates for the **current major version** and the **immediately preceding major version**, on a best-effort basis, as long as the Licensor continues to operate the project. Older versions may receive security updates at the Licensor's discretion. Where a security issue is reported via the channel in `SECURITY.md`, the Licensor will follow the disclosure timeline published there.

---

## 7. Term and termination

### 7.1 Free tier — perpetual

The Free-tier grant has no expiry. Your right to install and run the Free-tier Server on your hardware continues for as long as you wish, subject only to your continued compliance with § 3.

### 7.2 Paid tiers — co-terminus with the License Key

For Plus, Pro, and Ultimate, the paid-tier feature unlock is co-terminus with the validity of your active License Key:

- For recurring subscriptions (Plus, Pro), the key is valid for the paid period; on cancellation or expiry, the Server reverts to the Free tier and continues to function.
- For one-time-purchase Ultimate, the key is valid for life.

When a paid tier ends, the Server keeps running. Features above the Free tier shut off. Your media library, pairings, and configuration are not deleted by the Software. Cross-reference TERMS § 13 for the continuity commitments.

### 7.3 Termination on breach

If you materially breach § 3 — publishing keys, reverse-engineering, redistribution, building a service for third parties, tampering with key enforcement — the Licensor may:

- Revoke the specific License Key tied to the breach. The Server reverts to the Free tier on the next attempt to validate that key (or immediately, if the breach is detected during an authenticated support interaction).
- Refuse to issue replacement keys for the affected Customer.
- Pursue civil remedies in the jurisdiction set out in § 10.

Revocation does **not** brick the binary. The Server continues to function under Free-tier rules. There is no remote kill switch that the Licensor can use to disable an installed Server.

### 7.4 Continuity promise

In the event the project is discontinued, the Licensor becomes unreachable, or the marketing infrastructure goes offline, the last-released binary continues to function on the user's machine under the existing License Key indefinitely, without any upstream dependency. Recurring charges stop; activated keys keep working; no remote kill switch exists.

This commitment is structural — the Software is *built* not to depend on the Licensor's continued operation for normal use. It is not a promise that can be silently weakened by a future EULA update. Any change to this EULA that would weaken § 7.4 is a material change under § 12 and triggers the 14-day notice and cancel-and-refund right described there and in TERMS § 14.

---

## 8. Disclaimer of warranties

THE SOFTWARE IS PROVIDED **"AS IS"** AND **"AS AVAILABLE"**, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, ACCURACY OF DATA, AND QUIET ENJOYMENT.

In particular:

- The Licensor does **not** warrant that the Software will meet your requirements, that its operation will be uninterrupted or error-free, or that defects will be corrected within any specific timeframe.
- The Licensor does **not** warrant that streaming will succeed over any specific network. WebRTC depends on your NAT, ISP, and TURN configuration; mDNS depends on multicast; hardware encoding depends on your GPU and drivers.
- The Licensor does **not** warrant against loss of data. The Software does not back up your media library, library index, paired-device tokens, configuration, or playback history. Backups are your responsibility. If your storage fails, the Licensor cannot recover your data and is under no obligation to attempt to.
- The Licensor does **not** warrant compatibility with any specific media file. The Software handles a wide range of containers and codecs through bundled FFmpeg / Media3 / libmpv components; corner cases (rare codecs, malformed files, exotic HDR metadata) may fail in ways the Licensor will not always be able to fix.

To the maximum extent permitted by law, the Licensor disclaims any warranty not expressly stated in this document. Some jurisdictions do not allow exclusion of implied warranties; in those jurisdictions, the exclusions apply to the fullest extent permitted by local law.

---

## 9. Limitation of liability

To the maximum extent permitted by law:

- The Licensor's **total cumulative liability** to you for any claim arising from or related to this EULA or the Software is limited to **the amount you paid the Licensor for the Software in the 12 months preceding the claim**.
- If you are a **Free-tier user**, that cap is **₹0**, because you paid nothing for the Software. The Free tier is provided at no charge and carries no liability exposure for the Licensor beyond what mandatory local law imposes.
- For Plus and Pro subscribers, the cap is the sum of the recurring charges paid in the 12 months preceding the claim. For Ultimate purchasers, the cap is the one-time purchase price (currently ₹4,499).
- The Licensor is **not liable** for indirect, consequential, special, incidental, exemplary, or punitive damages, including (without limitation) lost profits, lost revenue, business interruption, loss of data, loss of goodwill, substitute-service costs, or harm to reputation, even if the Licensor has been advised of the possibility of such damages.
- Some jurisdictions do not allow limitation of liability for consequential damages or for personal injury caused by negligence; in those jurisdictions, the limitations apply to the fullest extent permitted by local law and nothing in this section limits liability that cannot be limited under that law.

This limitation reflects the price you paid (₹0 to ₹4,499) and the self-hosted nature of the Software. If you require warranty coverage beyond what is stated here, do not use the Software in a critical-path workflow without a separate written agreement.

---

## 10. Governing law

This EULA is governed by the laws of the **Republic of India**, without regard to conflict-of-laws principles. The Indian Contract Act, 1872, and the Information Technology Act, 2000, apply where relevant.

Disputes arising under this EULA are subject to the exclusive jurisdiction of the courts of **Delhi, India**, except where mandatory local consumer-protection law in your country of residence overrides this clause and provides you with a non-waivable right to sue locally. Where such an override applies, the Licensor consents to the jurisdiction of your local courts for claims brought under that mandatory law and for no other purpose.

For paid-tier customers in the European Union, the United Kingdom, or California, your local mandatory consumer-protection law applies in addition to Indian law and prevails to the extent of any conflict, consistent with TERMS § 18.

---

## 11. Contact

| Reason | Channel |
|--------|---------|
| Licence, refund, or billing matters | `legal@fluxora.marshalx.dev` |
| Lost or revoked key, re-issuance | `legal@fluxora.marshalx.dev` |
| Vulnerability disclosure | `security@fluxora.marshalx.dev` (see [`SECURITY.md`](SECURITY.md)) |
| Privacy / data subject requests | `privacy@fluxora.marshalx.dev` (see [`PRIVACY.md`](PRIVACY.md)) |
| General questions | GitHub Issues / Discussions on the showcase repository |
| Last-resort fallback | `marshalgcom@gmail.com` |

---

## 12. Changes to this EULA

The Licensor may revise this EULA. Two classes of change apply:

- **Material changes** — anything that narrows the rights granted in § 2, broadens the restrictions in § 3, weakens the no-telemetry commitment in § 5.3 / § 5.4, weakens the continuity promise in § 7.4, or changes governing law in § 10. Material changes are announced on the showcase repository's release notes at least **14 days** before they take effect, and are reflected by updating the "Effective" date and the "Version" number at the top of this document. This matches TERMS § 14.
- **Cosmetic edits** — typos, formatting fixes, clarifying re-phrases that do not change rights or obligations. These are made without notice; the commit history records them.

If you reject a material change, you may continue using the version of the Software you have already installed indefinitely under the EULA in force at the time you installed that version. **Installing a new version of the Software constitutes acceptance of the EULA that ships with that version.** You are never compelled to update; you are simply asked to agree to the then-current EULA when you choose to.

---

## 13. Entire agreement

This EULA, together with the [TERMS](TERMS.md), the [PRIVACY](PRIVACY.md) policy, the [`NOTICE`](NOTICE) file, and the security disclosure policy in [`SECURITY.md`](SECURITY.md), constitutes the entire agreement between you and the Licensor in respect of the Software. Any prior agreement, oral statement, sales pitch, or marketing copy on the same subject is superseded.

No oral modification of this EULA is binding. Modifications take effect only through the process in § 12.

If any provision of this EULA is held invalid or unenforceable by a court of competent jurisdiction, the remaining provisions remain in full force and effect, and the invalid provision will be replaced by a valid provision that most closely matches the original intent.

The Licensor's failure to enforce any provision of this EULA is not a waiver of that provision or of any other provision. A waiver of any breach is not a waiver of any subsequent breach.

---

## 14. Disclaimer

This document is written in plain English and reflects the actual operating practices of Fluxora as of the effective date. It is not legal advice. If your use case has specific regulatory obligations — healthcare data, financial-services workflows, defence applications — consult a lawyer about whatever additional contract should sit alongside this EULA.

If a court interprets a provision in this EULA in a way materially different from the Licensor's drafting intent, the Licensor will update the EULA to clarify the language rather than litigate the ambiguity.
