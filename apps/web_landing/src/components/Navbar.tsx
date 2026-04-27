export default function Navbar() {
  return (
    <header className="navbar">
      <div className="navbar-logo">
        Flux<span>ora</span>
      </div>

      <nav>
        <ul className="navbar-links">
          <li><a href="#features">Features</a></li>
          <li><a href="#how-it-works">How it works</a></li>
          <li><a href="#platforms">Download</a></li>
        </ul>
      </nav>

      <div className="navbar-actions">
        <a
          href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform"
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-secondary"
        >
          GitHub
        </a>
      </div>
    </header>
  )
}
