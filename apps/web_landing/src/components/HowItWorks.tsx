/**
 * HowItWorks — 3-step horizontal flow.
 *
 * Tight, benefit-focused copy. Each step is a card with a violet gradient
 * numbered badge and one-sentence description.
 */

const steps = [
  {
    n: '1',
    title: 'Install in 2 minutes',
    desc: 'One executable. Windows, macOS, or Linux. No Docker. No config files. No dependencies to chase.',
  },
  {
    n: '2',
    title: 'Pair your devices',
    desc: 'QR-pair your phone, laptop, or TV in 30 seconds. Approve once on the control panel — never again.',
  },
  {
    n: '3',
    title: 'Stream anywhere',
    desc: 'LAN-fast at home. WebRTC-seamless when you leave. Same library, same library card, every device.',
  },
]

export default function HowItWorks() {
  return (
    <section className="section" id="how-it-works">
      <div className="section-header">
        <p className="section-label">How it works</p>
        <h2 className="section-title">Up and streaming in five minutes flat.</h2>
        <p className="section-desc">
          No cloud signup. No payment to start. No technical setup that takes a weekend. Just install, pair, watch.
        </p>
      </div>

      <div className="steps">
        {steps.map((s) => (
          <div className="step" key={s.n}>
            <div className="step-number">{s.n}</div>
            <h3 className="step-title">{s.title}</h3>
            <p className="step-desc">{s.desc}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
