# Ship guide — from source to signed installer

> **Effective:** 2026-05-06
> **Companion to:** [`installer/Fluxora.iss`](Fluxora.iss), [`installer/BUILD.md`](BUILD.md)
> **Plan:** [`docs/10_planning/06_installer_plan.md`](../docs/10_planning/06_installer_plan.md)

`BUILD.md` is the **mechanical pipeline** — "run these commands, get an
installer." This doc is the **strategic checklist** — "here's everything
that's blocking us from running that pipeline successfully today, and
here's the order to fix them in." Written 2026-05-06 after auditing the
server source against the Inno Setup script's expectations and finding
three real code-side blockers.

---

## TL;DR — what's blocking the first ship

| Category | Item count | Severity |
|----------|-----------:|---------:|
| Code changes required (server source must respect new env vars) | **3 hard blockers + 1 soft** | 🛑 Blocks build |
| Infrastructure to acquire | 5 items | 🟡 Blocks first ship; not first build |
| Documentation gaps | 3 items | 🟡 Blocks polished release |
| External services to configure | 5 items | 🟡 Blocks first ship |
| Smoke-test gates | 1 matrix | 🛑 Blocks first ship |

**Read §3 first** — those three code changes block the very first
Nuitka build. Everything else can be parallelised.

---

## 1. What you're producing (recap)

A single `Fluxora-Setup-<version>-x64.exe`:

```
Fluxora-Setup-0.1.0-x64.exe (~180–220 MB, signed)
├── Embeds installer\payload\server\         (Nuitka standalone, obfuscated)
│     └── fluxora_server.exe + _internal\runtime
├── Embeds installer\payload\desktop\        (Flutter --obfuscate)
│     └── fluxora_desktop.exe + flutter_windows.dll + plugins + data\
├── Embeds installer\payload\ffmpeg\         (LGPL build, version-pinned)
│     └── ffmpeg.exe + ffprobe.exe + LICENSE
├── Embeds installer\payload\redist\         (chained at install if missing)
│     └── vc_redist.x64.exe
└── Embeds top-level legal docs              (LICENSE / PRIVACY / TERMS / SECURITY / CODE_OF_CONDUCT / NOTICE)
```

After install, the user has:

- A **Windows Service** named `FluxoraServer` running as `LocalService`,
  auto-starting on boot, restarting after crash (5s/5s/30s ladder).
- A **desktop control panel** with a Start menu shortcut + optional
  desktop shortcut + optional auto-start-on-login.
- **Data directory** at `C:\ProgramData\Fluxora\` (writeable by both
  the service and the desktop app).
- **Firewall rule** opened on TCP 8000 for incoming pairing.
- **Defender exclusion** on the HLS scratch dir for streaming throughput.

---

## 2. Big picture — order to do things in

```
Stage 0: One-time prerequisites
   │
   ▼
Stage 1: Code changes (§3) ────────────► Run server pytest (488/488)
   │                                              │
   │                                              ▼
   │                                       NUITKA BUILD WORKS
   │
   ├─► Stage 2: Acquire infrastructure (§4)  ┐
   │     • Code-signing cert (3-7 day wait)  │
   │     • FFmpeg LGPL build                 │   parallelisable
   │     • VC++ redist                        ├──► Stage 4: ISCC compile
   │     • Email forwarders                  │
   │     • Update host (Firebase)             ┘
   │
   ├─► Stage 3: External services (§5)
   │     • Polar production webhook
   │     • Sentry DSN (optional)
   │     • DNS config (fluxora.marshalx.dev subdomain)
   │
   └─► Stage 5: Smoke-test matrix (§7)
         │
         ▼
       Tag release → CI publishes signed installer + Squirrel RELEASES
```

---

## 3. Code changes required — HARD BLOCKERS for the first build

These three (plus one soft one) **must land in source before the
Nuitka build will produce a working installer**. Confirmed by reading
the current `apps/server/` source at the time of writing.

### 3.1 🛑 Server data dir is not env-var configurable

**Problem.** [`apps/server/config.py`](../apps/server/config.py) `_data_dir()` is hardcoded to
`%APPDATA%\Fluxora` on Windows. The Inno Setup script registers the
service to run as `LocalService`, which **cannot access** any per-user
`%APPDATA%` location — it would resolve to
`C:\Windows\System32\config\systemprofile\AppData\Roaming\Fluxora` and
the user's desktop app could never read the same DB.

The .iss tries to set `FLUXORA_DATA_DIR=C:\ProgramData\Fluxora\` in the
service's environment block, but the server **ignores that env var**.

**Fix.** Update `_data_dir()` to consult `FLUXORA_DATA_DIR` first:

```python
def _data_dir() -> Path:
    # New: env-var override for service-mode installs (see installer/Fluxora.iss).
    override = os.environ.get("FLUXORA_DATA_DIR")
    if override:
        return Path(override)

    system = platform.system()
    if system == "Windows":
        base = Path(os.environ["APPDATA"]) / "Fluxora"
    elif system == "Darwin":
        base = Path.home() / "Library" / "Application Support" / "Fluxora"
    else:
        base = Path.home() / ".fluxora"
    return base
