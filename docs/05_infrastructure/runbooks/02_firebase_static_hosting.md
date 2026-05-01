# Runbook: Firebase Hosting + custom domain

> **What:** Host a static site (Next.js export, plain HTML, Vite build, etc.) on Firebase, served over HTTPS at your own domain. Free tier is generous; live + UAT + per-PR preview channels supported.
> **Estimated time:** 30–60 minutes the first time; 10 minutes for any additional channel.

| Placeholder | What it is | Example |
|-------------|-----------|---------|
| `<PROJECT_ID>` | Firebase project ID | `myapp-streaming-platform` |
| `<APEX>` | Domain you own (in Cloudflare DNS) | `example.dev` |
| `<LIVE_HOSTNAME>` | Production URL | `myapp.example.dev` |
| `<UAT_HOSTNAME>` | UAT/staging URL | `uat.myapp.example.dev` |
| `<APP_DIR>` | Path to the static-site project in your repo | `apps/web_landing` |
| `<BUILD_OUTPUT>` | Where the site builds to | `out/` (Next.js export), `dist/` (Vite), `build/` (CRA) |

---

## Prerequisites

1. **A Cloudflare zone** for `<APEX>`. Cloudflare here is just the DNS provider — it does NOT proxy traffic for Firebase-hosted hostnames (TLS reasons; see step 4).
2. **A Google account** with billing/ownership on a Firebase project, or willingness to create one (Firebase Hosting works on the free Spark plan for most cases).
3. **Local Node.js** (whatever the static-site framework needs).
4. **Firebase CLI:** `npm install -g firebase-tools`.

---

## Step 1 — Initialize Firebase Hosting in the project

In your repo:

```bash
cd <APP_DIR>
firebase login                # opens browser
firebase init hosting
```

