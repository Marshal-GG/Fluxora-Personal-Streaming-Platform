/**
 * AboutStrip — short two-column "About Fluxora" band with stats row.
 *
 * Sits between the FAQ and the final CTA. Pulls a stranger's attention
 * back to the brand story without committing to a full About page.
 */

const ArrowRight = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <line x1="5" y1="12" x2="19" y2="12" />
    <polyline points="12 5 19 12 12 19" />
  </svg>
)

const stats = [
  { value: 'MIT',   label: 'Open-source license' },
  { value: '100%',  label: 'Code on your machine' },
  { value: '5',     label: 'Native platforms' },
  { value: '0',     label: 'Cloud dependencies' },
]

export default function AboutStrip() {
  return (
    <section className="about-strip" id="about">
      <div>
        <p className="about-text-eyebrow">About Fluxora</p>
        <h2 className="about-text-title">
          Built by a developer who got tired of subscriptions for media they already own.
        </h2>
        <p className="about-text-body">
          Fluxora is open-source media streaming, designed from day one to live on your hardware. No cloud accounts. No tracking. No "we're shutting down, your library is gone" risk. The free server is yours forever — paid tiers fund continued development without locking up the basics.
        </p>
        <a
          href="https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform"
          target="_blank"
          rel="noopener noreferrer"
          className="about-text-link"
        >
          Read the source on GitHub <ArrowRight />
        </a>
      </div>

      <div className="about-stats">
        {stats.map((s) => (
          <div className="about-stat" key={s.label}>
            <div className="about-stat-value">{s.value}</div>
            <div className="about-stat-label">{s.label}</div>
          </div>
        ))}
      </div>
    </section>
  )
}
