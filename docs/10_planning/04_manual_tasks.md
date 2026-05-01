# Manual / External Tasks

> **Category:** Planning
> **Status:** Active — open list

Tasks that require a **human at a UI somewhere** — third-party signups, dashboard configuration, one-off operational steps. They're "blocked on a person doing the thing" rather than "blocked on code being written."

Code-side TODOs live with the code (`grep -rn "TODO\|FIXME" .`) or as GitHub issues. This file is for the external/operational items that don't fit either of those.

---

## Status legend

| Symbol | Meaning |
|--------|---------|
| 🔲 | Not started |
| 🔵 | In progress |
| ✅ | Done — move to "Recently completed" section |
| ❌ | Cancelled — keep with rationale |

---

## Pending

### 🔲 UptimeRobot monitor for `/healthz`

- **What:** sign up at [uptimerobot.com](https://uptimerobot.com) (free tier — 50 monitors, 5-min interval), add an HTTP(S) monitor pointed at `https://fluxora-api.marshalx.dev/api/v1/healthz`, add an email alert contact.
- **Why:** automated detection of tunnel-down / FastAPI-down without checking manually.
- **Prereqs:** Phase 2 of the routing plan must ship first (the `/healthz` endpoint doesn't exist yet — see [`../05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) §Phase 2.5).
- **Time:** ~5 min UI clicks once `/healthz` is live.
- **Doc:** [`runbooks/09_monitoring_and_observability.md`](../05_infrastructure/runbooks/09_monitoring_and_observability.md) § Tier 1.
- **Owner:** project owner.

### 🔲 Sentry project + DSN

- **What:** create a Sentry project at [sentry.io](https://sentry.io) (free tier covers 5k errors/month + 10k performance events). Copy the project's DSN. Paste into `~/.fluxora/.env` (or platform data dir) as:
  ```
  SENTRY_DSN=https://<key>@<id>.ingest.us.sentry.io/<project>
  SENTRY_TRACES_SAMPLE_RATE=0.0
  ```
- **Why:** capture unhandled exceptions with full context (stack trace, request, release tag).
- **Prereqs:** none — server code is wired ([`apps/server/main.py`](../../apps/server/main.py) `_init_sentry()`). Empty DSN = no init = zero overhead, so the absence of this task isn't blocking anything.
- **Time:** ~5 min UI clicks.
- **Trigger:** before public launch, OR sooner if you want production-error visibility on a current deployment.
- **Doc:** [`runbooks/09_monitoring_and_observability.md`](../05_infrastructure/runbooks/09_monitoring_and_observability.md) § Tier 2.
- **Owner:** project owner.

### 🔲 Delete stale `api.fluxora.marshalx.dev` CNAME

- **What:** Cloudflare DNS dashboard → `marshalx.dev` zone → delete the unused `api.fluxora` CNAME (left over from the first tunnel attempt before pivoting to single-level subdomain).
- **Why:** harmless (no cert was ever issued for it, requests just fail) but adds visual noise to the DNS panel.
- **Prereqs:** none.
- **Time:** ~1 min.
- **Trigger:** any time.
- **Doc:** see [`../05_infrastructure/04_domains_and_subdomains.md`](../05_infrastructure/04_domains_and_subdomains.md) § Phase 1 setup record.
- **Owner:** project owner.

### 🔲 Cleanup: stale systemprofile `cloudflared` dir

- **What:** in admin PowerShell, `Remove-Item -Recurse -Force "C:\Windows\System32\config\systemprofile\.cloudflared"`. Restart the service afterward to confirm it still runs.
- **Why:** the `cloudflared` Windows service used to read config from this path; after the registry `ImagePath` override (Phase 1 workaround), the service reads from the user-level config and this dir is unused clutter.
- **Prereqs:** ImagePath registry override must already be in place (it is — see [`../05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) §Phase 1 step 6).
- **Time:** ~30 sec.
- **Trigger:** any time.
- **Owner:** project owner.

### 🔲 Bump `cloudflared` to latest

- **What:** run `winget upgrade Cloudflare.cloudflared` (currently no upgrade available — winget catalog lags behind Cloudflare's release cadence). When winget catches up, run the upgrade and `Restart-Service Cloudflared` afterward.
- **Why:** running on `2025.8.1`; Cloudflare warns it's outdated (current is `2026.3.0`+). Tunnel still works fine — purely a "stay current" task.
- **Prereqs:** none, when `winget` finally has the version.
- **Time:** ~2 min.
- **Trigger:** when `winget upgrade Cloudflare.cloudflared` shows an update available, or quarterly review.
- **Owner:** project owner.

### 🔲 Polar webhook endpoint cutover (smee.io → public URL)

- **What:** in Polar dashboard → Webhooks → edit the production endpoint from the smee.io tunnel URL to `https://fluxora-api.marshalx.dev/api/v1/webhook/polar`. Keep smee.io as the dev/testing endpoint.
- **Why:** smee.io is for local dev only ([`runbooks/06_webhook_testing_with_smee.md`](../05_infrastructure/runbooks/06_webhook_testing_with_smee.md)); production webhooks should hit the home server directly via the tunnel.
- **Prereqs:** Phase 2 of the routing plan must ship first AND Polar webhook secret must be configured server-side.
- **Time:** ~3 min.
- **Trigger:** any time after Phase 2 of routing lands.
- **Doc:** [`../05_infrastructure/02_polar_webhook_deployment.md`](../05_infrastructure/02_polar_webhook_deployment.md).
- **Owner:** project owner.

### 🔲 Set up GitHub `production` + `uat` environments

- **What:** GitHub repo → Settings → Environments. Create two environments:
  - **`production`** — deployment branches: `main` only; required reviewers: project owner (yourself); URL: `https://fluxora.marshalx.dev`.
  - **`uat`** — deployment branches: `uat` only; no reviewers (auto-deploy); URL: `https://uat.fluxora.marshalx.dev`.
- **Why:** the `web_landing_ci.yml` workflow references `environment: production` / `environment: uat`. **If those environments don't exist in GitHub, the deploy gate is silently ignored** — pushes to `main` deploy to live with no review.
- **Prereqs:** none.
- **Time:** ~5 min.
- **Doc:** [`runbooks/04_branch_and_pr_workflow.md`](../05_infrastructure/runbooks/04_branch_and_pr_workflow.md) §Step 2.
- **Owner:** project owner.

### 🔲 Add CI secrets to GitHub

- **What:** GitHub repo → Settings → Secrets and variables → Actions. Verify these exist:
  - **`FIREBASE_SERVICE_ACCOUNT_FLUXORA_STREAMING_PLATFORM`** — service account JSON for `web_landing_ci.yml` deploys. Generate via `firebase init hosting:github` or manually in Google Cloud IAM.
  - **`PUBLIC_REPO_TOKEN`** — fine-grained PAT scoped to the public-mirror repo with write access. Required by `mirror-public.yml`.
- **Why:** without these, `web_landing_ci.yml` and `mirror-public.yml` fail at deploy / push steps. The workflows reference the names — adding them is a one-time UI step.
- **Prereqs:** Firebase project + public mirror repo must already exist.
- **Time:** ~10 min combined.
- **Doc:** [`runbooks/03_github_ci_cd.md`](../05_infrastructure/runbooks/03_github_ci_cd.md) §Required GitHub secrets.
- **Owner:** project owner.

### 🔲 Verify `cloudflared` service auto-starts on PC reboot

- **What:** reboot the home PC (or stop+start it via VM lifecycle if relevant). Wait 60 sec. Run `sc.exe query Cloudflared` — confirm `STATE: 4 RUNNING`. Hit `https://fluxora-api.marshalx.dev/api/v1/info` from another network and confirm response.
- **Why:** Phase 1 set up the service to auto-start, but the registry-override workaround was added after install. The reboot path hasn't actually been tested. If it breaks, the next reboot drops the public URL silently.
- **Prereqs:** ability to schedule a PC reboot.
- **Time:** ~5 min including the reboot.
- **Owner:** project owner.

### 🔲 Quarterly: backup verification drill

- **What:** run the restore drill from [`runbooks/05_backup_and_recovery.md`](../05_infrastructure/runbooks/05_backup_and_recovery.md) §"Backup verification" — restore latest backup to a temp location and confirm the server starts + library queries return.
- **Why:** a backup you've never restored from is a hopeful prayer, not a backup. Catches silent-corruption / partial-backup / changed-paths issues before you actually need the backup.
- **Prereqs:** a recent backup exists.
- **Time:** ~15 min per drill.
- **Cadence:** quarterly (every ~3 months). Track last-run date inline below.
- **Last run:** never (set initial baseline on first drill).
- **Owner:** project owner.

### 🔲 Pre-launch: rotate `TOKEN_HMAC_KEY` and `FLUXORA_LICENSE_SECRET`

- **What:** generate fresh values for both secrets via `python -c "import secrets; print(secrets.token_hex(32))"`, write to `~/.fluxora/.env`. Restart server.
- **Why:** these secrets were generated during initial dev setup and may have been pasted into terminal scrollback / IDE settings / chat tools at some point. Before going public, rotate to clean values that have only ever existed in `.env`.
- **Side effects of rotating:**
  - `TOKEN_HMAC_KEY` rotation: every paired client must re-pair (mobile + desktop). For a solo deployment, ~2 minutes of friction.
  - `FLUXORA_LICENSE_SECRET` rotation: every issued license key becomes invalid. See [`../06_security/02_license_key_operations.md`](../06_security/02_license_key_operations.md) §Rotation for the customer-comms flow. Skip if no license keys have been issued yet.
- **Prereqs:** all paying customers (if any) have been notified about the license-key reissuance window.
- **Time:** ~10 min for the keys themselves; potentially hours for customer comms if license keys exist.
- **Trigger:** before announcing the project publicly / accepting first real paying customer.
- **Owner:** project owner.

### 🔲 Process the Dependabot PR queue (19 PRs from first run)

- **What:** triage and merge per the plan in [`runbooks/11_dependabot_triage.md`](../05_infrastructure/runbooks/11_dependabot_triage.md).
  - **Round 1 — instant wins (10 PRs):** #4, #8, #9, #10, #11, #14, #15, #16, #17, #19. All passed local tests against current `main`. Merge from GitHub UI one at a time, watching CI between each.
  - **Round 2 — paired (2 PRs):** #12 (`pytest-asyncio 1.3`) **then** #13 (`pytest 9`). #13 alone fails install because of pytest-asyncio constraint; #12 first unblocks #13.
  - **Round 3 — needs prep, already done (1 PR):** #20 (`flutter_lints` 6 in core). Prep commit `9549645` is on `main` (removed `library fluxora_core;` declaration that flutter_lints 6 flags). Click "Update branch" on the PR, then merge.
  - **Close — coupled blocker (1 PR):** #18 (`flutter_secure_storage 10` in core). Bumping it in `packages/fluxora_core` alone breaks `apps/mobile` and `apps/desktop`, both of which separately pin `^9.x`. Needs a manual cross-pubspec PR — open one when ready.
  - **Close — Action majors (5 PRs):** #2, #3, #5, #6, #7. The pending `dependabot.yml` ignore-rule edit prevents these from being re-opened.
- **Why:** outstanding PR queue noise; CI signals dilute; merge confidence decays the longer they sit.
- **Prereqs:** push the `dependabot.yml` ignore-rule for Actions majors before closing #2/#3/#5/#6/#7 (otherwise they'll re-open on next Dependabot run).
- **Time:** ~30 min total (~1 min per merge × 13 merges + ~5 min for paired/prep dance).
- **Doc:** [`runbooks/11_dependabot_triage.md`](../05_infrastructure/runbooks/11_dependabot_triage.md).
- **Owner:** project owner.


### 🔲 Stand up self-hosted TURN at `turn.fluxora.marshalx.dev`

- **What:** install `coturn` on the home PC (or a small VPS), expose it through a second Cloudflare Tunnel ingress on `turn.fluxora.marshalx.dev`, point `webrtc_service` STUN/TURN config at it. Replaces the free public STUN-only fallback with an authenticated TURN relay for clients behind symmetric NATs (mobile carriers, double-NAT home routers).
- **Why:** WebRTC currently falls back to HLS over the tunnel when ICE fails — that's correct but slow. A self-hosted TURN relay carries the failed-P2P path without burning Cloudflare bandwidth (TURN traffic is UDP/TCP-relay, not HTTP, so it doesn't go through the existing tunnel). Mobile users on cellular networks routinely hit symmetric NAT.
- **Prereqs:** TURN credentials secret added to `~/.fluxora/.env` (e.g. `FLUXORA_TURN_SECRET`); `webrtc_service.py` `_ICE_SERVERS` list updated to include the new TURN URL with `username` + `credential`; client `flutter_webrtc` config likewise; firewall opens UDP 3478 + TCP 5349 (TLS) on the home PC. Plan + costs in [`../05_infrastructure/06_webrtc_and_turn.md`](../05_infrastructure/06_webrtc_and_turn.md).
- **Time:** ~2 hours for the install + tunnel ingress; another 1-2 hours for client wiring + smoke tests on cellular.
- **Trigger:** when at least one user reports WebRTC failures from cellular / restrictive networks. Not urgent for solo / LAN-mostly deployments.
- **Owner:** project owner.

### 🔲 Cloudflare WAF custom rules for the public tunnel hostname

- **What:** in the Cloudflare dashboard for `marshalx.dev`, add WAF custom rules scoped to `(http.host eq "fluxora-api.marshalx.dev")`:
  1. Block requests with empty / missing `User-Agent` header.
  2. Block requests with bodies > 25 MB (Fluxora's largest legitimate request is a small JSON; uploads happen on LAN).
  3. Rate-limit `/api/v1/auth/request-pair` to 30 requests / IP / hour at the edge (server-side `slowapi` already does 5/min, the edge rule is defense in depth).
- **Why:** the tunnel exposes the FastAPI server to the public internet. Server-side already rate-limits and validates input, but cheap edge rules drop the most common scanner / bot junk before it reaches `cloudflared`.
- **Prereqs:** Cloudflare account, dashboard access to the `marshalx.dev` zone.
- **Time:** ~15 min to author + smoke-test the three rules.
- **Trigger:** before announcing the public URL externally / accepting non-trusted clients.
- **Owner:** project owner.

### 🔲 Cloudflare tunnel health alerts

- **What:** in the Cloudflare Zero Trust dashboard → Networks → Tunnels → `fluxora-home`, enable health notifications: email when the tunnel goes "Inactive" (cloudflared daemon stops sending heartbeats) for > 5 min.
- **Why:** the public URL silently 502s when the tunnel is down — paired clients off-LAN fail with no diagnostic. An email alert is the cheapest possible signal that the home PC needs attention.
- **Prereqs:** Cloudflare Zero Trust enabled on the account (free for personal use).
- **Time:** ~5 min.
- **Trigger:** before announcing the public URL externally.
- **Owner:** project owner.

### 🔲 Cloudflare Access on admin paths (defense in depth)

- **What:** in Cloudflare Zero Trust → Access → Applications, add a self-hosted application matching `fluxora-api.marshalx.dev/api/v1/auth/approve*` + `/auth/reject*` + `/auth/revoke*` + `/auth/clients` + `/orders*` + `/settings*` + `/info/restart` + `/info/stop`, gated by an Access policy of "email matches owner". Anything matching the policy gets a one-click email-OTP login at the edge before the request reaches FastAPI.
- **Why:** these endpoints are already localhost-only (`require_local_caller` rejects any tunneled request, and the Phase 2 server middleware double-checks via `CF-Connecting-IP`). Adding Cloudflare Access in front is defense-in-depth — if a future bug ever weakens the server-side localhost gate, the edge still requires owner identity.
- **Prereqs:** Cloudflare Zero Trust account, owner email registered.
- **Time:** ~20 min.
- **Trigger:** optional. Skip unless the threat model expands to assume potential server-side bypasses.
- **Owner:** project owner.

### 🔲 Long-term: decide whether to register `fluxora.cloud`

- **What:** if v2 multi-tenant becomes a real plan, register `fluxora.cloud` (or another single-purpose TLD) so per-user subdomains (`<user>.fluxora.cloud`) get free Universal SSL. Alternative: pay $10/mo for Cloudflare ACM on `*.fluxora.marshalx.dev`.
- **Why:** v2 multi-tenant requires per-user subdomains at depth, which Cloudflare's free Universal SSL doesn't cover. Either pay ACM monthly or buy a dedicated TLD once.
- **Prereqs:** v2 multi-tenant has actual user demand / commitment to ship.
- **Time:** ~10 min to register; days to migrate marketing site.
- **Trigger:** at v2 kickoff, not before. See [`../05_infrastructure/04_domains_and_subdomains.md`](../05_infrastructure/04_domains_and_subdomains.md) §Brand-domain options for the migration plan.
- **Owner:** project owner.

---

## Recently completed

Move items here once done; prune entries older than ~3 months to keep this readable.

- ✅ **Phase 1 of public routing** — Cloudflare Tunnel `fluxora-home` live at `fluxora-api.marshalx.dev` (2026-05-01). See [`../05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) §Phase 1.
- ✅ **Dart SDK floor bumped 3.8 → 3.9** (2026-05-01). CI Flutter pin moved 3.32.0 → 3.41.3 in `desktop_ci.yml` + `mobile_ci.yml`. All three pubspecs now declare `sdk: '>=3.9.0 <4.0.0'`. Removed previously held ceilings on `json_annotation`, `json_serializable`, `build_runner`, and `go_router` — Dependabot's existing latest pins (`json_annotation ^4.11`, `json_serializable ^6.13`, `build_runner ^2.14`, desktop `go_router ^17.2`) now resolve cleanly.

---

## What's NOT in this file

- **Code-side TODOs** — leave them as `# TODO:` comments next to the code, or open GitHub issues. Two trackers for the same work is one too many.
- **Future feature ideas** — those go in [`01_roadmap.md`](./01_roadmap.md).
- **Architectural questions** — those go in [`03_open_questions.md`](./03_open_questions.md).
- **Decisions already made** — those go in [`02_decisions.md`](./02_decisions.md) as ADRs.

---

## Cross-references

- [`01_roadmap.md`](./01_roadmap.md) — feature roadmap by phase
- [`02_decisions.md`](./02_decisions.md) — ADRs
- [`03_open_questions.md`](./03_open_questions.md) — unresolved architectural questions
- [`../05_infrastructure/runbooks/`](../05_infrastructure/runbooks/) — reusable runbooks for the patterns these tasks touch
