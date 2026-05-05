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

### 🔲 Regenerate (or re-skip) `m3_dashboard_golden_test.dart` baseline

- **What:** The Dashboard golden test fails with **62.77 % pixel diff** against the stored baseline as of 2026-05-06. The Dashboard screen was untouched in the failing session; the diff is leftover drift from the V2 theme cutover whose baseline was never regenerated. Failing goldens in the suite output mask real regressions and erode trust in the test signal.
- **Why:** Either the baseline reflects current code (regenerate) or the test is flaky and should opt out (re-skip until the `golden_toolkit` migration). Letting it sit half-on is the worst option.
- **Steps:**
  1. From `apps/desktop/`, decide intent — does the current Dashboard render match the prototype? If yes, regenerate. If a future change is queued that will touch Dashboard, prefer skip.
  2. **Regenerate path:** `flutter test --tags=golden --update-goldens test/goldens/m3_dashboard_golden_test.dart`. Verify the new PNG visually before committing. Add the regenerated PNG + delete `test/goldens/failures/` debris.
  3. **Re-skip path:** add `@Tags(['golden_skip'])` (or revive the dart_test.yaml tag) on the failing test only, with a comment pointing at this manual task and the discontinued-`golden_toolkit` migration item below.
- **Trigger:** any session that runs `flutter test` and sees the failure; or before next CI re-enable.
- **Owner:** any agent doing desktop work — quick (~5 min).

### 🔲 Audit `last_seen` consumers after migration 023 changed semantics

- **What:** Migration 023 (2026-05-06) changed `clients.last_seen` from "frozen at pair / approval" to "live within one poll cycle" (refreshed by `auth_service.update_client_heartbeat()` from `validate_token` on every authenticated request). Any UI that previously interpreted the field as a paired-at proxy now sees a live value and may surprise users.
- **Why:** Both meanings render plausibly — the bug is silent. A user who previously saw "Last active: 3 days ago" because that was approval time will now see "Last active: 30 seconds ago" once the device polls. No technical regression, but a visible behaviour change worth confirming each surface handles correctly.
- **Steps:**
  1. **Mobile profile screen** ([`apps/mobile/lib/features/profile/`](../../apps/mobile/lib/features/profile/)) — confirm `last_seen` is rendered as "Last active" (live) and not "Connected since" (would now lie).
  2. **Desktop Clients screen** — confirm "Last Active" column updates within a poll cycle of an authenticated request from the device. Already wired through `_LastActiveCell(lastSeen: c.lastSeen)`; should just work after migration 023, but worth eyeballing.
  3. **Dashboard "Connected Clients" stat tile** — counts approved + trusted; doesn't read `last_seen`, so unaffected.
  4. **Activity feed** — events use their own timestamp, not `last_seen`. Unaffected.
- **Trigger:** after migration 023 has run on at least one production-shaped database.
- **Owner:** any agent doing client-screen work.

### 🔲 Migrate desktop golden tests off discontinued `golden_toolkit`

- **What:** `golden_toolkit ^0.15.0` is flagged discontinued in pub.dev. Still works on current Flutter but will eventually break on a future SDK bump. Used in `apps/desktop/test/goldens/`.
- **Why:** Pre-emptive — when it breaks the suite is dead and the fix sits on the critical path of whoever's mid-task at the time. Migrating now is cheap (one test file today).
- **Options (pick one when forced or convenient):**
  1. **`alchemist`** (Betterment) — closest API to `golden_toolkit`, actively maintained, supports CI vs local divergence (CI runs platform-agnostic, local runs platform-specific).
  2. **Vanilla `flutter_test` `matchesGoldenFile`** — zero new dep but lose `multiScreenGolden`, `loadAppFonts`, `testGoldens` ergonomics. Higher rewrite cost.
- **Steps:**
  1. Convert `m3_dashboard_golden_test.dart` (the only existing golden) to chosen alternative.
  2. Regenerate baseline.
  3. Remove `golden_toolkit` from `apps/desktop/pubspec.yaml`.
  4. Update `apps/desktop/test/goldens/_README.md` with the new pattern.
- **Trigger:** when `golden_toolkit` finally breaks on a Flutter bump, OR when an agent has bandwidth before that and wants the suite stable for the next year.
- **Owner:** any agent doing desktop test work.

### 🔲 Migrate existing `media_files.poster_url` rows to use the TMDB proxy

