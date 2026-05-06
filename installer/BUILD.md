# Building the Fluxora Windows installer

> **Effective:** 2026-05-06
> **Companion to:** [`installer/Fluxora.iss`](Fluxora.iss)
> **Plan reference:** [`docs/10_planning/06_installer_plan.md`](../docs/10_planning/06_installer_plan.md)

This is the operator-facing build pipeline. It produces a single signed
`Fluxora-Setup-<version>-x64.exe` from a clean checkout in 10–15 minutes
on a modest desktop.

---

## What you produce

| Output | Path | Size (typical) |
|--------|------|----------------|
| Server binary (Nuitka, obfuscated) | `installer/payload/server/fluxora_server.exe` + `_internal/` tree | ~80 MB |
| Desktop binary (Flutter, obfuscated) | `installer/payload/desktop/fluxora_desktop.exe` + DLLs + `data/` | ~60 MB |
| Bundled FFmpeg (LGPL) | `installer/payload/ffmpeg/{ffmpeg,ffprobe}.exe` | ~95 MB |
| VC++ Redistributable | `installer/payload/redist/vc_redist.x64.exe` | ~25 MB |
| Final installer | `dist/installer/Fluxora-Setup-<version>-x64.exe` | ~180–220 MB |

Smaller payload = faster downloads. The biggest single savings come from
trimming Nuitka's `_internal/` tree (~30 % reduction by stripping unused
stdlib modules — see §3 below).

---

## Prerequisites (one-time setup)

| Tool | Version | Install command |
|------|---------|-----------------|
| Python | 3.11 (3.12 acceptable, 3.13 not yet validated) | <https://www.python.org/downloads/> — install for all users, add to PATH |
| Nuitka | 2.4+ | `pip install nuitka` |
| Flutter SDK | 3.41.3 stable (matches CI pin) | <https://docs.flutter.dev/get-started/install/windows> |
| Inno Setup | 6.2.0+ | <https://jrsoftware.org/isdl.php> — install the Unicode build |
| FFmpeg LGPL builds | 7.0.x (pin) | Download from <https://www.gyan.dev/ffmpeg/builds/> — `ffmpeg-release-essentials.zip` (LGPL, no GPL components statically linked) |
| Visual C++ Redistributable | 2015–2022 (latest 14.40.x as of writing) | <https://aka.ms/vs/17/release/vc_redist.x64.exe> |
| signtool.exe | Windows SDK | Comes with Windows 10/11 SDK; on PATH after SDK install |
| Code-signing cert | Sectigo OV (per plan D1) | OV cert in PFX or attached to a hardware token |

Optional but recommended:

| Tool | Why |
|------|-----|
| `ResourceHacker` | Lets you strip metadata from the Nuitka exe before packaging — cosmetic. |
| `7-zip` | Faster than `tar` on Windows for unpacking FFmpeg builds. |

---

## Build pipeline

The pipeline has five stages. Run them in order. CI scripts this in
`.github/workflows/release.yml`; locally you run them by hand.

### 1. Build the server with Nuitka (obfuscation pass)

**Why Nuitka, not PyInstaller:** PyInstaller bundles can be unpacked with
`pyinstxtractor` in seconds — your source code is recoverable verbatim.
Nuitka compiles each `.py` file to native C and links it into a real
binary; reverse-engineering needs IDA Pro and an afternoon, not a single
script. For paid-tier code where the license-key validator lives, that's
the difference between "obfuscated" and "compiled."