```

**Cascading fix.** The same module also uses `_data_dir()` to compute
`env_file=str(_data_dir() / ".env")` for `pydantic-settings`. That call
happens at module-import time, before our override has a chance — but
since `_data_dir()` is now a function call, this is fine; just make sure
no one inlines it.

**Test gate.** Add a pytest case verifying `FLUXORA_DATA_DIR=/tmp/x`
makes `_data_dir() == Path("/tmp/x")`. Today there's no test for this.

### 3.2 🛑 FFmpeg path resolution doesn't respect bundled-binary env var

**Problem.** [`apps/server/services/ffmpeg_service.py`](../apps/server/services/ffmpeg_service.py) `_ffmpeg_bin()`:

```python
def _ffmpeg_bin() -> str:
    if getattr(sys, "frozen", False):
        bundled = Path(sys._MEIPASS) / "ffmpeg"  # PyInstaller-only marker
        ...
    found = shutil.which("ffmpeg")  # PATH fallback
```

Two issues:

1. **`sys._MEIPASS` is PyInstaller's marker.** Nuitka uses
   `sys.frozen = True` (set when running from a Nuitka standalone build)
   but `sys._MEIPASS` is **PyInstaller-specific** and doesn't exist on
   Nuitka. The `getattr(sys, "frozen", False)` check is fine; the
   `sys._MEIPASS` access raises `AttributeError`. **Caught by `getattr`
   below if used carefully but as written above will crash.**
2. **The .iss sets `FLUXORA_FFMPEG_BIN=...\ffmpeg\ffmpeg.exe`** in the
   service env. The server ignores it. Service ends up calling
   `shutil.which("ffmpeg")` — which on a `LocalService`-restricted PATH
   may not find the bundled FFmpeg under `Program Files\Fluxora\ffmpeg\`.

**Fix.** Reorder + add env-var support:

```python
def _ffmpeg_bin() -> str:
    # 1. Explicit env-var override — set by installer (see installer/Fluxora.iss).
    explicit = os.environ.get("FLUXORA_FFMPEG_BIN")
    if explicit and Path(explicit).exists():
        return explicit

    # 2. Bundled binary inside a frozen build (Nuitka or PyInstaller).
    if getattr(sys, "frozen", False):
        # Nuitka exposes the runtime dir via __compiled__.containing_dir
        # in 2.4+; falls back to sys.executable's parent for older.
        bundle_root = Path(sys.executable).resolve().parent
        # Look one level up (runtime sibling: server\ + ffmpeg\)
        for candidate in (
            bundle_root / "ffmpeg.exe",
            bundle_root / "ffmpeg",
            bundle_root.parent / "ffmpeg" / "ffmpeg.exe",
            bundle_root.parent / "ffmpeg" / "ffmpeg",
        ):
            if candidate.exists():
                return str(candidate)
        # Legacy PyInstaller path — kept for back-compat with the .spec.
        meipass = getattr(sys, "_MEIPASS", None)
        if meipass:
            for candidate in (Path(meipass) / "ffmpeg.exe", Path(meipass) / "ffmpeg"):
                if candidate.exists():
                    return str(candidate)

    # 3. PATH fallback (dev workflow).
    found = shutil.which("ffmpeg")
    if found is None:
        raise FileNotFoundError(
            "FFmpeg not found. Install it and ensure it is on PATH, "
            "or set FLUXORA_FFMPEG_BIN to its full path."
        )
    return found
```

Same change applied to `_ffprobe_bin()`.

**Test gate.** Mock `os.environ` and `Path.exists` — assert the env-var
path wins when set, the bundle-relative path wins when frozen + env-var
absent, and the PATH path wins as fallback.

### 3.3 🛑 No `if __name__ == "__main__"` entry point

**Problem.** [`apps/server/main.py`](../apps/server/main.py) ends with `app = FastAPI(...)`. There's no
top-level launcher. In dev, you run `uvicorn main:app --host 0.0.0.0
--port 8000`. In production-from-source, same thing. **Nuitka doesn't
work that way** — the standalone exe Nuitka emits runs the module
top-level; if there's no launcher, the exe loads, defines `app`, and
exits.

**Fix.** Add to the bottom of `main.py`:

```python
if __name__ == "__main__":
    # Self-launch path — used by the Nuitka-compiled standalone exe.
    # When running from `uvicorn main:app` in dev, this block is skipped.
    import uvicorn
    uvicorn.run(
        app,
        host=settings.fluxora_host,
        port=settings.fluxora_port,
        log_config=None,  # we configure logging ourselves earlier
    )
