/**
 * Screenshots — tabbed gallery of desktop control-panel surfaces.
 *
 * Six screens from the prototype, switchable via tabs. Pure CSS via the
 * `:checked` sibling selector — zero JS, full keyboard accessibility,
 * works in every browser.
 *
 * The tab radios are visually hidden but keyboard-focusable; tab labels
 * are clickable and styled per the design tokens.
 */

type Screen = {
  id: string
  label: string
  src: string
  alt: string
  caption: string
}

const screens: Screen[] = [
  {
    id: 'shot-dashboard',
    label: 'Dashboard',
    src: '/screenshots/dashboard.png',
    alt: 'Fluxora desktop dashboard — server overview, recent activity, storage breakdown',
    caption: 'Server overview at a glance. Live CPU, RAM, network, and recent activity — all on one screen.',
  },
  {
    id: 'shot-library',
    label: 'Library',
    src: '/screenshots/library.png',
    alt: 'Fluxora desktop library management — TMDB-enriched media browser',
    caption: 'Browse, scan, and organize your library. TMDB-enriched posters, metadata, and resume points.',
  },
  {
    id: 'shot-clients',
    label: 'Clients',
    src: '/screenshots/clients.png',
    alt: 'Fluxora desktop clients screen — paired-device management',
    caption: 'Approve, revoke, and inspect every paired device. See who&apos;s streaming what, in real time.',
  },
  {
    id: 'shot-groups',
    label: 'Groups',
    src: '/screenshots/groups.png',
    alt: 'Fluxora desktop groups management — household + roommate access controls',
    caption: 'Bundle clients into groups with shared library access, time windows, and bandwidth caps.',
  },
  {
    id: 'shot-settings',
    label: 'Settings',
    src: '/screenshots/settings.png',
    alt: 'Fluxora desktop settings — network, streaming, and security configuration',
    caption: 'Network, streaming, transcoding, and security settings — all from a single panel.',
  },
  {
    id: 'shot-logs',
    label: 'Logs',
    src: '/screenshots/logs.png',
    alt: 'Fluxora desktop logs viewer — structured server log explorer',
    caption: 'Structured logs with level / source filtering. No more SSH-ing into the server.',
  },
]

export default function Screenshots() {
  return (
    <section className="section" id="screenshots">
      <div className="section-header">
        <p className="section-label">Inside Fluxora</p>
        <h2 className="section-title">Every surface, designed to the same standard.</h2>
        <p className="section-desc">
          The desktop control panel is where you manage everything. Built with the same dark glassmorphic aesthetic — no Electron-bloat, native performance.
        </p>
      </div>

      <div className="screenshots">
        {screens.map((s, i) => (
          <input
            key={`r-${s.id}`}
            type="radio"
            name="screenshot-tabs"
            id={s.id}
            defaultChecked={i === 0}
            className="screenshots-input"
          />
        ))}

        <div className="screenshots-tabs" role="tablist">
          {screens.map((s) => (
            <label key={`l-${s.id}`} htmlFor={s.id} className="screenshots-tab" role="tab">
              {s.label}
            </label>
          ))}
        </div>

        <div className="screenshots-stage">
          {screens.map((s) => (
            <figure key={`f-${s.id}`} className={`screenshots-figure screenshots-figure--${s.id}`}>
              <div className="screenshots-frame">
                <img
                  src={s.src}
                  alt={s.alt}
                  width={1536}
                  height={1024}
                  loading="lazy"
                />
              </div>
              <figcaption className="screenshots-caption">{s.caption}</figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  )
}
