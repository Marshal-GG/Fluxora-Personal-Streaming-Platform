const steps = [
  {
    n: '1',
    title: 'Install the server',
    desc: 'Download the Fluxora server executable for your platform. Run it — no config files, no Docker, no dependencies.',
  },
  {
    n: '2',
    title: 'Add your library',
    desc: 'Open the desktop control panel and point it at your media folders. Fluxora indexes everything automatically.',
  },
  {
    n: '3',
    title: 'Pair your devices',
    desc: 'Open the mobile app on the same network. Approve the pairing request in the control panel. Done.',
  },
  {
    n: '4',
    title: 'Stream anywhere',
    desc: 'Your full library is now available on every paired device — at home via LAN, or away via the internet.',
  },
]

export default function HowItWorks() {
  return (
    <section className="section" id="how-it-works">
      <div className="section-header">
        <p className="section-label">How it works</p>
        <h2 className="section-title">Up and running in minutes</h2>
        <p className="section-desc">
          No cloud accounts. No configuration wizards. Just install, point, and stream.
        </p>
      </div>

      <div className="steps">
        {steps.map((s) => (
          <div className="step" key={s.n}>
            <div className="step-number">{s.n}</div>
            <div className="step-content">
              <h3 className="step-title">{s.title}</h3>
              <p className="step-desc">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
