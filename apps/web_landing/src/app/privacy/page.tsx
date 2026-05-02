import type { Metadata } from 'next'
import LegalLayout from '@/components/LegalLayout'

export const metadata: Metadata = {
  title: 'Privacy Policy — Fluxora',
  description:
    'How Fluxora handles personal data. Marketing site uses no tracking. Self-hosted server keeps your media on your hardware. Polar processes payment data only.',
  alternates: {
    canonical: 'https://fluxora.marshalx.dev/privacy',
  },
  robots: { index: true, follow: true },
}

export default function PrivacyPage() {
  return (
    <LegalLayout title="Privacy Policy" effectiveDate="2 May 2026">
      <p className="legal-lede">
        Fluxora is a self-hosted media streaming product. Most "user data" in a typical SaaS sense doesn&apos;t exist here — your media, library index, watch history, and pairing tokens all live on hardware you own and never touch us. This page covers the narrow surface where data does flow through Fluxora-controlled systems: this marketing website, and the payment + license-delivery path for paid tiers.
      </p>

      <h2>1. Data we collect</h2>

      <h3>1.1 The marketing site (<code>fluxora.marshalx.dev</code>)</h3>
      <p>
        This site is a static export served via Cloudflare Pages. We do not run analytics, do not use third-party cookies, and do not embed tracking pixels. Cloudflare may collect standard request metadata (IP address, user agent, request timestamp) for platform operations and DDoS protection — see Cloudflare&apos;s own privacy policy. We never see this data in identifiable form.
      </p>

      <h3>1.2 Paid tier purchases (Polar.sh)</h3>
      <p>
        Plus, Pro, and Ultimate purchases are processed by <a href="https://polar.sh" target="_blank" rel="noopener noreferrer">Polar</a>, a Stripe-backed payment platform. When you pay, Polar collects: your email address, billing details, and the items purchased. Polar shares an anonymised order ID and your email back to Fluxora so we can issue your license key.
      </p>
      <p>
        Fluxora stores the resulting <strong>license key</strong> and <strong>customer email</strong> in our backend solely for support purposes (re-issuing a key if you lose it). We do not store payment details. We do not market to you. Card numbers and address details live with Polar / Stripe, not us.
      </p>

      <h3>1.3 The self-hosted server (when you install it)</h3>
      <p>
        The Fluxora server runs on your hardware. It indexes your local media, talks to <a href="https://www.themoviedb.org" target="_blank" rel="noopener noreferrer">TMDB</a> for poster artwork and metadata (sending only the file name / title), and accepts pairing requests from your devices. None of this data leaves your hardware unless <em>you</em> initiate it (e.g. by enabling internet streaming, which sends your stream over WebRTC to your own paired devices).
      </p>
      <p>
        Optional integrations that <em>do</em> involve external services: TMDB metadata fetch (your network → TMDB), and <a href="https://sentry.io" target="_blank" rel="noopener noreferrer">Sentry</a> error reporting if you enable it (off by default).
      </p>

      <h2>2. What we do not do</h2>
      <ul>
        <li>We do not run third-party analytics or behavioural tracking</li>
        <li>We do not sell, share, or rent any user data</li>
        <li>We do not use your media library content for any purpose</li>
        <li>We do not build profiles of users for marketing</li>
        <li>We do not require account creation to use the Free tier</li>
      </ul>

      <h2>3. Cookies</h2>
      <p>
        The marketing site uses <strong>no cookies</strong>. Polar&apos;s checkout pages set their own cookies during the payment flow — see Polar&apos;s cookie policy.
      </p>

      <h2>4. Your rights (GDPR / DPDP Act)</h2>
      <p>
        Even though our data footprint is small, you have the right to: request a copy of any data we hold about you, request deletion of any data we hold, and lodge a complaint with your local data-protection authority. Contact us through GitHub Issues or Discussions to exercise any right.
      </p>
      <p>
        Indian users: this product complies with the spirit of the Digital Personal Data Protection Act, 2023. We&apos;re a small project — if any provision applies and we&apos;ve missed it, file a GitHub issue and we&apos;ll fix it.
      </p>

      <h2>5. Children</h2>
      <p>
        Fluxora is not directed at children under 13. The Free tier requires no account so no age verification happens; if you are a parent and your child has installed Fluxora, no data flows to us anyway.
      </p>

      <h2>6. Changes to this policy</h2>
      <p>
        Material changes will be announced on the GitHub repository at least 14 days before they take effect. The "Effective" date at the top of this page reflects the current version.
      </p>

      <h2>7. Contact</h2>
      <p>
        File a <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues" target="_blank" rel="noopener noreferrer">GitHub Issue</a> tagged <code>privacy</code> or open a <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/discussions" target="_blank" rel="noopener noreferrer">Discussion</a>. The maintainer is the only person who reads these.
      </p>

      <p className="legal-disclaimer">
        This document is provided in good faith and reviewed periodically; it is not legal advice. If you operate a Fluxora server commercially, consult a lawyer for jurisdiction-specific obligations.
      </p>
    </LegalLayout>
  )
}