- **What:** `FLUXORA_TMDB_IMAGE_BASE_URL` makes *new* TMDB lookups produce proxy-prefixed poster URLs (`https://<worker-host>/tmdb-img/t/p/w342/...`).  Rows enriched **before** the env var was set still hold the original `https://image.tmdb.org/t/p/w342/...` URL — and the mobile / desktop client fetches them directly, hitting whatever ISP block the original deployment was working around.  A one-shot SQL migration rewrites the existing rows.
- **Why:** without it, posters stay broken on every pre-existing media file even after the proxy is fully wired up.  Re-running "Rescan TMDB" doesn't help because the rescan only touches `tmdb_id IS NULL` rows.
- **Steps:**
  1. Add migration `023_rewrite_poster_urls_to_proxy.sql` (or similar).
  2. SQL body should accept the proxy host as a parameter — different operators may use different proxy URLs.  Easiest path: read `FLUXORA_TMDB_IMAGE_BASE_URL` at startup, run the migration once if any rows still match the old prefix.  Skip silently if env var is empty.
  3. ```sql
     UPDATE media_files
        SET poster_url = REPLACE(poster_url, 'https://image.tmdb.org/t/p/w342', :new_prefix)
      WHERE poster_url LIKE 'https://image.tmdb.org/%';
     ```
  4. Test before shipping: backup `fluxora.db`, dry-run with a SELECT to count rows that would change.
- **Trigger:** confirmed working Worker proxy on the operator's domain + at least one user reports broken posters on existing media.
- **Owner:** project owner / next agent session.

### 🔲 Investigate `fluxora-api.marshalx.dev` DNS resolution from Indian Jio networks

- **What:** the user added a DNS record for `fluxora-api.marshalx.dev` (proxied/orange-cloud on Cloudflare).  `nslookup` from PowerShell returns the right Cloudflare anycast IPs from `1.1.1.1`, `8.8.8.8`, *and* the user's ISP resolver — but `curl.exe` (and Python `httpx`) can't resolve the hostname.  Local Windows DNS Client cache has stuck NXDOMAIN past `ipconfig /flushdns`.  `Restart-Service Dnscache` would clear it but isn't user-friendly.
- **Why:** as a workaround the user is on the workers.dev URL which works fine, but the custom domain would be nicer for branded shipping.
- **Steps:**
  1. Wait 24-48 hours and re-test (negative cache TTL may eventually expire).
  2. If still broken: capture more diagnostics (`Resolve-DnsName fluxora-api.marshalx.dev` from admin PowerShell; check whether the issue is specific to one IPv4 vs IPv6 resolution path).
  3. Possibly switch the DNS record from a wildcard or explicit A/AAAA — proxied records auto-generate both, but a manual override might behave differently in the local resolver.
  4. If unfixable: document the workers.dev URL as the canonical proxy URL in shipping docs; treat custom-domain as optional.
- **Trigger:** owner has time to investigate further OR another user reports the same on a fresh Jio install.
- **Owner:** project owner.

### 🔲 iOS Picture-in-Picture support

- **What:** Android PIP shipped 2026-05-04 via a `dev.marshalx.fluxora/pip` Kotlin method channel + manifest `android:supportsPictureInPicture="true"`. iOS PIP is harder: `media_kit` uses MPV (libmpv) under the hood, which doesn't bridge to `AVPictureInPictureController` (the iOS PIP API works against `AVPlayer`, not arbitrary GL surfaces). The PIP button is hidden on iOS via a `Platform.isAndroid` guard in `flux_player_controls.dart`.
- **Why:** PIP is a baseline mobile-app expectation in 2026; missing-on-iOS is a real UX gap for the half of mobile users on iPhone.
- **Prereqs:** physical iOS device (or paid iOS Simulator with PIP capability); decision on player-backend swap (stay on `media_kit` and write a custom AVFoundation surface, or switch to `flutter_inappwebview` / native AVPlayer for iOS only).
- **Trigger:** owner has an iOS test device + bandwidth for the player-backend conversation.
- **Owner:** project owner.

### 🔲 Replace bundled FFmpeg with a libdav1d-enabled build