```powershell
# From the repo root.
cd apps\server

# Install runtime + Nuitka. CI uses a venv; locally you can pip install --user.
python -m pip install -r requirements.txt
python -m pip install nuitka ordered-set zstandard

# Compile.
# --standalone           : bundle Python + all imports under dist\<name>\
# --onefile              : NOT used — a single-file build delays first-run
#                          startup by ~3 s while it unpacks to %TEMP%; the
#                          standalone tree starts faster and ships cleaner.
# --enable-plugin=anti-bloat : drops unused stdlib modules from the bundle.
# --include-package=...  : explicit include for packages Nuitka misses
#                          via static analysis (aiosqlite, asyncio loops
#                          on Windows, FastAPI's lazy imports, slowapi).
# --windows-icon-from-ico : embeds the brand icon in the resulting .exe.
# --product-name / --product-version / --file-version : populate the
#                          Windows file-properties dialog.
# --remove-output         : let Nuitka clean its build dir on success.
python -m nuitka ^
  --standalone ^
  --enable-plugin=anti-bloat ^
  --enable-plugin=multiprocessing ^
  --include-package=fastapi ^
  --include-package=uvicorn ^
  --include-package=aiosqlite ^
  --include-package=httpx ^
  --include-package=psutil ^
  --include-package=pydantic ^
  --include-package=zeroconf ^
  --include-package=slowapi ^
  --include-data-dir=database/migrations=database/migrations ^
  --windows-icon-from-ico=..\desktop\windows\runner\resources\app_icon.ico ^
  --windows-company-name="Marshalx" ^
  --windows-product-name="Fluxora Server" ^
  --windows-file-description="Fluxora Media Server" ^
  --windows-product-version=0.1.0.0 ^
  --windows-file-version=0.1.0.0 ^
  --output-dir=build_nuitka ^
  --remove-output ^
  --output-filename=fluxora_server.exe ^
  main.py

# Move output to where the .iss expects it.
xcopy /E /I /Y build_nuitka\main.dist ..\..\installer\payload\server
rename ..\..\installer\payload\server\main.dist server
# main.dist becomes "server" — actually, easier: have Nuitka emit
# directly with --output-dir but that controls the build cache, not
# the dist tree. Use the rename approach above.

cd ..\..
```

**Sanity check the output:**

```powershell
.\installer\payload\server\fluxora_server.exe --help
```

Should print FastAPI / uvicorn help text. If it crashes with
`ModuleNotFoundError`, add the missing module to `--include-package`
and recompile.

**Strip migrations + database directory** is included in the bundle so
the server can apply migrations against the runtime DB. Don't omit it.

### 2. Build the desktop control panel (Flutter --obfuscate)

```powershell
cd apps\desktop

# Pull deps.
flutter pub get

# Release build with Dart-code obfuscation enabled.
# --obfuscate                    : strips identifiers from the AOT snapshot.
# --split-debug-info=<path>      : MANDATORY when --obfuscate is set;
#                                  Flutter refuses to obfuscate without
#                                  somewhere to dump the symbol map. Keep
#                                  the symbol map in version control on a
#                                  private branch — you need it to
#                                  symbolize crash reports later.
# --dart-define=...              : compile-time constants (unused here;
#                                  placeholder for future build flags).
flutter build windows ^
  --release ^
  --obfuscate ^
  --split-debug-info=build\symbols\windows ^
  --dart-define=FLUXORA_BUILD_CHANNEL=stable

# Output is at build\windows\x64\runner\Release\
# Move to where the .iss expects it.
xcopy /E /I /Y build\windows\x64\runner\Release ..\..\installer\payload\desktop

cd ..\..
```

**Important: keep `build\symbols\windows\` somewhere safe.** When a crash
report comes in from the field, you need the symbol map to read the stack
trace. Without it, the trace is `0x7ff8a1234567` all the way down. Store
it on a private branch (e.g. `release-symbols/<version>`) — never commit
to `main` since the symbol map is what someone with a stripped binary
would need to "un-obfuscate" the AOT snapshot.

**Sanity check the output:**

```powershell
.\installer\payload\desktop\fluxora_desktop.exe
```

Should open the desktop app's connect screen. If it fails to start on a
clean machine, you've got a missing DLL — almost always VC++ Redistributable
(handled at install time, not here) or a missing Flutter plugin DLL (check
`build\windows\x64\runner\Release\` matches what's under
`installer\payload\desktop\`).

### 3. Trim the Nuitka bundle (optional but worth ~30 % size cut)

Nuitka's `_internal/` ships everything it could possibly need, including
modules Fluxora doesn't import:

```powershell
# Modules safe to delete from installer\payload\server\_internal\
# — confirmed by `python -m fluxora_server --help` not pulling them.
$bloat = @(
  'tkinter*',       # Fluxora has no Tk UI
  'turtle*',        # ditto
  'curses*',        # not used
  'distutils*',     # build-time only, not runtime
  'setuptools*',    # ditto
  'pip*',           # ditto
  'test_*',         # stdlib test suites
  '_test*',         # ditto
  'unittest*',      # not used at runtime by the server
  'pydoc_data*',    # internal doc data
  'idlelib*',       # IDLE
  'venv*',          # we don't spawn venvs at runtime
  'ensurepip*',     # ditto
  'lib2to3*'        # not used
)
foreach ($pat in $bloat) {
  Get-ChildItem installer\payload\server\_internal -Recurse -Filter $pat |
    ForEach-Object { Remove-Item -Recurse -Force $_.FullName }
}
```

Run the sanity check after trimming:

```powershell
.\installer\payload\server\fluxora_server.exe --help
```

If anything broke, restore the deleted module from the un-trimmed Nuitka
output and add it to your "do not delete" list.

### 4. Stage the rest of the payload

```powershell
# FFmpeg — extract the ffmpeg-release-essentials.zip you downloaded.
mkdir installer\payload\ffmpeg -Force
copy <path-to-extracted-ffmpeg>\bin\ffmpeg.exe   installer\payload\ffmpeg\
copy <path-to-extracted-ffmpeg>\bin\ffprobe.exe  installer\payload\ffmpeg\
copy <path-to-extracted-ffmpeg>\LICENSE          installer\payload\ffmpeg\LICENSE.txt

