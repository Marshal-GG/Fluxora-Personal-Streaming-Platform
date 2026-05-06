# Security Policy

> **Effective:** 2026-05-06
> **Maintainer:** Marshalx — portfolio at <https://marshalx.dev>, GitHub `@Marshal-GG`

Fluxora is a self-hosted media streaming product. The threat model is unusual for an open-source project — most installs run on a single home machine, but the server can be exposed to the public internet via the Cloudflare Tunnel feature, and bearer tokens / license-key HMAC secrets / paired-device credentials all live on the operator's hardware. Vulnerabilities in any of those surfaces matter.

This document describes how to report a vulnerability, what we commit to do with the report, and which versions are covered.

---

## Reporting a vulnerability

**Do not open a public GitHub issue for a security vulnerability.** Issues are world-readable and would expose the flaw before a fix is available.

Instead, report privately through one of these channels (in order of preference):

1. **GitHub private security advisory** — open a draft advisory at
   <https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/security/advisories/new>.
   This is the preferred channel: GitHub holds the report privately, lets us collaborate on a fix, and assigns a CVE if appropriate.
2. **Email** — `security@fluxora.marshalx.dev` (preferred) or `marshalgcom@gmail.com` (fallback). PGP key not currently published; if you need encryption, ask in plaintext for a key and we'll provide one before the disclosure.

When you report, please include:

- A short description of the vulnerability and its impact.
- Steps to reproduce (a minimal proof-of-concept is ideal — even pseudocode helps).
- Affected component(s): server (`apps/server/...`), desktop control panel (`apps/desktop/...`), mobile app (`apps/mobile/...`), shared core (`packages/fluxora_core/...`), public landing site (`apps/web_landing/...`), or infrastructure (Cloudflare Tunnel config, Polar webhook flow, etc.).
- Affected version(s) — branch name, commit SHA, or release tag if you know it.
- Your assessment of severity (CVSS score is welcome but not required).

You may report anonymously. If you want public credit in the eventual advisory, tell us how to attribute you.

---

## Our commitment

| What | Within |
|------|--------|
| Acknowledge receipt of your report | 72 hours |
| Initial triage assessment (confirmed / not-a-bug / need more info) | 7 days |
| Status update on remediation progress | At least every 14 days while the issue is open |
| Coordinated disclosure window (we ship the fix first, then publish the advisory) | 90 days from initial report by default; longer if the fix requires a major refactor and you agree to wait |

We will:

- Treat your report as confidential until a coordinated public disclosure.
- Not pursue legal action against good-faith research that follows this policy. If you stay within the [scope](#scope) below and do not exfiltrate user data, we will treat your report as authorised research under the safe-harbour terms of this policy.
- Credit you in the advisory unless you ask us not to.
- Backport the fix to actively-supported versions where reasonable.

We will **not**:

- Pay a bounty. Fluxora is a small project and does not currently fund a bug-bounty programme. We will publicly credit researchers and link to your write-up in the advisory.
- Disclose your identity without consent.

---

## Supported versions

| Channel | Status |
|---------|--------|
| `main` branch | ✅ Supported. All security fixes land here first. |
| Latest tagged release | ✅ Supported until the next minor release ships. |
| Pre-release / beta tags | ⚠️ Best-effort. Severe issues will be patched; minor ones may roll into the next stable. |
| Anything older than the latest release | ❌ Not supported. Update before reporting. |

If you can reproduce the issue on `main`, that's the version to report against.

---

## Scope

### In-scope

Vulnerabilities in any code shipped from this repository:

- Server (`apps/server/`) — auth/pairing flow, license-key HMAC, FFmpeg subprocess handling, request validation, log redaction, the Cloudflare Tunnel ingress middleware (`HLSBlockOverTunnelMiddleware`, `RealIPMiddleware`).
- Desktop control panel (`apps/desktop/`).
- Mobile clients (`apps/mobile/`).
- Shared core (`packages/fluxora_core/`).
- Public landing site (`apps/web_landing/`).
- Build / release tooling (`.github/workflows/`, `Dockerfile`, `fluxora_server.spec`, etc.).
- Documentation that materially mis-describes a security control (e.g. claims a field is encrypted when it isn't).

### Out-of-scope

- **Issues in third-party services we depend on** — Polar, Stripe, Cloudflare, TMDB, Sentry. Report those to the vendor directly. We'll coordinate if a Fluxora-side mitigation is possible.
- **Self-imposed risks** — running the server with debug mode on, exposing port 8000 directly to the internet without the Cloudflare Tunnel, sharing your own license key, etc.
- **Theoretical issues without a clear attack path** — "this could in principle be unsafe in a different threat model" is not a vulnerability.
- **Denial of service via resource exhaustion** on the operator's own machine. The server is single-tenant by design; an authenticated user can saturate FFmpeg if they want to. Document the bounded resource use; don't report it as a vulnerability.
- **Brute force / volumetric attacks against the marketing site or the public Cloudflare Tunnel ingress.** Cloudflare's WAF + rate-limit handle these and they're not Fluxora-side bugs.
- **Outdated dependencies** unless the outdated version has a known CVE that affects Fluxora's actual usage. A version bump is not a vulnerability report.
- **Auto-scanner output** — please verify any flagged issue manually before reporting. False positives from generic scanners are common.

If you're unsure whether something is in scope, ask first via a private advisory or email. We'd rather field a maybe-out-of-scope question than have a real issue go unreported.

---

## Threat model recap

For context, the things we actively defend against:

| Asset | Control |
|-------|---------|
| Bearer auth tokens | Stored as HMAC-SHA256 hashes only — never plaintext (CLAUDE.md hard prohibition #13). Token is shown to the client once at approval and never re-derivable from the DB. |
| License keys | HMAC-SHA256 signed; format `FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>`. Server validates the signature locally with a secret from `~/.fluxora/config.json` — no network call. |
| Polar webhook events | Verified via Standard-Webhooks signature before any side effect. Order-ID idempotency table rejects replays. |
| Admin endpoints | Localhost-only via `require_local_caller` (rejects loopback callers carrying `CF-Connecting-IP` so a tunneled request cannot impersonate localhost). See `docs/06_security/01_security.md`. |
| HLS segments over the public tunnel | Blocked by `HLSBlockOverTunnelMiddleware` — segments are LAN-only by design. |
| Path traversal / unsafe upload paths | `library_service._is_valid_absolute_media_path` rejects relative, `[`-prefixed, and null-byte paths in scan + upload (migration 022). |
| Logged sensitive data | CLAUDE.md hard prohibition #8 — bearer tokens, passwords, license keys, customer email, file system paths under user's home directory: never logged in production. |

If you find a way around any of these, that's the kind of report we want.

Architectural details + non-security gotchas: [`docs/06_security/01_security.md`](docs/06_security/01_security.md), [`docs/12_guidelines/03_gotchas.md`](docs/12_guidelines/03_gotchas.md).

---

## Disclosure history

This section will list past advisories once any are filed. None as of 2026-05-06.

---

## Changes to this policy

Material changes are announced on the repository's release notes and tagged in the commit log. The "Effective" date at the top of this document reflects the current version.
