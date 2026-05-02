/**
 * LibraryTiles — 5 colored category tiles representing the media types
 * Fluxora's libraries support.
 *
 * Each tile names the supported format set / quality target rather than
 * a fake item count, so visitors understand the *feature* surface
 * (formats, codecs, quality tiers) instead of mistaking the marketing
 * page for a live library view.
 */

type Library = {
  name: string
  caption: string
  color: string  // background colour for the icon square
  icon: React.ReactNode
}

const I = (children: React.ReactNode) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
    {children}
  </svg>
)

const libraries: Library[] = [
  {
    name: 'Movies',
    caption: 'Up to 4K HDR',
    color: '#A855F7',
    icon: I(<>
      <polygon points="23 7 16 12 23 17 23 7" />
      <rect x="1" y="5" width="15" height="14" rx="2" />
    </>),
  },
  {
    name: 'TV Shows',
    caption: 'Auto-resume per episode',
    color: '#22D3EE',
    icon: I(<>
      <rect x="2" y="4" width="20" height="14" rx="2" />
      <line x1="8" y1="22" x2="16" y2="22" />
      <line x1="12" y1="18" x2="12" y2="22" />
    </>),
  },
  {
    name: 'Documents',
    caption: 'PDF · EPUB · CBZ',
    color: '#EC4899',
    icon: I(<>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="8" y1="13" x2="16" y2="13" />
      <line x1="8" y1="17" x2="14" y2="17" />
    </>),
  },
  {
    name: 'Music',
    caption: 'Lossless FLAC + AAC',
    color: '#10B981',
    icon: I(<>
      <path d="M9 18V5l12-2v13" />
      <circle cx="6" cy="18" r="3" />
      <circle cx="18" cy="16" r="3" />
    </>),
  },
  {
    name: 'Photos',
    caption: 'EXIF-aware sorting',
    color: '#F59E0B',
    icon: I(<>
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <circle cx="9" cy="9" r="2" />
      <polyline points="21 15 16 10 5 21" />
    </>),
  },
]

export default function LibraryTiles() {
  return (
    <section className="section" id="libraries">
      <div className="section-row-header">
        <h2 className="section-row-title">One library, every format.</h2>
        <a href="#features" className="section-row-link">View features →</a>
      </div>

      <div className="libraries-grid">
        {libraries.map((lib) => (
          <a key={lib.name} href="#features" className="library-tile">
            <span
              className="library-tile-icon"
              style={{ background: `${lib.color}29`, color: lib.color }}
              aria-hidden="true"
            >
              {lib.icon}
            </span>
            <span className="library-tile-meta">
              <span className="library-tile-name">{lib.name}</span>
              <span className="library-tile-count">{lib.caption}</span>
            </span>
          </a>
        ))}
      </div>
    </section>
  )
}