```

Use the existing `settings.fluxora_host` / `settings.fluxora_port` so
the env vars `FLUXORA_HOST` / `FLUXORA_PORT` (already declared in
`config.py`) drive the bind address.

### 3.4 🟡 Service stop on Windows — graceful shutdown

**Problem.** When `sc.exe stop FluxoraServer` runs (during uninstall or
manual stop), Windows sends `SERVICE_CONTROL_STOP` to the service host.
Python's uvicorn doesn't listen for that natively — it listens for
`SIGINT` / `SIGTERM`, which Windows services don't deliver. Result:
the service "stops" but the FastAPI lifespan teardown doesn't run, so
in-flight stream sessions don't get a clean `ended_at` stamp and
FFmpeg subprocesses can leak.

**Fix.** Wrap the launcher in a `pywin32` service handler, OR simpler:
register a Windows console-handler for `CTRL_BREAK_EVENT` /
`CTRL_CLOSE_EVENT` and translate to `SIGINT`. Probably acceptable to
defer past first ship (the leaked FFmpeg processes are cleaned up by
the next service start's `stale-session` sweep). **Soft blocker.**

Workaround for v1: document that "stopping the service is best-effort
clean; the next start will clean up any orphaned sessions."

### Code-change summary

| File | Change | Test |
|------|--------|------|
| `apps/server/config.py` | `_data_dir()` consults `FLUXORA_DATA_DIR` first | New pytest |
| `apps/server/services/ffmpeg_service.py` | `_ffmpeg_bin()` + `_ffprobe_bin()` consult `FLUXORA_FFMPEG_BIN` / `FLUXORA_FFPROBE_BIN` first; recognise Nuitka-frozen layout via `sys.executable` parent | New pytest |
| `apps/server/main.py` | Add `if __name__ == "__main__":` block calling `uvicorn.run(app, host=..., port=...)` | Smoke run via `python main.py` |
| `apps/server/main.py` (soft) | Windows-service-friendly graceful shutdown | Defer to v1.1 |

After landing those four changes, `pytest -q` should still pass
488/488 (the new env-var tests bring it to ~491).

---

## 4. Infrastructure to acquire — blocks first ship, NOT first build

Build can produce an unsigned installer without any of these. Shipping
to users without them is a bad idea.

### 4.1 Code-signing certificate

**Why.** Without a signed installer, every download triggers Windows
SmartScreen's "Microsoft Defender prevented an unrecognised app from
starting" dialog. Conversion drops by ~70% on that prompt. Sectigo OV
builds reputation slowly over the first ~3,000 downloads; EV is instant
but ~2× the price.

**Action.**

1. Order a **Sectigo OV code-signing cert** (~$200/yr; 3–7 day delivery
   after identity verification). Plan default per D1 in [`06_installer_plan.md`](../docs/10_planning/06_installer_plan.md).
2. During issuance, vendor will ask for a private key — generate via
   `certreq.exe` on the build machine OR use a hardware token (YubiKey
   FIPS works). Hardware token is the modern default for new OV/EV
   issuance.
3. Once delivered, install in the build machine's certificate store
   under "Personal" (or load via the YubiKey vendor's middleware).
4. Update `installer\BUILD.md` §6 with the actual cert thumbprint /
   subject name so `signtool` can pick it.
5. Test-sign a dummy exe to confirm the chain validates:
   ```powershell
   signtool sign /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a dummy.exe
   signtool verify /pa /v dummy.exe
   ```

**Blocks:** every shipped binary (server exe, desktop exe, installer
exe). All three should be signed.

### 4.2 FFmpeg LGPL build (version-pinned)

**Why.** GPL-licensed FFmpeg builds (with `--enable-gpl` and
`libx264` / `libx265` statically linked) cannot be redistributed under
the MIT-licensed Fluxora installer. **LGPL builds are required.**

**Action.**

1. Download `ffmpeg-release-essentials.zip` from
   <https://www.gyan.dev/ffmpeg/builds/>. As of 2026-05-06 the current
   stable is 7.0.x.
2. **Pin the version** in `installer/BUILD.md` (today it just says
   "7.0.x"; pick a specific minor, e.g. 7.0.2, and update when needed).
3. Verify the LICENSE shipped is the LGPL variant — open `LICENSE.txt`
   in the zip; it should list LGPL-2.1+ at the top, NOT GPL-2.0+.
   Gyan's "essentials" build is LGPL by default; "full" is GPL — DO
   NOT use the full build.
4. Stage at `installer\payload\ffmpeg\{ffmpeg,ffprobe}.exe` per BUILD.md §4.
5. **Bonus: code-sign** the bundled FFmpeg too if your cert allows
   re-signing third-party binaries. Sectigo OV usually does. EV may or
   may not, depending on the policy. Reduces SmartScreen friction.

**Blocks:** payload staging (BUILD.md §4 fails without it).

### 4.3 Visual C++ Redistributable (x64)

**Why.** Both Nuitka-compiled Python and Flutter desktop binaries
depend on the MSVC runtime. Fresh Windows installs (~15% of clean
machines) lack it; the binary fails silently with no useful dialog.

**Action.**

1. Download `vc_redist.x64.exe` from <https://aka.ms/vs/17/release/vc_redist.x64.exe>.
   This URL is stable; Microsoft updates the underlying file in place
   when there's a new minor version.
2. Stage at `installer\payload\redist\vc_redist.x64.exe`.
3. Pin the version in BUILD.md (capture the file SHA-256 if you want
   reproducibility — the URL doesn't expose the version directly).

**Blocks:** payload staging.

### 4.4 Email forwarders for `*@fluxora.marshalx.dev`

**Why.** Every legal doc references `security@`, `privacy@`, `legal@`,
`support@`, `conduct@` at `fluxora.marshalx.dev`. Without forwarders,
those emails bounce — bad for credibility and legally awkward (privacy
rights requests have a 30-day clock).

**Action.**

1. Sign up for **Cloudflare Email Routing** (free) under your existing
   `marshalx.dev` zone (assuming Cloudflare DNS — confirm).
2. Add the 5 forwarders, all pointing at `marshalgcom@gmail.com`:
   - `security@fluxora.marshalx.dev → marshalgcom@gmail.com`
   - `privacy@fluxora.marshalx.dev → marshalgcom@gmail.com`
   - `legal@fluxora.marshalx.dev → marshalgcom@gmail.com`
   - `support@fluxora.marshalx.dev → marshalgcom@gmail.com`
   - `conduct@fluxora.marshalx.dev → marshalgcom@gmail.com`
3. Cloudflare Email Routing requires the destination to confirm — check
   your gmail for the verification email and click the link.
4. **Test each address.** Send a test email to each from a non-Fluxora
   address; confirm delivery within 5 minutes. Check spam folder.
5. Add SPF / DKIM if you want the "verified sender" badge in Gmail —
   Cloudflare's docs walk through this.

**Alternative if not using Cloudflare DNS.** ImprovMX (free for 25
forwards), Mailgun ($10/mo for outbound), or your registrar's built-in
mail-forwarding (most registrars include this).

**Blocks:** legal-doc credibility. Strongly recommended before any
public download is offered.

### 4.5 Update host (Squirrel.Windows RELEASES file)

**Why.** Plan item 2 — auto-update for paying users. Without it, every
bug fix needs the user to manually download a new installer; in
practice they don't, and the support burden compounds.

**Action.** Per plan default D4: host on Firebase under
`fluxora.marshalx.dev/updates/windows/`. Layout:

```
fluxora.marshalx.dev/updates/windows/
├── RELEASES                              (Squirrel format, one line per version)
├── Fluxora-1.0.0-full.nupkg              (full package)
└── Fluxora-1.0.0-delta.nupkg             (delta from previous)
```

The `.nupkg` files are produced by Squirrel.Windows from the .iss output
(or from the Nuitka standalone tree directly — Squirrel doesn't need
Inno Setup; the two installers can coexist or replace each other).

**Setup steps.**

1. Decide: ship via Inno Setup .exe AND Squirrel .nupkg, OR pick one.
   Most projects pick Squirrel (smaller deltas, in-app update flow,
   no "an installer is running" prompts). The plan recommends both
   initially — Inno Setup for first-install (better signed-EXE feel),
   Squirrel for auto-update of an installed app.
2. Install Squirrel.Windows (`choco install squirrel-windows.portable`
   or grab the binaries from <https://github.com/Squirrel/Squirrel.Windows>).
3. Add a CI step that runs `Squirrel --releasify Fluxora.<ver>.nupkg
   --releaseDir=updates\windows\` and uploads to Firebase.
4. Wire the desktop app to call `Squirrel --update <feed-url>` on
   launch + every 6 hours (per plan §"Auto-update model").

**Blocks:** auto-update on shipped builds. Acceptable to defer past
first ship — early users can manually download the new installer.

---

## 5. External services to configure

### 5.1 Polar production webhook secret + product IDs

**Why.** The server's webhook handler (`apps/server/routers/webhook.py`)
verifies Polar signatures using a shared secret. Test mode and prod
have different secrets; shipping with the test secret means production
purchases fail to issue license keys.

**Action.**

1. In Polar dashboard → Settings → Webhooks → create a production
   webhook pointing at `https://fluxora-api.marshalx.dev/api/v1/webhook/polar`
   (or wherever production routes; matches `FLUXORA_PUBLIC_URL`).
