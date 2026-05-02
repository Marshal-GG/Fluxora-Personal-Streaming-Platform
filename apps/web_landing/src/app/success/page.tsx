import type { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Purchase Successful — Fluxora',
  description:
    'Thanks for supporting Fluxora. Your license key is on its way to your inbox; open the desktop control panel to activate.',
  alternates: { canonical: 'https://fluxora.marshalx.dev/success' },
  robots: { index: false, follow: false },
}

const Check = () => (
  <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <polyline points="20 6 9 17 4 12" />
  </svg>
)

export default function SuccessPage() {
  return (
    <main style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '2rem' }}>
      <div className="manage-card">
        <div className="manage-icon-wrap" aria-hidden="true">
          <Check />
        </div>

        <div>
          <h1 className="manage-title">Purchase successful</h1>
          <p className="manage-desc" style={{ marginTop: '0.75rem' }}>
            Thanks for supporting Fluxora. Your payment has been processed and the license key is on its way to your inbox.
          </p>
        </div>

        <div className="manage-tiers" aria-label="Activation steps">
          <div className="manage-tier-row">
            <span className="manage-tier-badge manage-tier-plus">1</span>
            <span className="manage-tier-detail">Check your email inbox for your <strong style={{ color: 'var(--text-bright)' }}>license key</strong>.</span>
          </div>
          <div className="manage-tier-row">
            <span className="manage-tier-badge manage-tier-plus">2</span>
            <span className="manage-tier-detail">Open the <strong style={{ color: 'var(--text-bright)' }}>Fluxora desktop control panel</strong>.</span>
          </div>
          <div className="manage-tier-row">
            <span className="manage-tier-badge manage-tier-plus">3</span>
            <span className="manage-tier-detail">Go to <strong style={{ color: 'var(--text-bright)' }}>Settings → License</strong> and paste your key.</span>
          </div>
          <div className="manage-tier-row">
            <span className="manage-tier-badge manage-tier-plus">4</span>
            <span className="manage-tier-detail">Enjoy your upgraded streaming experience.</span>
          </div>
        </div>

        <Link href="/" className="btn btn-primary btn-lg manage-cta">
          Back to Fluxora
        </Link>

        <p className="manage-note">
          Didn&apos;t receive an email within a few minutes? Check your spam folder, or open a{' '}
          <a
            href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues"
            target="_blank"
            rel="noopener noreferrer"
            className="manage-inline-link"
          >
            GitHub issue
          </a>{' '}
          and we&apos;ll re-issue the key.
        </p>
      </div>
    </main>
  )
}
