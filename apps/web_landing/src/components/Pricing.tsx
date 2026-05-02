/**
 * Pricing — 4 tier cards (Free / Plus / Pro / Ultimate).
 *
 * Renamed from "Fluxora Core" → "Fluxora Free" per redesign decision §2.4.
 * Pricing in INR; checkout links from Polar's product dashboard.
 */

import TierComparison from './TierComparison'

// Checkout URLs — paste the unique links from your Polar dashboard:
//   Dashboard → Products → (Product name) → Share → Copy checkout link
// Replace each TODO_POLAR_CHECKOUT_* with the real URL before deploying.
const CHECKOUT = {
  plus:     'https://polar.sh/fluxora/checkout/plus',     // TODO: replace with real Polar checkout link for Fluxora Plus
  pro:      'https://polar.sh/fluxora/checkout/pro',      // TODO: replace with real Polar checkout link for Fluxora Pro
  ultimate: 'https://polar.sh/fluxora/checkout/ultimate', // TODO: replace with real Polar checkout link for Fluxora Ultimate
} as const

const CHECK_ICON = (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
  </svg>
)

export default function Pricing() {
  return (
    <section id="pricing" className="section">
      <div className="section-header">
        <p className="section-label">Pricing</p>
        <h2 className="section-title">Simple, fair pricing.</h2>
        <p className="section-desc">
          Start completely free. Upgrade when you want internet streaming, hardware encoding, or more concurrent devices. Your library lives on your hardware regardless of plan.
        </p>
      </div>

      <div className="pricing-grid">

        {/* Free */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Fluxora Free</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>0
            <span className="pricing-period">/forever</span>
          </div>
          <p className="pricing-desc">
            The full self-hosted experience. 100% open-source server, all clients. Yours forever.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Local LAN streaming</li>
            <li className="pricing-feature">{CHECK_ICON}All client apps included</li>
            <li className="pricing-feature">{CHECK_ICON}TMDB metadata &amp; artwork</li>
            <li className="pricing-feature">{CHECK_ICON}Community support</li>
          </ul>
          <a
            href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-secondary pricing-action"
          >
            Get the source
          </a>
        </div>

        {/* Plus */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Fluxora Plus</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>99
            <span className="pricing-period">/mo</span>
          </div>
          <p className="pricing-desc">
            For households. Stream from anywhere over the internet, with up to 3 simultaneous remote viewers.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Everything in Free</li>
            <li className="pricing-feature">{CHECK_ICON}HLS + WebRTC internet streaming</li>
            <li className="pricing-feature">{CHECK_ICON}3 simultaneous remote streams</li>
            <li className="pricing-feature">{CHECK_ICON}Mobile offline downloads</li>
            <li className="pricing-feature">{CHECK_ICON}Advanced user roles</li>
          </ul>
          <a href={CHECKOUT.plus} className="btn btn-secondary pricing-action">
            Get Plus
          </a>
          <div className="pricing-compare">Cancel any time. Server keeps running.</div>
        </div>

        {/* Pro — featured */}
        <div className="pricing-card featured">
          <div className="pricing-badge">Most Popular</div>
          <h3 className="pricing-tier">Fluxora Pro</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>199
            <span className="pricing-period">/mo</span>
          </div>
          <p className="pricing-desc">
            For power users. Hardware transcoding, 10 concurrent streams, priority support — all in.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Everything in Plus</li>
            <li className="pricing-feature">{CHECK_ICON}10 simultaneous remote streams</li>
            <li className="pricing-feature">{CHECK_ICON}Hardware transcoding (NVENC / QSV / VAAPI)</li>
            <li className="pricing-feature">{CHECK_ICON}Client groups &amp; restrictions</li>
            <li className="pricing-feature">{CHECK_ICON}Priority support</li>
          </ul>
          <a href={CHECKOUT.pro} className="btn btn-primary pricing-action">
            Get Pro
          </a>
        </div>

        {/* Ultimate */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Fluxora Ultimate</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>4,499
            <span className="pricing-period">/lifetime</span>
          </div>
          <p className="pricing-desc">
            One payment, lifetime access. Unlimited streams, every future feature, every future version.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Everything in Pro</li>
            <li className="pricing-feature">{CHECK_ICON}Unlimited simultaneous streams</li>
            <li className="pricing-feature">{CHECK_ICON}Lifetime access — no renewals, ever</li>
            <li className="pricing-feature">{CHECK_ICON}Early access to beta features</li>
          </ul>
          <a href={CHECKOUT.ultimate} className="btn btn-secondary pricing-action">
            Get Lifetime
          </a>
          <div className="pricing-compare">One payment. Forever yours.</div>
        </div>

      </div>

      <TierComparison />
    </section>
  )
}