2. Copy the webhook secret. Store in your production secret manager
   (or set as `FLUXORA_POLAR_WEBHOOK_SECRET` env var on the
   server's deploy config — see `config.py`).
3. Confirm the three products (Plus / Pro / Ultimate) have the `tier`
   metadata key set per [`docs/01_product/06_polar_product_setup.md`](../docs/01_product/06_polar_product_setup.md).
4. Test with Polar's "Send test webhook" — confirm a license key gets
   issued and emailed.

**Blocks:** paid-tier delivery. Free tier ships fine without this.

### 5.2 Sentry DSN (optional)

**Why.** Plan item 10. The server already has Sentry wiring in
`apps/server/sentry_init.py` with PII scrubbing. Without a DSN it's
disabled; with a DSN it surfaces unhandled exceptions to your Sentry
project.

**Action.**

1. Sign up for Sentry (free tier covers an indie project).
2. Create a project named "Fluxora Server" (Python platform).
3. Copy the DSN.
4. Document in `installer/BUILD.md` that the DSN goes into the
   per-install `.env` post-installation; the installer doesn't prompt.
5. Optional: add the desktop app's Flutter Sentry too — separate DSN.

**Blocks:** crash visibility. Sentry-less ship is fine for v1.

### 5.3 DNS — `fluxora.marshalx.dev` subdomain

**Why.** The marketing site is presumed to live at this URL (per
`/privacy`, `/terms`, the legal docs). If you haven't actually pointed
DNS yet, the legal references 404.

**Action.**

1. In Cloudflare DNS for `marshalx.dev`, add a CNAME or A record:
   - `fluxora.marshalx.dev → fluxora-marketing.pages.dev` (Cloudflare Pages)
   - or A → IP if hosting elsewhere.
2. Add DNS for `fluxora-api.marshalx.dev` for the production server
   (Cloudflare Tunnel hostname).
3. Optional: `fluxora.marshalx.dev/updates/` mapping for the Squirrel
   update host — could be a Pages function or another rewrite.
4. Verify TLS — Cloudflare Pages auto-provisions Let's Encrypt; should
   show a green padlock at `https://fluxora.marshalx.dev`.

**Blocks:** site availability. Assumed already done; verify if not.

### 5.4 Polar customer-portal URL

**Why.** Per `apps/server/routers/orders.py` `/portal-url` endpoint.
Used by the desktop Subscription → Manage tab to give the user a
one-click cancel-subscription link.

**Action.** Set `FLUXORA_POLAR_PORTAL_URL` env var on production
server (or in `~/.fluxora/.env`). The URL lives in your Polar dashboard
under each product's "Customer portal" section.

**Blocks:** the desktop "Open Customer Portal" button shows
"Portal URL not configured" until set. Soft.

### 5.5 GitHub Actions secrets

**Why.** CI workflow (`.github/workflows/release.yml`, not yet written
— see §7) needs three secrets to produce a signed installer:

- `CODESIGN_PFX_BASE64` — base64-encoded PFX of the code-signing cert
  (or hardware-token-emulating equivalent).
- `CODESIGN_PFX_PASSWORD` — password for the PFX.
- `SIGNTOOL_TIMESTAMP_URL` — vendor timestamp URL, e.g.
  `http://timestamp.sectigo.com`.

**Action.** Add via GitHub repo Settings → Secrets and variables →
Actions. Document the names + format in BUILD.md.

**Blocks:** unsigned CI builds — acceptable for dev; not for release.

---

## 6. Documentation gaps

### 6.1 `.github/workflows/release.yml` does not exist

**Why.** CI must be the single source of truth for production builds
(per BUILD.md §8). Local builds are useful for iteration; never ship
them.

**What it needs to do:**

1. Trigger on `release` events with `vN.M.P` tag.
2. Run on `windows-latest` runner.
3. Cache: pub-cache (`~/.pub-cache`), Nuitka build cache, pip cache.
4. Run server pytest first — fail-fast if 488 tests don't pass.
5. Run `flutter analyze` for desktop + core — fail-fast.
6. Build server with Nuitka per BUILD.md §1.
7. Build desktop with `flutter build windows --release --obfuscate
   --split-debug-info=...` per BUILD.md §2.
8. Stage payload (FFmpeg + VC redist) — pull from a separate "vendor"
   repo or storage bucket (don't commit ~120 MB of binaries to the
   main repo).
9. Sign the server + desktop binaries.
10. Compile installer with ISCC, signing the final output.
11. Generate Squirrel `RELEASES` entry + `.nupkg`.
12. Upload installer + .nupkg to GitHub Releases.
13. Sync `RELEASES` file to update host.
14. Optionally push the symbol map (Flutter `--split-debug-info`) to a
    private branch.

**Action.** Write the workflow. ~150 lines of YAML. Reference
[`docs/01_product/06_polar_product_setup.md`](../docs/01_product/06_polar_product_setup.md) for the smoke-test commands.

**Blocks:** automated releases. Acceptable to ship the first version
manually from a local build.

### 6.2 Wizard imagery for Inno Setup

**Why.** The .iss references `installer\assets\wizard-large.bmp` (164×314)
and `installer\assets\wizard-small.bmp` (55×55). Inno Setup falls back
to defaults if missing — but defaults are the generic Inno Setup logo,
which screams "amateur." Branded wizard imagery is the easiest UX
upgrade available.

**Action.**

1. Create `installer/assets/` directory.
2. Design the two BMPs:
   - **wizard-large.bmp** — 164×314 pixels, 24-bit BMP. Brand splash.
     Place the Fluxora wordmark vertically centered, gradient
     background matching the M9.5 V2 violet palette.
   - **wizard-small.bmp** — 55×55 pixels, 24-bit BMP. Just the F lettermark.
3. Use the existing brand assets at `assets/brand/logo-icon.png` +
   `assets/brand/logo-wordmark-h.png` as input. Pillow can render the
   BMPs from a script — or do them by hand once.
4. Optional: also create `installer/assets/post-install-readme.txt`
   referenced as `InfoAfterFile`. Short text shown after install
   completes — "Congratulations, here's how to pair your first device."
5. Optional: `installer/assets/terms.rtf` — a Rich Text export of
   `TERMS.md` for the LicenseFile slot. Pandoc can do this:
   `pandoc TERMS.md -o installer/assets/terms.rtf -f gfm -t rtf`.

**Blocks:** brand polish. Installer compiles fine without these (Inno
Setup falls back).

### 6.3 First-run UX docs

**Why.** Per plan item 10 + BUILD.md §7's smoke test, a fresh-install
user needs to:

1. Open the desktop app.
2. Confirm the server is running (green dot in status bar).
3. Add their TMDB API key (Settings → Advanced).
4. Optionally enter their license key (Settings → Security).
5. Add their first library (Library → Create).
6. Pair their first phone (Clients → Pair Device → QR or manual IP).

There's no doc covering this flow end-to-end for a non-technical user.
Plan item 10 explicitly skips an in-installer onboarding wizard
("Put onboarding in the desktop app's first launch, not the installer")
— but the desktop app doesn't have a first-run wizard yet either.

**Action.** Three options, increasing effort:

1. **Doc only** (~1 hour). Write `docs/01_product/07_first_run_guide.md`
   targeting end-users. Include screenshots from a clean install.
   Link from `installer/assets/post-install-readme.txt`.
2. **Help-screen integration** (~2 hours). Add a "First-time setup"
   section to the existing `apps/desktop/lib/features/help/...help_screen.dart`
   that walks through the same 6 steps with "Open this screen" buttons.
3. **Real first-run wizard** (~4–8 hours). Detect "no clients paired
   AND no libraries created" on launch; show a step-by-step modal.
   Plex / Jellyfin both do this.

**Blocks:** good first impression. Acceptable to ship with option (1).

---

## 7. Smoke-test matrix — HARD GATE before publish

A signed installer that doesn't actually work on a clean Windows is
worse than no installer. Run these on at least two clean VMs before
each release.

### 7.1 Test environments

| VM | Why test |
|----|----------|
| Windows 10 22H2 (clean install) | Latest 10; still ~30% of Windows market |
| Windows 11 23H2 (clean install) | Current default for new PCs |
| Windows 11 23H2 with Defender + UAC at maximum | Catches the firewall + Defender + service-account paper cuts |

VMware Workstation Player or VirtualBox both work. Snapshot before
install; rollback after each test so subsequent runs stay clean.

### 7.2 What to verify per VM

1. **Installer launch** — UAC prompt appears; SmartScreen accepts the
   signature (or shows the "unrecognised app" dialog if cert reputation
   hasn't built yet).
2. **VC redist** — chained installer runs silently (or skips if
   already installed).
3. **Service registration** — `services.msc` shows `FluxoraServer`,
   running, "Automatic" start, log-on as `LocalService`. Recovery tab
   shows the 5s/5s/30s ladder.
4. **Firewall rule** — `netsh advfirewall firewall show rule name="Fluxora Server"`
   lists the rule; profile=private,domain.
5. **Defender exclusion** — `Get-MpPreference | Select-Object
   -ExpandProperty ExclusionPath` includes `C:\ProgramData\Fluxora\hls-tmp`.
6. **Server up + reachable** — `curl http://localhost:8000/api/v1/healthz`
   returns `{"ok":true}` within 30 seconds of install completion.
7. **Data dir** — `C:\ProgramData\Fluxora\fluxora.db` exists (created
   by first migration run); `C:\ProgramData\Fluxora\fluxora.log` shows
   the server starting up.
8. **Desktop app launch** — Start menu shortcut works; app connects to
   `http://localhost:8000`; Server Status shows green "Running."
9. **Pairing over LAN** — pair a phone; confirm the firewall rule lets
   the request through.
10. **Uninstall flow** — uninstaller asks about wiping data dir,
    defaults to NO, only wipes if you opt in. Service unregisters cleanly.
    Firewall rule + Defender exclusion both removed.
11. **Reinstall preserves data** — uninstall (keep data); reinstall;
    confirm paired devices + library are still there.

### 7.3 Failure modes to specifically test

These are the cases most likely to break in production:

- Install on a machine **without VC++ redist** — does the chained
  installer actually install it?
- Install on a machine where **port 8000 is already taken** by another
  app — server fails to bind; what does the user see? (Check the log;
  we should fail loud.)
- Install with **Defender real-time scanning enabled** — does
  `Add-MpPreference` work, or does it require additional admin rights?
- Install on **Windows Home** (no local group policy editor) —
  service registration should still work but worth confirming.
- **Repair install** (re-run the installer over an existing install)
  — does it preserve user data + service config?
- **Old version → new version upgrade** — does Inno Setup detect the
  prior version (same AppId GUID) and offer "upgrade"? Service should
  stop, files update, service restart.

---

## 8. Per-release checklist

Things to do every time you cut a release. This is the
"copy-paste-and-tick-each-box" version.

```markdown
## Release checklist for Fluxora vX.Y.Z

### Pre-build
- [ ] Pull `main` clean (`git status` clean, `git pull --rebase`)
- [ ] Server pytest passes: `cd apps/server && pytest -q` → all green
- [ ] Desktop analyze clean: `cd apps/desktop && flutter analyze` → 0 issues
- [ ] Core analyze clean: `cd packages/fluxora_core && flutter analyze` → 0 issues
- [ ] Bump version in:
  - `apps/server/pyproject.toml` `version`
  - `apps/desktop/pubspec.yaml` `version`
  - `apps/web_landing/package.json` `version` (if releasing the site)
  - `installer/Fluxora.iss` — actually rebuilt-time via /D, but bump
    the `#define MyAppVersion` literal too for local dev compiles
- [ ] Update `docs/00_overview/current_status.md` "As of" paragraph
  if anything material shipped
- [ ] AGENT_LOG.md entry for the release

### Build
- [ ] Run `installer\BUILD.md` §1 (Nuitka server) — confirm exe runs
- [ ] Run BUILD.md §2 (Flutter desktop) — confirm exe runs
- [ ] Run BUILD.md §3 (trim Nuitka) — confirm exe still runs after trim
- [ ] Run BUILD.md §4 (stage payload — FFmpeg, redist, wizard imagery)
- [ ] Sign server + desktop binaries (BUILD.md §6)
- [ ] Run BUILD.md §5 (ISCC compile)
- [ ] Sign final installer (already wired via /S in ISCC if cert configured)

### Smoke test
- [ ] Win 10 clean VM smoke (§7.2 — all 11 items)
- [ ] Win 11 clean VM smoke (§7.2)
- [ ] Test pair-device over LAN with at least one mobile client
- [ ] Test paid-tier license key activation if releasing a paid feature

### Publish
- [ ] Tag the release: `git tag vX.Y.Z && git push --tags`
- [ ] Create GitHub Release with the signed installer attached
- [ ] Generate Squirrel RELEASES entry + .nupkg; upload to update host
- [ ] Push Flutter symbol map to private `release-symbols/vX.Y.Z` branch
- [ ] Update `fluxora.marshalx.dev` — release-notes section if any
- [ ] Update `docs/00_overview/current_status.md` "As of" — note the release
- [ ] AGENT_LOG.md entry confirming the release shipped

### Post-publish
- [ ] Verify the GitHub Release download triggers SmartScreen-clean
- [ ] Verify auto-update picks up vX.Y.Z from a vX.Y.(Z-1) install
- [ ] Monitor Sentry for any post-release exception spike
- [ ] Watch GitHub Issues / `support@fluxora.marshalx.dev` for first-day reports
```

---

## 9. The "skip these" list

Things that look like they should be in scope but aren't, per the
plan's "Things to actively SKIP" table. Captured here so you don't
accidentally re-add them under pressure:

| Skip | Why |
|------|-----|
| Custom install path option | Adds 2 wizard pages for a 1% audience; Program Files is correct for service-mode |
| 32-bit build | Windows 11 dropped 32-bit; not worth the build matrix split |
| Per-user install option | Per-machine is correct for server-as-service |
| Welcome wizard inside the installer | Onboarding lives in the desktop app's first launch (§6.3) |
| Logging to Windows Event Log | File logs + Sentry covers it; Event Log is enterprise-IT theater |
| EULA click-through wall | LicenseFile in [Setup] shows TERMS.md inline; not a click-through gate |
| Custom uninstall confirmation page beyond §3.4 | The MsgBox-based confirmation in [Code] is enough |
| Bundled cloudflared / Tailscale | Optional integrations; ship as docs not as bundle |
| Bundled NSSM | Built-in `sc.exe` does what we need; NSSM is dead weight |

---

## 10. Cross-references

- **Mechanical build pipeline:** [`installer/BUILD.md`](BUILD.md)
- **Inno Setup script:** [`installer/Fluxora.iss`](Fluxora.iss)
- **Edge-case audit + fixes:** [`installer/AUDIT.md`](AUDIT.md) — 15 findings catalogue covering update / repair / reset / partial-uninstall / silent-mode / branding paths. Read this before changing the .iss.
- **Strategic plan + decisions:** [`docs/10_planning/06_installer_plan.md`](../docs/10_planning/06_installer_plan.md)
- **Server architecture:** [`docs/09_backend/01_backend_architecture.md`](../docs/09_backend/01_backend_architecture.md)
- **Polar product setup:** [`docs/01_product/06_polar_product_setup.md`](../docs/01_product/06_polar_product_setup.md)
- **PyInstaller-era runbook (legacy, kept for reference):** [`docs/05_infrastructure/runbooks/10_pyinstaller_distribution.md`](../docs/05_infrastructure/runbooks/10_pyinstaller_distribution.md)
- **Known sharp edges:** [`docs/12_guidelines/03_gotchas.md`](../docs/12_guidelines/03_gotchas.md) — the FFmpeg PATH gotcha + Defender HLS scanning + service-account-PATH issues are all documented there
- **Privacy / Terms / Security / Code of Conduct / Notice / License:** repo root
- **Outstanding manual tasks:** [`docs/10_planning/04_manual_tasks.md`](../docs/10_planning/04_manual_tasks.md)

---

## 11. What I will NOT cover here (out of scope for this doc)

- **macOS .dmg + notarisation** — separate workstream, ~1 day after
  Windows is solid (per plan §"Cross-platform notes").
- **Linux .AppImage / .deb** — defer past v1 launch.
- **Mobile app stores (Play Store, App Store)** — completely separate
  process; published via Flutter mobile build pipeline (`apps/mobile/`),
  not via this installer.
- **Docker / Helm / k8s deployment** — Fluxora is not a service product;
  not relevant.
- **Headless server-only installer** — listed in plan D8 as a future
  power-user option; same .iss with `[Tasks] noservice` selected covers
  90% of the case for now.
- **Auto-update implementation details (Squirrel.Windows)** — separate
  workstream; this doc just calls out it exists.

---

## Document maintenance

This doc goes stale as you knock items off the list. When you complete
a section, replace the "Action" subheading with a "**DONE 20YY-MM-DD**"
note + a link to the commit / PR. Don't delete the section — future
maintainers benefit from seeing what was on the critical path.

If you add a new blocker, file it in the same numbered section as the
existing ones (3.1–3.4, 4.1–4.5, etc.) so the structure stays
predictable.

The "TL;DR — what's blocking the first ship" table at the top should
reflect the current count. Update it as items resolve.
