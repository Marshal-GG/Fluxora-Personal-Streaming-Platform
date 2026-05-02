import { ImageResponse } from 'next/og'

// Auto-generated 1200x630 OG card. Picked up by Next.js metadata system
// as `og:image` and `twitter:image` for the root route. Styled to mirror
// the v2 violet brand: dark-violet background, gradient title, tagline.
//
// `runtime` = nodejs because static export builds run in node; Edge
// runtime is incompatible with `output: 'export'`.

export const runtime = 'nodejs'
// Required when `output: 'export'` is set in next.config — emit one PNG
// at build time and bake it into the static export.
export const dynamic = 'force-static'
export const alt = 'Fluxora — Stream. Sync. Anywhere.'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          justifyContent: 'center',
          padding: '80px',
          background:
            'radial-gradient(circle at 0% 0%, rgba(168,85,247,0.25), transparent 55%), radial-gradient(circle at 100% 100%, rgba(34,211,238,0.18), transparent 55%), #08061A',
          color: '#F1F5F9',
          fontFamily: 'sans-serif',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 18,
            marginBottom: 56,
          }}
        >
          <div
            style={{
              width: 64,
              height: 64,
              borderRadius: 16,
              background: 'linear-gradient(135deg, #8B5CF6, #A855F7, #22D3EE)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 40,
              fontWeight: 800,
              color: '#fff',
              letterSpacing: '-0.04em',
            }}
          >
            F
          </div>
          <div
            style={{
              fontSize: 36,
              fontWeight: 800,
              letterSpacing: '-0.04em',
            }}
          >
            FLUXORA
          </div>
        </div>

        <div
          style={{
            fontSize: 92,
            fontWeight: 800,
            lineHeight: 1.05,
            letterSpacing: '-0.04em',
            marginBottom: 24,
            color: '#F1F5F9',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <div>Stream. Sync.</div>
          <div
            style={{
              background:
                'linear-gradient(135deg, #C4A8F5, #A855F7, #22D3EE)',
              backgroundClip: 'text',
              color: 'transparent',
            }}
          >
            Anywhere.
          </div>
        </div>

        <div
          style={{
            fontSize: 28,
            fontWeight: 500,
            color: '#94A3B8',
            maxWidth: 880,
            lineHeight: 1.4,
          }}
        >
          Open-source self-hosted media streaming. Movies, TV, music — owned, encrypted, private.
        </div>

        <div
          style={{
            position: 'absolute',
            bottom: 60,
            right: 80,
            display: 'flex',
            gap: 12,
            fontSize: 20,
            fontWeight: 600,
            color: '#C4A8F5',
            letterSpacing: '0.04em',
          }}
        >
          fluxora.marshalx.dev
        </div>
      </div>
    ),
    {
      ...size,
    },
  )
}
