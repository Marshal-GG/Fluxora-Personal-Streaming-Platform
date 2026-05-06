# Installer & Distribution Plan — v1

> **Category:** Planning
> **Status:** 🔵 **IN PROGRESS** — captured 2026-05-03; ISS implementation landed 2026-05-06 at [`installer/Fluxora.iss`](../../installer/Fluxora.iss) with build-pipeline doc at [`installer/BUILD.md`](../../installer/BUILD.md). All 10 must-have items from the §"10-item installer feature checklist" below are implemented in the .iss; D1–D8 owner decisions defaulted as listed.
> **Outstanding work:** running the payload-staging build pipeline once (Nuitka for the server + `flutter build windows --release --obfuscate` for the desktop + FFmpeg LGPL bundle + VC++ redist staging + ISCC compile), Squirrel.Windows auto-update wire-up (item 2 of the checklist — separate workstream from the .iss), and the smoke-test matrix on clean Win 10 / Win 11 VMs. Tracked in [`04_manual_tasks.md`](./04_manual_tasks.md).

This doc captures the full design conversation around how to ship Fluxora's server + desktop binaries to end users. The bundled-installer model (Option A) is now implemented in [`installer/Fluxora.iss`](../../installer/Fluxora.iss); this doc remains the design rationale for *why* the .iss looks the way it does (every section in the .iss has a comment cross-referencing the matching plan item here).

---

## The three packaging options

| | A: Bundled installer (one download) | B: Bootstrapper-then-download (Adobe pattern) | C: Separate downloads (Plex pattern) |
|---|---|---|---|
| **First-install friction** | Lowest — one click | Medium — installer + first-run wait | Highest — find + download both |
| **Initial download size** | ~200 MB (server PyInstaller + desktop Flutter + FFmpeg) | ~50 KB stub | ~150 MB server / ~50 MB desktop separately |
| **Update path** | One updater, both bins versioned independently | Per-binary update streams, more moving parts | Two update flows the user must trigger |
| **Headless server** (NAS, tucked-away PC, no monitor) | 🟡 GUI bundled but unused | 🟡 Same | ✅ Server-only is clean |
| **Mobile-only users** (phone-only, never opens desktop) | 🟡 Forced to install desktop too | 🟡 Same | ✅ Can install just server |
| **Brand confusion** | None — "one app called Fluxora" | None | "Wait, do I download both? Which one first?" |
| **Code signing** | One cert, one signature per platform | Two signed binaries (bootstrapper + payload) | Two signed binaries |
| **First-run failure modes** | Either install works or it fails (clean) | First-run can break on flaky network; AV flags second download more aggressively | N/A |
| **Infrastructure required** | Static file hosting (~200 MB) | CDN + version-metadata API + bandwidth | Static file hosting (~200 MB split) |
| **Reputation risk** | None | High — "Adobe Updater is using 47% CPU" memes | None |

### Recommended: Option A + a power-user escape hatch

- **Default landing-page download:** bundled installer. One click, server registered as a Windows Service auto-starting on boot, desktop launches showing "Server: ✅ Running" green light. Mental model: "one app called Fluxora." Covers ~90% of users.
- **Power-user secondary download:** server-only `.exe` for headless NAS / HTPC setups. Hidden behind a "Running headless?" link. Covers ~5% of users.
- **Don't do B (lazy bootstrapper)** because two binaries crossing the firewall = two SmartScreen / Gatekeeper flags, first-run network failures = terrible first impression, update divergence is a real support load, and the pattern is universally seen as enterprise bloatware in 2026.
- **Don't do C (separate)** because Fluxora doesn't have Plex's brand recognition — first-time users would be confused by "wait, which one do I download?"

---

## Auto-update model — keep what's useful from Adobe, skip what isn't

Adobe's installer ships two distinct things:

1. **Bootstrapper installer** — the bad / contentious part. Skip.
2. **Updater service + crash monitoring** — genuinely valuable for a 24/7 server. Adopt, but with modern lightweight tools.

### Recommended stack

