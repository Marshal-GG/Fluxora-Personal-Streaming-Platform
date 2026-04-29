import type { Metadata } from 'next'
import Navbar from '@/components/Navbar'
import Hero from '@/components/Hero'
import Features from '@/components/Features'
import HowItWorks from '@/components/HowItWorks'
import Pricing from '@/components/Pricing'
import Platforms from '@/components/Platforms'
import Footer from '@/components/Footer'

export const metadata: Metadata = {
  alternates: {
    canonical: 'https://fluxora.marshalx.dev',
  },
}

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <div className="divider" />
        <Features />
        <div className="divider" />
        <HowItWorks />
        <div className="divider" />
        <Pricing />
        <Platforms />
      </main>
      <Footer />
    </>
  )
}