Pick:
- **Use an existing project** (or create one) → select `<PROJECT_ID>`
- **Public directory:** `<BUILD_OUTPUT>` (e.g. `out` for Next.js)
- **Single-page app rewrites:** `Yes` if it's an SPA, `No` for a multi-page static export
- **Set up automatic builds and deploys with GitHub:** `No` (we'll do CI by hand for more control — see `03_github_ci_cd.md`)
- **Overwrite index.html?** `No`

This generates:
- `firebase.json` — hosting config
- `.firebaserc` — project alias

Commit both. The `<BUILD_OUTPUT>` directory should be in `.gitignore`.

### Sanity-test a manual deploy

```bash
npm run build           # builds into <BUILD_OUTPUT>
firebase deploy --only hosting
```

Output gives you a `https://<PROJECT_ID>.web.app` URL. Verify it loads. This is the default Firebase-issued hostname; we'll add your custom domain on top.

---

## Step 2 — Wire `<LIVE_HOSTNAME>` to the `live` channel

The `live` channel is Firebase's term for "production." Custom domains attach to it:

1. Firebase console → Hosting → **Add custom domain**
2. Enter `<LIVE_HOSTNAME>`, target the live channel
3. Firebase shows you 2 `A` records to add to your DNS. Copy them.
4. In **Cloudflare DNS** for `<APEX>`, add both `A` records:
   - Name: the hostname's left-side (e.g. `myapp` for `myapp.example.dev`)
   - Value: the IP from Firebase
   - **Proxy status: DNS only (grey cloud, NOT orange).** This is non-negotiable — see "Why proxy must be off" below.
5. Back in Firebase console, click **Verify**. Provisioning takes 5–30 minutes.

Once provisioning completes, `https://<LIVE_HOSTNAME>` serves your site with a Let's Encrypt cert that Firebase auto-renews.

### ⚠️ Why Cloudflare proxy MUST be off

Firebase provisions and renews TLS certs by performing the TLS handshake **directly** with your domain (HTTP-01 challenge over the same hostname). Cloudflare's orange-cloud proxy intercepts that handshake, presents Cloudflare's cert instead, and Firebase's challenge fails. The cert never issues / never renews.

Set both `A` records to grey cloud. You lose Cloudflare's DDoS protection and edge caching for this hostname, but you gain reliable TLS that auto-renews. For a marketing/landing site, this is a fine trade.

---

## Step 3 — Set up UAT (`<UAT_HOSTNAME>`) on a non-live channel

Firebase channels are like git branches for hosting: you deploy a build to a named channel, and that channel has its own URL.

```bash
# Create the UAT channel and deploy to it (channel auto-created on first deploy)
npm run build
firebase hosting:channel:deploy uat --expires 30d
```

That gives you a URL like `https://<PROJECT_ID>--uat-xxxxxxx.web.app`. Then attach the custom domain:

1. Firebase console → Hosting → **Add custom domain**
2. Enter `<UAT_HOSTNAME>`, target the **`uat`** channel
3. Add the `A` records to Cloudflare DNS, **proxy off** (same as live)
4. Verify

Once this is done, `https://<UAT_HOSTNAME>` serves whatever you most-recently deployed to the `uat` channel. CI will keep this fresh on every push to your `uat` branch.

### About channel expiry

Firebase channels other than `live` have a **30-day TTL**. Each `hosting:channel:deploy` resets it. As long as you push to `uat` regularly, the channel never expires. If you go silent for a month, the channel auto-deletes and you'll need to re-deploy + re-attach the custom domain.

In practice: CI deploys to `uat` on every push to the `uat` branch, so this never happens. The 30-day default is fine.

---

## Step 4 — PR preview channels (automatic per-PR URLs)

Firebase has first-class support for ephemeral channels per pull request. The URL pattern is `https://<PROJECT_ID>--pr-<NUMBER>-<HASH>.web.app`. They're automatically deleted when the PR closes.

PR preview channels are wired up in CI — no manual configuration. See [`03_github_ci_cd.md`](./03_github_ci_cd.md) for the workflow.

You don't typically attach custom domains to PR previews; the auto-generated `*.web.app` URL is fine.

---

## Step 5 — Lock down production (require approval before live deploys)

By default, anyone with push access to `main` can deploy to production. To gate production deploys behind a manual approval:

1. GitHub → repo Settings → **Environments**
2. **New environment** → name it `production` (lowercase exactly)
3. **Deployment protection rules** → check **Required reviewers** → add the GitHub usernames who can approve
4. Save

Now the CI workflow (which references `environment: production`) will pause and email reviewers before deploying.

> **GitHub Free plan caveat:** required reviewers on environments only work for **public repos** on Free, or any visibility on **GitHub Team / Pro / Enterprise**. If you're on Free + private, you have two options:
>
> - **Upgrade to GitHub Team** ($4/user/month). Required reviewers work everywhere.
> - **Use branch protection on `main`** instead. Settings → Branches → Add rule for `main` → **Require a pull request before merging** + **Required approvals: 1**. The reviewer approves the PR, not the deploy itself, but the effect is the same: nothing reaches `main` without a second pair of eyes.
>
> For solo projects, a third option: just be careful with `main`, use `uat` as your personal QA gate, push to `main` only when satisfied.

---

## Step 6 — Required GitHub secrets

If you're going to wire CI to deploy (you should — see [`03_github_ci_cd.md`](./03_github_ci_cd.md)), CI needs a service-account credential.

Run in your repo with Firebase CLI:

```bash
firebase init hosting:github
```

This walks you through creating a service account, granting it Hosting Admin, and storing the JSON key as a GitHub secret. The secret name will be like `FIREBASE_SERVICE_ACCOUNT_<PROJECT_ID_UPPERCASE>`.

You can also do this manually:
1. Google Cloud console → IAM & Admin → Service Accounts → create one for `<PROJECT_ID>`
2. Grant it role **Firebase Hosting Admin**
3. Create a JSON key, download it
4. GitHub repo → Settings → Secrets → Actions → add as `FIREBASE_SERVICE_ACCOUNT_<NAME>`

---

## Recap: what you have after this runbook

| Asset | Status |
|-------|--------|
| `<LIVE_HOSTNAME>` serving production | ✅ live |
| `<UAT_HOSTNAME>` serving UAT | ✅ refreshes on each `uat` branch deploy |
| Per-PR preview URLs | ✅ wired through CI (next runbook) |
| Production deploy gate | ✅ required-reviewers on `production` environment |
| TLS certs auto-renewing via Let's Encrypt | ✅ |
| Cost | $0/month for typical static-site traffic |

---

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| Cert provisioning never completes | Cloudflare proxy on (orange cloud) | Toggle records to DNS-only (grey) and wait 10 min |
| `firebase deploy` fails with "No project active" | `.firebaserc` missing or out of sync | `firebase use <PROJECT_ID>` |
| Custom domain shows "Needs setup" forever | A records point at wrong IPs (e.g. old Firebase IPs from a different project) | Re-copy IPs from current Firebase console, update Cloudflare DNS |
| Build output directory doesn't match `firebase.json` | Static export changed (e.g. Next.js `out/` vs Vite `dist/`) | Update `"public"` in `firebase.json` |
| `firebase hosting:channel:list` shows the channel expired | UAT branch went 30+ days without a push | Push or run `firebase hosting:channel:deploy uat --expires 30d` to revive |

---

## Cross-references

- **CI/CD that wires this together:** [`03_github_ci_cd.md`](./03_github_ci_cd.md)
- **Branch / PR / preview-channel workflow:** [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md)
- **Project-specific Firebase setup for Fluxora:** [`../01_infrastructure.md`](../01_infrastructure.md)
