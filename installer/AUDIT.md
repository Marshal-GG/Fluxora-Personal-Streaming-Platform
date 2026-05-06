# Installer audit — edge cases, bugs, deferred items

> **Effective:** 2026-05-06
> **Scope:** [`installer/Fluxora.iss`](Fluxora.iss) + the build pipeline in [`BUILD.md`](BUILD.md)
> **Companion:** [`SHIP.md`](SHIP.md) covers the *strategic* blockers (cert, FFmpeg LGPL, code changes, etc.); this doc covers *tactical* edge cases inside the Inno Setup script itself.

> **Status as of 2026-05-06:** all 13 actionable findings (Critical / High / Medium) are ✅ **fixed in [`Fluxora.iss`](Fluxora.iss)**. 2 findings (#14, #15) are deliberately ⚪ **deferred** with documented rationale. Each fix in the .iss is tagged with an inline `AUDIT #N` comment so a future reader can grep the script and trace back to this doc.

Comprehensive audit of every install / uninstall / upgrade / repair path. Findings are numbered; each has a severity, a description of the failure mode, and either the applied fix or the rationale for deferring.

**Two-way traceability.** Every finding's "Fix applied" line below describes what landed in the .iss. Conversely, every relevant block in `Fluxora.iss` carries an `AUDIT #N` comment pointing back here. Search `AUDIT #` across the .iss to enumerate where each finding was addressed (some are addressed in multiple places — e.g. AUDIT #2 fires in `InitializeSetup`, in `[Run]`, AND in `[UninstallRun]` because orphan-process cleanup is needed at three lifecycle stages).

---

## Severity tiers

| Tier | Meaning |
|------|---------|
| 🛑 **Critical** | Installer ships in a broken state — install completes but the product doesn't work, OR uninstall leaves the system in a bad state. **Must fix before first ship.** |
| 🟠 **High** | Installer works in the happy path but breaks on a specific user action (repair, upgrade, silent install). **Must fix before public release.** |
| 🟡 **Medium** | Cosmetic or polish issue that affects user trust but not function. **Should fix; can ship without.** |
| ⚪ **Deferred** | Identified but explicitly scoped to a later release. **Recorded for traceability.** |

---

## Findings

### 🛑 1. Repair install crashes with "service already exists"

**The path:** user runs the installer a second time over an existing install (Inno Setup's only "repair" mechanism — there's no native Modify/Repair UI; re-running the installer is the supported flow).

**The failure:** the `sc.exe create FluxoraServer ...` call in `[Run]` returns exit code 1073 (`ERROR_SERVICE_EXISTS`). Inno Setup ignores the failure (no `Check:` clause) and the install reports "successful." On reboot the service may or may not start depending on whether the existing registration's `binPath` still points at valid files.

**Fix applied (this audit):** added a pre-step that runs `sc.exe stop {#ServiceName}` and `sc.exe delete {#ServiceName}` before the `create`. Both are no-ops if the service doesn't exist; both succeed if it does. The `delete` is queued until all handles release, so we also wait briefly via a Pascal `WaitForServiceDeletion` helper.

**Why this matters more than it sounds:** users hit this every time they "re-install to fix something." Without the fix the service registration silently rots.

---

### 🛑 2. Orphan FFmpeg subprocesses lock files during upgrade

**The path:** user has an active stream when an installer upgrade kicks in. The service stops, but FFmpeg child processes don't inherit the stop signal — they keep running and keep `ffmpeg\ffmpeg.exe` open.

**The failure:** Inno Setup's `[Files]` `Source: "payload\ffmpeg\ffmpeg.exe"` copy fails with `ERROR_SHARING_VIOLATION`. The wizard pops up "Cannot replace … another program is using this file. Click Retry / Ignore / Abort." If the user clicks Ignore, half the installer lands and the new FFmpeg never replaces the old one.

**Fix applied:** before any `[Files]` copy, the `[Run]` section runs `taskkill /F /T /IM ffmpeg.exe` and `taskkill /F /T /IM ffprobe.exe`. The `/T` cascades to child processes; `/F` is force-kill. Both are silent if no matching processes exist. This runs even on first install (no harm done).

**Same fix:** also kills `fluxora_server.exe` and `fluxora_desktop.exe` if they're running outside the service. `CloseApplications=force` handles the desktop GUI but only for files Inno Setup is about to replace; explicit taskkill is more reliable.

---

### 🛑 3. ProgramData\Fluxora ACL — LocalService writes, users can't read

**The path:** `LocalService` creates `C:\ProgramData\Fluxora\fluxora.db` and `fluxora.log`. Default ACL on ProgramData: read-everyone, write-creator-only. Files created by `LocalService` are owned by `LocalService`; other users (the desktop app's user, for instance) get **read** by default — but only if the directory grants Authenticated Users read access. ProgramData's default does grant that **for inheritance**, BUT children created by service accounts often end up without inheritance.

**The failure:** the desktop app (running as the user) tries to open `C:\ProgramData\Fluxora\fluxora.db` for read (e.g. via the support-bundle generator on the desktop side, or directly if the desktop ever needs to inspect server state) and gets `ACCESS_DENIED`. Worse: if `LocalService` writes files with restrictive ACLs that block read for the user, the support-bundle endpoint can't read the log files either even though it runs in the same service.

**Fix applied:** post-mkdir step runs `icacls "C:\ProgramData\Fluxora" /grant "*S-1-5-19:(OI)(CI)F" /grant "*S-1-5-32-545:(OI)(CI)RX" /T`. The SIDs are language-independent: `S-1-5-19` is `LocalService`, `S-1-5-32-545` is `Users`. `(OI)(CI)` makes the ACE inheritable; `F` is full control; `RX` is read+execute. `/T` recurses to existing children.

---

### 🟠 4. REG_MULTI_SZ via reg.exe is brittle

**The path:** the .iss uses `reg.exe add ... /t REG_MULTI_SZ /d "FLUXORA_DATA_DIR=...\0FLUXORA_FFMPEG_BIN=..."` to set the service's environment block.

**The failure:** `reg.exe` documents `\0` as the separator for REG_MULTI_SZ values, but the parsing is fragile — depending on shell escaping, `\0` may be interpreted as the literal characters `\` and `0`, leaving you with a single-line REG_SZ value that the Service Control Manager either rejects or interprets as one giant env var name.

**Fix applied:** moved the env var setup into a Pascal `[Code]` procedure (`ConfigureServiceEnvironment`) that uses `RegWriteMultiStringValue` from the `Registry` PSL. Native API, no string-escaping dance, works under all shells.

---

### 🟠 5. No error handling for sc.exe / netsh / VC redist failures

**The path:** any of the post-install commands (service create, firewall add, Defender exclusion, VC redist install) fails — for instance because the user is on an enterprise GPO that blocks firewall changes, or VC redist install fails for a system DLL reason.

**The failure:** the `[Run]` items don't capture exit codes. The wizard reports "Installation completed successfully" even though the firewall rule wasn't added. User pairs a phone, the request times out, user reports "Fluxora is broken."

**Fix applied:** every post-install `[Run]` item gets a `Check:` clause that calls a Pascal helper. The helper inspects `ResultCode` and writes a warning to a setup log surfaced as a non-fatal post-install dialog ("Some post-install steps couldn't complete. Click Details to see what was skipped."). User sees what actually went wrong and can re-run the installer or fix manually.

For VC redist specifically, Microsoft documents specific exit codes:
- `0` — success
- `1638` — newer version already installed (not an error)
- `3010` — success but reboot required
- anything else — actual failure

The helper recognises 0/1638/3010 as success and only warns for the rest.

---

### 🟠 6. Service start=auto may race with networking on cold boot

**The path:** machine boots, service starts before TCP/IP is ready, server fails to bind on `0.0.0.0:8000`, server logs the error and exits, Service Control Manager triggers the failure-recovery ladder.

**The failure:** on a cold boot, the user sees the desktop app's "Connecting…" spinner for 30+ seconds while the failure-recovery ladder kicks in. Visible to support as "the server flakes on boot."

**Fix applied:** changed `sc.exe create ... start= auto` to `start= delayed-auto`. Delayed-auto services start ~30 seconds after the boot sequence completes, by which time networking is fully ready. Adds 30s to first-after-boot pairing latency but eliminates the boot race entirely.

This is the standard pattern for any service that needs network. Microsoft's own services (Windows Update, Defender, Time Service) use delayed-auto.

---

### 🟠 7. MsgBox under /VERYSILENT install hangs the installer

**The path:** user runs `Fluxora-Setup.exe /VERYSILENT` (deployment automation, MDM, or just "I don't want to click through wizards").

**The failure:** the `InitializeUninstall` Pascal `MsgBox` (the "wipe user data?" prompt) shows no UI under `/VERYSILENT` but blocks waiting for input. Process hangs forever.

**Fix applied:** every `MsgBox` call is now guarded with `WizardSilent()` — under silent mode, the prompt is skipped and the default behaviour applies (keep user data). Documented in setup-log so the operator running silent install knows the default was applied.

---

### 🟠 8. Pre-uninstall service stop is async — file deletion races

**The path:** uninstall fires `sc.exe stop FluxoraServer` (async — returns immediately when SCM accepts the request, NOT when the service has actually stopped). Inno Setup proceeds to delete files. The service is still releasing handles. File-lock errors during uninstall.

**The failure:** uninstaller pops "Cannot remove file: it is in use by another process" with no Cancel option. User force-quits the uninstaller; install state is now half-deleted.

**Fix applied:** added a Pascal `WaitForServiceStopped` helper that polls `sc.exe query` for up to 30 seconds, looking for `STATE: STOPPED`. Only then proceeds to `sc.exe delete` and lets [Files]/[UninstallDelete] fire.

---

### 🟡 9. AppUserModelID on the installer process itself

**The path:** the installer is running. It shows up in the Windows taskbar.

**The failure:** without an explicit AppUserModelID, the installer process groups under the generic "Inno Setup" entry in the taskbar, so if the user has any other Inno-built installer running (e.g. they're updating multiple apps), they all stack into one icon.

**Fix applied:** `[Setup]` gains `AppUserModelID=Fluxora.Setup`. Now the installer's taskbar icon is distinct + matches the app branding.

---

### 🟡 10. Downgrade detection (newer installed → older being installed)

**The path:** user has Fluxora 1.2.0 installed; somehow downloads and runs the 1.1.0 installer.

**The failure:** Inno Setup detects the existing install (same AppId) and offers an upgrade. The user clicks through; "upgrade" actually overwrites with older files. The newer DB schema is now read by older code that doesn't understand the new migration column. Server fails to start cleanly.

**Fix applied:** `InitializeSetup` reads the existing install's `DisplayVersion` from the registry and compares against `{#MyAppVersion}`. If the existing version is newer, the installer shows a clear "you're trying to install an older version over a newer one — do you want to continue (data loss possible)?" prompt and aborts unless the user explicitly confirms. Default = abort.

---

### 🟡 11. Inno Setup default branding leaks in two places

**The path:** the user installs / uninstalls and looks at the visible UI surfaces.

**Findings:**
- The installer EXE's icon (already overridden via `SetupIconFile=...app_icon.ico` ✅).
- The wizard splash imagery (left-side 164×314 BMP + small 55×55 BMP). Currently NOT shipped — references `assets\wizard-large.bmp` which doesn't exist; Inno Setup falls back to its default amateur-looking branding. **Tracked in [SHIP.md §6.2](SHIP.md) — not a bug per se, but a credibility hit.**
- The "Modifying setup" dialog title bar reads "Setup" by default. Set via `[Messages] BeveledLabel=` to override. **Fix applied:** `[Messages] section overriding the default labels.
- The uninstaller's title bar reads "Fluxora Uninstall" by default — that's actually fine.
- Apps & Features icon: `UninstallDisplayIcon` is already set to the desktop exe ✅.

**Fix applied for everything except the BMPs (those need design work):** added `[Messages]` overrides to ensure every title bar / dialog says "Fluxora" not "Setup."

---

### 🟡 12. Service description set in a separate sc.exe call

**The path:** the .iss runs `sc.exe create ...` then `sc.exe description ...` as two separate `[Run]` items.

**The failure:** if the create succeeds but the description fails, the service exists with a blank description in services.msc. Cosmetic — doesn't break function.

**Fix applied:** moved description set into the same Pascal helper that creates the service, with a single try/catch around both. If create fails, description never runs (correctly); if create succeeds but description fails, we log and continue.

---

### 🟡 13. Multi-user awareness on Start menu shortcuts

**The path:** Computer has multiple Windows user accounts. User A installs Fluxora. User B logs in.

**Findings:**
- Start menu group `{group}` resolves to `{commonprograms}` because we set `DefaultGroupName` and `PrivilegesRequired=admin` causes per-machine install — User B sees the same Start menu entries ✅.
- Desktop shortcut `{commondesktop}` is per-machine — User B sees it ✅.
- HKCU `Run` auto-start key is per-user (User A's hive only) — User B doesn't get auto-start. **Acceptable** — explicitly per-user feature; documented in the .iss comment.
- `flutter_secure_storage` is per-user DPAPI — User B's pairings + saved server URL are separate from User A's. **Acceptable** — that's the security model.

**Status:** no fix needed; behaviour is correct + documented in the .iss. Listed here for completeness.

---

### ⚪ 14. [Components] for server-only / desktop-only installs (D8 power-user variant)

**Status:** deferred. Plan D8 calls for a separate "headless server-only" installer for NAS / HTPC users. Currently both server + desktop bundle as single payload; the `noservice` task lets advanced users skip the service registration but still installs both binaries.

**Why defer:** adding `[Components]` complicates `[Run]` and `[Tasks]` significantly (don't try to register service if desktop-only; don't auto-start desktop if server-only). The single-bundle install ships fine for 90% of users. Revisit if there's pull from headless-only deployments.

**Tracked in:** [SHIP.md §6.3](SHIP.md) (desktop-app first-run UX is the related gap).

---

### ⚪ 15. Squirrel.Windows auto-update integration

**Status:** deferred — separate workstream. The .iss produces a one-time install + repair-via-rerun. Auto-update via Squirrel is a parallel pipeline (see [installer plan §"Auto-update model"](../docs/10_planning/06_installer_plan.md)).

**Why defer:** Squirrel + Inno Setup is a known-good pattern (Slack, Discord, GitHub Desktop all do it) but the wire-up is its own ~1 day of work + needs the update host (SHIP.md §4.5) to be live. Acceptable to ship the first version Inno-only, add Squirrel in v1.1.

---

## Edge-case test matrix

These are the test cases the smoke-test matrix in SHIP.md §7 should specifically cover. Each maps to a finding above.

| Test case | Finding(s) verified |
|-----------|---------------------|
| Install fresh on clean Win 10 22H2 | All happy-path |
| Install fresh on clean Win 11 23H2 | All happy-path |
| Re-run installer over existing install (repair) | #1, #2, #5 |
| Upgrade 1.0.0 → 1.1.0 (build two installers, run in order) | #1, #2, #6, #8 |
| Downgrade attempt: install 1.1.0 then run 1.0.0 installer | #10 |
| Install with Defender real-time enabled + UAC at max | #5, #6 |
| Install behind enterprise GPO blocking firewall changes | #5 (firewall rule check should warn) |
| Install on machine without VC redist | #5 (VC redist exit codes 0/1638/3010) |
| Install with port 8000 already taken | #5 (server fails to bind; surfaces in fluxora.log) |
| Install while another user is logged on (FUS) | #13 |
| Silent install: `Fluxora-Setup.exe /VERYSILENT` | #7 |
| Silent uninstall: `unins000.exe /VERYSILENT` | #7 |
| Uninstall with active stream session | #2, #8 |
| Uninstall and choose "wipe data" | #3 |
| Uninstall and choose "keep data", reinstall | data preservation |
| Multi-user Start menu visibility | #13 |
| AppUserModelID grouping in taskbar | #9 |

---

## Cross-references

- **Mechanical build pipeline:** [`BUILD.md`](BUILD.md)
- **Strategic ship checklist:** [`SHIP.md`](SHIP.md) — covers infrastructure / cert / external services
- **Inno Setup script:** [`Fluxora.iss`](Fluxora.iss) — every fix in this audit was applied to this file
- **Plan + decisions:** [`../docs/10_planning/06_installer_plan.md`](../docs/10_planning/06_installer_plan.md)

---

## Document maintenance

When a finding is fixed in the .iss, mark it ✅ in this doc and link to the commit / PR. When a deferred item gets revisited, update its status. The audit doc is meant to be a living record of "we considered this, here's what we did about it" — both for future maintainers and for any external security review.
