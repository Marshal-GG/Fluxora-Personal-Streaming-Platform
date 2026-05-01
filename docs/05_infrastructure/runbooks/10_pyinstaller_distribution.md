# Runbook: PyInstaller standalone-binary distribution

> **What:** Bundle a Python application into a single executable that end-users run without installing Python. Works for Windows `.exe`, macOS Universal binaries, and Linux ELFs. The pattern Fluxora's server uses to ship its FastAPI server.
> **Estimated time:** 2–4 hours for the first build (tuning the spec); 5 minutes for subsequent builds.

---

## When to use this

- ✅ Your end users aren't developers
- ✅ Asking them to `pip install` and configure Python is friction you can't accept
- ✅ Your app has many dependencies and you want a self-contained ship
- ✅ You can ship per-OS binaries (you can't ship one binary that works on all OSes — see "Cross-platform builds" below)

**When NOT to use:**

- 🔴 Your audience is developers (they already have Python)
- 🔴 You need < 5 MB binary size — PyInstaller bundles everything, expect 30–80 MB minimum
- 🔴 You need to call other Python from the user's environment (e.g. plugins) — bundled CPython doesn't see the system Python's site-packages

Alternatives: `pipx` for end-user-developers; native Rust/Go rewrite for size-critical; Nuitka for ahead-of-time compilation (faster startup, smaller binary, more setup work).

---

## Step 1 — Install PyInstaller

In your dev environment (venv recommended):

```bash
pip install pyinstaller
```

Add `pyinstaller>=6.0` to your dev dependencies:

```toml
# pyproject.toml
[project.optional-dependencies]
dev = [
  ...
  "pyinstaller==6.10.0",
]
```

PyInstaller is a build tool, not a runtime dependency. It runs on your machine to produce the binary.

---

## Step 2 — First build attempt

In your project root with the entry point at `apps/server/main.py`:

```bash
pyinstaller --onefile --name myapp-server apps/server/main.py
```

`--onefile` produces a single `dist/myapp-server.exe`. Without `--onefile`, you get a `dist/myapp-server/` directory with the binary + all bundled DLLs.

Try running it: `./dist/myapp-server.exe`. It probably works! Or maybe it crashes with `ModuleNotFoundError: No module named 'X'` — see "Hidden imports" below.

Once you have a working build, **delete the auto-generated `myapp-server.spec`** and write a real one. The auto-spec is fine for hello-world; real apps need control.

---

## Step 3 — Write a proper `.spec` file

`apps/server/myapp_server.spec`:

```python
# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all, collect_data_files

# Collect all metadata, datas, binaries for packages PyInstaller can't find statically
fastapi_datas, fastapi_binaries, fastapi_hiddenimports = collect_all('fastapi')
pydantic_datas, pydantic_binaries, pydantic_hiddenimports = collect_all('pydantic')

block_cipher = None

a = Analysis(
    ['apps/server/main.py'],
    pathex=['apps/server'],
    binaries=[
        *fastapi_binaries,
        *pydantic_binaries,
    ],
    datas=[
        # Bundle migration SQL files
        ('apps/server/database/migrations/*.sql', 'database/migrations'),
        # Bundle templates / static assets if any
        # ('apps/server/templates', 'templates'),
        *fastapi_datas,
        *pydantic_datas,
    ],
    hiddenimports=[
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        *fastapi_hiddenimports,
        *pydantic_hiddenimports,
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',           # huge, almost never needed for a server
        'matplotlib',        # if a transitive dep pulls it in
        'PyQt5',             # ditto
    ],
    noarchive=False,
    optimize=2,              # equivalent to python -OO
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='myapp-server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,                      # UPX compresses but is flagged as malware by some AVs
    runtime_tmpdir=None,
    console=True,                   # show stdout — set False for GUI-style apps
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,         # set for macOS code signing
    entitlements_file=None,
    icon='assets/icon.ico',         # optional
)
```

Build with the spec:

```bash
pyinstaller apps/server/myapp_server.spec
```

Output: `dist/myapp-server.exe` (Windows) or `dist/myapp-server` (mac/linux).

---

## Step 4 — Handle resources at runtime (`sys._MEIPASS`)

In a normal Python app, `Path(__file__).parent / "data" / "config.yaml"` works. In a PyInstaller `--onefile` build, the running binary unpacks itself into a temp directory at startup, and your code is running from there. The path `__file__` no longer points where you expect.

Pattern for resolving bundled resources:

```python
import sys
from pathlib import Path

def resource_path(*parts: str) -> Path:
    """Return absolute path to a bundled resource, working both
    in dev (running from source) and frozen (PyInstaller)."""
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).parent.parent))
    return base.joinpath(*parts)

# Usage
migrations_dir = resource_path("database", "migrations")
```

`sys._MEIPASS` is set only in PyInstaller-frozen builds. Falling back to `__file__`'s parent gives correct dev behavior.

For Fluxora's server, FFmpeg is bundled the same way:

```python
def _ffmpeg_bin() -> str:
    if getattr(sys, "frozen", False):
        bundled = Path(sys._MEIPASS) / "ffmpeg.exe"
        if bundled.exists():
            return str(bundled)
    return shutil.which("ffmpeg") or "ffmpeg"
```

---

## Step 5 — Bundle non-Python binaries (FFmpeg etc.)

Add them to `datas` in the `.spec` file:

```python
datas=[
    ('vendor/ffmpeg-windows/ffmpeg.exe', '.'),         # bundled into root of unpacked dir
    ('vendor/ffmpeg-windows/ffprobe.exe', '.'),
    ('apps/server/database/migrations/*.sql', 'database/migrations'),
],
```

Format: `(source_path, dest_in_bundle)`. `'.'` puts the file at the bundle root (where `sys._MEIPASS` points).

Per-OS, you'll either bundle different binaries or have separate spec files.

---

## Step 6 — Hidden imports

PyInstaller does static analysis to find your imports. It misses:

- Anything imported via `importlib.import_module(name)` where `name` is dynamic
- Plugins that get loaded based on config
- Optional imports inside try/except blocks
- C-extension submodules

Symptoms: works in dev, crashes the bundled binary with `ModuleNotFoundError`.

Fix: add to `hiddenimports` in the spec. Common offenders:

```python
hiddenimports=[
    # Uvicorn loads protocols dynamically
    'uvicorn.loops.auto',
    'uvicorn.protocols.http.auto',
    'uvicorn.protocols.websockets.auto',
    'uvicorn.lifespan.on',

    # SQLAlchemy / aiosqlite
    'aiosqlite',

    # Pydantic v2 ships compiled core
    'pydantic_core',

    # Logging
    'pythonjsonlogger.json',

    # Argon2 native bindings
    '_argon2_cffi_bindings',
],
```

Find missing ones by running the binary with verbose import logs:

```bash
./dist/myapp-server --debug imports 2>&1 | head -100
```

Or `python -v ./dist/myapp-server` on the source side to see the load order.

---

## Step 7 — Per-OS builds

You **cannot** cross-compile. A binary built on Windows runs on Windows; one built on macOS runs on macOS. Build each OS on a matching CI runner:

```yaml
# .github/workflows/release.yml (excerpt)
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]

runs-on: ${{ matrix.os }}
steps:
  - uses: actions/checkout@v5
  - uses: actions/setup-python@v5
    with:
      python-version: '3.11'
  - run: pip install -e '.[dev]'
  - run: pyinstaller apps/server/myapp_server.spec
  - uses: actions/upload-artifact@v4
    with:
      name: myapp-server-${{ matrix.os }}
      path: dist/myapp-server*
```

Result: three artifacts, one per OS. Attach to a GitHub Release (next step).

---

## Step 8 — Code signing

Unsigned binaries trigger SmartScreen warnings on Windows and Gatekeeper rejection on macOS. For end-user distribution, sign them.

### Windows

- **Cheap option:** Buy a code-signing cert from Sectigo / Comodo (~$50/year for a basic individual cert; ~$300/year for an EV cert that bypasses SmartScreen)
- **Sign with `signtool`:**
  ```cmd
  signtool sign /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a dist\myapp-server.exe
  ```

### macOS

- **Apple Developer ID** ($99/year) is required for end-user distribution
- **Sign + notarize:**
  ```bash
  codesign --deep --force --options runtime --sign "Developer ID Application: Your Name (TEAMID)" dist/myapp-server
  ditto -c -k --keepParent dist/myapp-server myapp-server.zip
  xcrun notarytool submit myapp-server.zip --keychain-profile "AC_PASSWORD" --wait
  xcrun stapler staple dist/myapp-server
  ```

### Linux

No standard signing. Distribute as a tarball + SHA256 checksum + ideally a Debian/Fedora package (out of scope here).

---

## Step 9 — Auto-update strategy

Pick one:

| Strategy | Setup | UX |
|----------|-------|-----|
| **Don't auto-update** | Free | User downloads new binary from your site / GitHub Releases when motivated |
| **Check for new version on startup, link to download** | 1 hour | App checks `/api/v1/latest-version` (or GitHub Releases API), shows banner if outdated |
| **In-place self-update** | Days | App downloads new binary, replaces self, restarts. Painful on Windows because you can't replace a running .exe |
| **Microsoft Store / Mac App Store** | Weeks of bureaucracy | Free for users, store handles updates |

For Fluxora's server, **option 2** is the plan — show a notification in the desktop control panel when a newer release exists, link to download.

---

## Step 10 — Distribute via GitHub Releases

```yaml
# .github/workflows/release.yml (continued)
- name: Create GitHub Release
  uses: softprops/action-gh-release@v2
  if: startsWith(github.ref, 'refs/tags/v')
  with:
    files: |
      myapp-server-windows-latest/myapp-server.exe
      myapp-server-macos-latest/myapp-server
      myapp-server-ubuntu-latest/myapp-server
    body: |
      Release notes for ${{ github.ref_name }}.
      See CHANGELOG.md for details.
```

Triggered by pushing a tag like `v0.4.0`. GitHub Releases provides a permanent download URL and shows changelog notes.

---

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ModuleNotFoundError` at runtime | Dynamic imports PyInstaller missed | Add to `hiddenimports` in spec |
| Binary is 200+ MB | Bundled stdlib + ML deps | Add `excludes` for unused heavy modules; use `--noupx` is fine but `--upx` shrinks more (at AV-flag risk) |
| Slow startup (5+ seconds) | `--onefile` unpacks to temp on every launch | Switch to `--onedir` (folder of files, faster startup) |
| AV flags binary as malware | UPX compression + bootloader pattern matches some AV signatures | Submit binary to Microsoft / VirusTotal for whitelist review; or stop using UPX |
| Works on dev machine, fails on user's | Built against newer libc / Windows API than user has | Build on the oldest OS version you want to support (Ubuntu 20.04, Windows 10) |
| `sys._MEIPASS` errors at runtime | Code accessing `__file__` paths in frozen mode | Use `resource_path()` helper (Step 4) |
| Logs vanish at startup | `console=False` swallows stdout | Either `console=True` or write logs to a file directly |

---

## Size optimization checklist

- [ ] Add `excludes` for `tkinter`, `matplotlib`, `PIL`, etc. if not used
- [ ] Use `--onedir` if startup speed matters; `--onefile` only for distribution simplicity
- [ ] Set `optimize=2` (equivalent to `python -OO`) — strips docstrings + asserts
- [ ] Strip debug symbols from C extensions: `strip=True`
- [ ] Don't use UPX unless you've confirmed AV won't flag it
- [ ] Audit `dist/myapp-server/` (or extract `--onefile` with `pyi-archive_viewer`) — what's the biggest thing? Can it go?

A FastAPI server typically ends up at 30–60 MB. Don't expect smaller than 25 MB.

---

## Cross-references

- **CI for release builds:** [`03_github_ci_cd.md`](./03_github_ci_cd.md)
- **Where build artifacts go:** GitHub Releases (covered above)
- **Fluxora's spec file:** `apps/server/fluxora_server.spec` (project-specific)
