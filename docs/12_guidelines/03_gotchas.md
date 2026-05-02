# Known Risks & Gotchas

> Sharp edges encountered during Fluxora development. Read this when troubleshooting an unexplained failure — the answer is often here.

| Area | Gotcha | Mitigation |
|------|--------|-----------|
| FFmpeg | Must be installed separately by the user; PyInstaller cannot bundle it | Startup check with friendly error message and download link |
| mDNS on Android 12+ | Android silently drops multicast packets without `WifiManager.MulticastLock` | `MainActivity.kt` exposes `MethodChannel('dev.marshalx.fluxora/multicast')`; `ConnectCubit.startDiscovery()` acquires the lock before scanning, releases on close. Manual IP entry remains as fallback. |
| `flutter_webrtc` | v0.10.x uses removed v1 Flutter plugin API (`PluginRegistry.Registrar`) — fails to compile on AGP 8+ | v1.4.1 integrated and working. Do not downgrade. |
| SQLite concurrency | WAL mode helps but high client counts can still lock | Connection pool limit; queue writes; plan PostgreSQL migration path for Pro tier. |
| HLS temp files | FFmpeg writes to `/tmp` — can fill up on long sessions | Cleanup enforced on stream close AND on server startup (orphan cleanup in `main.py` lifespan). |
| PyInstaller + FFmpeg | FFmpeg subprocess path must use the bundled binary path, not `PATH` | Resolve FFmpeg path via `sys._MEIPASS` in frozen builds. |
| Token storage (Flutter) | `shared_preferences` is not encrypted | Use `flutter_secure_storage` for the bearer token. |
| Path traversal | File-serving routes could expose files outside the library root | Always canonicalize and prefix-check before serving. |
| Bash / Git Commits | Backticks inside double-quoted commit messages execute as bash commands, causing pathspec errors | Use single quotes (`'`) instead of double quotes to wrap commit messages containing backticks. |
| Dart 3.9 null-aware map syntax | `{'key': ?value}` looks like a syntax error to older analyzers / IDEs | Valid in SDK `>=3.8.0`; project floor is `>=3.9.0` (CI pins Flutter 3.41.3 / Dart 3.11). `flutter analyze` confirms no issues. |
| Pytest & CI | `pytest` exits with code 5 if no tests are found, breaking CI pipelines | Always include at least one placeholder test (e.g. `def test_placeholder(): pass`). |
| Git Pull / Merge | `git pull` with diverged branches creates an unwanted `Merge branch 'main' of...` commit | Always use `git pull --rebase`. |
| URL query encoding | `+` in a query string is decoded as a space (HTML form rule) — breaks ISO timestamps with `+00:00` | Use httpx `params={...}` (or `urllib.parse.quote`); never f-string a timestamp directly into the query. |
| Python `or` truthiness on lists | `lst or default` substitutes `default` when `lst` is `[]` (falsy) — silently turns "deny everything" into "allow everything" | Use `lst if lst is not None else default` for explicit None-check. |
