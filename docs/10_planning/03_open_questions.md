# Open Questions & Research Items

> **Category:** Planning  
> **Status:** Active - Updated 2026-05-01 (Q-004 hardware encoding resolved; Q-009 honor system confirmed)

---

## Open Questions

| # | Question | Priority | Resolved? |
|---|----------|---------|-----------|
| Q-001 | Should state management be BLoC or Riverpod? | Medium | ✅ **Resolved: BLoC** (flutter_bloc v9) |
| Q-002 | Self-host TURN server vs. use a service (Twilio, Metered.ca)? Cost vs. complexity tradeoff. | High | ❌ |
| Q-003 | Should HLS segments be stored in temp dir or memory-mapped? Impact on performance with many concurrent streams. | Medium | ❌ |
| Q-004 | How to handle FFmpeg hardware encoding detection? Check at startup; fall back to software. | Low | ✅ **Resolved: `ffmpeg_service.py` selects encoder/preset/CRF from DB; user selects encoder via Settings; no runtime detection — user is responsible for selecting a supported encoder** |
| Q-005 | Payment processor for monetization — Stripe? Paddle? In-app purchases (Google/Apple)? | High | ✅ **Resolved: Polar.sh via webhooks** |
| Q-006 | License key server — self-hosted or third-party (Keygen.sh, Polar.sh)? | High | ✅ **Resolved: self-hosted Fluxora HMAC keys issued from Polar paid-order webhooks** |
| Q-007 | mDNS behavior on Android 12+ (multicast permission changes) — needs investigation | Medium | ✅ **Resolved** — `MulticastLock` acquired via `MethodChannel` in `ConnectCubit`; non-fatal on non-Android |
| Q-008 | Should `control_panel` and `client` share a Flutter monorepo with shared packages? | Low | ✅ **Resolved: Yes** — `packages/fluxora_core` |
| Q-009 | How do we prevent license key sharing or theft? Should we bind keys to a unique Server ID or require a one-time cloud activation in the future? | High | ✅ **Resolved: Honor system for Phase 4; Hardware binding planned for Phase 5** |

---

## Research Items

| # | Topic | Notes | Done? |
|---|-------|-------|-------|
| R-001 | `flutter_webrtc` package maturity and maintenance status | ✅ **Resolved** — `flutter_webrtc ^1.4.1` integrated; active maintenance, v1 plugin API (no breaking change) | ✅ |
| R-002 | `media_kit` vs `better_player` for HLS on all Flutter platforms | ✅ **media_kit v1.2.6 chosen** — `better_player` dropped (AGP 8+ incompatible) | ✅ |
| R-003 | Dart `zeroconf` package — does it support both registration and discovery? | ✅ **AsyncZeroconf required** — sync version deadlocks on FastAPI event loop | ✅ |
| R-004 | PyInstaller + FFmpeg bundling — size and startup time | Reference: `omni_bridge_server.spec` pattern | ❌ |
| R-005 | TMDB API rate limits on free tier | ✅ **Mitigated** — enrichment runs per-file during scan, not batched | ✅ |
| R-006 | STUN server reliability — Google public vs. self-hosted | ✅ **Partially resolved** — Google STUN used by default; TURN env-var support implemented (`WEBRTC_TURN_URL`, `WEBRTC_TURN_USERNAME`, `WEBRTC_TURN_CREDENTIAL`); production uptime evaluation pending | ❌ |

---

## Risks & Unknowns

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| WebRTC complexity delays Phase 3 | High | ✅ Resolved | Signaling engine complete; smart path selection + badge shipped Phase 3 |
| FFmpeg transcoding too slow on weak PCs | High | Medium | Hardware encode fallback; document minimum PC specs |
| mDNS blocked on managed/corporate networks | Medium | Medium | Manual IP entry fallback always available |
| App store approval issues (iOS) for streaming | High | Low | Review App Store guidelines; may need server-side media validation |
| TURN server costs unsustainable at scale | High | Low | Start self-hosted; model cost per user before public launch |