- **What:** the bundled `ffmpeg.exe` / `ffmpeg` binary lacks `--enable-libdav1d`. The native AV1 software decoder fails on common sources (`[av1] Failed to get pixel format`), including HDR 10-bit AV1 files from game captures. The NVIDIA cuvid auto-fallback correctly detects this case and surfaces the error, but cannot fix it without a working software AV1 decoder.
- **Why:** AV1 NVDEC has tight GPU-generation and chroma/bit-depth constraints (RTX 30+ for 8/10-bit 4:2:0; older GPUs = no AV1 at all; 4:4:4 / 12-bit unsupported on most consumer cards). Without libdav1d, AV1 sources that NVDEC can't decode also can't be transcoded in software — the only workarounds are re-encoding the source or replacing the FFmpeg binary.
- **Steps:** download a static FFmpeg build with `--enable-libdav1d` (e.g. from `ffmpeg.org/download.html` → "Static builds" → Windows/Linux; or `brew install ffmpeg` on macOS). Replace the bundled binary at the path the PyInstaller executable uses (check `config.py` / `sys._MEIPASS` path resolution). Verify `ffmpeg -decoders | grep dav1d` shows `libdav1d`.
- **Time:** ~15 min.
- **Trigger:** when a user reports AV1 source playback failure and is not on RTX 30+.
- **Owner:** project owner.

### 🔲 Validate cuvid auto-fallback on each NVIDIA generation

- **What:** the cuvid input-decoder hint (`av1_cuvid`, `hevc_cuvid`, etc.) plus auto-fallback retry was written and tested against RTX-class hardware. NVIDIA NVDEC capabilities differ meaningfully across generations: RTX 20 (Turing) lacks AV1 NVDEC entirely; RTX 30 (Ampere) adds AV1 but only 8/10-bit 4:2:0; RTX 40 (Ada Lovelace) adds AV1 12-bit on select models. The `_is_cuvid_failure` substring classifier is conservative but needs real-world validation on each generation.
- **Why:** if the classifier fails to trigger on a generation-specific error string, the first attempt fails and the second attempt also fails (no retry), giving the user a confusing double-error instead of a clean fallback. Alternatively, if it fires on a non-cuvid error, unnecessary retries add latency.
- **Steps:** test playback of: (a) h264 source, (b) HEVC source, (c) AV1 SDR source, (d) AV1 HDR 10-bit source on each available GPU generation. Check server logs for `cuvid decoder rejected source … retrying without cuvid hint` entries on expected-fail sources.
- **Time:** ~30 min per GPU generation.
- **Trigger:** when hardware from a new GPU generation (RTX 20 / 30 / 40 / 50) becomes available for testing.
- **Owner:** project owner.

### 🔲 iOS lockscreen / Now Playing card

- **What:** Phase 2 of the player polish round wired Android's MediaSession via `audio_service ^0.18.18`. iOS support exists in the same package but couldn't be tested without a device, so `Info.plist` `UIBackgroundModes` was left untouched and the iOS half of `FluxoraAudioHandler` is unverified.
- **Why:** without it, iOS users get no lockscreen card, no Bluetooth-headset transport, no audio when the screen locks.
- **Steps to enable:** add `<key>UIBackgroundModes</key><array><string>audio</string></array>` to [`apps/mobile/ios/Runner/Info.plist`](../../apps/mobile/ios/Runner/Info.plist); rebuild on a real iPhone; verify the now-playing card appears and that backgrounding doesn't kill audio.
- **Time:** ~30 min plumbing + however long iOS-device QA takes.
- **Trigger:** owner has an iOS test device.
- **Owner:** project owner.

### 🔲 Swap landing-page hero screenshot for a real Dashboard capture

