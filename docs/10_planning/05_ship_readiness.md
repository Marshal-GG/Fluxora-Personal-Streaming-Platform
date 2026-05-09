# Ship Readiness — v1

> **Category:** Planning
> **Status:** Active — Updated 2026-05-08 (streaming pipeline §16 + §17 + same-day real-device follow-on patches all shipped on top of the mobile redesign + settings remediation closure earlier same day; uniform `-loglevel info`, new `services/ffmpeg_capabilities.py` version probe, transcode-only capability-gated `-readrate 1.5` + `-readrate_initial_burst 30`, end-to-end `playlistOffsetSec` plumbing for source-time scrubber after seek-restart, mobile `_ProgressBar` Stateful drag-preview state.  Mobile redesign M10/M11/M12 + settings remediation plan M1–M5 + M2.5 server endpoint all closed earlier same day; Profile-as-settings rebuilt from "8 of 11 dead-tap" to "8 live + 2 honestly-stubbed"; bearer-only `PATCH /api/v1/auth/clients/me` self-rename endpoint; `connectivity_plus`-backed Wi-Fi-only enforcement in `PlayerCubit.startStream`; audit §17.3 #8 (Notifications FIFO cap parity) + #9-Custom (sleep-timer `showTimePicker`).  **Server suite 698; mobile suite 78; desktop 90; core 8.**  Settings remediation plan archived to [`docs/10_planning/archive/15_mobile_settings_remediation_plan.md`](./archive/15_mobile_settings_remediation_plan.md).  Audit §17.3 #1 (iOS PIP) + #7 (player-overlay goldens — folds into M14) + #9-End-of-episode (needs next-episode resolver) remain the only mobile-redesign opens.  M13 (host-a-server shell — Phase 5+ runtime gate) + M14 (goldens + a11y) are the only redesign milestones still open.) 2026-05-07 (mobile UI row flipped to ✅ — Groups v2 mobile shipped completes the redesign rollout)
> **Purpose:** "Can we ship?" synthesis. What v1's architecture deliberately doesn't need, what's actually blocking the door, and the distribution-side gaps the rest of the docs don't cover. References [`04_manual_tasks.md`](./04_manual_tasks.md) for individual task detail rather than duplicating it.

---

## What v1 deliberately does NOT need

These are common "before-launch" assumptions that **don't apply** to Fluxora's v1 single-tenant model. Each user runs their own server; there is no central backend to stand up.

| ❌ Not needed for v1 | Why |
|---|---|
| **User accounts / login system** | Auth is **pairing-based** via HMAC bearer tokens. Each user's mobile/desktop pairs with their own server. There is no central user identity, no signup form, no password reset. See [`docs/06_security/01_security.md`](../06_security/01_security.md) §Pairing & Tokens. |
| **Cloud Functions / serverless tier** | The Polar webhook lands directly on the home server via the Cloudflare Tunnel (`fluxora-api.marshalx.dev/api/v1/webhook/polar`). No intermediate function. See [`docs/05_infrastructure/02_polar_webhook_deployment.md`](../05_infrastructure/02_polar_webhook_deployment.md). |
| **Hosted user database** | Each server has its own SQLite. Library/clients/orders/notifications are local. License keys are HMAC-signed strings — verification is offline + stateless ([`docs/06_security/02_license_key_operations.md`](../06_security/02_license_key_operations.md)). |
| **Self-hosted TURN** | WebRTC falls back to HLS-over-tunnel when ICE fails. TURN is a "when a real user complains about cellular" task, tracked in [`04_manual_tasks.md`](./04_manual_tasks.md). |
| **Multi-tenant `*.fluxora.cloud` infra** | That's the v2 plan, explicitly out-of-scope for v1 ship. See ADR-013 in [`02_decisions.md`](./02_decisions.md). |
| **Per-user SSL certs / wildcard ACM** | One Universal SSL cert covers `fluxora-api.marshalx.dev`. Multi-tenant subdomain certs are a v2 concern. |
| **Ops on-call / paging** | UptimeRobot email alerts + Cloudflare tunnel health alerts are sufficient for solo operator. No PagerDuty needed. |

The point of v1's architecture is exactly this: **"Plex without the cloud account."** Don't accidentally rebuild what we deliberately removed.

---

## Hard ship blockers (paid product can't go public without these)

These three together gate the public-launch / first-paying-customer line. Total wall time: ~20 minutes.

| # | Blocker | Where | Time |
|---|---------|-------|------|
| 1 | **Wire real Polar checkout URLs** in `Pricing.tsx` (placeholders today; Plus/Pro/Ultimate buttons hit invalid URLs) | [`apps/web_landing/src/components/Pricing.tsx`](../../apps/web_landing/src/components/Pricing.tsx) lines 6–9 | ~5 min |
| 2 | **Cut Polar webhook over from smee.io → public URL** in Polar dashboard | Polar dashboard → Webhooks | ~3 min |
| 3 | **Rotate `TOKEN_HMAC_KEY` and `FLUXORA_LICENSE_SECRET`** before first real customer (dev-era values may have leaked into terminal scrollback / IDE history) | `~/.fluxora/.env` | ~10 min |

All three are tracked individually in [`04_manual_tasks.md`](./04_manual_tasks.md) under "Pending."

---

## Streaming pipeline regressions (demo-visible)

Surfaced 2026-05-05 during user-acceptance testing.  Not infra blockers but visible the moment anyone touches the seek bar or HDR toggle in a demo — should be fixed before any public-facing recording, screenshot, or first-paying-customer onboarding.

| Defect | Why | Where tracked |
|--------|-----|---------------|
| **HDR→SDR toggle silently fails** ("code error 1") | 10 s playlist timeout kills FFmpeg right as it finishes the first tonemapped segment. Tonemap is CPU-only (~0.6× realtime) so first segment lands at ~10 wall-seconds. | [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md) §3.2 |
| **Seek ahead 404s or hangs** | No `-ss` restart. FFmpeg only ever encodes from `t=0`; segments past the encoded boundary don't exist; router waits 5 s then 404. | [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md) §3.1 |
| **GPU/CPU pegs after rapid stream re-spins** | Mobile cubit's `setTonemap` / `startStream` cycle can leave a previous FFmpeg orphaned if the dispose path's network call fails or the app is backgrounded mid-toggle. | [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md) §3.3 |
| **HDR sources look washed out** on SDR mobile displays even with HDR badge showing | media_kit (libmpv on Android) does no display-side tonemap. Server-side tonemap is the only fix and depends on the row above shipping. | [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md) §3.4 |

Plan covers six additional non-headline issues (zombie FFmpeg accumulation, missing session-dir cleanup on failure, log rotation, etc.) — see [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md) §4.

**Sequencing:** four commits, ~1.5 days work end-to-end. Commit 1 (tonemap unblock + diagnostic upgrade) is independently shippable and unblocks the most visible demo issue immediately.

---

## Strongly-recommended pre-launch hardening

Not strictly blocking, but you'll want them on before announcing externally. All UI-clicks-only, no code:

| Task | Why | Where tracked |
|------|-----|---------------|
| Cloudflare WAF custom rules on `fluxora-api.marshalx.dev` (block empty UA, oversized bodies, edge rate-limit `/auth/request-pair`) | Defense in depth at the edge before requests touch FastAPI | [`04_manual_tasks.md`](./04_manual_tasks.md) |
| Cloudflare tunnel health alerts (email when "Inactive" > 5 min) | Otherwise tunnel-down silently 502s every off-LAN client | [`04_manual_tasks.md`](./04_manual_tasks.md) |
| UptimeRobot HTTP monitor on `/healthz` | Independent uptime signal | [`04_manual_tasks.md`](./04_manual_tasks.md) |
| Sentry DSN in server `.env` (code is wired; just paste the key) | Production error visibility with full stack trace | [`04_manual_tasks.md`](./04_manual_tasks.md) |
| GitHub `production` + `uat` environments configured | Otherwise CI deploy gates are silently bypassed (workflows reference these names) | [`04_manual_tasks.md`](./04_manual_tasks.md) |
| Verify `cloudflared` service auto-restarts on PC reboot | The reboot path has never actually been tested since the registry override | [`04_manual_tasks.md`](./04_manual_tasks.md) |
| Cloudflare Access on admin paths | Optional defense-in-depth on `/auth/approve`, `/auth/revoke`, `/info/restart`, etc. | [`04_manual_tasks.md`](./04_manual_tasks.md) |

---

## Distribution gaps (not blocking infra; **are** blocking actual install)

These are real ship-blockers that the rest of the docs don't currently cover. Each has a matching entry in [`04_manual_tasks.md`](./04_manual_tasks.md) for tracking. **Concrete packaging plan (10-item installer checklist, auto-update via Squirrel/Sparkle, Windows Service auto-restart, etc.) lives in [`06_installer_plan.md`](./06_installer_plan.md) — proposed, awaiting owner decision on §"Open decisions for the owner".**

| Gap | What's missing | Why it bites at launch |
|-----|----------------|------------------------|
| **Server `.exe` code signing (Windows)** | PyInstaller produces `dist/fluxora-server.exe`, but it's unsigned. Windows SmartScreen scares every download with a red "unrecognized publisher" dialog. | First install friction is brutal — most users will close the dialog. Need an EV / OV code-signing cert (~$200/yr from Sectigo/DigiCert) and `signtool.exe` step in the build pipeline. |
| **Desktop app installer + signing** | The Flutter desktop ships as a folder of files today, not a real installer. No `.msix` (Win), `.dmg` (macOS), or `.AppImage`/`.deb` (Linux). No Apple notarization story. | Users can't double-click to install. Mac install is impossible without notarization (Gatekeeper blocks). |
| **Mobile store submission** | Android needs a Play Console account ($25 one-time), upload keystore, store listing, screenshots, content rating, privacy policy URL. iOS needs Apple Developer Program ($99/yr), App Store Connect listing, TestFlight beta, full review (3–7 day cycle on first submit). | Multi-day calendar time, not multi-minute. iOS in particular has soft rejection risks around "streaming app must demonstrate first-party content rights" — see Risk row in [`03_open_questions.md`](./03_open_questions.md). |

---

## Polish gaps (look weak but won't block ship)

| Gap | Status |
|-----|--------|
| **Mobile UI redesign** | ✅ M0–M9 complete 2026-05-03; Phase A + B real-data backfill complete 2026-05-04; player polish (PIP + audio_service + bg toggle) added 2026-05-04; seek-restart wire-up landed 2026-05-05; Groups v2 mobile UX (M4 + M6 + M8) shipped 2026-05-07.  Mobile is now V2-pure end-to-end.  Plan in [`docs/11_design/mobile_redesign_plan.md`](../11_design/mobile_redesign_plan.md). |
| **Real Dashboard screenshot on landing page** | Currently a faux mockup; tracked in [`04_manual_tasks.md`](./04_manual_tasks.md). |
| **Footer placeholder links** (Documentation, Help Center, Status, Roadmap, Blog, Discord, X/Twitter) | Tracked in [`04_manual_tasks.md`](./04_manual_tasks.md). |

---

## Recommended ship paths

Pick one — these are not all-or-nothing.

### Path A — Soft launch / friends-and-family beta

**Time:** ~30 minutes of UI clicks + however long the desktop installer takes you to figure out.

1. Do the 3 hard blockers above (~20 min).
2. Hand-distribute the Windows server `.exe` + desktop folder + sideloaded Android APK to people who already trust you. Skip code-signing (they'll click through SmartScreen).
3. Skip iOS — TestFlight invite-only is fine if you already have an Apple Developer account.

### Path B — Public launch with paying strangers

**Time:** weeks, mostly waiting on store reviews and cert issuance.

1. All of Path A.
2. Strongly-recommended hardening (~1–2 hours of UI clicks).
3. Order EV code-signing cert (1–5 business days for issuance + identity verification).
4. Build Windows `.msix` + macOS `.dmg` + notarize.
5. Submit Play Store + App Store. Plan for 1 round of soft rejection on iOS.
6. Wait on cert delivery → sign installers → final smoke test.

### Path C — "Just the desktop and self-hosted server, no mobile, no payments"

**Time:** ~10 minutes.

1. Skip blockers 1 + 2 (no Polar checkout if you're not selling).
2. Do blocker 3 (rotate secrets) just for hygiene.
3. Distribute the unsigned `.exe` + desktop folder to your own LAN.

This is genuinely useful as the "I built a Plex for myself" outcome. Don't let "but it's not perfect for strangers yet" stop you from running v1 as your own daily driver.

---

## Cross-references

- [`01_roadmap.md`](./01_roadmap.md) — phase-by-phase feature status
- [`02_decisions.md`](./02_decisions.md) — ADRs, including v2 multi-tenant plan
- [`04_manual_tasks.md`](./04_manual_tasks.md) — canonical task tracker for every item above
- [`../05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) — Cloudflare Tunnel setup (Phase 1 complete; Phase 6 hardening = the recommended-hardening list above)
- [`../05_infrastructure/runbooks/10_pyinstaller_distribution.md`](../05_infrastructure/runbooks/10_pyinstaller_distribution.md) — server `.exe` build pattern (does NOT yet cover signing)
