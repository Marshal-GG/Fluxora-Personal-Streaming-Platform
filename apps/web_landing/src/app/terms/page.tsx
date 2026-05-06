import type { Metadata } from 'next'
import LegalLayout from '@/components/LegalLayout'

export const metadata: Metadata = {
  title: 'Terms of Service — Fluxora',
  description:
    'Terms governing use of the Fluxora marketing site and paid tier subscriptions (Plus, Pro, Ultimate). The self-hosted server software is MIT-licensed; see the LICENSE in the GitHub repo.',
  alternates: {
    canonical: 'https://fluxora.marshalx.dev/terms',
  },
  robots: { index: true, follow: true },
}

export default function TermsPage() {
  return (
    <LegalLayout title="Terms of Service" effectiveDate="6 May 2026">
      <p className="legal-lede">
        These Terms cover three different things, and which sections apply to you depends on which you&apos;re using: just visiting <code>fluxora.marshalx.dev</code> (sections 1, 2, 4, 13–22); running the open-source server (Free tier, plus the <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">MIT LICENSE</a>); or paying for Plus / Pro / Ultimate (all of the above plus 5–11). The MIT License governs the <strong>software</strong>; these Terms govern the <strong>service surface</strong>. The canonical version of these Terms is <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/blob/main/TERMS.md" target="_blank" rel="noopener noreferrer"><code>TERMS.md</code></a> in the GitHub repository — this rendered page mirrors it.
      </p>

      <h2>1. Acceptance</h2>
      <p>
        You accept these Terms by visiting <code>fluxora.marshalx.dev</code> (passive — by browsing, you agree), purchasing a paid tier (active — Polar&apos;s checkout requires confirmation), or using a Fluxora license key in your self-hosted server. You must be at least 18 (or the age of majority in your jurisdiction) to purchase a paid tier. The Free tier has no age requirement (we collect no data and run no account system).
      </p>

      <h2>2. Definitions</h2>
      <ul>
        <li><strong>&quot;Fluxora&quot;, &quot;we&quot;, &quot;us&quot;</strong> — the open-source project, maintained by Marshalx (portfolio at <a href="https://marshalx.dev" target="_blank" rel="noopener noreferrer">marshalx.dev</a>) as an individual operator in Delhi, India. Not a registered legal entity.</li>
        <li><strong>&quot;Site&quot;</strong> — <code>fluxora.marshalx.dev</code> and any other domain or subdomain we operate.</li>
        <li><strong>&quot;Software&quot;</strong> — the open-source code in the GitHub repository.</li>
        <li><strong>&quot;Self-Hosted Server&quot;</strong> — a Fluxora server instance running on hardware controlled by an operator (not us).</li>
        <li><strong>&quot;Free / Plus / Pro / Ultimate&quot;</strong> — the four tiers.</li>
        <li><strong>&quot;License Key&quot;</strong> — the HMAC-SHA256-signed string in the format <code>FLUXORA-&lt;TIER&gt;-&lt;EXPIRY&gt;-&lt;NONCE&gt;-&lt;SIG&gt;</code> issued after a successful Polar payment.</li>
        <li><strong>&quot;Polar&quot;</strong> — Polar.sh, the payment platform we use for paid-tier checkout (Stripe-backed).</li>
      </ul>

      <h2>3. The Free tier and the open-source software</h2>
      <p>
        The Software is open-source under the <strong>MIT License</strong>. You may run, copy, modify, redistribute, fork, and sell services around your fork — see the LICENSE file. The Free tier requires no account, no payment, no License Key, and no agreement beyond the LICENSE.
      </p>
      <p>
        Two clarifications, neither of which contradicts the MIT License:
      </p>
      <ul>
        <li><strong>Brand assets are not MIT-licensed.</strong> The &quot;Fluxora&quot; name, the F lettermark, and the gradient logos are reserved by the maintainer. If you distribute a fork or derivative product, rename it and replace the brand assets. See §10.</li>
        <li><strong>The license-key system is part of the Software</strong> and licensed under MIT. Forks may issue their own keys with their own signing secret. Generating Fluxora-formatted keys without a Polar payment, or distributing keys obtained through your fork against <code>fluxora.marshalx.dev</code>&apos;s issued keys, is not a license violation but is addressed under §6.4 (acceptable use) and §11 (termination).</li>
      </ul>

      <h2>4. The marketing site</h2>
      <p>You may not: attempt to break the site (DDoS, exploit attempts, exhaustion attacks); scrape at a rate that materially burdens the host; redistribute the site&apos;s content as your own. Linking, citing, and reasonable archival are fine. The site provides product info and links to checkout — no user accounts, no comment system, no upload surface.</p>
      <p>Finding a vulnerability and reporting it via the channel in <code>SECURITY.md</code> is <strong>not</strong> a violation — that&apos;s actively encouraged.</p>

      <h2>5. Paid tiers</h2>

      <h3>5.1 What you get</h3>
      <ul>
        <li><strong>Plus</strong> — ₹99/month. Full HLS + WebRTC internet streaming, TMDB-powered artwork, up to 3 simultaneous remote streams.</li>
        <li><strong>Pro</strong> — ₹199/month. Everything in Plus, up to 10 simultaneous remote streams, priority support.</li>
        <li><strong>Ultimate</strong> — ₹4,499 one-time, lifetime. Everything in Pro, unlimited simultaneous streams, lifetime access.</li>
      </ul>
      <p>
        The feature list at the time of your purchase is what you&apos;re entitled to. If we add features later, they roll forward to existing customers at the same tier; if we ever remove features, existing customers retain the original feature set for the duration of their subscription (or for life, in Ultimate&apos;s case).
      </p>

      <h3>5.2 What &quot;feature unlock&quot; actually means</h3>
      <p>
        Tier limits are enforced by the Self-Hosted Server reading your License Key locally. There is no online check, no usage telemetry, no rate limiting from us.
      </p>

      <h3>5.3 Billing &amp; recurrence</h3>
      <p>
        Plus and Pro are recurring monthly subscriptions billed in INR via Polar. Ultimate is a single one-time payment. Polar handles billing including local taxes (GST in India, VAT in EU, etc.); Stripe is the underlying processor. You may cancel a Plus or Pro subscription at any time via your Polar customer-portal link or by contacting us. Cancellation stops future charges. Past charges are non-refundable except as set out in §5.4.
      </p>

      <h3>5.4 Refund policy</h3>
      <p>
        <strong>First 14 days, no questions asked.</strong> File a <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues" target="_blank" rel="noopener noreferrer">GitHub Issue</a> tagged <code>refund</code> or contact Polar support directly. We will refund 100% of the most recent charge.
      </p>
      <p>
        After 14 days, refunds are at our discretion — typically only granted for billing errors (you were charged twice, etc.) or for products that materially fail to deliver as described. Ultimate refunds follow the same 14-day rule; after that, only granted if a feature you specifically purchased the tier for is permanently broken and cannot be fixed within a reasonable time.
      </p>

      <h3>5.5 License-key delivery</h3>
      <p>
        Your License Key is emailed to you within minutes of a successful Polar checkout. If it doesn&apos;t arrive in 30 minutes: check spam, visit <a href="/manage">/manage</a> to look up your order, or contact <a href="mailto:support@fluxora.marshalx.dev">support@fluxora.marshalx.dev</a> with your Polar order ID. We re-issue lost keys on request as long as the original purchase is verifiable; manual operator step, may take up to 7 days.
      </p>

      <h3>5.6 License-key obligations</h3>
      <ul>
        <li>You may install your key on as many devices as <em>you personally use</em>. Plex / Jellyfin&apos;s &quot;household&quot; model — same family, same physical residence — applies here. Trust-based; we don&apos;t enforce technically.</li>
        <li>You may not sell, lend, sub-license, or distribute your key to third parties outside your household.</li>
        <li>You may not publish your key to a public location (GitHub commit, paste site, Discord, etc.). Keys published publicly are presumed compromised and may be revoked.</li>
        <li>Revocation: if we discover a key has been distributed in violation of this section, we may revoke it.</li>
      </ul>

      <h2>6. Acceptable use</h2>
      <p>You may not use Fluxora to:</p>
      <ol>
        <li>Distribute content you do not have the right to distribute. By using the Software you affirm that the media in your library is content you own a personal copy of, content you have a license to use, or content in the public domain. We do not police this; you indemnify us if you breach it (see §8).</li>
        <li>Circumvent DRM or copy-protection on third-party media. The Software is not designed to and does not include DRM-circumvention tools.</li>
        <li>Build a multi-tenant streaming service that resells Fluxora&apos;s capabilities. The Software is licensed for self-hosted, single-tenant use. Operating a public Fluxora-as-a-Service or running a &quot;Fluxora hosting&quot; business requires a separate written agreement. Casual sharing within your household / friend group is fine and expected.</li>
        <li>Reverse-engineer the License Key system to bypass tier limits, generate counterfeit keys, modify the Software to ignore the key check, or distribute patches that do so. Specifically scoped to interactions with <code>fluxora.marshalx.dev</code>&apos;s license-issuance system.</li>
        <li>Distribute child sexual abuse material, non-consensual content, or content illegal under Indian law via the Software. Non-negotiable. We will cooperate with any law-enforcement inquiry.</li>
        <li>Harass, threaten, or impersonate other contributors or users in any Fluxora-controlled space.</li>
        <li>Submit malicious content (malware-laden uploads, phishing-link inserts in metadata fetches, etc.) targeting the Software or its operators.</li>
        <li>Use the Site or Software to send spam.</li>
      </ol>

      <h2>7. Disclaimer of warranties</h2>
      <p>
        THE SOFTWARE AND THE SITE ARE PROVIDED &quot;AS IS&quot; AND &quot;AS AVAILABLE&quot;, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND ACCURACY OF DATA.
      </p>
      <p>
        Streaming reliability is not guaranteed (WebRTC depends on your network, NAT type, ISP; mDNS depends on multicast working in your network). Hardware encoding is not guaranteed (depends on your GPU + drivers; software fallback is automatic but performance is governed by your CPU). TMDB metadata accuracy is not guaranteed (community-edited database; mismatched titles happen). <strong>Backups are your responsibility</strong> — the Software does not back up your media library or library index.
      </p>

      <h2>8. Indemnification</h2>
      <p>
        You agree to indemnify, defend, and hold harmless the maintainer, contributors, and project from any claim, demand, loss, or expense (including reasonable attorneys&apos; fees) arising from your use of the Software or Site in violation of these Terms, your violation of any third party&apos;s rights, or your violation of any law or regulation.
      </p>

      <h2>9. Limitation of liability</h2>
      <p>
        To the maximum extent permitted by law, our total cumulative liability is limited to <strong>the amount you paid us in the 12 months preceding the claim</strong>, or <strong>₹0 if you are a Free-tier user</strong>. For Ultimate purchasers, that is ₹4,499. We are not liable for indirect, consequential, special, incidental, or exemplary damages — including lost profits, business interruption, loss of data, loss of goodwill, or substitute-service costs — even if advised of the possibility.
      </p>

      <h2>10. Intellectual property</h2>
      <p>
        <strong>Software:</strong> licensed to you under the MIT License. Use, copy, modify, merge, publish, distribute, sublicense, sell.
      </p>
      <p>
        <strong>Brand:</strong> the &quot;Fluxora&quot; name and the brand assets (F lettermark, wordmark, gradient logos) are reserved by the maintainer. The MIT License does not grant rights to brand assets.
      </p>
      <p>You may use the Fluxora name to: refer to the project, link to it, write a review or article, file a bug report. You may not: brand a fork or derivative product as Fluxora (rename your fork); imply endorsement, affiliation, or partnership; register Fluxora-named domains, social handles, or trademarks. Nominative use (&quot;for Fluxora&quot;, &quot;compatible with Fluxora&quot;, &quot;Fluxora plugin&quot;) is fine for third-party integrations.</p>
      <p>
        <strong>Documentation, content, brand artwork:</strong> © Marshalx, 2026. The MIT License does not cover them. Linking, quoting, and short citations are fine; wholesale republication is not.
      </p>
      <p>
        <strong>Contributions:</strong> by submitting a PR, issue, or other contribution, you license it under the same MIT License. You retain copyright. No separate CLA.
      </p>

      <h2>11. Termination</h2>
      <p>
        <strong>Termination by you:</strong> Free tier — stop using the Software. Paid tier — cancel via Polar customer portal or contact us. License Key continues to work for the remainder of the paid period.
      </p>
      <p>
        <strong>Termination by us:</strong> for material breach of §6 (with notice + 14-day cure period if curable), for non-payment (Polar handles this automatically), or as required by law / court order. If we terminate a paid tier for breach we cannot or will not cure, we will refund the unused portion of the most recent monthly charge. Ultimate purchasers terminated for breach are not refunded.
      </p>
      <p>
        Sections 7 (warranties), 8 (indemnification), 9 (liability), 10 (IP), 17 (governing law), and 18 (disputes) survive termination.
      </p>

      <h2>12. Third-party services</h2>
      <p>
        The Software optionally integrates with third-party services. Each is governed by its own terms; using these features means you accept those: TMDB (operator-provided API key, subject to TMDB&apos;s API Terms of Use); Cloudflare (Tunnel + DNS-over-HTTPS, subject to Cloudflare&apos;s subscription agreement); Polar (paid-tier checkout, subject to Polar&apos;s ToS); Sentry (opt-in error reporting, subject to Sentry&apos;s Service Terms). We are not responsible for the availability, accuracy, or behaviour of third-party services.
      </p>

      <h2>13. Modifications to these Terms</h2>
      <p>
        Material changes will be announced on the GitHub repository at least 14 days before they take effect, and reflected by updating the &quot;Effective&quot; date at the top of this page. A material change modifies pricing for an existing tier in a way that disadvantages existing customers, removes a feature you paid for, changes refund / cancellation policy, changes governing law or jurisdiction, or reduces our commitments / increases your obligations. If you object to a material change, you may cancel your paid subscription before the change takes effect and receive a refund of the unused portion of the most recent payment.
      </p>

      <h2>14. Force majeure</h2>
      <p>
        Neither party is liable for failure or delay in performance due to causes beyond reasonable control: natural disasters, war, civil unrest, terrorism, government action, internet-infrastructure outages, third-party service outages (Cloudflare, Polar, Stripe, GitHub), pandemic-related disruption, or labour disputes.
      </p>

      <h2>15. Severability &amp; entire agreement</h2>
      <p>
        If any provision is held invalid or unenforceable, the remaining provisions remain in full force. These Terms, together with the LICENSE, PRIVACY.md, SECURITY.md, and CODE_OF_CONDUCT.md, constitute the entire agreement.
      </p>

      <h2>16. Notices &amp; assignment</h2>
      <p>
        Notices to us: <a href="mailto:legal@fluxora.marshalx.dev">legal@fluxora.marshalx.dev</a> or <a href="mailto:marshalgcom@gmail.com">marshalgcom@gmail.com</a>. Notices to you: email to the address on your Polar order, or — if no paid tier — by an update to these Terms.
      </p>
      <p>
        You may not assign these Terms or your paid-tier subscription to a third party without our written consent. We may assign in connection with a transfer of the project to a successor maintainer. If the project is discontinued, recurring charges stop, already-issued License Keys continue to function (HMAC-signed, self-validating; no upstream check), and the source remains under MIT at the GitHub repository or its mirrors.
      </p>

      <h2>17. Governing law</h2>
      <p>
        These Terms are governed by the laws of the <strong>Republic of India</strong>, without regard to conflict-of-laws principles. The Indian Contract Act, 1872, the Information Technology Act, 2000, and the Digital Personal Data Protection Act, 2023 apply where relevant.
      </p>
      <p>
        For paid-tier customers in the European Union, United Kingdom, or California, your local mandatory consumer-protection law applies in addition to Indian law and prevails to the extent of any conflict.
      </p>

      <h2>18. Dispute resolution</h2>
      <p>
        Before filing any formal dispute, contact <a href="mailto:legal@fluxora.marshalx.dev">legal@fluxora.marshalx.dev</a> and attempt to resolve informally. Most disputes settle by email within 30 days.
      </p>
      <p>If informal resolution fails:</p>
      <ul>
        <li><strong>Indian customers + Free tier worldwide:</strong> in the courts of Delhi, India.</li>
        <li><strong>EU / UK customers:</strong> at your election, in the courts of Delhi, India, or in the courts of your country of residence as required by EU consumer-protection law.</li>
        <li><strong>California customers:</strong> at your election, in the courts of Delhi, India, or in the small-claims court of your county of residence for disputes within its jurisdictional limit.</li>
      </ul>
      <p>
        To the maximum extent permitted by law, disputes will be brought individually, not as part of a class action, consolidated action, or representative proceeding.
      </p>

      <h2>19. No waiver, no agency</h2>
      <p>
        Failure to enforce any provision is not a waiver of that provision. No agency, partnership, joint venture, or employment relationship is created by these Terms.
      </p>

      <h2>20. Contact</h2>
      <ul>
        <li><strong>Question about these Terms:</strong> <a href="mailto:legal@fluxora.marshalx.dev">legal@fluxora.marshalx.dev</a></li>
        <li><strong>Refund request:</strong> <a href="mailto:legal@fluxora.marshalx.dev">legal@fluxora.marshalx.dev</a> or a <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues" target="_blank" rel="noopener noreferrer">GitHub Issue tagged <code>refund</code></a></li>
        <li><strong>License-key issue (lost / re-issue):</strong> <a href="mailto:support@fluxora.marshalx.dev">support@fluxora.marshalx.dev</a></li>
        <li><strong>Privacy / data rights:</strong> <a href="mailto:privacy@fluxora.marshalx.dev">privacy@fluxora.marshalx.dev</a> (see <a href="/privacy">Privacy Policy</a>)</li>
        <li><strong>Security vulnerability:</strong> see <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/blob/main/SECURITY.md" target="_blank" rel="noopener noreferrer"><code>SECURITY.md</code></a></li>
        <li><strong>Conduct issue:</strong> <a href="mailto:conduct@fluxora.marshalx.dev">conduct@fluxora.marshalx.dev</a></li>
        <li><strong>Anything else:</strong> <a href="mailto:marshalgcom@gmail.com">marshalgcom@gmail.com</a> (last resort)</li>
      </ul>

      <p className="legal-disclaimer">
        This document is written in plain language and reflects the actual operating practices of Fluxora as of the effective date. It is not legal advice. If you depend on Fluxora for a commercial workflow, consult a lawyer about whatever contract should sit alongside these Terms.
      </p>
    </LegalLayout>
  )
}