# VC++ Redistributable.
mkdir installer\payload\redist -Force
copy <path-to-vc_redist.x64.exe>  installer\payload\redist\

# Wizard imagery (optional — Inno Setup falls back to defaults if absent).
# Place 164x314 large + 55x55 small BMPs at:
# installer\assets\wizard-large.bmp
# installer\assets\wizard-small.bmp
```

### 5. Compile the installer

```powershell
# ISCC.exe is in the Inno Setup install dir. Add to PATH or call full path.
# /DMyAppVersion= rewrites the #define in Fluxora.iss for this build.
# /Qp suppresses the verbose progress (cleaner CI logs).
# /Sfluxora_signtool=... wires SignTool for both the chained binaries
# and the final installer (see §6 below).

ISCC.exe ^
  /DMyAppVersion=0.1.0 ^
  /Sfluxora_signtool=signtool sign /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /n "Marshalx" $f ^
  installer\Fluxora.iss
```

Output: `dist\installer\Fluxora-Setup-0.1.0-x64.exe`.

### 6. Code signing

If you have a code-signing cert from Sectigo / DigiCert / SSL.com, the
`/Sfluxora_signtool=...` flag above wires it through to every binary the
installer touches AND the final installer. The signature uses RFC 3161
timestamping so the installer remains valid after the cert expires.

For an EV cert on a hardware token, swap `/n "Marshalx"` with
`/sha1 <thumbprint>` — token-backed certs can't always be selected by
subject name.

If you do NOT have a cert yet, omit the `/S...` flag entirely; ISCC
emits an unsigned installer. Windows SmartScreen will pop a "Microsoft
Defender prevented an unrecognised app from starting" dialog the first
~3,000 downloads (Sectigo OV reputation builds based on volume).

The Nuitka server binary and the Flutter desktop binary should ALSO be
signed BEFORE staging into `installer\payload\` — `/S...` on ISCC only
signs the chained .exes Inno Setup adds itself; the bundled binaries
need a separate signtool pass:

```powershell
signtool sign ^
  /tr http://timestamp.sectigo.com /td sha256 /fd sha256 ^
  /n "Marshalx" ^
  installer\payload\server\fluxora_server.exe ^
  installer\payload\desktop\fluxora_desktop.exe
```

### 7. Smoke test

On a clean Windows VM (Win 10 22H2 + Win 11 23H2, no prior Fluxora):

1. Run `Fluxora-Setup-<ver>-x64.exe`.
2. SmartScreen should accept the signature without the unrecognised-app
   warning (assuming cert reputation has built up).
3. Confirm:
   - VC++ Redistributable installs silently if missing.
   - The service `FluxoraServer` registers and starts.
   - `services.msc` shows the service "Running" with "Automatic" start
     and the recovery tab shows the 5s/5s/30s restart actions.
   - `netsh advfirewall firewall show rule name="Fluxora Server"` lists
     the rule.
   - `Get-MpPreference | Select-Object -ExpandProperty ExclusionPath`
     contains `C:\ProgramData\Fluxora\hls-tmp`.
   - The desktop app launches (if the user kept the post-install
     checkbox) and connects to `http://localhost:8000`.
   - `C:\ProgramData\Fluxora\fluxora.log` exists and shows the server
     starting up.
