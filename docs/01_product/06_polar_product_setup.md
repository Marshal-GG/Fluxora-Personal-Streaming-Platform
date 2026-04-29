# Polar.sh Product Setup Guide

This document contains the exact configuration required to set up the Fluxora products on [Polar.sh](https://polar.sh/). 

## Important Configuration Note
For all products, the **Metadata** key `tier` is mandatory. The Fluxora server uses this value to determine which type of license key to generate.

---

## Product 1: Fluxora Plus
- **Name**: Fluxora Plus
- **Pricing**:
  - **Type**: Recurring subscription
  - **Cycle**: Every 1 month
  - **Currency**: INR
  - **Price Type**: Fixed price
  - **Price**: 99.00
- **Automated Benefits**: Leave as "No benefits available" (The Fluxora server handles fulfillment via webhooks).
- **Metadata**:
  - **Key**: `tier`
  - **Value**: `plus`
- **Customer Portal**: Public
- **Description (Markdown)**:
  ```markdown
  **Perfect for home use.** 
  Unlock full HLS + WebRTC internet streaming, TMDB-powered artwork, and up to **3 simultaneous remote streams** from your personal media library.
  *You will receive your FLUXORA license key shortly after purchase to activate your server.*
  ```

---

## Product 2: Fluxora Pro
- **Name**: Fluxora Pro
- **Pricing**:
  - **Type**: Recurring subscription
  - **Cycle**: Every 1 month
  - **Currency**: INR
  - **Price Type**: Fixed price
  - **Price**: 199.00
- **Automated Benefits**: Leave as "No benefits available"
- **Metadata**:
  - **Key**: `tier`
  - **Value**: `pro`
- **Customer Portal**: Public
- **Description (Markdown)**:
  ```markdown
  **Scaled up for power users.** 
  Everything in Plus, but upgraded to allow up to **10 simultaneous remote streams** and priority support. Self-hosted, private, and fully under your control.
  *You will receive your FLUXORA license key shortly after purchase to activate your server.*
  ```

---

## Product 3: Fluxora Ultimate
- **Name**: Fluxora Ultimate
- **Pricing**:
  - **Type**: One-time purchase
  - **Currency**: INR
  - **Price Type**: Fixed price
  - **Price**: 4499.00
- **Automated Benefits**: Leave as "No benefits available"
- **Metadata**:
  - **Key**: `tier`
  - **Value**: `ultimate`
- **Customer Portal**: Public
- **Description (Markdown)**:
  ```markdown
  **The ultimate self-hosted experience.** 
  Removes all stream limits (**unlimited simultaneous streams**) and gives you **lifetime access** with a single, one-time purchase. No renewals, ever.
  *You will receive your FLUXORA lifetime license key shortly after purchase to activate your server.*
  ```