| Concern | Tool / approach | Notes |
|---------|-----------------|-------|
| **Auto-update — Windows** | [Squirrel.Windows](https://github.com/Squirrel/Squirrel.Windows) | Used by Slack, Discord, GitHub Desktop, VS Code. App checks for updates on launch + every N hours. Delta downloads. Zero infrastructure beyond a static `RELEASES` file. **No service running on the user's machine.** |
| **Auto-update — macOS** | [Sparkle](https://sparkle-project.org/) | Used by Transmission, Obsidian, Bartender. App polls a static `appcast.xml`. No daemon. |
| **Auto-update — Linux** | Punt | `.AppImage` users update manually; `.deb` users get apt updates from your repo (more work — defer past v1). |
| **Server crash recovery** | Windows Service auto-restart via `sc.exe failure` | `restart/5000/restart/5000/restart/30000` = restart after 5s twice, then 30s. Counter resets after 24h. Built into Windows. **Zero code on your end.** |
| **Crash telemetry** | Sentry (already wired in `apps/server/main.py`) | Just paste DSN in `~/.fluxora/.env`. Tracked in [`04_manual_tasks.md`](./04_manual_tasks.md). |

### Update infrastructure

Static files only. No API. Hostable on Firebase (already in use):

```
fluxora.marshalx.dev/updates/
├── windows/
│   ├── RELEASES                  (Squirrel format, one line per version)
│   ├── Fluxora-1.0.0-full.nupkg
│   └── Fluxora-1.0.0-delta.nupkg
└── macos/
    ├── appcast.xml               (Sparkle format, ~30 lines)
    └── Fluxora-1.0.0.dmg
```

User-facing benefit set is identical to Adobe ("always up to date, recovers from crashes") with **none of Adobe's reputation hit** ("this app installed 4 background services I never asked for").

---

## The 10-item installer feature checklist

Everything below is "must-have for v1 launch." Items 1–10 are scoped tightly so an Inno Setup author could implement the whole list in 1–2 days (3–4 days first time).

| # | Item | Why it matters | How |
|---|------|----------------|-----|
| 1 | One bundled installer (server + desktop) | First-install conversion | Inno Setup `[Files]` blocks for both binary trees |
| 2 | Auto-update via Squirrel (Win) / Sparkle (mac) — no bootstrapper, no daemon | Long-lived ship-it-and-forget | Static `RELEASES` / `appcast.xml` on Firebase |
| 3 | **Server registered as Windows Service with auto-restart on crash** | Streaming survives crashes; user never sees a 502 | `sc.exe create FluxoraServer ... start= auto` + `sc.exe failure ... reset= 86400 actions= restart/5000/restart/5000/restart/30000` |
| 4 | **Open Windows Firewall rules at install** | Without this, mobile clients can't reach the server on first install — pairing fails silently. Critical UX blocker. | `netsh advfirewall firewall add rule name="Fluxora Server" dir=in protocol=TCP localport=8000 action=allow` in post-install |
| 5 | **Add HLS temp dir to Windows Defender exclusions** | Defender scans every 4-second `.ts` segment as it's written — silently cuts streaming throughput by 30–60%. Already documented in [`12_guidelines/03_gotchas.md`](../12_guidelines/03_gotchas.md). | `powershell.exe -Command "Add-MpPreference -ExclusionPath '$env:TEMP\fluxora-hls'"` |
| 6 | **Bundle Visual C++ Redistributable + chain-install if missing** | PyInstaller binaries depend on it. On a fresh Windows install (~15% of clean machines), `.exe` silently fails to launch with no useful error. | Inno Setup `[Files]` ships `vc_redist.x64.exe`; `[Run]` chains `/quiet /install` if not present |
| 7 | **Don't update server while active streams are running** | Otherwise you boot a paying user out of their movie at 11 PM | Squirrel `--squirrel-updated` hook → server checks `stream_sessions` count → refuses → updater retries in 30 min |
| 8 | **Run server as `LocalService`, not `LocalSystem`** | Least privilege. `LocalSystem` is admin-equivalent — bigger blast radius if the server ever has an RCE bug. | `sc.exe create ... obj= "NT AUTHORITY\LocalService"` |
| 9 | **Keep user data on uninstall (default ON)** | Most uninstalls are "trying to fix something, will reinstall." Wiping `~/.fluxora/` = re-pairing every device. | Inno Setup `[UninstallDelete]` + checkbox defaulting OFF on the uninstaller's confirmation page |
| 10 | **Sentry DSN slot in `.env`** | Crash telemetry — code is already wired in `apps/server/main.py`. Just need the DSN pasted post-install. | Already done code-wise; tracked as a manual task |

---

## Worth adding, can defer past launch

| # | Item | Why defer |
|---|------|-----------|
| A | **Anonymous telemetry opt-in toggle** (version, OS, uptime — nothing else) | Sentry covers urgent stuff (crashes). Add when you have ≥10 paying users and want adoption insight. Will eventually be required by some app stores. |
| B | **Detect existing install + offer upgrade vs reinstall** | Inno Setup detects this by default — failure mode is "two side-by-side installs in different folders," which is annoying but not broken. Tighten when someone complains. |

---

## Things to actively SKIP

| Item | Why not |
|------|---------|
| Custom install path option | Power users can edit the registry; everyone else picks default. Adds wizard steps for a 1% audience. |
| 32-bit build | Windows 11 dropped 32-bit entirely. Don't bother. |
| Per-user install option | Per-machine install is correct for a server. Per-user is a Plex-app-style thing for clients only — not relevant when you bundle. |
| Welcome / onboarding wizard inside the installer | Put onboarding in the **desktop app's first launch**, not the installer. Installers should finish ASAP. |
| Logging to Windows Event Log | File logs + Sentry covers it. Event Log is enterprise-IT theater that nobody actually reads. |
| License agreement EULA wall | Code-signing CAs don't require this despite myths. Adds a click; gains nothing. Skip unless legal counsel says otherwise pre-launch. |

---

## Cross-platform notes

| OS | Approach | Effort |
|----|----------|--------|
| **Windows** | Inno Setup script. Server runs as Windows Service (`sc.exe`). Squirrel for updates. Code-signing cert applied to both `.exe`s and the installer itself. | ~1–2 days experienced; 3–4 days first time |
| **macOS** | Server binary inside `Fluxora.app/Contents/Resources/server/`. Desktop launches it via launchd plist on first run. One Apple notarization covers both. Sparkle for updates. | ~1 day after Windows is solid |
| **Linux** | Two `.deb` packages with a `fluxora-meta` package depending on both, OR one big `.AppImage`. systemd unit for the server. No native auto-update — defer to apt repo or manual. | ~1–2 days; lower priority |

---

## When the bootstrapper / Adobe model would actually be right

For completeness, the Adobe pattern is correct when:

- Install size > 1 GB (Fluxora isn't)
- Server-side A/B testing on installer flow needed (you don't)
- Ship 50+ optional components (you ship 2)
- Have ops staff to run the CDN + monitoring (you don't)

None apply yet. Revisit at v2 if you grow into them.

---

## Effort estimate (Option A, full checklist)

| Workstream | Time | Prerequisite |
|------------|------|--------------|
| Inno Setup script with all 10 must-have items | 1–2 days experienced; 3–4 days first time | None |
| Windows code-signing integration into build pipeline | ~30 min once cert arrives | OV/EV cert ordered (3–7 day wait) |
| Squirrel.Windows integration (in-app update check + RELEASES file generation in CI) | ~1 day | None |
| Static update hosting on Firebase | ~30 min | Existing Firebase project |
| macOS `.dmg` + notarization + Sparkle | ~1 day | Apple Developer Program ($99/yr) |
| Linux `.AppImage` + `.deb` | ~1–2 days | None |
| Smoke-test matrix (clean Win 10, clean Win 11, fresh macOS) | ~1 day | VMs / spare hardware |
| **Total for Win-only v1 launch** | **~3–4 days** | Plus cert wait |
| **Total for Win + Mac v1 launch** | **~5–6 days** | Plus cert wait + Apple membership |

---

## Open decisions for the owner

Before any implementation, the following need owner choices:

| # | Decision | Options | Default if undecided |
|---|----------|---------|----------------------|
| D1 | Code-signing cert vendor | Sectigo / DigiCert / SSL.com (OV) — ~$200–400/yr; or EV variants for instant SmartScreen reputation — ~$300–600/yr | Sectigo OV (cheapest, builds reputation over downloads) |
| D2 | macOS support at launch? | Yes ($99/yr Apple Developer + extra ~1 day work) / No (defer) | Defer — Win-only v1 launch |
| D3 | Linux support at launch? | Yes / No (defer) | Defer |
| D4 | Update hosting location | `fluxora.marshalx.dev/updates/` on Firebase / Cloudflare R2 / GitHub Releases | Firebase (already paid, 0 extra setup) |
| D5 | Default install location | `Program Files\Fluxora\` (per-machine, requires UAC) / `%LOCALAPPDATA%\Fluxora\` (per-user, no UAC) | `Program Files` — server-as-service requires it |
| D6 | Telemetry opt-in at launch? | Yes (default OFF; "share anonymous version + uptime?") / No (Sentry only) | No — Sentry is enough for v1 |
| D7 | Bundled FFmpeg version | Pin specific (e.g. 7.0.1) / track latest stable | Pin specific — already a known gotcha to avoid PATH pickup ([`12_guidelines/03_gotchas.md`](../12_guidelines/03_gotchas.md)) |
| D8 | Power-user "server-only" download offered at launch? | Yes (small extra build artifact) / No (only bundled) | Yes — covers headless NAS users, ~30 min extra in CI |

Once D1–D8 are decided, the relevant rows in [`04_manual_tasks.md`](./04_manual_tasks.md) (Windows server `.exe` code signing, Desktop installer + signing) get rewritten with concrete steps and assigned an owner.

---

## Cross-references

- [`installer/Fluxora.iss`](../../installer/Fluxora.iss) — the implementation of this plan (all 10 must-have items + 13 audit fixes inline)
- [`installer/BUILD.md`](../../installer/BUILD.md) — mechanical build pipeline (Nuitka + Flutter `--obfuscate` + ISCC compile + signing)
- [`installer/SHIP.md`](../../installer/SHIP.md) — strategic ship-readiness checklist (every blocker before first ship — 22 items)
- [`installer/AUDIT.md`](../../installer/AUDIT.md) — 15-finding edge-case audit covering update / repair / reset / partial-uninstall / silent-mode / branding paths
- [`05_ship_readiness.md`](./05_ship_readiness.md) — the broader "can we ship?" view; this doc is the distribution-side detail
- [`04_manual_tasks.md`](./04_manual_tasks.md) — task tracker (22-checkbox ship-blocker entry)
- [`02_decisions.md`](./02_decisions.md) — once approved, this becomes ADR-014 (Installer & distribution model)
- [`../05_infrastructure/runbooks/10_pyinstaller_distribution.md`](../05_infrastructure/runbooks/10_pyinstaller_distribution.md) — server `.exe` build pattern (signing section to be added when this plan is picked up)
- [`../12_guidelines/03_gotchas.md`](../12_guidelines/03_gotchas.md) — known sharp edges (FFmpeg PATH, Defender HLS scanning) referenced above
