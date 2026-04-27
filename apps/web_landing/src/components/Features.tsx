const features = [
  {
    icon: '🏠',
    title: 'Zero-Config LAN',
    desc: 'Automatically discovers your server on the local network via mDNS. No IP addresses, no port forwarding, no setup.',
  },
  {
    icon: '🌐',
    title: 'Seamless Internet Fallback',
    desc: 'When you leave home, Fluxora silently switches to a WebRTC connection. Your stream continues without interruption.',
  },
  {
    icon: '🔒',
    title: 'Manual Pairing Only',
    desc: 'New devices require explicit approval on your control panel. No passwords, no OAuth, no third-party accounts.',
  },
  {
    icon: '📦',
    title: 'Truly Self-Hosted',
    desc: 'The server runs as a single executable on your hardware. Your files never touch anyone else\'s servers.',
  },
  {
    icon: '⚡',
    title: 'HLS Streaming',
    desc: 'FFmpeg transcodes on the fly to HLS, giving you adaptive quality, reliable seeking, and broad device support.',
  },
  {
    icon: '🖥️',
    title: 'Desktop Control Panel',
    desc: 'Manage your libraries, paired clients, stream sessions, and server settings from a native desktop app.',
  },
]

export default function Features() {
  return (
    <section className="section" id="features">
      <div className="section-header">
        <p className="section-label">Features</p>
        <h2 className="section-title">Everything you need, nothing you don&apos;t</h2>
        <p className="section-desc">
          Built around a single principle: your media, your hardware, your control.
        </p>
      </div>

      <div className="features-grid">
        {features.map((f) => (
          <div className="feature-card" key={f.title}>
            <div className="feature-icon">{f.icon}</div>
            <h3 className="feature-title">{f.title}</h3>
            <p className="feature-desc">{f.desc}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
