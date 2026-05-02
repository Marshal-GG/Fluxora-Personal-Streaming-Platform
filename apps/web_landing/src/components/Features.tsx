/**
 * Features — 4-card row pixel-matching the bottom of `web_landing_hero.png`.
 *
 * Each card: violet icon-bg square, title, two-line description, tiny
 * emerald check-pill in the top-right ("available everywhere") signal.
 */

const CheckIcon = () => (
  <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
  </svg>
)

type Feature = {
  iconPath: React.ReactNode
  title: string
  desc: string
}

const features: Feature[] = [
  {
    iconPath: (
      <>
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <line x1="3" y1="10" x2="21" y2="10" />
      </>
    ),
    title: 'All Your Content',
    desc: 'Movies, shows, music, documents, photos — one beautiful library across every device you own.',
  },
  {
    iconPath: (
      <>
        <rect x="5" y="2" width="14" height="20" rx="2" />
        <line x1="12" y1="18" x2="12.01" y2="18" />
      </>
    ),
    title: 'Any Device',
    desc: 'Phones, tablets, laptops, TVs, anywhere. LAN-fast at home, internet-seamless when you leave.',
  },
  {
    iconPath: (
      <>
        <path d="M12 2L4 6v6c0 5 3.5 9.5 8 11 4.5-1.5 8-6 8-11V6l-8-4z" />
        <polyline points="9 12 11 14 15 10" />
      </>
    ),
    title: 'Secure & Private',
    desc: 'Your data lives on your hardware. No cloud accounts, no tracking, no ads — ever.',
  },
  {
    iconPath: (
      <>
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
        <polyline points="7 10 12 15 17 10" />
        <line x1="12" y1="15" x2="12" y2="3" />
      </>
    ),
    title: 'Watch Offline',
    desc: 'Download what you want. Watch on the plane, the train, the cabin — anywhere with no signal.',
  },
]

export default function Features() {
  return (
    <section className="section" id="features">
      <div className="section-header">
        <p className="section-label">Why Fluxora</p>
        <h2 className="section-title">Built to feel like the streaming services — owned by you.</h2>
        <p className="section-desc">
          The polish of Plex. The independence of self-hosting. The privacy of zero-cloud. All in one open-source bundle.
        </p>
      </div>

      <div className="features-grid">
        {features.map((f) => (
          <div className="feature-card" key={f.title}>
            <span className="feature-check" aria-hidden="true">
              <CheckIcon />
            </span>
            <div className="feature-icon-wrap" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                {f.iconPath}
              </svg>
            </div>
            <h3 className="feature-title">{f.title}</h3>
            <p className="feature-desc">{f.desc}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
