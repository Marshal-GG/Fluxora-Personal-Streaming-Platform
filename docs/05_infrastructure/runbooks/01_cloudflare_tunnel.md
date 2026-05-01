# Runbook: Cloudflare Tunnel for a self-hosted service

> **What:** Expose a service running on your home/office PC at a public HTTPS URL via Cloudflare Tunnel. No port forwarding, no public IP, no ongoing cost.
> **Estimated time:** 30–45 minutes for a clean setup; budget 2 hours if you're following this for the first time and hit any platform-specific quirks.

This runbook is project-agnostic. Substitute the placeholders for your specific values.

| Placeholder | What it is | Example |
|-------------|-----------|---------|
| `<APEX>` | The domain you own | `example.dev` |
| `<HOSTNAME>` | The single-level subdomain you want clients to use | `myapp-api.example.dev` |
| `<TUNNEL_NAME>` | Friendly name for the tunnel | `myapp-home` |
| `<PORT>` | Local port the service listens on | `8080` |
| `<USER>` | Your Windows username (for path examples) | `alice` |

---

## Prerequisites

1. **A domain in Cloudflare DNS.** Either bought through Cloudflare, or transferred to use Cloudflare nameservers. The plan can be free.
2. **Admin access to the home/office PC** that will run the daemon — needed once for the Windows service install + once for any registry override.
3. **The local service is running** at `http://127.0.0.1:<PORT>`. You don't need it up while you set up the tunnel, but you'll want it up for the smoke test.
4. **A regular and an admin terminal.** Most steps are non-admin; service install + registry edit + service restart need admin.

---

## ⚠️ Hostname depth rule (read this first)

Cloudflare's free Universal SSL covers the apex + **one level** of subdomain. That means:

| Hostname | Free cert? |
|----------|-----------|
| `example.dev` | ✅ |
| `api.example.dev` | ✅ |
| `myapp-api.example.dev` | ✅ |
| `staging.api.example.dev` | ❌ (two levels — needs Advanced Cert Manager $10/mo) |
| `dev.www.example.dev` | ❌ |

Tunneled hostnames **must** go through Cloudflare's edge (proxy ON), which means Cloudflare terminates TLS, which means Universal SSL applies. Pick a single-level subdomain, **hyphenated** if you want grouping (`myapp-api`, `myapp-uat`). Don't pivot to deep subdomains unless you're ready to pay.

Source: [Cloudflare Total TLS error-messages docs](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/total-tls/error-messages/).

---

## Step 1 — Install `cloudflared`

```powershell
# Windows
winget install --id Cloudflare.cloudflared
```

```bash
# macOS
brew install cloudflared

# Debian / Ubuntu
sudo apt install cloudflared

# Linux generic — download from https://github.com/cloudflare/cloudflared/releases
```

Open a fresh terminal afterward (PATH may not refresh in existing sessions). Verify:

```powershell
cloudflared --version
```

Expect a version string. Don't worry about "version is outdated" warnings — patch versions matter rarely.

---

## Step 2 — Authenticate to Cloudflare

```powershell
cloudflared tunnel login
```

Browser opens. Log into Cloudflare, **select the `<APEX>` zone**, click Authorize. Cert lands at `~/.cloudflared/cert.pem` (Windows: `C:\Users\<USER>\.cloudflared\cert.pem`).

This cert is your tunnel-creation credential for that zone. **Back it up** — losing it doesn't break running tunnels but blocks creating new ones in the same zone.

---

## Step 3 — Create the tunnel

```powershell
cloudflared tunnel create <TUNNEL_NAME>
```

Output:

```
Tunnel credentials written to ~/.cloudflared/<UUID>.json
Created tunnel <TUNNEL_NAME> with id <UUID>
```

**Capture the UUID.** The `.json` file is the tunnel's private key — **back this up too**.

---

## Step 4 — Create the DNS record

```powershell
cloudflared tunnel route dns <TUNNEL_NAME> <HOSTNAME>
```

Cloudflare creates a CNAME `<HOSTNAME>` → `<UUID>.cfargotunnel.com` with proxy ON. No dashboard step needed.

---

## Step 5 — Write the local config

`~/.cloudflared/config.yml` (Windows: `C:\Users\<USER>\.cloudflared\config.yml`):

```yaml
tunnel: <UUID>
credentials-file: C:\Users\<USER>\.cloudflared\<UUID>.json   # absolute path

ingress:
  - hostname: <HOSTNAME>
    service: http://127.0.0.1:<PORT>      # NOT http://localhost:<PORT> — see pitfall #2
  - service: http_status:404
```

> **⚠️ Pitfall #1 — `localhost` resolves to IPv6 first on Windows.** If your service binds IPv4 only, cloudflared dials `[::1]:<PORT>` and gets connection refused. Use `127.0.0.1` explicitly.

---

## Step 6 — Install + start the Windows service

In an **elevated** PowerShell (right-click Start → "Terminal (Admin)"):

```powershell
cloudflared.exe service install
```

This registers a Windows service named `Cloudflared` running as `LocalSystem`. The service auto-starts on boot.

> **⚠️ Pitfall #2 — service install does not pass `--config`.** It registers the service to use cloudflared's default config search, which on `LocalSystem` looks at `C:\Windows\System32\config\systemprofile\.cloudflared\config.yml`. As of cloudflared 2025.8.x, this path is unreliable: even with files copied there, the service can crash with exit code `1067`. The fix is to override the launch command via the registry to use explicit `--config`:

```powershell
# Admin PS — grant SYSTEM read access to your user-level config dir
icacls "$env:USERPROFILE\.cloudflared" /grant "SYSTEM:(OI)(CI)F" /T

# Substitute YOUR username and tunnel name
$cmdline = '"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --config "C:\Users\<USER>\.cloudflared\config.yml" run <TUNNEL_NAME>'
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Cloudflared" `
  -Name "ImagePath" -Value $cmdline -Type ExpandString

# Restart so the new ImagePath takes effect
sc.exe stop Cloudflared 2>$null
taskkill /F /IM cloudflared.exe 2>$null
Start-Sleep -Seconds 2
sc.exe start Cloudflared
sc.exe query Cloudflared          # expect STATE: 4 RUNNING
```

After this, the service reads from your user-level `~/.cloudflared/config.yml` directly — future config edits just need a service restart.

---

## Step 7 — Smoke test

In any terminal (start your local service first if you want a real response):

```powershell
curl.exe -fsS https://<HOSTNAME>/<some-path>
```

Possible outcomes:

| Result | Meaning |
|--------|---------|
| Valid response from your service | ✅ Done |
| `502 Bad Gateway` | ✅ Tunnel works; your service isn't running on `<PORT>` |
| `error code: 1033` | Tunnel daemon doesn't have a route for this hostname — check service is running, ImagePath is correct, and config has the right `hostname:` |
| `error code: 530` | Tunnel daemon isn't connected to Cloudflare edge — service is probably crashing, see pitfalls |
| TLS handshake error | Cert is still provisioning (wait 1–15 min) — or the hostname is too deep for Universal SSL |

---

## Day-2 operations

### Edit the config

Edit `~/.cloudflared/config.yml`, then in an **admin** shell:

```powershell
sc.exe stop Cloudflared
taskkill /F /IM cloudflared.exe 2>$null
sc.exe start Cloudflared
sc.exe query Cloudflared
```

### Add a second hostname (e.g. UAT alongside production)

Edit `config.yml`:

```yaml
ingress:
  - hostname: <HOSTNAME>
    service: http://127.0.0.1:<PORT>
  - hostname: <HOSTNAME-UAT>
    service: http://127.0.0.1:<UAT-PORT>
  - service: http_status:404
```

Create the second DNS record:

```powershell
cloudflared tunnel route dns <TUNNEL_NAME> <HOSTNAME-UAT>
```

Restart the service. Done.

### Stop the tunnel

```powershell
sc.exe stop Cloudflared       # admin
```

### Permanently remove the tunnel

```powershell
sc.exe stop Cloudflared
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" service uninstall
cloudflared tunnel delete <TUNNEL_NAME>
# Then delete the DNS record from Cloudflare dashboard
```

---

## All known pitfalls (consolidated)

| # | Symptom | Cause | Fix |
|---|---------|-------|-----|
| 1 | `dial tcp [::1]:<PORT>: connectex: No connection could be made` | Windows resolves `localhost` to IPv6 first; service binds IPv4 only | Use `http://127.0.0.1:<PORT>` in config (NOT `localhost`) |
| 2 | Service start succeeds, then exits in seconds with code 1067 | cloudflared 2025.8.x default config search is unreliable on LocalSystem | Override `ImagePath` in registry to use explicit `--config` (Step 6) |
| 3 | TLS handshake fails / no cert presented | Hostname is two levels deep, Universal SSL only covers one | Pivot to single-level hyphen pattern (`myapp-api`, not `api.myapp`) |
| 4 | `Could not find a part of the path 'C:\...\systemprofile\.cloudflared\'` | Default systemprofile dir doesn't exist; PowerShell's `Copy-Item` doesn't auto-create parents | Either `New-Item -ItemType Directory -Force` first, OR avoid this path entirely by using the registry override |
| 5 | `cloudflared --version` not found after winget install | PATH not refreshed in current shell | Open a new terminal, or refresh PATH via `$env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine')+';'+[Environment]::GetEnvironmentVariable('PATH','User')` |
| 6 | `sc.exe stop Cloudflared` returns "service has not been started" | Already stopped, or the previous start crashed before recording state | Just proceed — `taskkill /F /IM cloudflared.exe` handles any residual process |
| 7 | `Copy-Item /Y ...` fails in PowerShell | `/Y` is `cmd` syntax; PowerShell's `Copy-Item` uses `-Force` | Either use `-Force` or run from `cmd.exe`, not PowerShell |

---

## What to back up

| Path | Why |
|------|-----|
| `~/.cloudflared/cert.pem` | Zone authentication. Lose it → can't create new tunnels in the zone |
| `~/.cloudflared/<UUID>.json` | Per-tunnel private key. Lose it → must recreate the tunnel + update DNS CNAME |
| `~/.cloudflared/config.yml` | Trivial to recreate from this runbook + your knowledge of which ingress rules you had |

Project-specific backup procedures: see [`05_backup_and_recovery.md`](../05_backup_and_recovery.md).

---

## Cross-references

- **Static-site hosting + custom domain (Firebase):** [`02_firebase_static_hosting.md`](./02_firebase_static_hosting.md)
- **CI/CD around these pieces:** [`03_github_ci_cd.md`](./03_github_ci_cd.md)
- **Branch / PR workflow:** [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md)
- **Fluxora's specific tunnel deployment:** [`../03_public_routing.md`](../03_public_routing.md) (project-specific values, decisions, and history)
