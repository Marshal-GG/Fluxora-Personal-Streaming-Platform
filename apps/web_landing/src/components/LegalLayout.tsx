/**
 * LegalLayout — shared shell for Privacy / Terms pages.
 *
 * Renders a navbar-less, footer-less page with a centred content column
 * styled to read like a real legal document — generous line-height,
 * limited width, hierarchical headings.
 */

import Link from 'next/link'

const ArrowLeft = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M19 12H5M12 5l-7 7 7 7" />
  </svg>
)

export default function LegalLayout({
  title,
  effectiveDate,
  children,
}: {
  title: string
  effectiveDate: string
  children: React.ReactNode
}) {
  return (
    <main className="legal-page">
      <Link href="/" className="manage-back-link">
        <ArrowLeft />
        Back to Fluxora
      </Link>

      <article className="legal-article">
        <header>
          <h1>{title}</h1>
          <p className="legal-effective">Effective {effectiveDate}</p>
        </header>
        {children}
      </article>
    </main>
  )
}
