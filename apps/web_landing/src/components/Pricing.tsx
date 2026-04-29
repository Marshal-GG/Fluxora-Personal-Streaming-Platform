// Checkout URLs — paste the unique links from your Polar dashboard:
//   Dashboard → Products → (Product name) → Share → Copy checkout link
// Replace each TODO_POLAR_CHECKOUT_* with the real URL before deploying.
const CHECKOUT = {
  plus: 'https://polar.sh/fluxora/checkout/plus',      // TODO: replace with real Polar checkout link for Fluxora Plus
  pro: 'https://polar.sh/fluxora/checkout/pro',        // TODO: replace with real Polar checkout link for Fluxora Pro
  ultimate: 'https://polar.sh/fluxora/checkout/ultimate', // TODO: replace with real Polar checkout link for Fluxora Ultimate
} as const

const CHECK_ICON = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
  </svg>
)

export default function Pricing() {
  return (
    <section id="pricing" className="section">
      <div className="section-header">
        <div className="section-label">Pricing</div>
        <h2 className="section-title">Simple, transparent pricing</h2>
        <p className="section-desc">
          Self-host for free forever, or upgrade to unlock premium features and support development. Priced fairly for the Indian market.
        </p>
      </div>

      <div className="pricing-grid">

        {/* Core (Free) */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Fluxora Core</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>0
            <span className="pricing-period">/forever</span>
          </div>
          <p className="pricing-desc">
            The core self-hosted experience. 100% free and open source.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Local LAN streaming</li>
            <li className="pricing-feature">{CHECK_ICON}All client apps included</li>
            <li className="pricing-feature">{CHECK_ICON}TMDB metadata &amp; artwork</li>
            <li className="pricing-feature">{CHECK_ICON}Community support</li>
          </ul>
          <a href="#platforms" className="btn btn-secondary pricing-action">
            Download Now
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
            Perfect for home use. HLS + WebRTC internet streaming, up to 3 simultaneous remote streams.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Everything in Core</li>
            <li className="pricing-feature">{CHECK_ICON}HLS + WebRTC internet streaming</li>
            <li className="pricing-feature">{CHECK_ICON}3 simultaneous remote streams</li>
            <li className="pricing-feature">{CHECK_ICON}Mobile offline downloads</li>
            <li className="pricing-feature">{CHECK_ICON}Advanced user roles</li>
          </ul>
          <a href={CHECKOUT.plus} className="btn btn-secondary pricing-action">
            Get Plus
          </a>
          <div className="pricing-compare">Compare to Plex: ~₹399/mo</div>
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
            Scaled up for power users. Everything in Plus, upgraded to 10 simultaneous remote streams.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Everything in Plus</li>
            <li className="pricing-feature">{CHECK_ICON}10 simultaneous remote streams</li>
            <li className="pricing-feature">{CHECK_ICON}10 concurrent hardware transcodes</li>
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
            <span className="pricing-period">/once</span>
          </div>
          <p className="pricing-desc">
            The ultimate self-hosted experience. Unlimited simultaneous streams, lifetime access, no renewals ever.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK_ICON}Everything in Pro</li>
            <li className="pricing-feature">{CHECK_ICON}Unlimited simultaneous streams</li>
            <li className="pricing-feature">{CHECK_ICON}Lifetime access — one-time payment</li>
            <li className="pricing-feature">{CHECK_ICON}Early access to beta features</li>
          </ul>
          <a href={CHECKOUT.ultimate} className="btn btn-secondary pricing-action">
            Get Lifetime
          </a>
          <div className="pricing-compare">Compare to Plex: ~₹9,999 once</div>
        </div>

      </div>
    </section>
  )
}
