/**
 * Hero — two-column layout pixel-matching `web_landing_hero.png`.
 *
 * Left: heading + subhead + Get Started / Learn More CTAs, with the
 * animated HeroWaves SVG drifting behind the text.
 * Right: a framed screenshot of the redesigned desktop Dashboard.
 *
 * The SVG and the screenshot are static assets in `public/`. Reduced-motion
 * users see the waves hidden via the `globals.css` @media query.
 */

const PlayIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
    <circle cx="12" cy="12" r="10" />
    <polygon points="10 8 16 12 10 16 10 8" fill="currentColor" stroke="none" />
  </svg>
)

const ArrowRightIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
    <line x1="5" y1="12" x2="19" y2="12" />
    <polyline points="12 5 19 12 12 19" />
  </svg>
)

export default function Hero() {
  return (
    <section className="hero" id="hero">
      <img
        src="/illustrations/hero_waves.svg"
        alt=""
        aria-hidden="true"
        className="hero-waves-bg"
        loading="eager"
      />

      <div className="hero-content">
        <span className="hero-eyebrow">
          <span className="hero-eyebrow-pulse" />
          Self-hosted · Open source · No tracking
        </span>

        <h1 className="hero-title">
          Stream. Sync.
          <br />
          <span className="gradient">Anywhere.</span>
        </h1>

        <p className="hero-subtitle">
          Movies, TV, music, documents — one library, every device. Owned,
          encrypted, private. LAN-fast at home, seamless over the internet
          when you leave.
        </p>

        <div className="hero-actions">
          <a
            href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-primary btn-lg"
          >
            Star on GitHub
            <ArrowRightIcon />
          </a>
          <a href="#how-it-works" className="btn btn-secondary btn-lg">
            <PlayIcon />
            See How It Works
          </a>
        </div>

        <div className="hero-social-proof">
          <a
            href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform"
            target="_blank"
            rel="noopener noreferrer"
            className="hero-github-pill"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 .3a12 12 0 0 0-3.8 23.4c.6.1.8-.3.8-.6v-2c-3.3.7-4-1.6-4-1.6-.6-1.4-1.4-1.8-1.4-1.8-1.1-.7.1-.7.1-.7 1.2.1 1.9 1.3 1.9 1.3 1.1 1.9 2.9 1.3 3.6 1 .1-.8.4-1.3.8-1.6-2.7-.3-5.5-1.3-5.5-6 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2a11.5 11.5 0 0 1 6 0c2.3-1.5 3.3-1.2 3.3-1.2.7 1.7.2 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.7-5.5 6 .4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6A12 12 0 0 0 12 .3"/>
            </svg>
            <span className="hero-github-text">
              View source on <strong>GitHub</strong>
            </span>
            <span className="hero-github-arrow">→</span>
          </a>
          <span className="hero-social-text">
            MIT licensed · Self-host in 5 min · No credit card
          </span>
        </div>
      </div>

      <div className="hero-mockup">
        <div className="hero-mockup-frame">
          <img
            src="/mockups/desktop-dashboard.png"
            alt="Fluxora desktop control panel — dashboard view"
            width={1536}
            height={1024}
            loading="eager"
            fetchPriority="high"
          />
        </div>
      </div>
    </section>
  )
}
