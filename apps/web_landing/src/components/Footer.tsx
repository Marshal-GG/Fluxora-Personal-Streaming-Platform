/**
 * Footer — 4-column grid + brand column + bottom strip.
 *
 * Most internal links are `#` placeholders for now. Tracked in
 * `docs/10_planning/04_manual_tasks.md` "Wire landing-page footer
 * placeholder links" — sweep to live URLs as `/help`, `/blog`, etc. ship.
 */

import Link from 'next/link'

export default function Footer() {
  return (
    <footer className="footer">
      <div className="footer-inner">
        <div className="footer-grid">

          <div className="footer-brand-col">
            <Link href="/" className="footer-brand-mark-row" aria-label="Fluxora home">
              <img src="/brand/logo-wordmark-h.png" alt="Fluxora" className="footer-brand-wordmark" />
            </Link>
            <p className="footer-tagline">Stream. Sync. Anywhere.<br />Self-hosted. Open-source. Yours forever.</p>
          </div>

          <div className="footer-col">
            <div className="footer-col-title">Product</div>
            <ul>
              <li><a href="#features">Features</a></li>
              <li><a href="#pricing">Pricing</a></li>
              <li><a href="#platforms">Download</a></li>
              <li><a href="#popular-movies">For Movies</a></li>
              <li><a href="#libraries">For Music</a></li>
            </ul>
          </div>

          <div className="footer-col">
            <div className="footer-col-title">Resources</div>
            <ul>
              <li><a href="#" aria-label="Documentation (coming soon)">Documentation</a></li>
              <li><a href="#faq">FAQ</a></li>
              <li><a href="#" aria-label="Help center (coming soon)">Help Center</a></li>
              <li><a href="#" aria-label="Status page (coming soon)">Status</a></li>
              <li><a href="#" aria-label="Roadmap (coming soon)">Roadmap</a></li>
            </ul>
          </div>

          <div className="footer-col">
            <div className="footer-col-title">Company</div>
            <ul>
              <li><a href="#about">About</a></li>
              <li><a href="#" aria-label="Blog (coming soon)">Blog</a></li>
              <li><a href="#" aria-label="Press kit (coming soon)">Press kit</a></li>
              <li><a href="#" aria-label="Contact (coming soon)">Contact</a></li>
              <li><Link href="/manage">Manage Subscription</Link></li>
            </ul>
          </div>

          <div className="footer-col">
            <div className="footer-col-title">Connect</div>
            <ul>
              <li>
                <a
                  href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  GitHub
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/discussions"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Discussions
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Report a bug
                </a>
              </li>
              <li><a href="#" aria-label="Discord (coming soon)">Discord</a></li>
              <li><a href="#" aria-label="X / Twitter (coming soon)">X / Twitter</a></li>
            </ul>
          </div>

        </div>

        <div className="footer-attribution">
          <p>
            This product uses the TMDB API but is not endorsed or certified by{' '}
            <a href="https://www.themoviedb.org/" target="_blank" rel="noopener noreferrer">TMDB</a>.
            Movie poster artwork remains © respective rights holders and is shown for editorial preview only.
          </p>
        </div>

        <div className="footer-bottom">
          <span>© {new Date().getFullYear()} Fluxora · MIT licensed · Built by <a href="https://github.com/Marshal-GG" target="_blank" rel="noopener noreferrer">@Marshal-GG</a></span>
          <span>
            <Link href="/privacy">Privacy</Link> · <Link href="/terms">Terms</Link>
          </span>
        </div>
      </div>
    </footer>
  )
}
