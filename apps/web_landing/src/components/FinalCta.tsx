/**
 * FinalCta — bottom-of-page conversion band.
 *
 * One-line value reminder + single primary action. Sits above the footer.
 */

const Arrow = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <line x1="5" y1="12" x2="19" y2="12" />
    <polyline points="12 5 19 12 12 19" />
  </svg>
)

export default function FinalCta() {
  return (
    <section className="final-cta" id="get-started">
      <div className="final-cta-inner">
        <h2 className="final-cta-title">Start streaming your library today.</h2>
        <p className="final-cta-sub">
          Self-host in 5 minutes. No credit card. No cloud account. Yours forever.
        </p>
        <a href="#pricing" className="btn btn-primary btn-lg">
          Download Free Server
          <Arrow />
        </a>
      </div>
    </section>
  )
}
