/**
 * Platforms — 5 cards: Windows / macOS / Linux / iOS / Android.
 *
 * Each card has a platform-style icon (simple-icons-style SVGs inlined),
 * title, supported version note, and a "Coming soon" pill until release.
 */

const Windows = () => (
  <svg width="36" height="36" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M3 5.5L10.5 4.5V11.5H3V5.5ZM11.5 4.4L21 3V11.5H11.5V4.4ZM3 12.5H10.5V19.5L3 18.5V12.5ZM11.5 12.5H21V21L11.5 19.6V12.5Z"/>
  </svg>
)

const Apple = () => (
  <svg width="36" height="36" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M17.05 12.04c-.03-3.03 2.47-4.49 2.59-4.56-1.41-2.07-3.61-2.35-4.39-2.38-1.87-.19-3.65 1.1-4.6 1.1-.95 0-2.42-1.07-3.97-1.04-2.04.03-3.93 1.19-4.99 3.02C-.43 11.84.94 17.31 3 20.31c1.04 1.47 2.27 3.12 3.88 3.06 1.55-.06 2.14-1.01 4.02-1.01 1.88 0 2.4 1.01 4.04.98 1.66-.03 2.71-1.5 3.74-2.97 1.18-1.7 1.66-3.35 1.69-3.43-.04-.02-3.25-1.25-3.32-4.95zM14.42 3.74C15.27 2.71 15.84 1.27 15.69 0c-1.13.05-2.5.75-3.38 1.78-.79.91-1.48 2.37-1.29 3.6 1.26.1 2.55-.64 3.4-1.64z"/>
  </svg>
)

const Linux = () => (
  <svg width="36" height="36" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M12.504 0C9.16 0 6.946 2.95 6.95 6.5c0 1.83.6 3.32 1.4 4.45-.7.3-1.5.5-2.5.5-1.6 0-2.6-.8-3.6-1.6-.7-.6-1.5-.7-1.7.3-.2 1 .8 1.6 1.5 2 .8.4 1.5.5 2.2.5 1 0 2-.2 2.7-.5-.5.6-.8 1.4-.8 2.3 0 1.5 1 2.7 2.5 3.2-.5 1.5-.5 3.2-.5 4.5 0 .7.3 1.3 1 1.5.7.3 1.4 0 1.4 0s.5.8 1.7.8 1.7-.5 1.7-.5.8.6 2 .6 1.7-.4 1.7-.4.7.5 1.4.3c.7-.2 1.1-.7 1.1-1.5 0-1.3 0-3.1-.5-4.5 1.5-.5 2.5-1.7 2.5-3.2 0-.9-.3-1.7-.8-2.3.7.3 1.7.5 2.7.5.7 0 1.4-.1 2.2-.5.7-.4 1.7-1 1.5-2-.2-1-1-.9-1.7-.3-1 .8-2 1.6-3.6 1.6-1 0-1.8-.2-2.5-.5.8-1.13 1.4-2.62 1.4-4.45C17.054 2.95 14.84 0 12.504 0z"/>
  </svg>
)

const Android = () => (
  <svg width="36" height="36" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M17.523 15.343c-.6 0-1.1-.5-1.1-1.1s.5-1.1 1.1-1.1 1.1.5 1.1 1.1-.5 1.1-1.1 1.1m-11.046 0c-.6 0-1.1-.5-1.1-1.1s.5-1.1 1.1-1.1 1.1.5 1.1 1.1-.5 1.1-1.1 1.1m11.443-6.052l2.196-3.802a.456.456 0 0 0-.165-.622.456.456 0 0 0-.622.165l-2.222 3.85A13.8 13.8 0 0 0 12 7.4c-2.054 0-3.987.495-5.707 1.482L4.07 5.032a.456.456 0 0 0-.622-.165.456.456 0 0 0-.165.622l2.196 3.802C2.755 11.04 1.06 13.677 1.06 17.5h21.882c0-3.823-1.695-6.46-5.022-8.21"/>
  </svg>
)

const IOSIcon = () => (
  <svg width="36" height="36" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <rect x="6" y="2" width="12" height="20" rx="2.5" ry="2.5" stroke="currentColor" strokeWidth="0.5" fill="none" />
    <circle cx="12" cy="18.5" r="0.9" />
    <line x1="10.5" y1="4.2" x2="13.5" y2="4.2" stroke="currentColor" strokeWidth="0.6" strokeLinecap="round" />
    <text x="12" y="14" textAnchor="middle" fontSize="6" fontFamily="Inter, sans-serif" fontWeight="700">iOS</text>
  </svg>
)

type Platform = {
  title: string
  sub: string
  desc: string
  icon: React.ReactNode
  soon: boolean
}

const platforms: Platform[] = [
  { title: 'Windows',  sub: '10 / 11',         desc: 'Native installer. Single executable.',                 icon: <Windows />, soon: true },
  { title: 'macOS',    sub: '13+ Apple Silicon & Intel', desc: 'Universal binary. DMG installer.', icon: <Apple />,   soon: true },
  { title: 'Linux',    sub: 'Ubuntu / Arch / Fedora', desc: 'AppImage and .deb / .rpm packages.',     icon: <Linux />,   soon: true },
  { title: 'iOS',      sub: 'iPhone & iPad',   desc: 'iOS 16+. App Store and TestFlight.',           icon: <IOSIcon />, soon: true },
  { title: 'Android',  sub: 'Phone & Tablet',  desc: 'Android 10+. Play Store and APK direct.',      icon: <Android />, soon: true },
]

export default function Platforms() {
  return (
    <div className="platforms" id="platforms">
      <div className="platforms-inner">
        <div className="section-header">
          <p className="section-label">Download</p>
          <h2 className="section-title">Run it on every device you own.</h2>
          <p className="section-desc">
            One server. Every client. All free, all native — no Electron-bloat anywhere.
          </p>
        </div>

        <div className="platform-cards">
          {platforms.map((p) => (
            <div className="platform-card" key={p.title}>
              <span className="platform-card-icon">{p.icon}</span>
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
