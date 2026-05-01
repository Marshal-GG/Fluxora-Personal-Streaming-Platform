# Public API Routing — `fluxora-api.marshalx.dev`

> **Category:** Infrastructure
> **Status:** Phase 1 ops **COMPLETE** (2026-05-01); Phase 2-5 code work pending. v2 multi-tenant track scoped below.
> **Last Updated:** 2026-05-01 (rev 3 — Phase 1 ops complete; hostname pivoted from `api.fluxora.marshalx.dev` to `fluxora-api.marshalx.dev` due to Universal SSL depth limit)

---

## Goal

Give every Fluxora client a stable public address for the home server (`fluxora-api.marshalx.dev`) so that:

1. **WAN clients** (mobile on cellular, desktop away from home) reach the server through a friendly DNS name instead of a raw home IP.
2. **NAT, dynamic IPs, and port-forwarding requirements disappear** — no router config required from the user.
3. **LAN clients keep working with zero internet dependency** — local-first remains a hard product constraint.
4. **Media bandwidth never traverses the public proxy** — only small control-plane and signaling traffic does. Bulk video stays direct (LAN) or peer-to-peer (WebRTC).

## Non-goals

- Multi-tenant hosting — this plan covers a single owner's home server. Per-user subdomains are noted under "Future" but out of scope for v1.
- Replacing the local mDNS pairing flow — LAN discovery is unchanged.
- Hosting media at the edge — Cloudflare Tunnel free-tier bandwidth is not designed for sustained 4K HLS, so media routes are explicitly excluded.

---

## Architecture

### Three request planes

```
                        LAN                       WAN
─────────────────────────────────────────────────────────────────────
Control plane           direct HTTP               fluxora-api.marshalx.dev
(small JSON, infrequent)                          (Cloudflare Tunnel)

Signaling plane         direct WS                 wss://fluxora-api.marshalx.dev
(WebRTC negotiation,                              (Cloudflare Tunnel,
 status WS)                                        WS supported)

Media plane             direct HLS                WebRTC P2P
(.m3u8, .ts, RTP)       (home IP, fast)           (STUN/TURN; HLS over
                                                   tunnel is BLOCKED)
```

### Why split media off the public proxy

Routing `.ts` HLS segments through Cloudflare Tunnel works technically but burns the free-tier bandwidth budget within hours of a single 4K stream. CF will throttle or null-route long-lived high-throughput connections. The existing Phase 3 architecture already has WebRTC P2P with HLS fallback; **WAN media must always go P2P**, only the negotiation crosses the tunnel.

### Why a subdomain, not a path

`fluxora.marshalx.dev` (apex) is Firebase Hosting (Next.js static export). Firebase requires Cloudflare DNS proxy **off** for cert provisioning. `fluxora-api.marshalx.dev` is a separate record with proxy **on**, pointing to the tunnel — the apex stays untouched.

---

## Routing matrix

