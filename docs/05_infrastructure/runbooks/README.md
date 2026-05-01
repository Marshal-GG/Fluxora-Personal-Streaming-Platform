# Reusable Infrastructure Runbooks

> **What:** Project-agnostic playbooks for setup patterns this project uses. Copy-paste-substitute for any new project — no Fluxora-specific assumptions.

These are NOT operational status pages for the current Fluxora deployment. For that, see the project-specific docs in the parent directory:

- [`../01_infrastructure.md`](../01_infrastructure.md) — Fluxora's actual hosting model, CI inventory, and environment variables
- [`../03_public_routing.md`](../03_public_routing.md) — Fluxora's specific Cloudflare Tunnel deployment with the live tunnel ID and decisions
- [`../04_domains_and_subdomains.md`](../04_domains_and_subdomains.md) — Fluxora's domain inventory

The runbooks here are the **distilled version** — same patterns, no project specifics.

---

## Runbooks

Numbered roughly in the order you'd hit them when starting a new project from scratch:

| # | Title | When to use |
|---|-------|-------------|
| **0** | [Domain registration + Cloudflare zone](./00_domain_and_cloudflare_zone.md) | Step 0. Buy a domain, put it on Cloudflare DNS with sane defaults |
| **1** | [Cloudflare Tunnel for a self-hosted service](./01_cloudflare_tunnel.md) | Expose a locally-running service at a public HTTPS URL — no port forwarding |
| **2** | [Firebase Hosting + custom domain](./02_firebase_static_hosting.md) | Host a static site (Next.js export, Vite, etc.) on your own domain with auto-renewing TLS |
| **3** | [GitHub Actions CI/CD patterns](./03_github_ci_cd.md) | Wire up tests, lint, deploys, secret scanning, dependabot, public-mirror sync |
| **4** | [Branch + PR workflow](./04_branch_and_pr_workflow.md) | Branch protection, PR preview channels, production-deploy gating, hotfix exceptions |
| **5** | [Secrets management](./05_secrets_management.md) | Where secrets live (local / CI / prod), rotation, leak response, gitleaks |
| **6** | [Webhook testing with smee.io](./06_webhook_testing_with_smee.md) | Receive third-party webhooks (Polar, Stripe, GitHub) on your laptop without port forwarding |
| **7** | [New repo init checklist](./07_repo_init_checklist.md) | Day-zero setup: LICENSE, .gitignore, README, conventional commits, branch protection |
| **8** | [Devcontainer / consistent local dev](./08_devcontainer.md) | `.devcontainer/` so contributors get an identical dev env in seconds. Powers GitHub Codespaces too |
| **9** | [Monitoring & observability](./09_monitoring_and_observability.md) | Minimum-viable uptime checks (UptimeRobot), error reporting (Sentry), structured logging |
| **10** | [PyInstaller standalone-binary distribution](./10_pyinstaller_distribution.md) | Bundle a Python app into per-OS executables for end-users who don't have Python |
| **11** | [Dependabot PR triage](./11_dependabot_triage.md) | Working through 10–30 dependency-bump PRs that arrive after a long gap. Tier classification, coupling traps, merge order |

The runbooks reference each other where relevant. Greenfield order is roughly 0 → 7 → 5 → (1 or 2) → 3 → 4 → 6 → 8 → 9 → 10 depending on what your project actually needs. Runbook 11 kicks in any time after CI is wired (3) and Dependabot is configured (also 3).

---

## Substitution variables

All runbooks use these placeholders. Define them once for your project before you start:

| Placeholder | What it is | Fluxora's value (for reference) |
|-------------|-----------|----------------------------------|
| `<APEX>` | Your apex domain | `marshalx.dev` |
| `<HOSTNAME>` | Your tunneled API hostname (single-level under apex) | `fluxora-api.marshalx.dev` |
| `<LIVE_HOSTNAME>` | Your production marketing-site hostname | `fluxora.marshalx.dev` |
| `<UAT_HOSTNAME>` | Your UAT marketing-site hostname | `uat.fluxora.marshalx.dev` |
| `<TUNNEL_NAME>` | Cloudflare Tunnel name | `fluxora-home` |
| `<PROJECT_ID>` | Firebase project ID | `fluxora-streaming-platform` |
| `<APP_DIR>` | Path to the static-site source in your repo | `apps/web_landing` |
| `<BUILD_OUTPUT>` | Static-site build output dir | `out` |
| `<USER>` | Local Windows username | (whoever) |
| `<PORT>` | Local service port | `8080` |

---

## Total cost of this stack (Fluxora's actual numbers)

| Service | Tier | Monthly cost |
|---------|------|--------------|
| Cloudflare Tunnel | Free | $0 |
| Cloudflare DNS / Universal SSL | Free | $0 |
| Firebase Hosting | Spark (free) | $0 (within 10 GB / month bandwidth) |
| GitHub Actions CI | 2,000 free minutes for private repos | $0 (typical use) |
| Domain registration | One-off | varies |
| **Total recurring** | | **$0** |

The whole stack is free for typical solo / small-project traffic. Costs only kick in if you exceed Firebase Hosting's 10 GB/month bandwidth, GitHub Actions' 2,000 minutes/month, or pick paid features (Cloudflare ACM, Firebase Blaze plan).

---

## What this collection covers

End-to-end greenfield setup for a Fluxora-quality personal/small-team project: domain → hosting → tunnel → CI → branching → secrets → monitoring → distribution. You can spin up a new project on this stack from scratch in a weekend with these as the only reference.

| Capability | Runbook |
|-----------|---------|
| Domain ownership + DNS | 0 |
| Public HTTPS for a self-hosted service | 1 |
| Public HTTPS for a static site | 2 |
| Continuous integration & continuous deployment | 3 |
| Source-control workflow | 4 |
| Secret storage, rotation, leak response | 5 |
| Inbound-webhook dev testing | 6 |
| Day-1 repo bootstrap | 7 |
| Reproducible local dev environment | 8 |
| Uptime + error reporting + logs | 9 |
| End-user binary distribution (Python) | 10 |

---

## What's intentionally NOT covered

These are gaps on purpose — either out of scope for the project sizes these runbooks target, or genuinely better written when the need is concrete (a hypothetical runbook usually encodes a wrong best-guess).

| Topic | Why deferred | Trigger to write the runbook |
|-------|--------------|-------------------------------|
| **Database operational runbooks** (PostgreSQL/MySQL/Redis backups, replicas, point-in-time recovery, schema migration tooling like Alembic/Flyway) | Fluxora uses SQLite where ops are trivial; engine-specific best practices vary too widely for a single doc | When a project picks a real DB engine with non-trivial ops |
| **Container orchestration** (Kubernetes manifests, Helm charts, Nomad, Docker Swarm) | Overkill for the project sizes these runbooks target. Most personal/small projects ship to a VM, a managed PaaS, or a Cloudflare Tunnel — orchestration is more friction than value at that scale | When you genuinely need horizontal scaling across multiple hosts |
| **Observability at scale** (distributed tracing with OTel, custom Prometheus exporters, log aggregation with Loki/Datadog/New Relic, RUM, profiling in production) | Briefly mentioned in runbook 9 but real implementation should follow concrete pain. UptimeRobot + Sentry + grep-able logs cover the first ~10k MAU | When you have a performance complaint you can't reproduce locally, or when blast-radius monitoring becomes a customer ask |
| **Compliance frameworks** (SOC 2, GDPR data-handling, HIPAA, PCI-DSS) | Each one has its own runbook industry. No project-agnostic version is honest — controls depend heavily on what data you process and where | When a paying customer / contract requires it, or when handling regulated data |
| **Native mobile distribution** (App Store, Play Store, TestFlight, code signing for mobile, in-app updates) | Fluxora hasn't shipped to either store yet — we'd be guessing. Apple's and Google's processes also drift fast enough that any runbook would be partially stale within a year | When you're 60 days from a public mobile launch |
| **Browser extension distribution** (Chrome Web Store, Firefox Add-ons, manifest V3 specifics) | Niche; only relevant if you're shipping an extension | When you decide to ship one |
| **Email deliverability** (SPF, DKIM, DMARC for transactional email, warming up domains, Mailgun/Postmark/SendGrid setup) | Fluxora doesn't send transactional email. The Cloudflare Email Routing setup in runbook 0 covers receiving — sending is a different problem | When you start sending more than a handful of emails programmatically |
| **OAuth / SSO providers** (Auth0, Clerk, Supabase Auth, custom OIDC, Apple/Google Sign-In) | Auth choice drives architecture; a runbook would either be too provider-specific to be useful or too generic to copy from | When you pick a specific provider for a specific project |
| **Serverless / Edge function patterns** (Cloudflare Workers, Vercel functions, AWS Lambda) | Mentioned in passing for the v2 multi-tenant plan; will write when v2 actually starts | When v2 starts, or when you ship a serverless project |
| **Long-term cost monitoring & alerting** (FinOps for cloud bills, anomaly detection on monthly spend) | At $0/month current spend, the answer is "look at the dashboard once a quarter" | When monthly cloud spend exceeds ~$50 |
| **Disaster recovery drills + RTO/RPO targets** | The backup runbook ([`../05_backup_and_recovery.md`](../05_backup_and_recovery.md)) covers the mechanics. Formal RTO/RPO targets are a customer ask, not a personal-project concern | When a paying customer asks "what's your RTO?" or you sign an SLA |

