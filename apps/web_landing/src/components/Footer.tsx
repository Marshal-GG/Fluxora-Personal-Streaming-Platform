import Link from 'next/link'

export default function Footer() {
  return (
    <footer className="footer">
      <div className="footer-inner">
        <div>
          <div className="footer-brand">
            Flux<span>ora</span>
          </div>
          <div className="footer-tagline">Self-hosted. Open source. No cloud required.</div>
        </div>

        <ul className="footer-links">
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
            <a href="#features">Features</a>
          </li>
          <li>
            <a href="#pricing">Pricing</a>
          </li>
          <li>
            <Link href="/manage">Manage Subscription</Link>
          </li>
        </ul>
      </div>
    </footer>
  )
}