| Tier | Endpoints | LAN behavior | WAN behavior |
|------|-----------|--------------|--------------|
| **Control** | `GET /api/v1/info`, `GET /api/v1/info/logs`, `GET /api/v1/info/stats`, `POST /api/v1/auth/request-pair`, `GET /api/v1/auth/status/{id}`, `DELETE /api/v1/auth/revoke/{id}`, `GET /api/v1/library`, `POST /api/v1/library`, `GET/DELETE /api/v1/library/{id}`, `POST /api/v1/library/{id}/scan`, `GET /api/v1/files`, `GET /api/v1/files/{id}`, `POST /api/v1/files/upload`, `DELETE /api/v1/files/{id}` | direct (`http://lan-ip:8080`) | through `https://fluxora-api.marshalx.dev` |
| **Stream init** | `POST /api/v1/stream/start/{id}`, `PATCH /api/v1/stream/{id}/progress`, `GET /api/v1/stream/{id}` | direct | through `https://fluxora-api.marshalx.dev` |
| **Signaling** | `WS /api/v1/ws/status`, `WS /api/v1/ws/signal`, `WS /api/v1/ws/stats` | direct (`ws://lan-ip:8080`) | `wss://fluxora-api.marshalx.dev/...` |
| **Media (HLS)** | `GET /api/v1/hls/{session}/playlist.m3u8`, `GET /api/v1/hls/{session}/seg*.ts` | direct | **REJECTED** at server middleware — clients must negotiate WebRTC |
| **Media (WebRTC)** | n/a — peer-to-peer over data channel | direct | direct via STUN/TURN |
| **Webhook (Polar)** | `POST /api/v1/webhook/polar` | n/a (Polar can't reach LAN) | through `https://fluxora-api.marshalx.dev` (Polar endpoint config) |
| **Localhost-only admin** | `GET/PATCH /api/v1/settings`, `POST /api/v1/auth/approve/{id}`, `POST /api/v1/auth/reject/{id}`, `GET /api/v1/auth/clients`, `GET /api/v1/orders`, `GET /api/v1/stream/sessions`, `POST /api/v1/info/restart`, `POST /api/v1/info/stop` | direct (loopback only) | **never reached over WAN** — `require_local_caller` 403s remote callers |

> **Note on `/info/stats`:** This endpoint is currently no-auth and exposes uptime, LAN IP, CPU/RAM percentages, network throughput, and active stream count. None of these fields are PII or secret-equivalent — same risk class as `/info`. Acceptable to keep no-auth on WAN. Add an aggressive `slowapi` rate-limit (e.g. `60/minute`) when the routing lands so it can't be used as a free monitoring drain. The `public_address` field within the response is currently always `null` — Phase 2.6 below populates it.

---

## Phased implementation

### Current state (what's already in the codebase)

Some pieces of the routing plan landed alongside the desktop redesign work, ahead of the routing implementation itself. Treat these as "done" — the plan only needs to wire them up:

| Component | File | Status |
|-----------|------|--------|
| `SystemStatsResponse` model with `public_address` field | `apps/server/models/settings.py` | ✅ Shipped (field always `null` until Phase 2.6) |
| `system_stats_service` collecting CPU/RAM/network/uptime/active streams | `apps/server/services/system_stats_service.py` | ✅ Shipped |
| `GET /api/v1/info/stats` REST endpoint | `apps/server/routers/info.py` | ✅ Shipped (no auth) |
| `WS /api/v1/ws/stats` live-update WebSocket | `apps/server/routers/ws.py` | ✅ Shipped |
| `POST /api/v1/info/restart`, `POST /api/v1/info/stop` admin actions | `apps/server/routers/info.py` | ✅ Shipped (`require_local_caller`) |
| `GET /api/v1/info/logs` last-1000-lines endpoint | `apps/server/routers/info.py` | ✅ Shipped |
| Validation: `transcoding_encoder/preset/crf` Pydantic enums + bounds | `apps/server/models/settings.py` | ✅ Shipped |

The remaining server-side work for v1 routing is small: the four middlewares + one `/healthz` endpoint + the `FLUXORA_PUBLIC_URL` env var + populating `public_address` in stats. None of the existing code needs to be rewritten.

---

### Phase 1 — Cloudflare Tunnel (operations only, no code) ✅ COMPLETE (2026-05-01)

This is the runbook reproduction of what was actually done. Use it for disaster recovery, fresh-machine setup, or future tenants.

> **Hostname must be single-level under apex.** Cloudflare's free Universal SSL covers only one level deep (`*.marshalx.dev`). `fluxora-api.marshalx.dev` works (single level, hyphenated); `api.fluxora.marshalx.dev` does NOT (two levels — Cloudflare won't issue a free cert). See [`04_domains_and_subdomains.md`](./04_domains_and_subdomains.md#naming-philosophy).

1. **Install cloudflared** (Windows; pick equivalent for macOS/Linux):
   ```powershell
   winget install --id Cloudflare.cloudflared
   ```
   Open a fresh terminal afterward (PATH refresh) and verify with `cloudflared --version`.

2. **Authenticate** to your Cloudflare account; pick the `marshalx.dev` zone in the browser:
   ```powershell
   cloudflared tunnel login
   ```
   Writes `C:\Users\<user>\.cloudflared\cert.pem` — back this up.

3. **Create the tunnel.** Capture the UUID from the output:
   ```powershell
   cloudflared tunnel create fluxora-home
   ```
   Writes `C:\Users\<user>\.cloudflared\<UUID>.json` — back this up.

4. **Create the DNS record** via cloudflared (one-shot; no dashboard needed):
   ```powershell
   cloudflared tunnel route dns fluxora-home fluxora-api.marshalx.dev
   ```

5. **Config file** at `%USERPROFILE%\.cloudflared\config.yml`:
   ```yaml
   tunnel: <UUID>
   credentials-file: C:\Users\<user>\.cloudflared\<UUID>.json
   ingress:
     - hostname: fluxora-api.marshalx.dev
       service: http://127.0.0.1:8080   # NOT localhost — see pitfall #5 below
     - service: http_status:404
   ```

6. **Install the Windows service** in an elevated PowerShell:
   ```powershell
   cloudflared.exe service install
   ```
   This registers the service but does NOT pass `--config`; cloudflared 2025.8.1 then uses its default config-search, which on Windows running as `LocalSystem` proved unreliable — the service crashed within seconds with exit code `1067` even after copying config + credentials + cert into the LocalSystem profile and granting SYSTEM full ACLs. **Workaround that actually works:** override the service's launch command directly via the registry so cloudflared launches with explicit `--config` against the user-level config (which we know works because the foreground run with the same flags succeeded).

   ```powershell
   # Admin PS — grant SYSTEM read access to your user-level cloudflared dir
   icacls "$env:USERPROFILE\.cloudflared" /grant "SYSTEM:(OI)(CI)F" /T

   # Override ImagePath: hardcode the launch command (substitute YOUR username + tunnel name)
   $cmdline = '"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --config "C:\Users\<USER>\.cloudflared\config.yml" run <TUNNEL_NAME>'
   Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Cloudflared" `
     -Name "ImagePath" -Value $cmdline -Type ExpandString

   # Restart so the new ImagePath takes effect
   sc.exe stop Cloudflared 2>$null
   taskkill /F /IM cloudflared.exe 2>$null
   sc.exe start Cloudflared
   sc.exe query Cloudflared    # expect STATE: 4 RUNNING
   ```

   With this in place, the service reads from your user-level `~/.cloudflared/config.yml` directly. Future config edits take effect on the next service restart — no `Copy-Item` to systemprofile required, no dual-config divergence, no install/uninstall dance.

7. **Smoke test:**
   ```powershell
   curl.exe -fsS https://fluxora-api.marshalx.dev/api/v1/info
   ```
   With FastAPI running on `:8080`, returns the same JSON as the local `curl`. Without FastAPI running, returns 502 — also confirms the tunnel itself is reachable.

#### Setup record — what's currently live

| Item | Value |
|------|-------|
| Tunnel name | `fluxora-home` |
| Tunnel ID | `dea185fa-a26b-44eb-859b-f8916b1a3888` |
| Public hostname | `fluxora-api.marshalx.dev` |
| CNAME target | `dea185fa-a26b-44eb-859b-f8916b1a3888.cfargotunnel.com` |
| cloudflared version | `2025.8.1` (winget) |
| Service name | `Cloudflared` (LocalSystem) |
| Service ImagePath | `"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --config "C:\Users\<USER>\.cloudflared\config.yml" run fluxora-home` (registry override — see step 6) |
| Active config (read by service) | `C:\Users\<USER>\.cloudflared\config.yml` |
| Stale systemprofile copy | `C:\Windows\System32\config\systemprofile\.cloudflared\` exists but is no longer read; safe to delete or leave |

Backup priorities are documented in [`05_backup_and_recovery.md`](./05_backup_and_recovery.md#scenario-5-lost-cloudflare-tunnel-credentials-idjson).

#### Pitfalls hit during initial setup (so future-you doesn't repeat them)

1. **Deep subdomain TLS failure.** First attempt used `api.fluxora.marshalx.dev`. DNS resolved, tunnel was up, but TLS handshake failed because Cloudflare's Universal SSL doesn't issue certs at that depth on the free plan. Fix: pivoted to `fluxora-api.marshalx.dev` (hyphen, single-level). The dotted form would require Advanced Certificate Manager ($10/mo) or Total TLS (also requires ACM).
2. **Service config divergence.** Editing `~/.cloudflared/config.yml` AFTER `service install` doesn't take effect — the service reads from the systemprofile copy. Either re-run `service install` (which re-copies) or manually `Copy-Item` + `Restart-Service`.
3. **PowerShell `curl` alias.** `curl https://...` in PowerShell calls `Invoke-WebRequest`, which has different output. Use `curl.exe` explicitly for the smoke test.
4. **PATH not refreshed after winget install.** Existing terminals still see the old PATH. Open a new shell (or refresh PATH manually) before running `cloudflared`.
5. **`localhost` resolves to IPv6 first on Windows.** cloudflared dials `[::1]:8080`, FastAPI binds IPv4 (`127.0.0.1` or `0.0.0.0`), connection refused. Use `http://127.0.0.1:8080` in the ingress (NOT `http://localhost:8080`). The error in foreground logs reads: `dial tcp [::1]:8080: connectex: No connection could be made because the target machine actively refused it`. Telltale.
6. **`Copy-Item` doesn't auto-create parent directories.** `C:\Windows\System32\config\systemprofile\.cloudflared\` doesn't exist by default — `service install` only creates it if it copies files there, which on 2025.8.1 it doesn't always do. `New-Item -ItemType Directory -Path <dst> -Force` first, then `Copy-Item`.
7. **Service install snapshot vs. live config.** `cloudflared service install` registers a service that reads from `LocalSystem`'s `.cloudflared\` directory at runtime — but the install command does NOT auto-copy files there on every version. After editing the user-level config, you must mirror it to the systemprofile path AND restart the service. The "single source of truth + symlink" approach (`New-Item -ItemType SymbolicLink ...`) is cleaner if you'll be editing config often.

### Phase 2 — Server changes (FastAPI)

#### 2.1 CORS allow-list (`apps/server/main.py`)

Add `https://fluxora-api.marshalx.dev` and `https://fluxora.marshalx.dev` to `CORSMiddleware`. Reject `*` — the public surface is no longer fully self-contained.

#### 2.2 Real-IP middleware (`apps/server/utils/real_ip.py` — new)

When a request arrives via Cloudflare Tunnel, the source IP at FastAPI is loopback (the tunnel daemon). The actual client IP arrives in the `CF-Connecting-IP` header. Without a middleware, `slowapi` rate-limits all WAN traffic as if it were one IP.

The middleware:
- Reads `CF-Connecting-IP` only when the immediate peer IP is in the Cloudflare IP range list
- Sets `request.state.real_ip` to either `CF-Connecting-IP` or the immediate peer
- `slowapi`'s `key_func` reads `request.state.real_ip`

The Cloudflare IP list lives at `https://www.cloudflare.com/ips-v4` and `ips-v6`. Cache and refresh weekly via a startup task.

#### 2.3 HLS-blocks-on-tunnel middleware

For any path under `/api/v1/hls/`, if `CF-Connecting-IP` is present (i.e. the request arrived via Cloudflare Tunnel), respond with `403 Forbidden — HLS over public tunnel disabled; use WebRTC`. Forces the client to negotiate WebRTC for WAN media.

#### 2.4 Localhost-only hardening

`require_local_caller` already 403s non-loopback callers. The tunnel daemon makes WAN traffic appear loopback. Tighten the dependency: reject any request with a `CF-Connecting-IP` header for these endpoints.

```python
# apps/server/routers/deps.py
def require_local_caller(request: Request) -> None:
    if request.headers.get("CF-Connecting-IP"):
        raise HTTPException(403, "Admin endpoints not available over public tunnel")
    # ... existing loopback check ...
```

#### 2.5 Healthcheck (`apps/server/routers/info.py`)

Add `GET /api/v1/healthz` returning `{"ok": true}` — used by Cloudflare for tunnel uptime checks and by clients for "is remote access reachable?" probes. Lightweight: no DB access, no `system_stats` collection, just a constant body.

> **Status:** Not yet implemented. The rest of `/info/*` (`/info`, `/info/logs`, `/info/stats`, `/info/restart`, `/info/stop`) is shipped — this is the only remaining endpoint to add for the routing plan. ~10 lines including the test.

#### 2.6 System stats: report public address

The `SystemStatsResponse.public_address` field already exists (currently always `null` per the API contract). The routing implementation populates it: a periodic probe to `https://fluxora-api.marshalx.dev/api/v1/healthz`; on success, the `system_stats_service.public_address` cache is set to the configured `FLUXORA_PUBLIC_URL`; on failure, cleared back to `null`.

Probe schedule: every 30s, cached. Don't probe more often — Cloudflare's free tier doesn't want the noise and the desktop UI doesn't need sub-30s updates.

The desktop `SystemStatsCard` (which already consumes `/info/stats`) gets a green/red dot the moment this field flips between `null` and a string — no UI rework needed.

### Phase 3 — Shared core (`packages/fluxora_core`)

#### 3.1 `ApiClient` accepts dual base URLs

```dart
class ApiClient {
  ApiClient({
    required this.localBaseUrl,
    this.remoteBaseUrl,
    required this.networkPathDetector,
  });

  final String localBaseUrl;       // e.g. http://192.168.1.10:8080
  final String? remoteBaseUrl;     // e.g. https://fluxora-api.marshalx.dev

  Future<Uri> _resolveBase() async {
    final onLan = await networkPathDetector.isLan(localBaseUrl);
    if (onLan) return Uri.parse(localBaseUrl);
    final remote = remoteBaseUrl;
    if (remote == null) throw const NoRemoteConfiguredException();
    return Uri.parse(remote);
  }
}
```

#### 3.2 `SecureStorage` stores both URLs

```dart
Future<void> savePairing({
  required String localUrl,
  required String? remoteUrl,
  required String authToken,
});
```

#### 3.3 `NetworkPathDetector` extension

Already exists. Returns `true` when the device is in the same /24 as the configured `localBaseUrl`. No change needed — `ApiClient` does the routing decision.

### Phase 4 — Mobile client

1. **Pairing screen**: after the LAN pair completes, fetch `GET /api/v1/info` from the server which now returns `{ "remote_url": "https://fluxora-api.marshalx.dev" }` (server reads from its own settings — see 4.4). Save both URLs to `SecureStorage`.
2. **Library / Files / Stream**: no per-screen changes — `ApiClient` routes automatically.
3. **WebRTC signaling**: `WebRtcSignalingService` already builds its WS URL from `ApiClient` base. Will pick up `wss://fluxora-api.marshalx.dev/api/v1/ws/signal` on WAN automatically.
4. **Settings**: add a "Remote access" row showing whether `fluxora-api.marshalx.dev` is reachable (HEAD `/healthz`).

### Phase 5 — Desktop control panel

1. **`SystemStatsCard`** on Dashboard: show `public_address` field with a green/red indicator.
2. **Settings → Remote access section**:
   - Display the configured remote URL (read-only initially).
   - Status: tunnel reachable? cloudflared service running?
   - Button: "Open Cloudflare Tunnel setup guide" → links to `docs/05_infrastructure/03_public_routing.md`.
3. **Future**: in-app wizard that runs the `cloudflared` install/login/config commands. Out of scope for v1.

### Phase 6 — Optional hardening

- **Cloudflare Access** in front of admin paths (`/api/v1/auth/approve`, `/api/v1/auth/clients`, etc.) — though those are localhost-only and unreachable over the tunnel anyway.
- **WAF custom rules** — drop obvious junk (no `User-Agent`, oversized headers, etc.).
- **Tunnel health alerts** — Cloudflare can email when the tunnel goes down.
- **Self-hosted TURN** at `turn.fluxora.marshalx.dev` via a second tunnel ingress for reliable WebRTC fallback on symmetric NATs.

---

## Server config additions

`apps/server/config.py`:

| Setting | Default | Description |
|---------|---------|-------------|
| `FLUXORA_PUBLIC_URL` | `""` | The public URL clients should use when off-LAN. Empty = remote access disabled. |
| `FLUXORA_TRUST_CF_HEADERS` | `True` | Read `CF-Connecting-IP` and friends. Disable for non-Cloudflare deployments. |
| `FLUXORA_BLOCK_HLS_OVER_TUNNEL` | `True` | 403 HLS routes when `CF-Connecting-IP` is present. |

Persisted in `~/.fluxora/.env` like the rest. The desktop control panel's Settings screen is the canonical UI for editing these.

`GET /api/v1/info` response gains:
```json
{
  "server_name": "...",
  "version": "...",
  "tier": "...",
  "remote_url": "https://fluxora-api.marshalx.dev"  // null if not configured
}
```

---

## Security considerations

| Concern | Treatment |
|---------|-----------|
| **Bearer token in transit** | HTTPS terminates at Cloudflare edge, then re-encrypts to the tunnel. Cloudflare can technically inspect bodies if WAF is enabled — disable WAF inspection for the tunnel hostname or accept the trust trade-off. |
| **License keys** | Only sent in `PATCH /api/v1/settings` which is `require_local_caller`. Never traverse the tunnel. |
| **Polar webhook secret** | Stays in `~/.fluxora/.env`. Polar sends signed payloads to `fluxora-api.marshalx.dev/api/v1/webhook/polar` — signature verification happens server-side, body content is not trusted until verified. |
| **Header spoofing** | Real-IP middleware refuses to trust `CF-Connecting-IP` unless the immediate peer is in CF's published IP range. A malicious LAN client can't spoof the header. |
| **Public exposure of `/auth/request-pair`** | Already public (no auth). Pairing requires owner approval via the localhost-only `/auth/approve` — opening `request-pair` to WAN is harmless. |
| **Public exposure of `/auth/status/{id}`** | Returns the bearer token exactly once on the first approved poll. WAN exposure is OK because the token is single-use-per-poll and only revealed after explicit owner approval. |
| **Tunnel credentials** | `~/.cloudflared/<id>.json` is a private key — back up like any other secret. Treat compromise as "anyone can MITM your `fluxora-api.marshalx.dev` traffic until you rotate". |
| **DDoS amplification** | Cloudflare absorbs the L3/L4 hit. Add aggressive rate-limits on `/auth/request-pair` and `/info/logs` since those don't require auth. |

---

## Decisions (locked)

| # | Decision |
|---|----------|
| **D1** | **Server supplies its own remote URL during pairing.** `GET /api/v1/info` gains a `remote_url` field; clients persist both LAN URL and remote URL after pairing. The client binary is domain-agnostic — no Fluxora domain is hardcoded. This makes v2 multi-tenant a non-event for the apps. |
| **D2** | **Tunnel-down failures fail loudly with a clear error message — no DDNS fallback.** The desktop control panel self-probes `https://fluxora-api.marshalx.dev/api/v1/healthz` on a schedule and surfaces a red status with a "Restart cloudflared service" button. Clients show "Server unreachable via remote URL — try again on Wi-Fi at home." |
| **D3** | **Single-tenant for v1; multi-tenant deferred to v2** — see [v2 — Multi-tenant rollout](#v2--multi-tenant-rollout) below. The v1 architecture (server-supplied URL, license-key nonce as server identity) does not preclude multi-tenant; v2 is an additive build, not a rewrite. |
| **D4** | **`cloudflared` is system-installed, not bundled.** Desktop wizard runs the platform package manager (`winget` / `brew` / `apt`) and configures the tunnel for the user. Avoids 30 MB installer bloat, licensing redistribution questions, and stale-daemon update lag. |

---

## v2 — Multi-tenant rollout

> **Status:** Scoped, not yet started. Estimated ~1 month focused effort once v1 is live and stable.

### Goal

Users sign up on `fluxora.marshalx.dev`, register their home server, and receive a unique `<id>.fluxora.marshalx.dev` subdomain that points at their tunnel. Each user runs `cloudflared` on their own PC under their own subdomain. Cloudflare handles all traffic routing — no Fluxora-operated gateway service.

### Architecture

```
Marketing site                       Multi-tenant API
─────────────────                    ────────────────
fluxora.marshalx.dev                 alice.fluxora.marshalx.dev → Alice's tunnel
   (Firebase, static)                bob.fluxora.marshalx.dev   → Bob's tunnel
   ↓                                 charlie.fluxora.marshalx.dev → Charlie's tunnel
[Sign up / dashboard]                  ↑              ↑              ↑
   ↓                                   │              │              │
[Cloudflare Worker control plane] ─────┘              │              │
   │ - server registration             provisions     │              │
   │ - issues subdomain                 each subdomain │              │
   │ - returns cloudflared              dynamically    │              │
   │   config to user                   via            │              │
   │                                    Cloudflare     │              │
   ▼                                    for SaaS       │              │
[D1 SQLite: server registry]                           │              │
                                                       │              │
                                                  Each user's home cloudflared
```

The control plane is a thin Cloudflare Worker (no servers to maintain). The user-data store is Cloudflare D1 (SQLite-as-a-service). Routing is pure DNS via **Cloudflare for SaaS** — Cloudflare auto-provisions certs and forwards `<id>.fluxora.marshalx.dev` to the right tunnel.

### Why path-based (`fluxora-api.marshalx.dev/u/<id>/...`) was rejected

A path-based scheme would require **Fluxora-operated gateway infrastructure** (a Worker or VPS that reads the path and forwards to the right tunnel). That's:
- A failure mode owned by Fluxora ("the service is down" headlines)
- Bandwidth and latency on Fluxora's infrastructure
- A central point that has to understand bearer tokens to extract the user ID — leakier security model

Subdomains push the routing into DNS where Cloudflare handles it for free at the edge. **Less infra, less code, lower failure surface.**

### Components

| Component | What it is | Effort |
|-----------|-----------|--------|
| **Server identity** | The license-key nonce already uniquely identifies an issued key (it's the Polar order ID). Reuse as `server_id` — no schema change. Server reports its `server_id` to the control plane on first registration. | ~3 days |
| **Control plane Worker** | Cloudflare Worker with 4 endpoints: `POST /register` (server announces itself), `GET /subdomain` (server fetches its assigned hostname), `POST /heartbeat` (tunnel health), `GET /status/<id>` (public status page). All-in-one file, ~300 lines. | ~1 week |
| **D1 server registry** | One table: `servers (server_id, owner_email, subdomain, tunnel_id, created_at, last_seen)`. D1 is free for low volume. | ~1 day |
| **Cloudflare for SaaS configuration** | Wildcard `*.fluxora.marshalx.dev` configured in CF dashboard. Custom hostnames API for per-user provisioning. | ~2 days |
| **Desktop signup wizard** | Replaces the v1 manual cloudflared setup with: enter email → control plane registers you → returns a config snippet → desktop drops it into `~/.cloudflared/config.yml` and starts the service. | ~1 week |
| **Public status page** | Static-ish page on `fluxora.marshalx.dev/status/<id>` showing whether a given server's tunnel is up. Read-only, no auth. | ~2 days |
| **Migration shim for v1 users** | `fluxora-api.marshalx.dev` keeps working — existing v1 deployments don't need to migrate. New users get `<id>.fluxora.marshalx.dev`. v1 user can opt-in to migrate later via the desktop wizard. | ~3 days |
| **Polish, error handling, docs** | Tunnel registration retries, rate limits, monitoring, support runbooks. | ~1 week |
| **Total** | | **~1 month** |

### Auth model in v2

No change to client-side auth. Bearer tokens still issued by the home server during pairing. The control plane is **not** in the auth path for runtime requests — it only exists for one-time provisioning.

```
Provisioning (rare, runs once per server):
  Home server ──register──▶ control plane ──assigns──▶ <id>.fluxora.marshalx.dev

Runtime (every API call):
  Mobile client ──HTTPS──▶ <id>.fluxora.marshalx.dev ──CF Tunnel──▶ Home server
                                                                       │
                                                                  validates bearer
                                                                  token locally
                                                                  (no control plane
                                                                   round-trip)
```

This means the control plane being down does not affect existing servers. Only new signups break.

### Identity binding to license keys

`license_service` already produces 5-part keys with a nonce. Today the nonce = Polar order ID. In v2, the same key continues to work — the `server_id` registered with the control plane is derived from (or equals) the nonce. No re-issuance needed.

If a user wants to move their license to a different physical server, the desktop wizard re-registers under the same `server_id`, the control plane updates the tunnel mapping, and the subdomain stays the same. Hardware moves don't break the license.

### Billing (out of scope for v2 build, planning notes only)

- Polar webhook flow is unchanged — still issues license keys via the home server's webhook endpoint.
- The control plane could optionally check "is this server_id associated with a paid Polar order?" before issuing a subdomain. Free tier could get `<id>.fluxora.marshalx.dev` capped at 1 GB/month relayed traffic; Plus/Pro/Ultimate get higher caps. Cloudflare for SaaS does not enforce this — it would be measured at the home server and rejected via 402.
- For v2 simplicity: every registered server gets a subdomain regardless of tier. Defer paid-tier-gating until there's signal it's needed.

### v2 phasing

| Phase | Scope | Output |
|-------|-------|--------|
| **A — Identity baseline** | Make sure v1 server reports a stable `server_id`. Add `GET /api/v1/info/identity` returning `{server_id, license_tier, license_status}`. | Server ready to register. |
| **B — Control plane** | Cloudflare Worker + D1 + custom-hostnames API. Manual `curl` registers a test server. End-to-end: register → get subdomain → curl works. | Multi-tenant routing proven. |
| **C — Desktop wizard** | Replace the v1 manual setup wizard with the control-plane-driven one. Existing v1 users see a "Migrate to multi-tenant" button. | First non-test user can sign up. |
| **D — Status, polish, docs** | Public status page, error handling, retry logic, support runbook. | Public launch. |

Each phase is independently testable. Phase A can ship in v1 (it's just an additional endpoint).

### Multi-tenant decision points (resolve during v2 build)

| # | Question | Suggested resolution |
|---|----------|----------------------|
| **MT1** | Email signup or anonymous registration? | Email — needed for tunnel-down notifications and account recovery. |
| **MT2** | Does Fluxora own the subdomain namespace, or can users bring their own? | Both. Default `<id>.fluxora.marshalx.dev`; Pro/Ultimate users can configure a custom domain via CNAME. |
| **MT3** | What happens to the subdomain when a user stops using Fluxora? | 90 days inactive → tunnel disabled, subdomain reserved for 6 months, then released. |
| **MT4** | Free-tier abuse (someone uses Fluxora as a generic tunneling service)? | Subdomain only routes to the FastAPI server — not arbitrary HTTP. Enforced by ingress config in the user's tunnel. |

---

## Doc updates this implementation will trigger

When implementation begins, the following docs will need to be updated:

- `docs/02_architecture/01_system_overview.md` — add WAN routing diagram
- `docs/04_api/01_api_contracts.md` — base URL section gets a public entry; `GET /info` response gains `remote_url`; new `GET /healthz`
- `docs/05_infrastructure/01_infrastructure.md` — environment variables table gains `FLUXORA_PUBLIC_URL`, `FLUXORA_TRUST_CF_HEADERS`, `FLUXORA_BLOCK_HLS_OVER_TUNNEL`
- `docs/06_security/01_security.md` — Cloudflare threat model section
- `docs/10_planning/02_decisions.md` — ADR-013: "Public routing via Cloudflare Tunnel + media-plane direct/P2P"
- `docs/08_frontend/01_frontend_architecture.md` — `ApiClient` dual-base-URL pattern; mobile pairing flow
- `docs/00_overview/README.md` — add link to this doc
- `CLAUDE.md` — Tech Stack table gains "Cloudflare Tunnel"; Known Risks adds tunnel-down failure mode

---

## Rollout sequencing

1. **Land Phase 1** in operations (no code change). Verify `curl https://fluxora-api.marshalx.dev/api/v1/info` works.
2. **Land Phase 2** in a feature branch. Deploy + tunnel restart. Verify rate-limit, HLS-block, and admin-block all behave.
3. **Land Phase 3 + 4** together — `fluxora_core` and mobile in lockstep so the dual-base `ApiClient` doesn't ship without a remote URL to use.
4. **Land Phase 5** as desktop UI catch-up.
5. **Document everything** per the doc-updates list above.

Each phase is independently deployable — Phase 1 alone gives a working public URL with no client changes (clients keep using LAN-direct).
