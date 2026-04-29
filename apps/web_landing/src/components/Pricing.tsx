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
        {/* Basic Plan (Free) */}
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
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Unlimited personal streaming
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              All client apps included
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Community support
            </li>
          </ul>
          <a href="#platforms" className="btn btn-secondary pricing-action">
            Download Now
          </a>
        </div>

        {/* Plus Plan */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Fluxora Plus</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>99
            <span className="pricing-period">/mo</span>
          </div>
          <p className="pricing-desc">
            Unlock premium streaming features for individual users.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Hardware transcoding
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Mobile offline downloads
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Advanced user roles
            </li>
          </ul>
          <a href="#" className="btn btn-secondary pricing-action">
            Get Plus
          </a>
          <div className="pricing-compare">Compare to Plex: ~₹399/mo</div>
        </div>

        {/* Pro Plan */}
        <div className="pricing-card featured">
          <div className="pricing-badge">Most Popular</div>
          <h3 className="pricing-tier">Fluxora Pro</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>199
            <span className="pricing-period">/mo</span>
          </div>
          <p className="pricing-desc">
            The ultimate streaming experience for families and power users.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Everything in Plus
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Multiple concurrent transcodes
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Priority Support
            </li>
          </ul>
          <a href="#" className="btn btn-primary pricing-action">
            Get Pro
          </a>
        </div>

        {/* Ultimate Plan */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Fluxora Ultimate</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>4,499
            <span className="pricing-period">/once</span>
          </div>
          <p className="pricing-desc">
            Lifetime access to all premium features. Pay once, stream forever.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              All Pro features forever
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              Early access to beta features
            </li>
            <li className="pricing-feature">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
              </svg>
              One-time payment
            </li>
          </ul>
          <a href="#" className="btn btn-secondary pricing-action">
            Get Lifetime
          </a>
          <div className="pricing-compare">Compare to Plex: ~₹9,999 once</div>
        </div>
      </div>
    </section>
  )
}
