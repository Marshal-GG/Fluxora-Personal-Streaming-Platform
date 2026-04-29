# Monetization & Plans

## Overview
Fluxora uses a freemium model with premium tiers processed via [Polar.sh](https://polar.sh/). 
The core product offers basic media server capabilities, while premium tiers unlock advanced streaming protocols, more concurrent streams, and metadata fetching features.

## Pricing Tiers

### 1. Fluxora Core (Free)
- **Price:** ₹0 / forever
- **Target Audience:** Casual users with small local libraries.
- **Features:**
  - Unlimited personal streaming
  - All client apps included
  - Community support

### 2. Fluxora Plus
- **Price:** ₹99 / month
- **Target Audience:** Perfect for home use.
- **Description:** Unlock full HLS + WebRTC internet streaming, TMDB-powered artwork, and up to **3 simultaneous remote streams** from your personal media library.
- **Metadata**: `tier: plus`
- **Features:**
  - Hardware transcoding
  - Mobile offline downloads
  - Advanced user roles

### 3. Fluxora Pro
- **Price:** ₹199 / month
- **Target Audience:** Scaled up for power users.
- **Description:** Everything in Plus, but upgraded to allow up to **10 simultaneous remote streams** and priority support. Self-hosted, private, and fully under your control.
- **Metadata**: `tier: pro`
- **Features:**
  - Everything in Plus
  - 10 concurrent transcodes
  - Priority Support

### 4. Fluxora Ultimate
- **Price:** ₹4,499 / once
- **Target Audience:** The ultimate self-hosted experience.
- **Description:** Removes all stream limits (**unlimited simultaneous streams**) and gives you **lifetime access** with a single, one-time purchase. No renewals, ever.
- **Metadata**: `tier: ultimate`
- **Features:**
  - All Pro features forever
  - Early access to beta features
  - One-time payment

## User Flow
1. User clicks "Upgrade" or tries to access a premium feature in the Fluxora Client.
2. They are redirected to the Polar.sh checkout page.
3. User completes the payment process (currently via test mode / 100% discount codes like `TEST100`).
4. Polar sends an `order.paid` webhook to the Fluxora server.
5. The server cryptographically verifies the webhook, generates a unique license key (e.g., `FLUXORA-PLUS-YYYYMMDD-XXXXXX`), and stores it.
6. The user receives their license key to activate their server.