4. Pair a phone over LAN — confirm the firewall rule is doing its job.
5. Run the uninstaller — confirm it asks about wiping `C:\ProgramData\Fluxora\`,
   defaults to "no", and only wipes if you click yes.

### 8. CI integration

The above pipeline is captured in `.github/workflows/release.yml` (to be
written; tracked in [`docs/10_planning/04_manual_tasks.md`](../docs/10_planning/04_manual_tasks.md)).
The CI run additionally:

- Builds in a clean GitHub Actions Windows runner (no PATH pollution from
  the dev machine).
- Caches the Nuitka build dir + Flutter pub-cache between runs.
- Uploads the signed installer as a release asset.
- Publishes the symbol map to a private `release-symbols` branch.
- Generates a Squirrel `RELEASES` file entry pointing at the new installer
  for in-app auto-updates (per plan item 2).

CI is the one source of truth for production builds — local builds are
useful for iteration but should not ship to users.

---

## Troubleshooting

### Nuitka "ModuleNotFoundError" on first run

Nuitka's static analysis misses dynamic imports — anything done via
`importlib`, `__import__`, or string-built module names. Add the missing
package to `--include-package=` and recompile. If the import is conditional
on a runtime check (e.g. `if sys.platform == 'win32': import winreg`), use
`--include-module=winreg` for a single module.

### Flutter "split-debug-info path is required" error

You forgot `--split-debug-info` after `--obfuscate`. Flutter refuses to
ship an obfuscated binary without somewhere to write the symbol map.

### ISCC errors on `Source: "payload\server\*"`

The build sequence is wrong — `installer\payload\server\` doesn't exist
yet. Run §1 (Nuitka) before §5 (ISCC). Same applies to the desktop tree.

### Service registers but won't start

Look at `C:\ProgramData\Fluxora\fluxora.log`. The `LocalService` account
has limited rights; if the server tries to write somewhere that account
can't reach (e.g. a per-user `%TEMP%`), it fails to start. Confirm that
`FLUXORA_DATA_DIR=C:\ProgramData\Fluxora` is set in the service's
environment block:

```powershell
sc.exe qc FluxoraServer
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\FluxoraServer" /v Environment
```

### Service starts but desktop can't connect

Either the firewall rule didn't land or you typed a wrong port. Re-run:

```powershell
netsh advfirewall firewall show rule name="Fluxora Server"
sc.exe qc FluxoraServer
```

The `binPath` in the second output should match
`"C:\Program Files\Fluxora\server\fluxora_server.exe"` exactly, with
quotes intact.

### "VCRUNTIME140.dll missing" on launch

Your VC++ Redistributable check failed. Re-run the redist installer
manually:

```powershell
"C:\Program Files\Fluxora\redist\vc_redist.x64.exe" /install /quiet /norestart
```

If the file isn't there, the deleteafterinstall flag in `[Files]` already
ran. Download from <https://aka.ms/vs/17/release/vc_redist.x64.exe>.

---

## Cross-references

- Strategic ship-readiness checklist (every blocker before first ship): [`installer/SHIP.md`](SHIP.md)
- Edge-case audit + applied fixes (every install / uninstall / upgrade / repair / silent-mode path): [`installer/AUDIT.md`](AUDIT.md)
- Installer architecture decisions: [`docs/10_planning/06_installer_plan.md`](../docs/10_planning/06_installer_plan.md)
- Server PyInstaller-era runbook (superseded by Nuitka but kept for reference): [`docs/05_infrastructure/runbooks/10_pyinstaller_distribution.md`](../docs/05_infrastructure/runbooks/10_pyinstaller_distribution.md)
- Auto-update pipeline (Squirrel.Windows): captured in plan §"Auto-update model" (implementation TBD)
- Defender-exclusion rationale: [`docs/12_guidelines/03_gotchas.md`](../docs/12_guidelines/03_gotchas.md) "Defender real-time scan kills HLS throughput"
- Aero Peek fix the AppUserModelID matches: same gotchas doc, "No taskbar Aero Peek thumbnail on hover"
