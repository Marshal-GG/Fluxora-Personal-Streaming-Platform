import type { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Manage Subscription — Fluxora',
  description:
    'Access your Fluxora Plus, Pro, or Ultimate subscription — view billing history, update payment methods, or cancel at any time.',
  alternates: {
    canonical: 'https://fluxora.marshalx.dev/manage',
  },
}

export default function ManagePage() {
  return (
    <main style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '2rem' }}>

      {/* Back link */}
      <Link href="/" className="manage-back-link">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M19 12H5M12 5l-7 7 7 7" />
        </svg>
        Back to Fluxora
      </Link>

      <div className="manage-card">
        {/* Icon */}
        <div className="manage-icon-wrap" aria-hidden="true">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="1" y="4" width="22" height="16" rx="2" ry="2" />
            <line x1="1" y1="10" x2="23" y2="10" />
          </svg>
        </div>

        <h1 className="manage-title">Manage Subscription</h1>
        <p className="manage-desc">
          Your Fluxora subscription is managed securely through{' '}
          <a href="https://polar.sh" target="_blank" rel="noopener noreferrer" className="manage-inline-link">Polar.sh</a>.
          Use the portal below to view invoices, update your payment method, or cancel your plan.
        </p>

        {/* Tier overview */}
        <div className="manage-tiers">
          <div className="manage-tier-row">
            <span className="manage-tier-badge manage-tier-plus">Plus</span>
            <span className="manage-tier-price">₹99 / month</span>
            <span className="manage-tier-detail">3 simultaneous streams · HLS + WebRTC internet streaming</span>
          </div>
          <div className="manage-tier-row">
            <span className="manage-tier-badge manage-tier-pro">Pro</span>
            <span className="manage-tier-price">₹199 / month</span>
            <span className="manage-tier-detail">10 simultaneous streams · Priority support</span>
          </div>
          <div className="manage-tier-row">
            <span className="manage-tier-badge manage-tier-ultimate">Ultimate</span>
            <span className="manage-tier-price">₹4,499 once</span>
            <span className="manage-tier-detail">Unlimited streams · Lifetime access · No renewals</span>
          </div>
        </div>

        {/* CTA */}
        <a
          href="https://polar.sh/fluxora/portal"
          target="_blank"
          rel="noopener noreferrer"
          id="manage-portal-link"
          className="btn btn-primary btn-lg manage-cta"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6" />
            <polyline points="15 3 21 3 21 9" />
            <line x1="10" y1="14" x2="21" y2="3" />
          </svg>
          Open Billing Portal
        </a>

        <p className="manage-note">
          You will be redirected to Polar.sh, our payment processor.
          No Fluxora account is required — sign in with the email you used at checkout.
        </p>
      </div>

      {/* Activate section */}
      <div className="manage-activate">
        <h2 className="manage-activate-title">Already have a license key?</h2>
        <p className="manage-activate-desc">
          Open the <strong>Fluxora Desktop Control Panel</strong> → <strong>Settings</strong> → <strong>License</strong> and paste your key to activate your tier.
          The key was emailed to you after purchase. Check your spam folder if you did not receive it, or contact{' '}
          <a href="mailto:support@fluxora.dev" className="manage-inline-link">support@fluxora.dev</a>.
        </p>
        <Link href="/success" className="btn btn-secondary manage-activate-link">
          View activation guide
        </Link>
      </div>

    </main>
  )
}