If any of these gaps becomes relevant for a specific project, write the runbook **then** — when you're about to use it. A runbook written speculatively encodes a "best guess" that's usually wrong by the time you actually need it; one written while you're doing the thing for the first time is calibrated and correct.

---

## How these runbooks differ from project-specific docs

Each runbook is the **distilled, generic version** of patterns Fluxora actually uses. The project-specific application of each pattern lives in the parent directory:

| Runbook | Project-specific equivalent for Fluxora |
|---------|-----------------------------------------|
| 0 — Domains | [`../04_domains_and_subdomains.md`](../04_domains_and_subdomains.md) |
| 1 — Cloudflare Tunnel | [`../03_public_routing.md`](../03_public_routing.md) |
| 2 — Firebase Hosting | [`../01_infrastructure.md`](../01_infrastructure.md) sections on web landing |
| 3 — CI/CD | [`../01_infrastructure.md`](../01_infrastructure.md) sections on workflows + the actual `.github/workflows/` files |
| 4 — Branch + PR | [`../../../CONTRIBUTING.md`](../../../CONTRIBUTING.md) commit conventions + `.github/workflows/` deploy gates |
| 5 — Secrets | [`../../06_security/02_license_key_operations.md`](../../06_security/02_license_key_operations.md) for license keys; [`../05_backup_and_recovery.md`](../05_backup_and_recovery.md) for backup priority |
| 6 — Webhook testing | [`../02_polar_webhook_deployment.md`](../02_polar_webhook_deployment.md) and [`../../09_backend/02_polar_webhooks.md`](../../09_backend/02_polar_webhooks.md) |
| 7 — Repo init | The repo itself (this file is what step 7 produces) |
| 8 — Devcontainer | [`.devcontainer/devcontainer.json`](../../../.devcontainer/devcontainer.json) — Python 3.11 + Flutter 3.41 + Node 22 + FFmpeg + cloudflared, mounts host `~/.fluxora` for secrets |
| 9 — Monitoring | Sentry init wired in [`apps/server/main.py`](../../../apps/server/main.py) (`_init_sentry`) — set `SENTRY_DSN` in `.env` to enable. UptimeRobot still requires a manual signup + monitor pointed at `<HOSTNAME>/healthz` once Phase 2 of the routing plan ships |
| 10 — PyInstaller | `apps/server/fluxora_server.spec` |

Use the project-specific docs to see "what we did, with the actual values"; use the runbooks to see "the pattern, with placeholders" when starting fresh.
