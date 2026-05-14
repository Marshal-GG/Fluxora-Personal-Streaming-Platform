# Tech Stack

> **Category:** Architecture
> **Status:** Active — full canonical inventory of every dependency, codegen tool, build tool, and external service in use across the monorepo. Updated 2026-05-09 — no dependency changes since 2026-05-08; refresh covers test-count drift only (mobile 75 → 78 after the §17 second-round drag-state tests).

This doc lists what's *actually installed* (with versions) per package, why it's there, and what category it serves. When you add or remove a dep, update the relevant section here.

---

## Stack Summary

| Layer | Technology | Notes |
|-------|-----------|------|
| Backend Language | Python 3.11+ | Pinned floor in `pyproject.toml` |
| Backend Framework | FastAPI 0.111 | Async REST + WebSocket |
| ASGI Server | Uvicorn 0.29 | `uvicorn[standard]` (uvloop, httptools) |
| Streaming Engine | FFmpeg | HLS transcoding (libx264 / NVENC / QSV / VAAPI). External binary, not a Python dep. |
| Database | SQLite (`aiosqlite` 0.20) | Local metadata + library index, WAL mode |
| Rate Limiting | `slowapi` 0.1.9 | Per-IP throttling on hot endpoints |
| Structured Logging | `python-json-logger` 4.1 | JSON-line file handler + WS broadcast handler |
| System Stats | `psutil` 7.2 | CPU / RAM / network / uptime probes |
| Local Discovery | `zeroconf` 0.131 | mDNS auto-pairing on LAN |
| WebRTC (server) | `aiortc` 1.9 | STUN/TURN signaling server-side |
| Public Routing | Cloudflare Tunnel | `fluxora-api.marshalx.dev` (Phases 1–5 live, Phase 6 hardening operator-driven). See [`05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) |
| Secret Storage (server) | `keyring` 25.7 + `cryptography` 47.0 | OS-keyring backed; Fernet for at-rest encryption of API keys |
| Bearer Token Hashing | HMAC-SHA256 (stdlib) | Tokens stored as hashes, never plaintext (CLAUDE.md hard rule #13) |
| Password Hashing | `argon2-cffi` 25.1 | (Currently unused — Fluxora has no operator-password concept; reserved for future) |
| Error Tracking | `sentry-sdk[fastapi]` 2.58 | FastAPI integration |
| Metadata API | TMDB API | Movie/TV show metadata (HTTPS, key in DB) |
| Payment Webhooks | Polar Standard Webhooks | Paid-order license issuance |
| Frontend Framework | Flutter 3.41 (Dart SDK ≥ 3.9) | CI-pinned. Cross-platform Win/macOS/Linux/Android/iOS. |
| State Management | `flutter_bloc` 9.1 | Cubit primary, Bloc where streams matter |
| Routing | `go_router` 17 (desktop) / 13 (mobile) | Mobile is on the older minor pending player-redesign upgrade |
| DI | `get_it` 9 (desktop) / 7 (mobile) | Lazy singletons |
| Vector Graphics | `flutter_svg` 2.2.4 | SMIL-animated SVGs for hero waves, pulse rings, empty states |
| HTTP Client (Flutter) | `dio` 5.9 | Wrapped in `ApiClient` with dual-base routing |
| Secure Storage (Flutter) | `flutter_secure_storage` 9 | Keystore/Keychain-backed token + URL persistence |
| Codegen (Flutter) | `freezed` 3 + `json_serializable` 6.13 | Immutable entities + JSON marshalling — generates `.freezed.dart` + `.g.dart` |
| Testing (Flutter) | `mocktail` 1.0 + `bloc_test` 10 + `golden_toolkit` 0.15 | See [Testing & codegen](#testing--codegen) below |
| Web Landing | Next.js 16 + React 19 + TypeScript 5 | Static-exported; deployed to Cloudflare Pages |

---

## Backend (`apps/server`)

### Runtime dependencies
Versions pinned exactly in `apps/server/pyproject.toml` (no `^` / `~`).

| Package | Version | Purpose |
|---------|---------|---------|
| `fastapi` | 0.111.0 | Async REST + WebSocket framework |
| `uvicorn[standard]` | 0.29.0 | ASGI server with uvloop/httptools |
| `aiosqlite` | 0.20.0 | Async SQLite driver — singleton DB connection in `database/connection.py` |
| `zeroconf` | 0.131.0 | mDNS broadcast + browse (`AsyncZeroconf` for non-blocking I/O) |
| `aiortc` | 1.9.0 | WebRTC peer + signaling (Phase 3) |
| `httpx` | 0.27.0 | TMDB + Polar HTTP calls; also pytest fixture client |
| `python-multipart` | 0.0.9 | Multipart upload parsing |
| `pydantic-settings` | 2.14.0 | `BaseSettings` for `config.py` (env-driven, no hardcoded values) |
| `slowapi` | 0.1.9 | Per-IP rate limiting middleware |
| `python-json-logger` | 4.1.0 | JSON file log formatter + WS broadcast handler |
| `keyring` | 25.7.0 | OS-keyring secret backend |
| `cryptography` | 47.0.0 | Fernet at-rest encryption for API keys (TMDB, Polar) |
| `argon2-cffi` | 25.1.0 | Reserved — not yet wired (no operator-password concept v1) |
| `psutil` | 7.2.2 | CPU/RAM/network/uptime stats for `/info/stats` + `/ws/stats` |
| `sentry-sdk[fastapi]` | 2.58.0 | Server-side error tracking |

### Dev dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `pytest` | 8.2.0 | Test runner — **775 passing tests** as of 2026-05-09 (Groups v2 + streaming §4.5 + audit §17.3 #3 + M11 `/content` + M2.5 `PATCH /clients/me` + streaming §16 resume seek / audio diagnostics / scrubber-offset + streaming §17 `info` loglevel / `ffmpeg_capabilities` probe / transcode-only `-readrate` + same-day follow-on stream-copy regression guard; §17 second-round mobile follow-on on 2026-05-09 was mobile-only, no server delta; +3 audit follow-up TURN-ICE-server regression tests 2026-05-09) |
| `pytest-asyncio` | 0.23.7 | Async test support; `asyncio_mode = "auto"` |
| `httpx` | 0.27.0 | `AsyncClient` for endpoint tests |
| `black` | 24.4.0 | Code formatter (88-col, py311 target) |
| `ruff` | 0.15.12 | Linter (E, F, I, N, W, UP rules) |

### Distribution
- **PyInstaller** — Server ships as a single standalone executable. No Docker, no system Python required on user machines. Build script in `apps/server/build/`.

### External binaries
- **FFmpeg** — required at runtime. Probed on startup; encoder availability detected via `ffmpeg -encoders` and intersected with the known set.
- **`nvidia-smi`** — optional, best-effort GPU probe in `services/transcoding_service.py`. Returns `(None, None)` on any failure. 1.5 s timeout.

---

## Shared Core (`packages/fluxora_core`)

| Package | Version | Purpose |
|---------|---------|---------|
| `dio` | ^5.4.0 | HTTP client wrapped in `ApiClient` with dual-base LAN/remote routing |
| `flutter_secure_storage` | ^9.0.0 | Token + remote_url + pairing persistence |
| `freezed_annotation` | ^3.0.0 | Annotation pair for `freezed` codegen |
| `json_annotation` | ^4.11.0 | Annotation pair for `json_serializable` codegen |
| `logger` | ^2.7.0 | Structured logging — replaces `print` (CLAUDE.md hard rule #3) |
| `connectivity_plus` | ^7.1.1 | Network state monitoring (Wi-Fi vs cellular vs offline) |
| `equatable` | ^2.0.8 | Value-equality for non-freezed value classes |
| `flutter_svg` | ^2.2.4 | SMIL-animated SVG rendering for brand widgets |

### Dev dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_lints` | ^4.0.0 | Lint rule set |
| `build_runner` | ^2.14.0 | Codegen orchestrator (`dart run build_runner build`) |
| `freezed` | ^3.0.0 | Generates `.freezed.dart` (immutable data classes + copyWith + ==) |
| `json_serializable` | ^6.13.0 | Generates `.g.dart` (toJson / fromJson) |
| `mocktail` | ^1.0.5 | Mock generation for repo / API mocks |

---

## Desktop App (`apps/desktop`)

Inherits everything from `fluxora_core` via a path dependency. Adds:

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^9.1.1 | Cubit/BLoC state management |
| `go_router` | ^17.2.2 | Declarative routing — 13 routes today |
| `get_it` | ^9.2.1 | DI singleton registry; `getIt.registerLazySingleton<T>` |
| `intl` | ^0.20.2 | Date/number formatting |
| `file_picker` | ^11.0.2 | Folder/file pickers for library creation + uploads |
| `dio` | ^5.9.2 | (Own pin; matches core) |
| `window_manager` | ^0.5.1 | Frameless-window chrome — backs the custom 36 px `FluxTitlebar` (drag region, minimize / maximize / close, min-size enforcement). OS title bar hidden via `TitleBarStyle.hidden` in `main.dart`. |
| `qr_flutter` | ^4.1.0 | QR rendering for the desktop "Pair device" dialog (mobile scans the `fluxora://pair?host=&port=&name=` payload). |
| `url_launcher` | ^6.3.2 | Opens external URLs from the Help screen's "Get Help" link rows via `launchUrl(uri, mode: LaunchMode.externalApplication)`. Added 2026-05-06 (F5 follow-up); single new dep, established Flutter-team package. Logger-wrapped failure paths in `_LinkRowState._open()`. |
| `freezed_annotation` | ^3.0.0 | (Own pin) |
| `json_annotation` | ^4.11.0 | (Own pin) |
| `flutter_secure_storage` | ^9.2.4 | (Own pin) |
| `logger` | ^2.7.0 | (Own pin) |
| `equatable` | ^2.0.8 | (Own pin) |

### Dev dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_lints` | ^6.0.0 | Lint rule set |
| `mocktail` | ^1.0.3 | Mocks for repos in unit + golden tests |
| `bloc_test` | ^10.0.0 | `blocTest()` matcher harness |
| `build_runner` | ^2.14.0 | Codegen orchestrator |
| `freezed` | ^3.0.0 | Generates `.freezed.dart` |
| `json_serializable` | ^6.13.0 | Generates `.g.dart` |
| `golden_toolkit` | ^0.15.0 | Pixel-perfect screen-snapshot tests (M8). Opt-in via `--tags=golden`; CI excludes via `--exclude-tags=golden`. Production screens that resolve repos through `GetIt.I<>()` inside `MultiBlocProvider.create` use the GetIt-mock recipe documented in [`apps/desktop/test/goldens/_README.md`](../../apps/desktop/test/goldens/_README.md) (register mock repos in `setUp`, drop the wrapping `MultiBlocProvider`). |

### Native runners
- **Windows** — `apps/desktop/windows/runner/` (C++). Custom `WM_GETMINMAXINFO` handler enforces 1332×720 logical-px minimum window size (DPI-scaled) for native edge-drag resize. Programmatic resize is also constrained by `window_manager`'s `minimumSize` set in `main.dart`. The OS title bar is hidden via `TitleBarStyle.hidden`; the replacement `FluxTitlebar` widget renders the brand wordmark + tagline + help/bell + window-control buttons. Shell integration:
  - **AppUserModelID** — `main.cpp` calls `SetCurrentProcessExplicitAppUserModelID(L"Fluxora.Desktop")` before window creation so the Windows shell can group the running .exe with any pinned start-menu / taskbar shortcut and render Aero Peek thumbnails on hover. Linked via `shell32.lib` in `windows/runner/CMakeLists.txt`.
  - **Window-class icons** — `win32_window.cpp` registers the runner's `WNDCLASSEX` with **both** `hIcon` (large, used by Alt-Tab) and `hIconSm` (small, used by the taskbar / window caption). Without `hIconSm`, Windows downsamples the large icon for the taskbar — quality is poor and Win 11's thumbnail renderer can fail to register the window for Aero Peek.
- **macOS / Linux** — not yet generated. Windows-only desktop app today.

#### System fonts used by `FluxTitlebar`

The minimize / maximize / restore / close caption buttons render Unicode glyphs from a Windows-bundled icon font, **not** Material Icons — using the OS-native font means our buttons are pixel-identical to every other Win 11 app's caption strip.

| Font | Ships on | Status |
|------|----------|--------|
| `Segoe Fluent Icons` | Windows 11+ | Primary — referenced first via `fontFamily` in [`flux_titlebar.dart`](../../apps/desktop/lib/shared/widgets/flux_titlebar.dart) |
| `Segoe MDL2 Assets` | Windows 10 (1511+) and Windows 11 | Fallback — referenced via `fontFamilyFallback`. Same caption codepoints, slightly different stroke weight. |

Codepoints used (these match the `ChromeXxx` glyph names in Microsoft's [Segoe Fluent Icons reference](https://learn.microsoft.com/en-us/windows/apps/design/style/segoe-fluent-icons-font)):

| Glyph | Codepoint | Caption use |
|-------|-----------|-------------|
| `ChromeMinimize` | `U+E921` | Minimize button |
| `ChromeMaximize` | `U+E922` | Maximize button (window not currently maximized) |
| `ChromeRestore` | `U+E923` | Restore button (window currently maximized — two offset overlapping squares) |
| `ChromeClose` | `U+E8BB` | Close button |

**Cross-platform caveat:** these fonts are Windows-only. macOS / Linux runners (when generated) will need either bundled-font fallbacks (`material_symbols_icons` package or vendored TTF) or a `Platform.isWindows`-gated swap to draw glyphs with `CustomPainter`. Track when generating those runners.

**Verifying:** open Character Map (`charmap.exe`) and select "Segoe Fluent Icons"; confirm `U+E921`, `U+E922`, `U+E923`, `U+E8BB` are present and render as the caption-button shapes. If a baseline Windows install can't render them, fall back to `CustomPainter` paths.

---

## Mobile App (`apps/mobile`)

Inherits `fluxora_core`. Adds:

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^9.1.1 | State management |
| `go_router` | ^13.0.0 | Routing (older minor — pending player-redesign bump). **27 routes today** (M12 + settings remediation added `/splash`, `/upgrade`, `/account`, `/privacy`, `/playback-prefs`). |
| `get_it` | ^7.6.7 | DI — `PlayerCubit` is a long-lived `lazySingleton` (M7 `PlaybackProvider` per mobile redesign §9.2); `ProfileCubit` / `ProfileStatsCubit` / `MobileGroupsCubit` / `NotificationsCubit` also singleton-scoped so re-entries to tabs survive without refetching. |
| `multicast_dns` | ^0.3.2 | mDNS discovery — PTR→SRV→A resolution chain |
| `flutter_secure_storage` | ^9.0.0 | Token + URL storage. As of 2026-05-08 also persists 6 player prefs (`bg_playback_enabled`, `bg_playback_prompt_shown`, `wifi_only_streaming`, `max_streaming_quality`, `autoplay_next`, `subtitles_default_on`). |
| `logger` | ^2.7.0 | Logging |
| `media_kit` | ^1.2.6 | HLS video playback on **desktop + iOS + Android-rollback path** (wrapped behind `MediaKitEngine` since plan 24 M2, 2026-05-15). On Android, `_kForceMediaKitOnAndroid = true` (operator escape hatch) keeps libmpv as the engine. |
| `media_kit_video` | ^2.0.1 | Video widget integration (used by `MediaKitEngine` only) |
| `media_kit_libs_video` | ^1.0.7 | Bundled libmpv for HLS |
| `androidx.media3:media3-exoplayer-hls` (Android native) | 1.10.1 | HLS video playback on **Android default path** (plan 24 M3 + M4, 2026-05-15). Talks to Dart via `MethodChannel('dev.marshalx.fluxora/exo_player')` + `EventChannel('dev.marshalx.fluxora/exo_player_events')`. Pinned Gradle dep in `apps/mobile/android/app/build.gradle.kts`; verified latest stable on developer.android.com 2026-05-12 (Hard Prohibition #12). |
| `androidx.media3:media3-exoplayer` (Android native) | 1.10.1 | Core ExoPlayer; required by `media3-exoplayer-hls`. |
| `androidx.media3:media3-ui` (Android native) | 1.10.1 | `SubtitleView` for plan 24 M9's subtitle rendering path. |
| `junit:junit` (Android native, test) | 4.13.2 | JUnit suite for the Kotlin pure-function helpers (`buildAudioTrackMapping`, `parseSourceIndex`, `mapPlayerErrorCode`) in `apps/mobile/android/app/src/test/`. |
| `cached_network_image` | ^3.4.1 | TMDB poster caching (bumped from ^3.3.1 at M0 of mobile redesign) |
| `flutter_webrtc` | ^1.4.1 | WebRTC peer for internet streaming |
| `google_fonts` | ^8.1.0 | Inter (5 weights) at runtime — mobile redesign M0 (2026-05-03). Smaller than bundling Inter as an asset; cached after first download. |
| `lucide_icons_flutter` | ^3.1.13 | 1.6 px Lucide icons — mobile redesign M0 (2026-05-03). Chosen over the unmaintained `lucide_icons` package per plan §6 ("pick whichever is more recently maintained"). |
| `screen_brightness` | ^2.1.7 | Player left-rail brightness drag — mobile redesign M6 (2026-05-03). |
| `mobile_scanner` | ^7.1.2 | QR-pairing scanner — Phase A backfill / pairing UX (2026-05-04). Decodes the desktop's `fluxora://pair?host=&port=&name=` payload. |
| `audio_service` | ^0.18.18 | OS lockscreen + Now-Playing card + BT headset for video — Phase 3 player polish (2026-05-04). Music lockscreen integration via a separate `MusicAudioHandler` is **deferred to v1.1** to avoid sharing state with `FluxoraAudioHandler`. |
| `package_info_plus` | ^9.0.1 | Runtime version + build readout for Profile → About sheet + Account screen — settings remediation M1 (2026-05-08). Replaced the hardcoded `v1.0.0 · build 482` placeholder. |
| `just_audio` | ^0.10.5 | `MusicPlayerCubit` audio playback for the M11 music viewer (2026-05-08). `AudioSource.uri(headers:)` carries the bearer token. |
| `pdfx` | ^2.9.2 | PDF rendering for the M11 doc viewer (2026-05-08). pdfx 2.x has no network-loading API, so the screen downloads the file via `GET /api/v1/files/{id}/content` to a temp path before opening with `PdfDocument.openFile`. |
| `photo_view` | ^0.15.0 | Pinch-zoom for the M11 photo viewer (2026-05-08). Loads via `NetworkImage(url, headers: …)` directly — no temp download for viewing. |
| `share_plus` | ^12.0.2 | OS share sheet for "Open in..." flows — M11 (2026-05-08). New 12.x API: `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`. |
| `path_provider` | ^2.1.5 | Promoted from transitive to direct dep at M11 (2026-05-08) for `getTemporaryDirectory()` — used by the doc + photo viewers' temp-download flow and by the Privacy & security screen's "Clear temp downloads" button. |
| `connectivity_plus` | (transitive via core) | Wi-Fi vs cellular probe — settings remediation M3 (2026-05-08). Used by `PlayerCubit._shouldRefuseOverCellular()` for Wi-Fi-only enforcement; future M10 Offline live-detector will reuse it. Mobile re-pins it in `pubspec.yaml` for clarity even though core already declares it. |

### Dev dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_lints` | ^4.0.0 | Lint rule set |
| `mocktail` | ^1.0.5 | Mocks — `MockPlayerRepository`, `MockSecureStorage`, `MockAuthRepository`, etc. |
| `bloc_test` | ^10.0.0 | Bloc test harness |

> Mobile is **not** wired to `freezed` / `build_runner` codegen — entities come from `fluxora_core` which is already codegen'd. Mobile-only data classes use plain `equatable` (or `==` / `hashCode` overrides).
>
> **Test count: 78 passing as of 2026-05-09** (was 27 at M0 baseline; +51 from M3+M5+M6+M7+M8 cubits / Groups v2 / streaming §4.10 / M11 file kinds / M3 SecureStorage round-trip / M3 widget pump / Wi-Fi-only enforcement / §17 second-round drag-state tests).

---

## Web Landing (`apps/web_landing`)

| Package | Version | Purpose |
|---------|---------|---------|
| `next` | 16.2.4 | App Router, static export to Cloudflare Pages |
| `react` | ^19.2.5 | Component library |
| `react-dom` | ^19.2.5 | DOM renderer |

### Dev dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `typescript` | ^5.0.0 | Type checking |
| `eslint` | ^9.0.0 | Linter |
| `eslint-config-next` | 16.2.4 | Next.js lint preset |
| `@types/node` | ^22.0.0 | Node typings |
| `@types/react` | ^19.0.0 | React typings |
| `@types/react-dom` | ^19.0.0 | React DOM typings |

### Notes
- **Self-hosted Inter** via `next/font/google` — no external font CDN at runtime.
- **Auto-generated OG card** via `app/opengraph-image.tsx`.
- **Full SEO** — JSON-LD (Organization + WebSite + SoftwareApplication + FAQPage), OG/Twitter, `robots.ts`, `sitemap.ts`, `manifest.json`.
- **No JavaScript bundler config** — Next.js' App Router builds everything; output is static HTML/CSS/JS.

---

## Testing & codegen

### Codegen pipeline
- `freezed` (3.x) generates `*.freezed.dart` — immutable data classes with `copyWith`, equality, `toString`.
- `json_serializable` (6.13+) generates `*.g.dart` — `toJson` + `fromJson` (and codecs for unions / enums).
- Orchestrated by `build_runner`:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- Runs on every entity edit. Generated files **are committed** to the repo so consumers and CI don't need to rebuild on clone.
- Annotation packages (`freezed_annotation`, `json_annotation`) are runtime deps; the generators (`freezed`, `json_serializable`, `build_runner`) are dev-only.

### Test stack
| Package | Used in | Purpose |
|---------|---------|---------|
| `flutter_test` | All Flutter packages | Built-in widget testing |
| `mocktail` | core + desktop + mobile | Mock generation without source-code annotation |
| `bloc_test` | desktop + mobile | `blocTest()` for cubit emit-order verification |
| `golden_toolkit` 0.15 | desktop | Pixel-snapshot regression. Wraps `flutter_test`'s `matchesGoldenFile` with viewport + theme defaults. Goldens are tag-gated (`@Tags(['golden'])` per file); run with `flutter test --tags=golden test/goldens/`, regenerate with `--update-goldens`, exclude in CI with `--exclude-tags=golden`. Screens that build their cubits via `GetIt.I<>()` inside `MultiBlocProvider.create` need the GetIt-mock recipe in [`apps/desktop/test/goldens/_README.md`](../../apps/desktop/test/goldens/_README.md). |
| `pytest` + `pytest-asyncio` | server | 814 passing tests as of 2026-05-12; async-mode auto |
| `httpx.AsyncClient` | server | Endpoint integration tests against in-process FastAPI |

### Lint + format
- **Python** — `black` 24.4 (formatter, 88-col) + `ruff` 0.15 (linter, py311 target, rules `E/F/I/N/W/UP`).
- **Dart/Flutter** — `flutter_lints` 4 (core, mobile) / 6 (desktop). `flutter analyze` runs in CI.
  - **Use `flutter analyze` via Bash, not the MCP `mcp__dart__analyze_files` tool** — that tool is bugged. (See `feedback_dart_analyze_tool.md` in agent memory.)
- **TypeScript** — `eslint` 9 + `eslint-config-next`.

---

## Build / CI / deploy

| Tool | Where | Purpose |
|------|-------|---------|
| GitHub Actions | `.github/workflows/` | CI for server (`server.yml`), desktop (`desktop.yml`), mobile (`mobile.yml`) — `flutter test --exclude-tags=golden`, `flutter analyze`, `pytest`, `ruff`, `black --check` |
| `mirror-public.yml` | `.github/workflows/` | Mirrors private → public repo, strips `## For AI Agents` + filters `AGENT_LOG.md` / `CLAUDE.md` lines |
| PyInstaller | local + CI | Server distribution as standalone executable |
| Cloudflare Pages | `fluxora.marshalx.dev` | Static export of `apps/web_landing/` |
| Cloudflare Tunnel (`cloudflared`) | `fluxora-api.marshalx.dev` | Public routing v1 — no inbound port forwarding required |
| `.devcontainer/Dockerfile` | repo root | Dev container with Python 3.11, Flutter 3.41, Dart 3.9 floor |

---

## External Services

| Service | Usage | Tier |
|---------|-------|------|
| TMDB API | Movie/TV metadata, posters, descriptions | Free |
| STUN | WebRTC NAT traversal — Google public `stun.l.google.com:19302` | Free |
| TURN | WebRTC relay fallback when P2P blocked | Paid / self-hosted (Phase 6 evaluation pending) |
| Polar | Payment webhook events for license issuance + customer portal redirect | Paid provider / sandbox available |
| Cloudflare Tunnel | Public routing transport (v1 single-tenant) | Free |
| Cloudflare Pages | Web landing hosting | Free |
| Sentry | Error aggregation (server) | Free tier today |

---

## Networking

### LAN Path (Zeroconf/mDNS)
- Server broadcasts mDNS service on local network
- Client auto-discovers server IP — zero configuration required
- High-speed, low-latency direct HTTP connection
- Mobile: requires `MulticastLock` (Android) and stays on local-only HTTP (HLS playback never crosses the tunnel — enforced server-side by `HLSBlockOverTunnelMiddleware`)

### Internet Path (WebRTC)
- STUN: resolves public IP/port via Google STUN
- TURN: relay fallback when direct P2P is blocked (Phase 6 server selection pending)
- Signaling: lightweight aiortc-backed service to exchange WebRTC offer/answer

### Public Routing v1
- Cloudflare Tunnel `fluxora-home` → `fluxora-api.marshalx.dev`
- Server-side `RealIPMiddleware` resolves real client IP from CF headers (no IP spoofing)
- `HLSBlockOverTunnelMiddleware` returns 403 on tunneled requests to `/stream/*` — keeps streaming on LAN/WebRTC only
- Admin endpoints (`/auth/revoke/*`, `/info/restart`, `/info/stop`) reject tunneled requests outright (`require_local_caller`)
- Phase 6 hardening tracked in [`10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md): Cloudflare Access on `/orders`, WAF rules, tunnel-health alerts, TURN evaluation

---

## Technology Risks

| Technology | Risk | Mitigation |
|-----------|------|------------|
| WebRTC | Complex NAT traversal, mobile battery drain | TURN fallback; lifecycle disposal in `flutter_webrtc` |
| FFmpeg transcoding | CPU-intensive on weak hardware | Hardware encoders (NVENC / QSV / VAAPI); session queue |
| SQLite | Not multi-writer | WAL mode; singleton `user_settings` enforced via `CHECK id=1` |
| mDNS on mobile | iOS/Android multicast restrictions | Manual IP fallback in `connect` flow |
| Cloudflare Tunnel | Single point of failure for remote access | Phase 6 — tunnel-health alerts; LAN remains fully functional during outage |
| `golden_toolkit` | Platform-sensitive baselines (subpixel rendering) | CI runs with `--exclude-tags=golden`; goldens are opt-in locally |
| External README image services (`go-skill-icons`, `capsule-render`, `shields.io`) | SaaS rot | All used purely decorative; tech-stack table immediately under is the authoritative fallback |
