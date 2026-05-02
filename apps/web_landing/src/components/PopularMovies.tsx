/**
 * PopularMovies — horizontal carousel of real popular movie posters.
 *
 * Posters are served from TMDB's public image CDN at `image.tmdb.org`.
 * The CDN is free, attribution-friendly, and stable — paths don't change
 * once a poster is set. No API key required for image delivery.
 *
 * Per owner direction: use real names + current popular titles. The cards
 * are visual decoration only — no titles, descriptions or other metadata
 * leak into the HTML beyond `alt` text.
 */

const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p/w342'

type Movie = {
  title: string
  year: number
  posterPath: string // TMDB poster_path (with leading slash)
}

const movies: Movie[] = [
  { title: 'Dune: Part Two',                     year: 2024, posterPath: '/3HzGtM0JpfH2pWFGugJK22LRP6b.jpg' },
  { title: 'Oppenheimer',                        year: 2023, posterPath: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg' },
  { title: 'Deadpool & Wolverine',               year: 2024, posterPath: '/v0Q2uYARIqui1sEBF0bCLJaliDI.jpg' },
  { title: 'The Batman',                         year: 2022, posterPath: '/djCPA8NYhhsDT1DVTViOgH4INqY.jpg' },
  { title: 'Spider-Man: Across the Spider-Verse', year: 2023, posterPath: '/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg' },
  { title: 'Top Gun: Maverick',                  year: 2022, posterPath: '/n0YuM4f5lvGAP6MAW2kBIzugXnc.jpg' },
  { title: 'Interstellar',                       year: 2014, posterPath: '/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg' },
  { title: 'Inception',                          year: 2010, posterPath: '/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg' },
]

export default function PopularMovies() {
  return (
    <section className="section" id="popular-movies">
      <div className="section-row-header">
        <h2 className="section-row-title">Popular Movies</h2>
        <a href="#libraries" className="section-row-link">View All →</a>
      </div>

      <div className="posters-row" role="list">
        {movies.map((m) => (
          <div className="poster-card" role="listitem" key={m.title}>
            <img
              src={`${TMDB_IMAGE_BASE}${m.posterPath}`}
              alt={`${m.title} (${m.year}) poster`}
              loading="lazy"
              width={160}
              height={240}
            />
            <div className="poster-meta">
              <div className="poster-title" title={m.title}>{m.title}</div>
              <div className="poster-year">{m.year}</div>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
