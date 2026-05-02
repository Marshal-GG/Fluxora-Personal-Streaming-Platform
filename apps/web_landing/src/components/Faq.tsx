/**
 * FAQ — accordion of common questions, `<details>`-based for zero-JS support.
 *
 * Six starter Q&As covering pricing, networking, formats, privacy, billing,
 * and platform support — the questions a stranger arriving cold most often
 * asks.
 */

const Chevron = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" className="faq-chevron" aria-hidden="true">
    <polyline points="9 6 15 12 9 18" />
  </svg>
)

type Qa = { q: string; a: string }

const faqs: Qa[] = [
  {
    q: 'Is Fluxora actually free?',
    a: 'Yes. The Free tier is the full self-hosted server, every client app, LAN streaming, and TMDB metadata. Free forever, no credit card. Paid tiers add internet streaming, hardware transcoding, and more concurrent streams — they support development, but the core experience is genuinely free.',
  },
  {
    q: 'Do I need to be on the same Wi-Fi as my server?',
    a: 'Only for the Free tier. Plus, Pro, and Ultimate use WebRTC to stream from your home server to wherever you are — no port-forwarding, no VPN, no public IP needed. The server stays on your hardware; only the encrypted stream travels.',
  },
  {
    q: 'What media formats are supported?',
    a: 'Common video (MP4, MKV, MOV, AVI), audio (MP3, FLAC, AAC, WAV), and documents (PDF, EPUB, CBZ). FFmpeg handles transcoding under the hood — if it plays in VLC, it plays in Fluxora.',
  },
  {
    q: 'Where is my data stored?',
    a: 'Entirely on your hardware. Fluxora has no cloud accounts and never uploads your media anywhere. Metadata (titles, posters from TMDB) is fetched once and cached locally. Your library is your business.',
  },
  {
    q: 'Can I cancel anytime?',
    a: 'Yes. Plus and Pro are monthly — cancel from the manage page, keep using until the period ends. Ultimate is a one-time payment with lifetime access — no renewals, no surprises.',
  },
  {
    q: 'Which devices work?',
    a: 'Server runs on Windows 10/11, macOS 13+, and most Linux distros (Ubuntu / Arch / Fedora). Clients on iOS 16+, Android 10+, and the same desktop platforms. Apple TV and Android TV are on the roadmap.',
  },
]

export default function Faq() {
  return (
    <section className="section" id="faq">
      <div className="section-header">
        <p className="section-label">Questions</p>
        <h2 className="section-title">Frequently asked questions</h2>
        <p className="section-desc">
          Everything you need to know before getting started. Need more? <a href="#" className="about-text-link">Hit our community</a>.
        </p>
      </div>

      <div className="faq-list">
        {faqs.map((item, i) => (
          <details className="faq-item" key={item.q} open={i === 0}>
            <summary>
              <span>{item.q}</span>
              <Chevron />
            </summary>
            <div className="faq-answer">{item.a}</div>
          </details>
        ))}
      </div>
    </section>
  )
}
