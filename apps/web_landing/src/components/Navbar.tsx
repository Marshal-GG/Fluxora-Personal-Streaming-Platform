/**
 * Navbar — sticky glass top bar with logo + nav links + primary action.
 *
 * Pixel-aligns with `docs/11_design/ref images/web/web_landing_hero.png`.
 * Search and Sign-In removed — both pointed nowhere meaningful and a
 * non-functional search button confuses screen-reader users. They'll come
 * back when the linked surfaces ship.
 */

import Link from 'next/link'

export default function Navbar() {
  return (
    <header className="navbar">
      <Link href="/" className="navbar-brand" aria-label="Fluxora home">
        <img src="/brand/logo-wordmark-h.png" alt="Fluxora" className="navbar-brand-wordmark" />
      </Link>

      <ul className="navbar-links">
        <li><a href="#features">Features</a></li>
        <li><a href="#libraries">Library</a></li>
        <li><a href="#how-it-works">How it works</a></li>
        <li><a href="#pricing">Pricing</a></li>
        <li><a href="#faq">FAQ</a></li>
      </ul>

      <div className="navbar-actions">
        <a
          href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform"
          target="_blank"
          rel="noopener noreferrer"
          className="navbar-signin"
        >
          GitHub
        </a>
        <a href="#pricing" className="btn btn-primary">Get Started</a>
      </div>
    </header>
  )
}
