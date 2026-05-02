/**
 * TierComparison — feature × tier matrix table.
 *
 * Slots in below the pricing cards. Helps buyers see exactly what each
 * tier adds over the previous one.
 */

const Check = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" className="check" aria-label="Yes">
    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
  </svg>
)

const Dash = () => <span className="dash" aria-label="Not included">—</span>

type Row = {
  feature: string
  free: React.ReactNode
  plus: React.ReactNode
  pro: React.ReactNode
  ultimate: React.ReactNode
}

const rows: Row[] = [
  { feature: 'Local LAN streaming',          free: <Check />, plus: <Check />, pro: <Check />,         ultimate: <Check /> },
  { feature: 'TMDB metadata &amp; artwork',  free: <Check />, plus: <Check />, pro: <Check />,         ultimate: <Check /> },
  { feature: 'Internet streaming (WebRTC)',  free: <Dash />,  plus: <Check />, pro: <Check />,         ultimate: <Check /> },
  { feature: 'Mobile offline downloads',     free: <Dash />,  plus: <Check />, pro: <Check />,         ultimate: <Check /> },
  { feature: 'Simultaneous remote streams',  free: <span className="value">1</span>, plus: <span className="value">3</span>, pro: <span className="value">10</span>, ultimate: <span className="value">∞</span> },
  { feature: 'Hardware transcoding',         free: <Dash />,  plus: <Dash />,  pro: <Check />,         ultimate: <Check /> },
  { feature: 'Client groups &amp; restrictions', free: <Dash />,  plus: <Dash />,  pro: <Check />,     ultimate: <Check /> },
  { feature: 'Priority support',             free: <Dash />,  plus: <Dash />,  pro: <Check />,         ultimate: <Check /> },
  { feature: 'Lifetime access',              free: <Dash />,  plus: <Dash />,  pro: <Dash />,          ultimate: <Check /> },
  { feature: 'Early access to beta features', free: <Dash />, plus: <Dash />,  pro: <Dash />,          ultimate: <Check /> },
]

export default function TierComparison() {
  return (
    <div className="tier-comparison">
      <h3>Compare every feature</h3>
      <div className="tier-table-scroll">
      <table className="tier-table">
        <thead>
          <tr>
            <th scope="col">Feature</th>
            <th scope="col">Free</th>
            <th scope="col">Plus</th>
            <th scope="col" className="featured-col">Pro</th>
            <th scope="col">Ultimate</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.feature}>
              <td dangerouslySetInnerHTML={{ __html: r.feature }} />
              <td>{r.free}</td>
              <td>{r.plus}</td>
              <td className="featured-col">{r.pro}</td>
              <td>{r.ultimate}</td>
            </tr>
          ))}
        </tbody>
      </table>
      </div>
    </div>
  )
}
