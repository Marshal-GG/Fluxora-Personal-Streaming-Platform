# Product Vision & Goals

> **Category:** Product  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

## Vision Statement

**Fluxora** is a hybrid file streaming and syncing system — "Plex meets Syncthing."

The goal is to create a seamless, cross-device experience where files can be streamed or synced between a central PC server and mobile/desktop clients, automatically switching between local network (LAN) and internet connections for optimal speed and reliability.

---

## Problem Statement

Existing solutions are either:
- **Too closed** (Plex) — expensive, platform-locked, limited flexibility
- **Too complex** (Syncthing, Jellyfin) — require manual setup, poor UX
- **Not adaptive** — can't intelligently switch between LAN and internet

Fluxora bridges this gap: developer-friendly, modern UX, and smart network switching.

---

## Target Users

| Persona | Description | Pain Points |
|---------|-------------|-------------|
| Power User / Home Server Owner | Has large media libraries, serves from a home PC | Plex too expensive, Jellyfin too bare |
| Developer / Tech Enthusiast | Wants control over their own infrastructure | No open/flexible alternative |
| Content Creator | Needs to access large files remotely while traveling | Upload latency, no LAN-speed remote access |
| Family / Small Group | Shared media + file access across devices | Complex setup, no unified client |

---

## Core Goals

- [x] Build a hybrid streaming system with LAN + internet path switching
- [x] PC acts as the central server (Python/FastAPI)
- [x] Flutter client for mobile + desktop
- [x] Automatic LAN discovery via mDNS/Zeroconf
- [x] Internet fallback via WebRTC (STUN/TURN)
- [x] HLS adaptive streaming via FFmpeg pipeline
- [x] Library management with metadata (TMDB API)
- [x] Tiered monetization model
- [ ] End-to-end encryption
- [ ] AI-based file organization (Pro tier)

---

## Differentiators vs. Competitors

| Feature | Fluxora | Plex | Syncthing | Jellyfin |
|---------|---------|------|-----------|---------|
| Smart LAN/Internet switching | ✅ | ❌ | ❌ | ❌ |
| No account required | ✅ | ❌ | ✅ | ✅ |
| HLS adaptive streaming | ✅ | ✅ | ❌ | ✅ |
| Developer-friendly | ✅ | ❌ | ✅ | ✅ |
| Modern Flutter client | ✅ | ❌ | ❌ | ❌ |
| Free tier | ✅ | Limited | ✅ | ✅ |
| AI organization | ✅ (Pro) | ❌ | ❌ | ❌ |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| LAN stream latency | < 500ms | Internal testing |
| Internet stream startup | < 3s | QA benchmarks |
| Client connection success rate | > 99% | Error logging |
| Monetization conversion (Free → Paid) | > 5% | Analytics |

---

## Out of Scope (v1)

- Cloud storage hosting (files stay on user's PC)
- Mobile-to-mobile streaming (PC is always the server)
- Social features / user discovery
