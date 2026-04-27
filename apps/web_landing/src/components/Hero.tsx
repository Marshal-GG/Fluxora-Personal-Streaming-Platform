export default function Hero() {
  return (
    <section className="hero">
      <div className="hero-badge">
        Self-hosted &middot; No subscriptions &middot; Open source
      </div>

      <h1 className="hero-title">
        Your Media.<br />
        <span className="gradient">Any Device. Anywhere.</span>
      </h1>

      <p className="hero-subtitle">
        Fluxora streams your personal library to any paired device — instantly
        on your home network, seamlessly over the internet when you leave.
        No accounts. No cloud. No fees.
      </p>

      <div className="hero-actions">
        <a href="#platforms" className="btn btn-primary btn-lg">
          Download Server
        </a>
        <a
          href="https://github.com/marshalx/fluxora"
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-secondary btn-lg"
        >
          View on GitHub
        </a>
      </div>

      <div className="hero-meta">
        <span className="hero-meta-item">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
          </svg>
          Works offline on LAN
        </span>
        <span className="hero-meta-item">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
          </svg>
          Auto-switches to internet
        </span>
        <span className="hero-meta-item">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
          </svg>
          Windows · macOS · Linux · iOS · Android
        </span>
      </div>
    </section>
  )
}
