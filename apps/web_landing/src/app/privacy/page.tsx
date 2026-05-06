import type { Metadata } from 'next'
import LegalLayout from '@/components/LegalLayout'

export const metadata: Metadata = {
  title: 'Privacy Policy — Fluxora',
  description:
    'How Fluxora handles personal data. The marketing site uses no analytics or cookies. The self-hosted server keeps your media, library index, and pairing tokens on your hardware. Polar processes payment data only.',
  alternates: {
    canonical: 'https://fluxora.marshalx.dev/privacy',
  },
  robots: { index: true, follow: true },
}

export default function PrivacyPage() {
  return (
    <LegalLayout title="Privacy Policy" effectiveDate="6 May 2026">
      <p className="legal-lede">
        Fluxora is a <strong>self-hosted</strong> media streaming product. Most of what people call &quot;user data&quot; in a typical SaaS context — your media files, library index, watch history, paired-device tokens, preferences — lives on hardware <em>you own and control</em>. None of it touches Fluxora-controlled systems. This page covers the narrow surface where data does flow through systems we control: the marketing site, the paid-tier purchase + license-delivery path (which routes through Polar), and any opt-in integrations the operator turns on.
      </p>

      <p>
        This policy is written under and complies with the spirit of the EU <strong>General Data Protection Regulation</strong> (GDPR), the <strong>California Consumer Privacy Act / CPRA</strong>, and India&apos;s <strong>Digital Personal Data Protection Act, 2023</strong>. The canonical version of this policy is the <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/blob/main/PRIVACY.md" target="_blank" rel="noopener noreferrer"><code>PRIVACY.md</code></a> file in the GitHub repository — this rendered page mirrors it.
      </p>

      <h2>1. Who is responsible for your data</h2>
      <p>
        <strong>Maintainer / data controller:</strong> Marshalx (portfolio at <a href="https://marshalx.dev" target="_blank" rel="noopener noreferrer">marshalx.dev</a>), individual operator, Delhi, India. GitHub <code>@Marshal-GG</code>.
      </p>
      <p>
        Fluxora is not a registered legal entity. There is no Data Protection Officer — the maintainer reads every privacy email personally. For data the operator collects on their own self-hosted server: <strong>the operator is the controller</strong> of any data their paired clients send to their server. We provide the software; we are not a controller or processor of an operator&apos;s media library.
      </p>

      <h2>2. What data we actually collect</h2>
      <p>This list is exhaustive. If a category isn&apos;t here, we don&apos;t collect it.</p>

      <h3>2.1 Marketing site (<code>fluxora.marshalx.dev</code>)</h3>
      <p>
        The marketing site is a static export served by <strong>Cloudflare Pages</strong>. It runs no analytics, sets no cookies, embeds no tracking pixels, includes no third-party JavaScript beyond what Next.js statically inlines. Cloudflare may collect standard request metadata on our behalf for platform operations and DDoS protection: IP address, user-agent, timestamp, request method/path, HTTP referrer. We never see this in identifiable form. See <a href="https://www.cloudflare.com/privacypolicy/" target="_blank" rel="noopener noreferrer">Cloudflare&apos;s privacy policy</a>.
      </p>
      <p>
        We do <strong>not</strong> receive Cloudflare Analytics. We do not log IPs server-side. We do not store anything keyed to a visitor identity from this site.
      </p>

      <h3>2.2 Paid-tier purchases (Polar)</h3>
      <p>
        Plus, Pro, and Ultimate purchases are processed by <a href="https://polar.sh" target="_blank" rel="noopener noreferrer">Polar</a> (Stripe-backed). Polar collects: your email, billing address (for tax compliance — GST in India, sales tax / VAT elsewhere), payment-method details, the Polar order ID, the items purchased. <strong>Card details never touch Fluxora.</strong> See <a href="https://polar.sh/legal/privacy" target="_blank" rel="noopener noreferrer">Polar&apos;s privacy policy</a>.
      </p>
      <p>
        Polar shares back to Fluxora&apos;s webhook only: the Polar order ID, your email address, the product purchased (which maps to a tier), the order timestamp.
      </p>
      <p>
        Fluxora stores in our <code>polar_orders</code> table:
      </p>
      <ul>
        <li><strong><code>order_id</code></strong> — for idempotency (prevents double-issuing on webhook retry)</li>
        <li><strong><code>customer_email</code></strong> — solely to re-issue a license key if you lose it</li>
        <li><strong><code>tier</code></strong> — the tier associated with your purchase</li>
        <li><strong><code>license_key</code></strong> — the HMAC-signed key we generated and emailed you</li>
        <li><strong><code>processed_at</code></strong> — audit + duplicate detection</li>
      </ul>
      <p>
        We do <strong>not</strong> store: card numbers, CVV, billing addresses, IP addresses, payment-method tokens, or Polar customer IDs beyond the order ID. We do <strong>not</strong> market to you. There is no opt-in marketing list, no newsletter, no unsolicited mail.
      </p>

      <h3>2.3 The self-hosted server (operator side)</h3>
      <p>
        This is informational — it describes data <em>on your own hardware that we never see</em>. The Fluxora server stores in its local SQLite database: your media library index, paired client records (HMAC-hashed bearer tokens, never plaintext), stream-session history, operator settings (server name, transcoding preferences, optional TMDB API key, optional license key), and notifications generated by your server.
      </p>
      <p>
        <strong>None of this leaves your hardware unless you explicitly opt in.</strong> Specifically: pairing requests + token issuance never touch us; LAN streaming never touches us; WebRTC P2P streaming is between your devices and your server (we never proxy); Cloudflare Tunnel HLS segments are blocked at the public ingress so media stays LAN-only.
      </p>

      <h3>2.4 Third-party services your server may contact</h3>
      <p>
        The operator&apos;s server may contact these depending on configuration: TMDB (when an API key is set, for poster art + metadata — sends only the file&apos;s cleaned title); the operator&apos;s own Cloudflare Worker proxy for TMDB (when configured to bypass ISP-level blocks); Cloudflare DoH at <code>1.1.1.1/dns-query</code> (to resolve TMDB hosts past hijacked DNS); Cloudflare CIDR-range refresh on startup. We do not insert telemetry beyond these. There is no &quot;phone home&quot; check.
      </p>

      <h3>2.5 Sentry error reporting (opt-in)</h3>
      <p>
        If the operator sets <code>FLUXORA_SENTRY_DSN</code> to <em>their own</em> Sentry project&apos;s DSN, unhandled exceptions on the server are sent there. Bearer tokens, license keys, file paths under <code>~</code>, customer emails, and TMDB API keys are scrubbed before send. The DSN belongs to the operator. We do not run a Sentry project that aggregates everyone&apos;s errors. <strong>Off by default.</strong>
      </p>

      <h2>3. What we explicitly do not do</h2>
      <p>This is not boilerplate — these are the specific behaviours we&apos;ve decided not to engage in:</p>
      <ul>
        <li>No third-party analytics (Google Analytics, Plausible, Fathom, Amplitude, Mixpanel, Heap, Posthog, etc.) on the marketing site or the desktop / mobile clients.</li>
        <li>No behavioural cookies on the marketing site. Polar&apos;s checkout sets its own session cookies during payment — those are scoped to <code>polar.sh</code>, not us.</li>
        <li>No fingerprinting. No canvas, font, WebGL, or audio fingerprinting.</li>
        <li>No cross-site trackers, pixels, or beacons.</li>
        <li>No &quot;phone home&quot; telemetry from server, mobile, or desktop. No heartbeat, no update-check ping.</li>
        <li>No data sales, sharing, or rentals. We have not entered any data-sharing agreement.</li>
        <li>No advertising. No ad networks, no sponsored content.</li>
        <li>No use of your media library content for any purpose. We have no access to it.</li>
        <li>No marketing emails. The only mail we&apos;ll ever send a customer is the license-key delivery (and a single re-issue if you ask).</li>
        <li>No machine-learning training on customer data.</li>
        <li>No account creation requirement for the Free tier.</li>
      </ul>

      <h2>4. Cookies &amp; local storage</h2>
      <p>
        <strong>Marketing site:</strong> zero cookies, zero <code>localStorage</code> / <code>sessionStorage</code> writes. Inspect with DevTools to confirm.
      </p>
      <p>
        <strong>Polar checkout</strong> (third-party iframe / redirect): Polar sets its own session, fraud-detection, and post-payment redirect cookies. Scoped to <code>polar.sh</code> and <code>*.stripe.com</code>, not to <code>fluxora.marshalx.dev</code>. Lifecycle governed by <a href="https://polar.sh/legal/privacy" target="_blank" rel="noopener noreferrer">Polar&apos;s cookie policy</a>.
      </p>
      <p>
        <strong>Self-hosted server:</strong> uses HMAC-SHA256-hashed bearer tokens and opaque session identifiers in <code>flutter_secure_storage</code> on paired clients. These are functional credentials, not tracking cookies — scoped to your server, never sent to us.
      </p>

      <h2>5. Data retention</h2>
      <ul>
        <li><strong>Marketing site logs</strong> (Cloudflare Pages): per Cloudflare&apos;s standard retention. We do not export or aggregate.</li>
        <li><strong><code>polar_orders</code> table</strong> (license key + email): indefinite while the maintainer continues to operate. Deleted on request — see §7.</li>
        <li><strong>Polar&apos;s own customer record:</strong> per Polar&apos;s policy. They retain payment records as long as required by Indian / EU / US tax law (typically 7 years for invoicing).</li>
        <li><strong>Sentry error reports</strong> (if you opted in): per your project&apos;s retention setting. The maintainer has no access.</li>
      </ul>
      <p>
        If the maintainer ever ceases to operate, the customer-email + license-key table will be deleted within 90 days. Your already-issued license key continues to work — it&apos;s a self-contained HMAC-signed token, not a database lookup.
      </p>

      <h2>6. Data security</h2>
      <p>Real implementations, not aspirational:</p>
      <ul>
        <li><strong>License-key signing key</strong> stored in <code>~/.fluxora/config.json</code> with file-system permissions; never logged. Validation is local.</li>
        <li><strong>Bearer-token storage</strong> uses HMAC-SHA256 hashes only. The raw token is shown to the client once and never recoverable.</li>
        <li><strong>Polar webhook verification</strong> uses Standard-Webhooks signatures. Replay attacks are prevented by an idempotency table on <code>order_id</code>.</li>
        <li><strong>Admin endpoints</strong> are localhost-only; tunneled requests carrying <code>CF-Connecting-IP</code> are rejected even from loopback.</li>
        <li><strong>HLS media segments</strong> are blocked on the public Cloudflare Tunnel ingress — your media never traverses the public internet via the tunnel.</li>
        <li><strong>Logs are scrubbed</strong> of bearer tokens, license keys, customer emails, and home-directory file paths.</li>
      </ul>
      <p>
        Marketing site: TLS 1.2+ enforced by Cloudflare Pages, HSTS preloaded, no mixed content, no third-party JS.
      </p>
      <p>
        Paid-tier delivery: Polar / Stripe handle all PCI-scope. Card details never touch our infrastructure.
      </p>
      <p>
        Found a vulnerability? See <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/blob/main/SECURITY.md" target="_blank" rel="noopener noreferrer"><code>SECURITY.md</code></a>.
      </p>

      <h2>7. Your rights</h2>
      <p>These rights apply globally; the legal basis varies by jurisdiction (GDPR for EU/UK, CPRA for California, DPDP Act for India). Where the law gives you a stronger right, that one applies.</p>
      <ul>
        <li><strong>Access</strong> — get a copy of any data we hold about you.</li>
        <li><strong>Correction</strong> — fix incorrect data (typo in email, etc.).</li>
        <li><strong>Deletion</strong> — have your data deleted within 30 days. Your license key remains valid (HMAC-signed, not DB-looked-up).</li>
        <li><strong>Portability</strong> — receive a JSON export.</li>
        <li><strong>Objection / restriction</strong> — stop or limit processing.</li>
        <li><strong>Withdraw consent</strong> — the only optional processing is your operator-side Sentry opt-in, which you revoke by unsetting <code>FLUXORA_SENTRY_DSN</code>.</li>
        <li><strong>Lodge a complaint</strong> — with your local DPA (EU), the ICO (UK), the Data Protection Board (India), or the CPPA (California).</li>
      </ul>
      <p>
        Exercise rights via <code>privacy@fluxora.marshalx.dev</code>. We respond within 30 days, usually much sooner. We will not retaliate for a rights request.
      </p>

      <h2>8. Children&apos;s privacy</h2>
      <p>
        Fluxora is not directed at children under 13 (or the equivalent age of digital consent in your jurisdiction). The Free tier requires no account and no age verification, so we collect nothing from children any more than from adults; the paid-tier path inherits Polar&apos;s age requirements. If you are a parent and discover your child has purchased a paid tier on a card you control, contact us — refund and deletion guaranteed.
      </p>

      <h2>9. International transfers</h2>
      <p>
        Data flows in the paid-tier path: visitor browser → Cloudflare edge (anycast, global) → Polar checkout (US-based via Stripe) → Fluxora server (maintainer&apos;s machine in Delhi, India). EU/UK data is processed under standard contractual clauses where applicable. India: governed by the DPDP Act, 2023, with the maintainer as data fiduciary.
      </p>

      <h2>10. Changes to this policy</h2>
      <p>
        Material changes will be announced on the GitHub repository at least 14 days before they take effect, and reflected by updating the &quot;Effective&quot; date at the top of this page. A material change adds a data category, adds a third-party processor, changes retention, or reduces your rights / our commitments. Cosmetic edits don&apos;t reset that clock.
      </p>

      <h2>11. Contact</h2>
      <ul>
        <li><strong>Privacy rights request:</strong> <a href="mailto:privacy@fluxora.marshalx.dev">privacy@fluxora.marshalx.dev</a></li>
        <li><strong>Security vulnerability:</strong> see <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/blob/main/SECURITY.md" target="_blank" rel="noopener noreferrer"><code>SECURITY.md</code></a></li>
        <li><strong>General questions:</strong> <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/discussions" target="_blank" rel="noopener noreferrer">GitHub Discussion</a> tagged <code>privacy</code></li>
        <li><strong>Escalation if your request was mishandled:</strong> <a href="mailto:marshalgcom@gmail.com">marshalgcom@gmail.com</a></li>
      </ul>

      <p className="legal-disclaimer">
        This policy describes Fluxora&apos;s actual data practices in plain language. It is not a legal opinion or contract drafted by counsel. If you spot something here that&apos;s wrong (a service we no longer use, a flow that&apos;s deprecated), file an issue. Privacy claims that don&apos;t match implementation are bugs; we treat them as such.
      </p>
    </LegalLayout>
  )
}
