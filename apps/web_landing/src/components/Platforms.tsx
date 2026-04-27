const platforms = [
  {
    title: 'Server',
    sub: 'Windows · macOS · Linux',
    desc: 'Standalone executable. Runs on your home machine. No Python, no Docker required.',
    soon: true,
  },
  {
    title: 'Mobile',
    sub: 'iOS · Android',
    desc: 'Stream your library from anywhere. Discover the server automatically on LAN.',
    soon: true,
  },
  {
    title: 'Desktop',
    sub: 'Windows · macOS · Linux',
    desc: 'Control panel for managing libraries, clients, and server settings.',
    soon: true,
  },
]

export default function Platforms() {
  return (
    <div className="platforms" id="platforms">
      <div className="platforms-inner">
        <div className="section-header">
          <p className="section-label">Download</p>
          <h2 className="section-title">Available on every platform</h2>
          <p className="section-desc">Currently in active development. Sign up to be notified at launch.</p>
        </div>

        <div className="platform-cards">
          {platforms.map((p) => (
            <div className="platform-card" key={p.title}>
              <div>
                <div className="platform-card-title">{p.title}</div>
                <div className="platform-card-sub">{p.sub}</div>
              </div>
              <p className="feature-desc">{p.desc}</p>
              {p.soon && <span className="badge-soon">Coming soon</span>}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
