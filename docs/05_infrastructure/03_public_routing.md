# Public API Routing — `fluxora-api.marshalx.dev`

> **Category:** Infrastructure
> **Status:** v1 single-tenant routing **COMPLETE** (2026-05-01) — Phases 1–5 shipped end-to-end. Phase 6 hardening is operator-driven and tracked in `docs/10_planning/04_manual_tasks.md`. Mobile Settings UI deferred (mobile has no Settings feature yet, by design). v2 multi-tenant track scoped below.
> **Last Updated:** 2026-05-01 (rev 6 — Phase 6 closed out as operator-driven manual-task entries; v1 routing now end-to-end shippable)

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

> **Status (2026-05-01):** Phase 2 complete. All seven sub-steps shipped. Total 149 tests including 21 new tests for the routing surface (6 in `test_healthz.py`, 15 in `test_real_ip.py`).

#### 2.0 Config additions (`apps/server/config.py`) ✅ Complete

Three new env-driven settings, all with safe defaults:

| Setting | Default | Effect |
|---------|---------|--------|
| `FLUXORA_PUBLIC_URL` | `""` | Empty disables remote access entirely. `GET /info` returns `remote_url: null`. |
| `FLUXORA_TRUST_CF_HEADERS` | `True` | Read `CF-Connecting-IP` from incoming requests for rate-limiting / real-IP attribution. Disable only if running behind something other than Cloudflare. |
| `FLUXORA_BLOCK_HLS_OVER_TUNNEL` | `True` | When True, requests with `CF-Connecting-IP` set are 403'd on `/api/v1/hls/*`. Enforces "media plane never traverses the tunnel." Wired by middleware 2.3 below. |

#### 2.1 CORS allow-list (`apps/server/main.py`) ✅ Complete

