import type { MetadataRoute } from 'next'

export const dynamic = 'force-static'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      { userAgent: '*', allow: '/', disallow: ['/api/'] },
    ],
    sitemap: 'https://fluxora.marshalx.dev/sitemap.xml',
    host: 'https://fluxora.marshalx.dev',
  }
}
