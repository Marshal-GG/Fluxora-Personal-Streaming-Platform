import type { Metadata } from 'next'
import LegalLayout from '@/components/LegalLayout'

export const metadata: Metadata = {
  title: 'Terms of Service — Fluxora',
  description:
    'Terms governing use of the Fluxora marketing site and paid tier subscriptions. The self-hosted server itself is MIT-licensed; see LICENSE in the GitHub repo.',
  alternates: {
    canonical: 'https://fluxora.marshalx.dev/terms',
  },
  robots: { index: true, follow: true },
}

export default function TermsPage() {
  return (
    <LegalLayout title="Terms of Service" effectiveDate="2 May 2026">
      <p className="legal-lede">
        These terms cover use of the Fluxora marketing site (<code>fluxora.marshalx.dev</code>) and the Fluxora paid subscription tiers (Plus, Pro, Ultimate). The self-hosted Fluxora server software is governed by the MIT License — see the <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">LICENSE file</a> in the repository.
      </p>

      <h2>1. Acceptance</h2>
      <p>
        By using this site or purchasing a paid tier, you agree to these terms. If you do not agree, do not use the site or purchase a tier.
      </p>

      <h2>2. The free tier and the open-source server</h2>
      <p>
        The Fluxora server source code is open-source under the MIT License. You may use, copy, modify, and redistribute the source under the terms of that license. The Free tier ("Fluxora Free") requires no account, no payment, and no agreement beyond the MIT License.
      </p>

      <h2>3. Paid tiers</h2>

      <h3>3.1 What you get</h3>
      <p>
        Plus, Pro, and Ultimate unlock additional capabilities (internet streaming via WebRTC, hardware transcoding, additional concurrent streams, etc.) via a license key issued after payment. The list of features per tier is shown on the <a href="/#pricing">pricing page</a>; the feature list at the time of purchase is what you&apos;re entitled to.
      </p>

      <h3>3.2 Billing &amp; recurrence</h3>
      <p>
        Plus and Pro are billed monthly via Polar. Ultimate is a one-time payment for lifetime access. Currency is INR. You may cancel a recurring subscription at any time via your Polar customer-portal link or by contacting us; cancellation stops future charges, but past charges are non-refundable except in the cases below.
      </p>

      <h3>3.3 Refunds</h3>
      <p>
        We offer a full refund within 14 days of the original purchase, no questions asked. After 14 days, refunds are at our discretion — typically only for billing errors or products that fail to deliver as described. To request a refund, file a <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues" target="_blank" rel="noopener noreferrer">GitHub Issue</a> tagged <code>refund</code> or contact Polar support directly.
      </p>

      <h3>3.4 License keys</h3>
      <p>
        License keys are personal and tied to your purchase. Sharing keys with third parties violates these terms; we may revoke a shared key. If you lose a key, contact us with your purchase confirmation and we will re-issue.
      </p>

      <h2>4. Acceptable use</h2>
      <p>
        You may not use Fluxora to: distribute content you do not have the right to distribute; circumvent DRM or copy-protection on third-party media; build a service that resells Fluxora capabilities without our written agreement; reverse-engineer the license-key system to bypass tier limits.
      </p>

      <h2>5. Disclaimer of warranties</h2>
      <p>
        Fluxora is provided "AS IS", without warranty of any kind, express or implied, including but not limited to merchantability, fitness for a particular purpose, and non-infringement. In particular: streaming over the internet via WebRTC depends on your network and is not guaranteed to work in all environments.
      </p>

      <h2>6. Limitation of liability</h2>
      <p>
        To the maximum extent permitted by law, Fluxora&apos;s total liability arising from or related to these terms is limited to the amount you paid in the 12 months preceding the claim (₹0 for Free tier users). We are not liable for indirect, consequential, or special damages, including lost profits, data loss, or business interruption.
      </p>

      <h2>7. Termination</h2>
      <p>
        You may stop using Fluxora at any time. We may terminate paid tier access for breach of section 4 (acceptable use) with notice; in such cases we will refund the unused portion of any active monthly subscription.
      </p>

      <h2>8. Governing law</h2>
      <p>
        These terms are governed by the laws of India. Disputes will be resolved in the courts of Maharashtra, India.
      </p>

      <h2>9. Changes to these terms</h2>
      <p>
        Material changes will be announced on the GitHub repository at least 14 days before they take effect. Continued use of paid tiers after that period constitutes acceptance.
      </p>

      <h2>10. Contact</h2>
      <p>
        File a <a href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues" target="_blank" rel="noopener noreferrer">GitHub Issue</a> tagged <code>terms</code>.
      </p>

      <p className="legal-disclaimer">
        This document is provided in good faith and reviewed periodically; it is not legal advice. If you depend on Fluxora for a commercial workflow, consult a lawyer for any contract that should sit alongside these terms.
      </p>
    </LegalLayout>
  )
}