- **What:** in [`apps/web_landing/public/mockups/desktop-dashboard.png`](../../apps/web_landing/public/mockups/desktop-dashboard.png), replace the temporary placeholder (currently the ref image at `docs/11_design/ref images/desktop/desktop_dashboard_redesign.png`) with a real 1440 × 900 PNG/WebP capture of the redesigned Flutter desktop Dashboard. Compress to ≤ 200 KB. Re-export OG image (`public/og.png`) using the new screenshot.
- **Why:** the landing-page hero shows a faux-mockup; once redesign M3 ships the real Dashboard surface, the screenshot needs to be authentic to avoid the "fake screenshot" feel. Also improves OG card on Twitter / LinkedIn previews.
- **Prereqs:** desktop redesign M3 (Dashboard) ships — see [`../11_design/desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md) §9 M3.
- **Time:** ~10 min — boot desktop app at 1440 × 900, screenshot, optimize via `squoosh.app` or `sharp`.
- **Trigger:** desktop redesign M3 lands.
- **Doc:** [`../11_design/web_landing_redesign_plan.md`](../11_design/web_landing_redesign_plan.md) §15.1.
- **Owner:** project owner.

### 🔲 Replace TMDB movie posters with commissioned art (optional polish)

- **What:** the 8 horizontal-carousel posters in [`apps/web_landing/src/components/PopularMovies.tsx`](../../apps/web_landing/src/components/PopularMovies.tsx) load real popular titles from TMDB's public CDN at `image.tmdb.org`. Per TMDB API ToS, attribution is now in the footer ([`Footer.tsx`](../../apps/web_landing/src/components/Footer.tsx)). Optionally swap for commissioned brand-aligned art (or curated CC0 imagery in violet/cyan palette) for a richer brand presentation.
- **Why:** the current TMDB images are real-movie posters, legally fine with attribution, but optionally improvable with brand-aligned art.
- **Prereqs:** none. Purely optional polish.
- **Time:** commissioned art ~1–2 weeks; curated CC0 swap ~30 min.
- **Trigger:** before public launch announcement, OR any brand polish pass.
- **Doc:** [`../11_design/web_landing_redesign_plan.md`](../11_design/web_landing_redesign_plan.md) §15.2.
- **Owner:** project owner.

### 🔵 Wire remaining landing-page footer placeholder links

- **What:** several `href="#"` placeholders remain in [`apps/web_landing/src/components/Footer.tsx`](../../apps/web_landing/src/components/Footer.tsx). Wire them to live URLs as each corresponding page ships. **Already wired in 2026-05-02 gap-fix round:** GitHub repo, Discussions, Issues, `/privacy`, `/terms`, `#faq` (anchor). **Still placeholder:** `Documentation`, `Help Center`, `Status`, `Roadmap`, `About`, `Blog`, `Press kit`, `Contact`, `Discord`, `X / Twitter`.
- **Why:** broken / dead-link footers hurt SEO and look unprofessional.
- **Prereqs:** the corresponding pages need to exist first — see [`../11_design/web_landing_redesign_plan.md`](../11_design/web_landing_redesign_plan.md) §11 (Out of scope for the landing PR).
- **Time:** ~10 min once each linked page ships — find/replace `href="#"` with the real path.
- **Trigger:** as each linked page (`/about`, `/help`, `/blog`, Discord server creation, etc.) ships.
- **Doc:** [`../11_design/web_landing_redesign_plan.md`](../11_design/web_landing_redesign_plan.md) §15.3.
- **Owner:** project owner.

### 🔲 Wire Polar checkout URLs in landing-page Pricing component

- **What:** [`apps/web_landing/src/components/Pricing.tsx`](../../apps/web_landing/src/components/Pricing.tsx) lines 6–9 still contain placeholder URLs (`https://polar.sh/fluxora/checkout/{plus,pro,ultimate}`). Paste real share-links from your Polar dashboard: Dashboard → Products → (Product name) → Share → Copy checkout link.
- **Why:** Plus / Pro / Ultimate purchase buttons currently lead to invalid Polar URLs. **Site cannot ship to public until fixed** — paid product can't have broken checkout.
- **Prereqs:** Polar dashboard product entries already exist (see [`../01_product/06_polar_product_setup.md`](../01_product/06_polar_product_setup.md)).
- **Time:** ~5 min — copy 3 share links, paste into the `CHECKOUT` const at the top of the file.
- **Trigger:** before any public launch / announcement of the marketing site.
- **Doc:** [`../11_design/web_landing_redesign_plan.md`](../11_design/web_landing_redesign_plan.md) §15.4.
- **Owner:** project owner.

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

### 🔲 Cache management & data dir surfacing (server + desktop)

- **What:** add user-visible controls for the on-disk caches the app already creates but does not surface today.
  - **Server side:**
    - `GET /api/v1/system/data-dir` → returns `{path, total_bytes, hls_bytes, db_bytes, log_bytes}`. Reuses the data-dir helper in [`apps/server/config.py`](../../apps/server/config.py) (`%APPDATA%\Fluxora\` on Windows; `~/Library/Application Support/Fluxora/` on macOS; `~/.fluxora/` on Linux).
    - `POST /api/v1/system/clear-hls` → wipes orphaned HLS dirs on demand. Reuses [`_cleanup_orphaned_hls`](../../apps/server/main.py) logic that already runs at startup. Must skip dirs belonging to active sessions in `ffmpeg_service` registry.
    - Both endpoints localhost-only (`require_local_caller` like the other admin endpoints).
  - **Desktop side:** new "Storage" section in `SettingsScreen` showing server data-dir path with "Open folder" button (Process.run on `explorer`/`open`/`xdg-open`), per-bucket cache sizes from `/system/data-dir`, "Clear HLS cache" button hitting `/system/clear-hls`, and "Clear poster cache" button hooked to `DefaultCacheManager().emptyCache()` from `cached_network_image`. Optional: cap poster cache via a custom `CacheManager` (default is 200 MB / 7 days, no UI).
- **Why:** today there's no way for a user to see how much disk the server is using or to flush a stuck HLS dir / bloated poster cache. Logs (`fluxora.log`) and SQLite DB also have no rotation — surfacing sizes prompts the owner to add caps when they actually grow.
- **Steps:**
  1. New router `apps/server/routers/system.py` with the two endpoints + tests in `apps/server/tests/test_system.py`.
  2. New `SystemRepository` in `fluxora_core` for the desktop client (mirrors `SettingsRepository` shape).
  3. Storage card in `SettingsScreen` — reuses existing `FluxCard` / `StatTile` primitives.
  4. Wire `DefaultCacheManager().emptyCache()` button + confirmation dialog.
  5. Optional follow-up: add log rotation (`logging.handlers.RotatingFileHandler`, ~10 MB × 5 rolls) and a size cap on poster cache (`Config('fluxoraPosterCache', maxNrOfCacheObjects: 500, stalePeriod: Duration(days: 30))`).
- **Time:** ~3–4 hours for the core feature; +1 hour if log rotation is bundled.
- **Trigger:** post-v1 polish — file in the first month after public launch when real-user data-dir sizes are known. Not blocking ship per [`05_ship_readiness.md`](./05_ship_readiness.md).
- **Owner:** project owner (or next coding agent).

### 🔲 Fill in `apps/server/fluxora_server.spec` (PyInstaller spec)

- **What:** the spec file at [`apps/server/fluxora_server.spec`](../../apps/server/fluxora_server.spec) is a 35-byte placeholder containing only a corrupted comment header (`# PyInstaller build spec â€` — UTF-8 BOM + smart-quote artefact). It has been tracked in git since the initial scaffold (`0906852`) and never filled in. Despite this, [`runbooks/10_pyinstaller_distribution.md`](../05_infrastructure/runbooks/10_pyinstaller_distribution.md) and [`docs/05_infrastructure/01_infrastructure.md`](../05_infrastructure/01_infrastructure.md) reference the file as if it works. Running `pyinstaller apps/server/fluxora_server.spec` today would fail with "no Analysis block".
- **Why:** the server is the half of v1's "Plex without the cloud" pitch that the user actually installs on their PC. Right now there is no way to ship it. This is the gating piece between "code on github" and "double-click installer" for the home-server side of the product.
- **Steps:**
  1. Write a real `Analysis(['main.py'], ...)` block: pathex, datas (`apps/server/database/migrations/*.sql`, optionally a bundled `ffmpeg.exe`), hiddenimports for the non-static deps (uvicorn workers, `pythonjsonlogger.json`, slowapi, polar/sentry conditionals, aiosqlite). Then `PYZ`, `EXE` blocks.
  2. Run `pyinstaller apps/server/fluxora_server.spec` and chase the inevitable `ModuleNotFoundError`s — PyInstaller's static scanner misses anything dynamic, so add to `hiddenimports` until the resulting `dist/fluxora-server.exe` actually boots. Expect 4–6 rounds.
  3. Verify migrations bundle correctly. PyInstaller's onefile mode unpacks to `sys._MEIPASS` at startup; the migrations directory resolver in [`database/db.py`](../../apps/server/database/db.py) needs to handle both dev mode (`Path(__file__).parent / "migrations"`) and PyInstaller mode.
  4. Decide FFmpeg bundling strategy — bundled (~80 MB per platform binary, complicates AV1 / libdav1d swap tracked in this same file) or system-installed (smaller installer but breaks the "just double-click" promise). See the libdav1d task below for the reason this isn't trivially "bundle whatever".
  5. Cross-platform builds via GitHub Actions if you want CI artefacts. Each platform needs its own runner (windows-latest, macos-latest, ubuntu-latest) since PyInstaller can't cross-compile.
- **Time:** ~30 min for a baseline scaffold; ~2–4 hours of iterate-and-fix-imports until the .exe actually boots; ~1 day to add CI cross-platform build matrix and artefact upload.
- **Trigger:** when the installer / distribution work in [`06_installer_plan.md`](./06_installer_plan.md) is picked up. Until then, the empty spec is harmless — it just makes the runbook commands fail if you run them blindly.
- **Doc:** when this is picked up, also reword the references in [`runbooks/10_pyinstaller_distribution.md`](../05_infrastructure/runbooks/10_pyinstaller_distribution.md) and [`01_infrastructure.md`](../05_infrastructure/01_infrastructure.md) so they no longer imply the file is functional today.
- **Owner:** project owner (or next coding agent assigned the installer work).

### 🔲 Distribution: Windows server `.exe` code signing

- **What:** the PyInstaller-built `dist/fluxora-server.exe` is unsigned today. Buy an OV or EV code-signing certificate (Sectigo / DigiCert / SSL.com — ~$200–400/yr OV, ~$300–600/yr EV), add a `signtool.exe sign /tr <timestamp-url> /td sha256 /fd sha256 /a dist/fluxora-server.exe` step to the build pipeline. EV gets you instant SmartScreen reputation; OV builds reputation over downloads.
- **Why:** Windows SmartScreen blocks unsigned `.exe` downloads with a red "unrecognized publisher" dialog that requires a "More info" → "Run anyway" click-through. Most non-technical users abandon at that screen. First-impression friction is the #1 install conversion killer.
- **Prereqs:** business identity that the CA can verify (sole proprietor / LLC works; takes ~3–5 business days for OV, ~7 days for EV). Hardware token for EV (USB dongle the CA mails you).
- **Time:** ~30 min build-pipeline integration; days waiting on cert issuance.
- **Trigger:** before Path B public launch (see [`05_ship_readiness.md`](./05_ship_readiness.md) §Recommended ship paths). Skip for Path A friends-and-family.
- **Doc:** [`runbooks/10_pyinstaller_distribution.md`](../05_infrastructure/runbooks/10_pyinstaller_distribution.md) (signing section to be added when this task is picked up).
- **Owner:** project owner.

### 🔲 Distribution: Desktop app installer + signing (Win / macOS / Linux)

- **What:** Flutter desktop currently ships as a folder of files from `flutter build windows/macos/linux`. Wrap into proper installers:
  - **Windows:** `flutter_distributor` → `.msix` (preferred — Microsoft Store-compatible) or Inno Setup `.exe`. Sign with the same cert from the server-signing task above.
  - **macOS:** `.dmg` via `create-dmg`; **must** be code-signed with an Apple Developer ID + notarized via `xcrun notarytool submit` (Gatekeeper hard-blocks unsigned/un-notarized apps from Catalina+).
  - **Linux:** `.AppImage` (universal, no install needed) and/or `.deb` for Debian/Ubuntu. No signing requirement.
- **Why:** users can't double-click a folder. macOS install is impossible without notarization. Windows install without signing trips the same SmartScreen friction as the server `.exe`.
- **Prereqs:** Apple Developer Program membership ($99/yr) for macOS notarization; code-signing cert (shared with server task above) for Windows.
- **Time:** ~4–8 hours for first-time setup of all three; ~5 min per release after.
- **Trigger:** before any public download link goes on the landing page.
- **Owner:** project owner.

### 🔲 Distribution: Mobile app store submission (Play Store + App Store)

- **What:**
  - **Android (Google Play Console — $25 one-time):** create developer account, generate upload keystore (`keytool -genkey`), configure Play App Signing, create store listing (title, short + full description, 2–8 screenshots per form factor, feature graphic 1024×500, content rating questionnaire, privacy policy URL, target audience), upload signed `.aab`, submit for review (typically <72 hours first time).
  - **iOS (App Store Connect — Apple Developer Program $99/yr):** create app record, upload via Xcode Organizer or Transporter, configure App Privacy declarations, screenshots for every required device size (currently 6.9" + 6.5" iPhone + 13" iPad), age rating, submit for review (3–7 days first submission; expect at least 1 round of soft rejection).
- **Why:** sideloading APKs and TestFlight invites work for friends-and-family; public users expect store-discoverable apps.
- **Prereqs:** privacy policy hosted at `fluxora.marshalx.dev/privacy` (✅ done); app icons in correct densities (✅ done 2026-05-03); store screenshots taken from polished mobile UI (mobile redesign should be at least M3+ before this — current legacy screens look weak).
- **Time:** ~1 day per platform for first submission (assets + listing copy + form filling); review wait times above.
- **Risks:** iOS soft-rejection patterns: streaming apps may need to demonstrate first-party content rights or be classified as a "media player" rather than "streaming service" (see Risks table in [`03_open_questions.md`](./03_open_questions.md)).
- **Trigger:** before Path B public launch. Mobile redesign should be reasonably complete first.
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
