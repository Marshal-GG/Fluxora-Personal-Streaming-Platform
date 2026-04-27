import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Fluxora — Self-Hosted Media Streaming',
  description:
    'Stream your personal media library to any device. Instant on your home network, seamless over the internet. No subscriptions, no cloud, no accounts.',
  openGraph: {
    title: 'Fluxora — Self-Hosted Media Streaming',
    description: 'Your media library, anywhere. Self-hosted, zero subscriptions.',
    url: 'https://fluxora.marshalx.dev',
    siteName: 'Fluxora',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Fluxora — Self-Hosted Media Streaming',
    description: 'Your media library, anywhere. Self-hosted, zero subscriptions.',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  )
}
