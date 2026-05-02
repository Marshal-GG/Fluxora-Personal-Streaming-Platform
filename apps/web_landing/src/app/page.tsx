import type { Metadata } from 'next'
import Navbar from '@/components/Navbar'
import Hero from '@/components/Hero'
import Features from '@/components/Features'
import PopularMovies from '@/components/PopularMovies'
import LibraryTiles from '@/components/LibraryTiles'
import Screenshots from '@/components/Screenshots'
import HowItWorks from '@/components/HowItWorks'
import Pricing from '@/components/Pricing'
import Platforms from '@/components/Platforms'
import Faq from '@/components/Faq'
import AboutStrip from '@/components/AboutStrip'
import FinalCta from '@/components/FinalCta'
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
      <main id="main">
        <Hero />
        <Features />
        <PopularMovies />
        <LibraryTiles />
        <Screenshots />
        <HowItWorks />
        <Pricing />
        <Platforms />
        <Faq />
        <AboutStrip />
        <FinalCta />
      </main>
      <Footer />
    </>
  )
}
