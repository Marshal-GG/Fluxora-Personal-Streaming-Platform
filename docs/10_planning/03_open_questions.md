# Open Questions & Research Items

> **Category:** Planning  
> **Status:** Active — Updated 2026-04-27

---

## Open Questions

| # | Question | Priority | Resolved? |
|---|----------|---------|-----------|
| Q-001 | Should state management be BLoC or Riverpod? Evaluate at Phase 2 kickoff based on team familiarity. | Medium | ❌ |
| Q-002 | Self-host TURN server vs. use a service (Twilio, Metered.ca)? Cost vs. complexity tradeoff. | High | ❌ |
| Q-003 | Should HLS segments be stored in temp dir or memory-mapped? Impact on performance with many concurrent streams. | Medium | ❌ |
| Q-004 | How to handle FFmpeg hardware encoding detection? Check at startup; fall back to software. | Low | ❌ |
| Q-005 | Payment processor for monetization — Stripe? Paddle? In-app purchases (Google/Apple)? | High | ❌ |
| Q-006 | License key server — self-hosted or third-party (Keygen.sh, Polar.sh)? | High | ❌ |
| Q-007 | mDNS behavior on Android 12+ (multicast permission changes) — needs investigation | Medium | ❌ |
| Q-008 | Should `control_panel` and `client` share a Flutter monorepo with shared packages? | Low | ❌ |

---

## Research Items

| # | Topic | Notes | Done? |
|---|-------|-------|-------|
| R-001 | `flutter_webrtc` package maturity and maintenance status | Check pub.dev activity, GitHub issues | ❌ |
| R-002 | `media_kit` vs `better_player` for HLS on all Flutter platforms | Compare codec support, iOS/Android background audio | ❌ |
| R-003 | Dart `zeroconf` package — does it support both registration and discovery? | Check if server-side Dart Zeroconf is needed or only Python side | ❌ |
| R-004 | PyInstaller + FFmpeg bundling — size and startup time | Reference: `omni_bridge_server.spec` pattern | ❌ |
| R-005 | TMDB API rate limits on free tier | Ensure library scans don't hit limits | ❌ |
| R-006 | STUN server reliability — Google public vs. self-hosted | Evaluate uptime requirements | ❌ |

---

## Risks & Unknowns

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| WebRTC complexity delays Phase 3 | High | Medium | Timebox; use `flutter_webrtc` + reference implementations |
| FFmpeg transcoding too slow on weak PCs | High | Medium | Hardware encode fallback; document minimum PC specs |
| mDNS blocked on managed/corporate networks | Medium | Medium | Manual IP entry fallback always available |
| App store approval issues (iOS) for streaming | High | Low | Review App Store guidelines; may need server-side media validation |
| TURN server costs unsustainable at scale | High | Low | Start self-hosted; model cost per user before public launch |