`CORSMiddleware` is the outermost middleware, allow-listing exactly:
- `https://fluxora.marshalx.dev` (apex marketing site)
- `https://uat.fluxora.marshalx.dev` (uat marketing site)
- `https://fluxora-api.marshalx.dev` (this server's own public hostname; needed for browser-side calls from the marketing site)

`allow_credentials=False`, methods limited to `GET / POST / PATCH / DELETE / OPTIONS`, headers to `Authorization` + `Content-Type`. No wildcards.

#### 2.2 Real-IP middleware (`apps/server/utils/real_ip.py`) ✅ Complete

`RealIPMiddleware` sets `request.state.real_ip` from `CF-Connecting-IP` only when:
1. `FLUXORA_TRUST_CF_HEADERS` is enabled
2. The immediate peer IP is in Cloudflare's published range list (prevents LAN clients from spoofing the header to bypass rate-limits)

Otherwise the peer's host IP is used directly. `slowapi`'s `Limiter` is now keyed off `request.state.real_ip` via `real_ip_key`, so WAN traffic is rate-limited per actual-client-IP rather than per-tunnel.

The Cloudflare IP list is fetched from `https://www.cloudflare.com/ips-v4` + `ips-v6` at startup (`refresh_cf_ranges()` called in the lifespan). A hardcoded fallback list (last refreshed 2026-05-01) protects against startup failure if the CF endpoint is unreachable.

#### 2.3 HLS-blocks-on-tunnel middleware ✅ Complete

`HLSBlockOverTunnelMiddleware` 403s any request matching `/api/v1/hls/*` that carries a `CF-Connecting-IP` header (the tunnel signature). Toggleable via `FLUXORA_BLOCK_HLS_OVER_TUNNEL` (default: True). Forces clients to negotiate WebRTC for WAN streaming.

The 403 body is `{"detail": "HLS over public tunnel is disabled. Use WebRTC for WAN streaming."}`.

#### 2.4 Localhost-only hardening (`apps/server/routers/deps.py`) ✅ Complete

`require_local_caller` now rejects any request with `CF-Connecting-IP` set, in addition to the existing peer-IP-must-be-loopback check. This catches the case where cloudflared forwards a tunneled request via 127.0.0.1 — peer is loopback but the request originated remotely.

`validate_token_or_local` got the same treatment: tunneled requests skip the localhost-shortcut and always go through `validate_token`, so the desktop control panel's loopback-no-token convenience can't be exploited by a remote caller.

#### 2.5 Healthcheck (`apps/server/routers/info.py`) ✅ Complete

`GET /api/v1/healthz` returns `{"ok": true}` — no DB access, no auth, constant body. Used by Cloudflare Tunnel ingress health checks and by clients deciding whether the public URL is reachable. Excluded from OpenAPI schema (`include_in_schema=False`) since it's not part of the v1 contract.

#### 2.6 `remote_url` in `GET /info` ✅ Complete

`ServerInfoResponse.remote_url: str | None` is populated from `FLUXORA_PUBLIC_URL`:
- Empty env var → `null` in the response (clients infer remote access not configured)
- Set env var → URL string (clients persist it after pairing per [decision D1](#decisions-locked))

Test coverage: 6 tests in `tests/test_healthz.py` covering both endpoints + the response-shape contract.

#### 2.7 System stats: populate `public_address` ✅ Complete

`SystemStatsService._public_address()` probes `<FLUXORA_PUBLIC_URL>/api/v1/healthz` with a 5s timeout, returns the URL on 200, `None` on any failure (timeout, non-200, network error, missing config).

Result cached for 30s per-instance — `system_stats.collect()` reads the cached value; the probe only fires when the cache is stale. Keeps `/info/stats` fast and stays polite to the Cloudflare edge.

The desktop `SystemStatsCard` (which already consumes `/info/stats`) gets a green/red dot the moment this field flips between `null` and a string — no UI rework needed.

### Phase 3 — Shared core (`packages/fluxora_core`) ✅ Complete

#### 3.1 `ApiClient` accepts dual base URLs ✅

`packages/fluxora_core/lib/network/api_client.dart` now resolves the base URL per request via a `LanCheck` callback (defaults to `NetworkPathDetector.isLan`):

```dart
final client = ApiClient(
  localBaseUrl: 'http://192.168.1.10:8080',
  remoteBaseUrl: 'https://fluxora-api.marshalx.dev',
  // lanCheck defaults to NetworkPathDetector.isLan
);
```

Resolution rules (private `_resolveBaseUrl`):

| Local | Remote | LAN? | Result |
|-------|--------|------|--------|
| set   | set    | yes  | local  |
| set   | set    | no   | remote |
| set   | unset  | yes  | local  |
| set   | unset  | no   | throw `NoRemoteConfiguredException` |
| unset | set    | —    | remote |
| unset | unset  | —    | throw `NoRemoteConfiguredException` |

The Dio request interceptor calls `_resolveBaseUrl()` and rewrites `options.baseUrl` per request, so every screen/route benefits transparently. If the resolver throws, each public method (`get/post/put/patch/delete`) unwraps the `NoRemoteConfiguredException` from the `DioException` and rethrows it directly — so callers can `catch (NoRemoteConfiguredException)` cleanly.

`configure(...)` accepts the same dual-URL signature for live updates after pairing. The legacy single `baseUrl` arg is kept on both the constructor and `configure` as `@Deprecated` — calls keep compiling and route through `localBaseUrl`.

Test coverage: `packages/fluxora_core/test/network/api_client_test.dart` — 9 tests covering all six resolution branches, `configure()`, `clearRemoteBaseUrl()`, and the legacy `baseUrl` alias.

#### 3.2 `SecureStorage` stores both URLs ✅

`packages/fluxora_core/lib/storage/secure_storage.dart` adds:

- `saveRemoteUrl(url)` / `getRemoteUrl()` / `deleteRemoteUrl()`
- `savePairing({ authToken, serverUrl, clientId, remoteUrl? })` — single-call helper that writes all four fields atomically. Passing `remoteUrl: null` deletes any stored remote URL (used when the server has disabled remote access).

The `_keyRemoteUrl` storage key is `'remote_url'`.

#### 3.3 `NetworkPathDetector` moved into core ✅

The detector previously lived under `apps/mobile/lib/features/player/data/services/`; it has been moved to `packages/fluxora_core/lib/network/network_path_detector.dart` so the desktop and any future web client can reuse it. The mobile copy was deleted; the only mobile import (`PlayerCubit`) now imports from `package:fluxora_core/network/network_path_detector.dart`.

The same module exposes a `LanCheck` typedef (`Future<bool> Function(String)`) which `ApiClient` accepts for test injection.

#### 3.4 Injector + legacy callers migrated ✅

- `apps/mobile/lib/core/di/injector.dart` — restores both `serverUrl` and `remoteUrl` from `SecureStorage` on app start and calls `ApiClient.configure(localBaseUrl: …, remoteBaseUrl: …)`.
- All remaining callers (`auth_repository_impl`, `server_discovery_repository_impl`, `connect_screen`, desktop `injector`/`settings_cubit`/tests) now pass `localBaseUrl:` instead of the deprecated `baseUrl:`. `flutter analyze` is clean across `fluxora_core`, mobile, and desktop.

### Phase 4 — Mobile client ✅ Complete (data path); Settings UI deferred

#### 4.1 `ServerInfo` entity gains `remoteUrl` ✅

`packages/fluxora_core/lib/entities/server_info.dart` adds `String? remoteUrl` (auto-mapped to the JSON `remote_url` via `field_rename: snake` in `build.yaml`). Generated `*.freezed.dart` / `*.g.dart` rebuilt via `dart run build_runner build --delete-conflicting-outputs`.

#### 4.2 Pairing flow persists `remote_url` ✅

`apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart::saveCredentials` now:

1. Configures `ApiClient` with `localBaseUrl + bearerToken` (so the next call uses the freshly paired server).
2. Calls `GET /api/v1/info` and reads `info.remoteUrl`. The fetch is wrapped in a try/catch — failure is logged but non-fatal so a paired client without remote access keeps working LAN-direct.
3. Persists everything atomically through `SecureStorage.savePairing(authToken, serverUrl, clientId, remoteUrl)`.
4. If a remote URL came back, calls `_apiClient.configure(remoteBaseUrl: …)` so subsequent off-LAN requests route through the tunnel.

`PairCubit` and the `AuthRepository` interface are unchanged — the new behavior is hidden behind the existing `saveCredentials` signature.

`ApiClient.configure()` was tightened during this slice: previously it always overwrote `_bearerToken` (even when not passed), which meant the connect-screen's pre-auth `configure(localBaseUrl: …)` would wipe a saved token if it ever ran post-pair. It now only updates the fields that are non-null, with explicit `clearBearerToken()` and `clearRemoteBaseUrl()` for the rare cases that need to clear.

Test coverage: `apps/mobile/test/features/auth/auth_repository_impl_test.dart` (3 tests) covering happy path, no-remote server, and `/info` failure.

#### 4.3 Library / Files / Stream — no changes ✅

`ApiClient` does the routing per request. None of the per-screen repositories needed touches.

#### 4.4 WebRTC signaling — no changes ✅

`WebRtcSignalingService` builds its WS URL from `ApiClient`'s resolved base; it will pick up `wss://fluxora-api.marshalx.dev/api/v1/ws/signal` automatically when off-LAN.

#### 4.5 Mobile Settings — deferred 🔲

The plan called for a "Remote access" row showing whether `fluxora-api.marshalx.dev` is reachable via `HEAD /api/v1/healthz`. The mobile app currently has **no** Settings feature folder — by design, the Desktop Control Panel is the canonical v1 settings surface (see `CLAUDE.md` Current Status: mobile features are connect / auth / library / player / upgrade only). Building a full settings screen + cubit + repo + router entry just for one row is out of scope for this slice.

Tracked as a follow-up: when mobile gains a Settings screen (theme / language / unpair / etc.), the Remote-access row and a `_apiClient.get(Endpoints.healthz)` probe wire in trivially. `Endpoints.healthz` is already exported from `fluxora_core` for that use.

### Phase 5 — Desktop control panel ✅ Complete (configured-state UI; live `public_address` indicator deferred)

#### 5.1 Dashboard: Remote-access pill ✅

`apps/desktop/lib/features/dashboard/presentation/screens/dashboard_screen.dart::_ServerInfoCard` now renders two pills next to the server name: the existing `Online` pill plus a new `Remote: on` / `Remote: off` pill driven by `serverInfo.remoteUrl` (the field added to the `ServerInfo` entity in Phase 4). Tooltip on hover spells out the configured URL or explains why off-LAN access is unavailable. Pulled out into a reusable `_StatusPill` so future status indicators don't duplicate the styling.

The originally-planned "live `public_address` reachability" indicator (driven by `system_stats_service._public_address()` via `GET /info/stats`) is deferred — desktop doesn't yet consume `/info/stats` directly. The "configured" signal already gives the operator a clear go/no-go; live reachability is more useful in the Settings probe (5.2).

#### 5.2 Settings: Remote Access section ✅

`apps/desktop/lib/features/settings/presentation/screens/settings_screen.dart` gains a `Remote Access` `_SectionCard` between `Server Connection` and `Subscription`. It surfaces:

- **Public URL** — read-only display of `serverInfo.remoteUrl` from `/info`. Monospaced when configured; `Not configured` placeholder + link to the Cloudflare Tunnel runbook when not.
- **Reachability badge** — shows one of `Not checked yet` / `Checking…` / `Tunnel reachable` / `Tunnel unreachable` based on a one-shot probe.
- **Check now** button — fires the probe.

The probe lives in `SettingsCubit.checkRemoteAccess()` and bypasses the dual-base `ApiClient` deliberately: the desktop runs on the same /24 as the server, so the LAN check would always pick `localBaseUrl` and miss the point. Instead a fresh `Dio` is constructed with the remote URL as `baseUrl` and a 5s connect/receive timeout, then `GET /api/v1/healthz` is fired. 200 → reachable; anything else → unreachable. Errors are logged but never surface as exceptions — the UI just shows the red badge.

`SettingsLoaded` state added optional `remoteUrl` and `remoteAccessStatus` fields plus a `copyWith` so the cubit can update reachability without re-fetching settings. The probe is on-demand only (no background polling) to avoid hammering the Cloudflare edge.

`SettingsCubit.loadSettings()` now also fetches `/info` after the existing `/settings` call to populate `remoteUrl`. The `/info` call is wrapped in try/catch — failure is silent and the section renders as "Not configured".

Test coverage: 4 new tests in `settings_cubit_test.dart` covering `loadSettings` populating `remoteUrl`, tolerating `/info` failure, and `checkRemoteAccess` early-returning when no state / no remote URL is configured. Desktop suite goes 34 → 38.

#### 5.3 In-app cloudflared install wizard 🔲

Out of scope for v1 per the original plan. Operators run the steps in `runbooks/01_cloudflare_tunnel.md` manually for now. Triggered from the Remote Access section's hint text which links to the runbook.

### Phase 6 — Optional hardening (operator-driven)

Phase 6 is intentionally outside the codebase — every item is a Cloudflare-dashboard configuration or a separate piece of infrastructure (TURN). They've been written up as standalone entries in [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md) so the owner can pick them up on their own cadence:

| Item | Manual-tasks entry | Time | When to do it |
|------|-------------------|------|---------------|
| Self-hosted TURN at `turn.fluxora.marshalx.dev` | "Stand up self-hosted TURN" | ~3-4h | When the first cellular / symmetric-NAT user reports WebRTC failures. |
| Cloudflare WAF custom rules | "Cloudflare WAF custom rules for the public tunnel hostname" | ~15m | Before announcing the public URL externally. |
| Tunnel health alerts | "Cloudflare tunnel health alerts" | ~5m | Before announcing the public URL externally. |
| Cloudflare Access on admin paths | "Cloudflare Access on admin paths (defense in depth)" | ~20m | Optional — server-side already rejects tunneled admin calls; this is belt-and-suspenders. |

The first three are recommended before the public URL is shared with anyone outside the trusted-paired-clients model. The Cloudflare Access entry is purely defense-in-depth — `require_local_caller` and the Phase 2 `CF-Connecting-IP` rejection on admin endpoints already block tunneled admin traffic at the application layer.

The TURN entry is the only one with non-trivial scope; it's written up as its own manual task because it touches `webrtc_service.py`, the `~/.fluxora/.env` secrets, and a second Cloudflare Tunnel ingress. The coturn install + auth-credential rotation flow is already documented in [`06_webrtc_and_turn.md`](./06_webrtc_and_turn.md) (env-var support is shipped via `WEBRTC_TURN_URL`/`USERNAME`/`PASSWORD`; provisioning is deferred until WAN-failure telemetry shows the demand).

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
