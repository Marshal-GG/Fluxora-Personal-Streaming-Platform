# Frontend Architecture

> **Category:** Frontend  
> **Status:** Active - Updated 2026-05-04 (**Phase 6 follow-ups:** Mobile HDR UI — `StreamStartResponse` Dart class gains `hdrFormat: String?` + `tonemapped: bool` fields. `PlayerRepository.startStream(fileId, {bool tonemap = false})`. `PlayerReady` state gains `hdrFormat`, `tonemapped`, and an `isHdrSource` convenience getter. New `PlayerCubit.setTonemap(bool enabled)` method: restarts the stream with the new flag while preserving the current playback position as the new `resumeSec`; uses `_lastFileId` / `_lastFileName` / `_lastPosterUrl` fields cached in `startStream`. `FluxPlayerControls` gains `hdrFormat`, `tonemapped`, `onTonemapChanged` constructor params. New `_HdrChip` widget: renders a violet pill (`HDR10` / `HLG` / `DV`) when the source is HDR and a neutral `SDR` pill when tonemapping is active; `null` `hdrFormat` hides the chip. Previously-dead 3-dot icon now opens `_showOverflowMenu()` — a modal bottom sheet with a "Tone-map HDR to SDR" `Switch` tile (hidden when source is SDR). `ApiClient.post()` gained a `queryParameters: Map<String, dynamic>?` parameter so callers can pass query params without hand-building the URL. **GPU UX Slice C:** Settings → Streaming gained an "Encoder priority chain (advanced)" `_SettingBlock` rendering the `EncoderPriorityList` drag-and-drop widget — operator reorders encoders, "+ Add encoder" popup filters out already-chained entries, "Primary" pill on entry 0; widget is controlled (parent owns the chain list). `SettingsCubit.saveSettings` extended with `transcodingChain: List<String>?` parameter — only PATCHed when the local list differs from the loaded snapshot via a `_listEquals` helper. `SettingsLoaded.transcodingChain` is loaded from the server response and sanitised through `_kEncoders` to drop unknown IDs. New `FallbackHistoryCubit` polls `/transcoding/fallback-history` every 5 s and renders the `FallbackHistoryPanel` below the active sessions card on the Transcoding screen — collapses to nothing when the ring buffer is empty; otherwise renders one row per recent event with a `requested → actual` arrow + reason chip (OK / Cap hit / All saturated / Unknown encoder), capped at 5 most recent. Active-sessions table row gained a per-session encoder pill — purple `h264_nvenc` etc. when transcoding, info `stream-copy` when remuxing — reading from the new `ActiveTranscodeSession.encoderUsed` field. New `FallbackEvent` + `FallbackHistory` freezed entities; new `Endpoints.transcodingFallbackHistory`; `TranscodingRepository.fallbackHistory()`. Desktop suite 71 → 84. **GPU UX Slice B:** Settings → Streaming gained a `DetectedHardwareCard` widget reading from a one-shot `HardwareCubit` against `/transcoding/devices`. **GPU UX Slice A:** Settings → Streaming tab gained `ActiveEncoderStrip`, `EncoderRecommendationBanner`, `EncoderStatusPanel` widgets reading from `TranscodingCubit`; `SettingsScreen` now wraps in `MultiBlocProvider` with both `SettingsCubit` and `TranscodingCubit`; `TranscodingCubit._tick()` fetches `/status` + `/advisor` per 2 s poll. `ActivityCubit` now polls `/stream/sessions` every 2 s (was one-shot) via `start()`/`stop()` methods + `Timer.periodic` — active-sessions list and per-session progress on the Transcoding screen refresh live. `ApiException.fromDioException` rewritten to parse FastAPI's `detail` field (string or Pydantic list of `{loc, msg, type, ctx}`) and render Pydantic-list entries as `<field>: <msg>` joined by `; `. `SettingsCubit.saveSettings` now distinguishes 4xx errors (server rejected payload — "Server URL saved, but the server rejected one of the other settings: $detail") from 5xx/connection failures. Settings → General `_save` only includes `license_key` in the PATCH body when the field has been edited from `_loadedSnapshot.licenseKey`. Encoder Settings screen passes `licenseKey: null` since it never edits the license. Earlier 2026-05-04: Player polish round: Picture-in-Picture on Android via a `dev.marshalx.fluxora/pip` Kotlin method channel + new `PipService` Dart wrapper + top-bar PIP button on `flux_player_controls.dart`; lockscreen / notification / Bluetooth-headset transport controls via `audio_service ^0.18.18` + new `FluxoraAudioHandler` sidecar that bridges `media_kit.Player` to the OS MediaSession; foreground-service declared in `AndroidManifest.xml` + `ic_stat_fluxora` notification icon; first-time "Keep playing in background?" prompt in `player_screen.dart` on app-resume after auto-pause, persisted via two new `SecureStorage` keys (`bg_playback_enabled`, `bg_playback_prompt_shown`); new `_BackgroundPlaybackToggleRow` inline switch on Profile screen replaces the stub Playback row. Earlier 2026-05-04: QR-pairing scanner (`mobile_scanner ^7.1.2` + `PairingUri` parser + `ScanQrScreen`) on `/scan-qr`; Phase A + B real-data backfill (3 new cubits + 4 new endpoints wired); Downloads tab hidden in v1; mDNS reusePort fix on Android. 2026-05-03: mobile redesign M0–M9 landed; mobile theme is now V2-pure — V1 palette + V1 typography deleted from `fluxora_core` at M9 cutover.)

---

## Framework & Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart 3+) |
| Architecture | Clean Architecture (Domain / Data / Presentation) |
| State Management | BLoC (`flutter_bloc`) — Cubit for simple state, Bloc for event-driven |
| HTTP Client | `ApiClient` (Dio) from `fluxora_core` |
| Video Playback | `media_kit` — Phase 2 (player screen not yet built) |
| LAN Discovery | `multicast_dns` (Dart) — PTR→SRV→A resolution |
| WebRTC | `flutter_webrtc ^1.4.1` — Phase 3 ✅ (`WebRtcSignalingService`, LAN skip, transport badge, ICE degradation → HLS fallback) |
| Storage (secrets) | `flutter_secure_storage` (tokens, server URL, client ID) |
| Routing | `go_router` v13 with async auth redirect guard |
| DI | `get_it` — lazy singletons for repos, factories for BLoCs |

---

## Desktop Library Surface (✅ Done 2026-05-03)

The Library screen is now functionally complete after the P0 + P1 sweep tracked in [`docs/10_planning/07_library_screen_plan.md`](../10_planning/07_library_screen_plan.md). What's wired:

- **CRUD end-to-end**: Create · Edit (name + root_paths only — type is immutable per ADR-016) · Delete (DB row + file index only — files on disk are NEVER touched per ADR-017) · Scan with file-count snackbar.
- **Real per-library statistics**: detail panel + stat tiles consume `Library.fileCount` and `Library.totalSizeBytes` returned on every server response.
- **Client-side poster mosaic** (D1 = Option A): cubit picks up to 4 enriched poster URLs per library from `state.files` and the card renders a 2×2 mosaic with gradient overlay; gradient + icon fallback for libraries with no enriched files.
- **Files browser**: new `library_files_screen.dart` (637 lines) at `/library/:id/files` — header + 4 stat chips (file count · size · last scanned · type) + scoped file table; reuses the loaded `MediaFile` list filtered by `libraryId`.
- **Sort / Filter / View toggle** (D5): sort by Name (A–Z) · Last Scanned · File Count · Total Size; filters: enriched-only · with-files · recently-scanned (last 7 days); grid/list segmented toggle persists across tab changes.

Files (`apps/desktop/lib/features/library/`):
- `presentation/screens/library_screen.dart` (~2360 lines after the P0+P1 land)
- `presentation/screens/library_files_screen.dart` (NEW)
- `presentation/cubit/library_cubit.dart` — adds `updateLibrary()`, `deleteLibrary()` (optimistic state drop), `scanLibrary()` returning the added count
- `data/repositories/library_repository_impl.dart` — `PATCH /library/{id}` + `DELETE /library/{id}`
- `domain/repositories/library_repository.dart` — interface widened

Routing: `/library/:id/files` registered in `app_router.dart` plus a Cmd+K command "Open library files: <name>" per library.

---

## Two Client Targets

| Target | Purpose | Status |
|--------|---------|--------|
| **Flutter Mobile** (Android/iOS) | End-user streaming client | ✅ Phases 1–4 complete |
| **Flutter Desktop** (Windows/macOS/Linux) | PC control panel / server management | ✅ Phases 1–5 (Dashboard + Clients + Library + Orders + Activity + Logs + Transcoding + Settings) |

---

## Design System

[`DESIGN.md`](../../DESIGN.md) is the canonical, single-source-of-truth spec. The V2 violet system below powers desktop, web landing, and (post-migration per [`mobile_redesign_plan.md`](../11_design/mobile_redesign_plan.md)) the mobile Flutter app.

- **Color palette:** `#08061A` root, `#A855F7` violet primary, glassmorphic surfaces (`rgba(20,18,38,0.7)`), 7-color pill semantics, status-dot semantics.
- **Typography:** `Inter` 400/500/600/700/800 + `JetBrains Mono` 400/500/600.
- **Theming (desktop):** [`apps/desktop/lib/shared/theme/app_theme.dart`](../../apps/desktop/lib/shared/theme/app_theme.dart) wires V2 tokens through Material 3 `ThemeData` (`scaffoldBackgroundColor: bgRoot`, `colorScheme.primary: violet`, etc.) so Material defaults can't leak slate-blue. Every redesign primitive **also** owns its own `BoxDecoration` / `TextStyle` so it stays pixel-locked even outside the theme.
- **Theming (mobile):** V2-pure as of M9 cutover (2026-05-03). [`apps/mobile/lib/shared/theme/app_theme.dart`](../../apps/mobile/lib/shared/theme/app_theme.dart) wires V2 tokens through Material 3 `ThemeData` (`scaffoldBackgroundColor: bgRoot`, `colorScheme.primary: violet`, V2 typography in `textTheme`, V2 button + card themes, new `dividerTheme`); `AppTheme.dark` getter signature unchanged. `InputDecorationTheme.fillColor` uses `AppColors.bgRaised` — opaque so the M0 background gradient does not bleed through Material `TextField` chrome. Mobile literal `Color(0xFF0F0C24)` sites (mobile theme + `FluxBottomSheet` + a couple of mobile screens) still inline the raw hex pending the mobile agent's migration to the token; desktop is fully tokenised.
- **Surface-token policy (added 2026-05-04, refined later same day):** floating chrome must commit to *real glass* (`surfaceGlass` rgba + `BackdropFilter(blur: 20)`) or *opaque* (`bgRaised` `#0F0C24`). Translucent fill **without** blur is a layout bug. Two new shared widgets implement the real-glass path:
  - **[`FluxGlassDialog`](../../apps/desktop/lib/shared/widgets/flux_glass_dialog.dart)** — drop-in replacement for `AlertDialog`. Wraps title/content/actions in `Dialog(transparent) → ClipRRect → BackdropFilter(blur 20) → Container(surfaceGlass + border)`. Used by all 3 library-screen dialogs (Delete confirm, Add/Edit form, Filters) and the startup [`UpgradeDialog`](../../apps/desktop/lib/features/subscription/presentation/widgets/upgrade_dialog.dart).
  - **[`FluxGlassMenu`](../../apps/desktop/lib/shared/widgets/flux_glass_menu.dart)** — drop-in replacement for `PopupMenuButton`. Uses a custom `PopupRoute` that renders all menu items inside a single `BackdropFilter` so the blur covers the whole popup (a single `BackdropFilter` cannot span a stock `PopupMenuButton`'s items because each item is its own Material descendant). Used by the Library screen's Sort menu and per-card 3-dot menu. Items declared as `FluxGlassMenuItem<T>` records (value, label, icon, destructive, selected).
  
  Opaque `bgRaised` stays the default for theme-level surfaces where blur isn't worth the per-instance GPU cost (Material `Card` theme default, `AppBar` theme default, `SnackBar` theme default, `InputDecoration.fillColor`); widgets that opt into glass override per-instance. The 13-site `surfaceGlass` desktop sweep landed earlier this day under the same policy; library-screen popups + dialogs now sit on top of that as real glass.

  Inside [`flux_sidebar.dart`](../../apps/desktop/lib/shared/widgets/flux_sidebar.dart) the **System Status block** is wrapped in a `Container` with a translucent black fill (`Color(0x33000000)`) + `borderSubtle` + `AppRadii.md` so it reads as a recessed panel against the `sidebarGlass` rail rather than blending into the nav list above it. Same panel pattern is reused by the Upgrade callout — both should remain visually differentiated from the rail.

  [`FluxShell`](../../apps/desktop/lib/shared/widgets/flux_shell.dart) provides a shell-scoped `SettingsCubit` and wraps its body in a `BlocListener<SettingsCubit, SettingsState>` that fires the [`UpgradeDialog`](../../apps/desktop/lib/features/subscription/presentation/widgets/upgrade_dialog.dart) once per app launch on the first `SettingsLoaded` state, only when `tier != 'ultimate'`. The sidebar's `_UpgradeCard` reads the same cubit via `context.watch` and self-hides when the tier is `ultimate`. Settings / Subscription / Encoder screens still build their own `SettingsCubit` instances for save flows; the shell instance is read-only chrome. The dialog stays dismissable via outside-tap, Esc, "Maybe Later", or "View Plans" → `/subscription`.

- **Desktop notifications surface (audited 2026-05-04):** real end-to-end wiring — list / markRead / markAllRead / dismiss + 5 s REST polling stream (matching `SystemStatsCubit`'s v1 polling rationale; `WS /api/v1/ws/notifications` exists server-side and is post-v1 work). The titlebar bell renders its violet dot via `BlocSelector<NotificationsCubit, NotificationsState, int>` reading `unreadCount` — the dot only appears when `count > 0`. The slide-over panel mounts inside `FluxShell`'s Stack toggled by `NotificationsPanelNotifier`; `_PanelBody` is stateful with a 220 ms `easeOutCubic` `SlideTransition` from `Offset(1, 0)` → `Offset.zero` so it slides in once on mount (rebuilds during filter taps don't restart the animation). Row tap calls `NotificationsPanelScope.of(context).close()` before `context.go(route)` so the overlay doesn't linger over the destination screen. Mutation methods on `NotificationsCubit` rethrow on transport failure; the panel's header / footer "Mark all as read" and per-row dismiss callbacks catch and surface a SnackBar. `NotificationsCubit.markRead` short-circuits with no API call when the target's `readAt != null` (avoids server 404s on stale taps). `NotificationsRepositoryImpl.liveStream`'s `seen` set is capped at 500 entries (FIFO eviction) so long sessions don't accumulate IDs. Repository also exposes the correct `?unread=true` query-param name (server expects `unread`, not `unread_only`).
- **Tokens:** `packages/fluxora_core/lib/constants/app_colors.dart` (V2-only — V1 indigo/slate palette deleted at M9 cutover), `app_typography.dart` (V2-only — `displayLg`/`headingLg`/`bodyMd`/`caption`/`label`/`mono` etc. deleted at M9), `app_gradients.dart`, `app_spacing.dart`, `app_radii.dart`, `app_shadows.dart`. Both apps now share a single token set with no transitional comments.
- **Surface plans:** [`desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md), [`mobile_redesign_plan.md`](../11_design/mobile_redesign_plan.md), [`web_landing_redesign_plan.md`](../11_design/web_landing_redesign_plan.md).

---

## Desktop Redesign — M1 Foundation (✅ Done 2026-05-02) · M2 Shell (✅ Done) · M3 Dashboard (✅ Done 2026-05-02)

The redesigned Fluxora Desktop app is being built screen-by-screen following [`desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md). M1 (foundation) ships the design tokens, primitives, and brand visuals — every later milestone builds on these.

### Token files — `packages/fluxora_core/lib/constants/`

| File | Owns |
|------|------|
| `app_colors.dart` | v2 palette: `bgRoot`, **`bgRaised`** (opaque raised — popups, dialogs, AppBar, SnackBar; added 2026-05-04), `surfaceGlass` (translucent — on-page cards only), `sidebarGlass`, `titlebarGlass`, `borderSubtle`, `borderHover`, `textBright`/`textBody`/`textMutedV2`/`textDim`/`textFaint`, `violet`/`violetDeep`/`violetTint`/`violetSoft`, semantic colours, 7 pill bg/fg pairs, 8 status-dot colours |
| `app_gradients.dart` *(new)* | `brand` (135°), `progress` (90°), `upgradeCallout`, `bgRadialViolet`, `bgRadialCyan` |
| `app_spacing.dart` *(new)* | Locked spacing scale `s2 … s32` — anything outside the set is a typo |
| `app_radii.dart` *(new)* | `xs=6, sm=8, md=10, lg=12, pill=9999` |
| `app_shadows.dart` *(new)* | `cardGlow`, `buttonGlow`, `dotGlow(color)` |
| `app_typography.dart` | v2 styles `displayV2`, `h1`, `h2`, `body`, `bodySmall`, `captionV2`, `micro`, `eyebrow`, plus `monoBody`/`monoCaption`/`monoMicro` |

### Brand assets — `packages/fluxora_core/assets/`

| Path | Purpose |
|------|---------|
| `brand/logo-icon.png` | Standalone F lettermark — owner's original from `docs/11_design/ref images/brand/logo_icon_dark.png`, auto-processed (Pillow alpha-from-brightness) to remove the dark backdrop, gradient anti-aliasing preserved. Available for any slot that needs just the icon (favicon source, app icon, brand-card slot) |
| `brand/logo-wordmark.png` | Legacy stacked wordmark (F on top of FLUXORA text). Kept for brand-card slots that want the stacked layout; **not** used in primary nav surfaces |
| `brand/logo-wordmark-h.png` | **Primary brand asset** — integrated horizontal wordmark (F + FLUXORA in one image, refined 3D-style F). Sourced from `docs/11_design/ref images/brand/logo_wordmark_horizontal_v2_dark.png`, same Pillow processing. Used by `FluxoraWordmark` widget (Flutter), web Navbar / Footer (Next.js). Replaces the icon + separate-text composition in those surfaces — combining both would double the F |
| `illustrations/hero_waves.svg` | Decorative animated wave-line backdrop (5 paths, dash-offset + gradient-translate animations) |
| `illustrations/pulse_ring.svg` | Concentric expanding rings for live-status indicators (offset half-cycle) |
| `illustrations/empty_libraries.svg` | "No libraries yet" empty-state illustration |
| `illustrations/empty_clients.svg` | "No clients connected" empty-state illustration with animated signal arcs |

### Primitives — `apps/desktop/lib/shared/widgets/`

Pixel-matched to `docs/11_design/desktop_prototype/app/components/primitives.jsx`. Every primitive replaces a Material default; no `ElevatedButton`, `Switch`, `Card`, `LinearProgressIndicator`, etc.

| File | Widget | Notes |
|------|--------|-------|
| `flux_card.dart` | `FluxCard({padding, hoverable, glow, onTap})` | `MouseRegion` hover → `borderHover` + violet tint; optional `cardGlow` |
| `section_label.dart` | `SectionLabel(text)` | 11 / 600 / 0.14em uppercase |
| `status_dot.dart` | `StatusDot({status, size})` + `DotStatus` enum | 8-status palette; halo on online/active/streaming |
| `pill.dart` | `Pill(text, {color, icon})` + `PillColor` enum | 7 variants, optional leading icon |
| `flux_progress.dart` | `FluxProgress({value, height, color, trackColor})` | 400 ms `TweenAnimationBuilder` width animation; gradient fill |
| `flux_button.dart` | `FluxButton({variant, size, icon, iconRight, onPressed, fullWidth, child})` | 6 variants × 3 sizes; no Material ripple; hover via `MouseRegion` + `setState` |
| `stat_tile.dart` | `StatTile({icon, label, value, sub, color, iconBg, accent})` | Wraps `FluxCard`; 44 × 44 icon badge + label/value/sub stack |
| `sparkline.dart` | `Sparkline({data, color, height, strokeWidth})` | `CustomPainter` with single open path |
| `storage_donut.dart` | `StorageDonut({segments, centerText, unitText, size, strokeWidth})` + `StorageDonutSegment` | `CustomPainter` `drawArc` per segment, -90° start |
| `page_header.dart` | `PageHeader({title, subtitle, actions})` | Standard screen header — owns vertical padding only |

### Brand visuals — `packages/fluxora_core/lib/widgets/`

`brand_visuals.dart` exports:
- `HeroWaves({fit, alignment, opacity})` — renders `hero_waves.svg`
- `BrandLoader({size})` — composites the **untouched** `FluxoraMark` PNG inside a Flutter-painted rotating sweep-gradient ring + 6 % scale-pulse on the mark. The brand mark itself is never re-drawn; only the surrounding ring is Flutter-driven.
- `PulseRing({size, color})` — renders `pulse_ring.svg` with `colorFilter: srcIn` so the rings inherit the caller's chosen colour
- `EmptyState({illustration, title, message, illustrationHeight})` + `EmptyStateIllustration.libraries / .clients`

`fluxora_logo.dart` exports:
- `FluxoraMark({size, glow})` — standalone F lettermark, square. Use only when a non-F-bearing wordmark won't fit (favicon, app icon, tight brand-card slot).
- `FluxoraWordmark({height})` — **integrated horizontal wordmark** (F + FLUXORA in one image, `logo-wordmark-h.png`). Default height 28 px. The primary brand element for any nav / sidebar / hero use.
- `FluxoraLogo({size, withWordmark, withTagline})` — composite. With `withWordmark: true` (default), renders only the integrated wordmark + optional tagline below. With `withWordmark: false`, falls back to standalone `FluxoraMark` only. Never renders both side-by-side (would double the F).

### Showcase route

[`apps/desktop/lib/shared/showcase/primitives_showcase_screen.dart`](../../apps/desktop/lib/shared/showcase/primitives_showcase_screen.dart) renders every redesign primitive in every variant on the `bgRoot` background. Routed at `/showcase` outside the `ShellRoute` so it sits on a clean canvas for visual diff against the prototype. Kept post-M9 as an ongoing reference surface — useful when mobile starts referencing the same primitives.

---

## Screen / Route Map — Flutter Mobile (Implemented post-M9)

The redesign reorganised mobile around a 5-tab shell (`StatefulShellRoute.indexedStack`) plus auth-gate + deep-link routes that bypass the shell. Tab branches preserve state across switches; tapping the active tab pops to its branch root.

| Route | Screen | State class | Branch / Outside-shell | Status |
|-------|--------|-------------|------------------------|--------|
| `/connect` | ConnectScreen | `ConnectCubit` | Outside shell — auth gate | ✅ Done |
| `/pairing` | PairingScreen | `PairCubit` | Outside shell — auth gate | ✅ Done |
| `/home` | HomeScreen | — (mock data) | Tab 1 | ✅ Done (M3) |
| `/library` | LibraryScreen | — (mock data + legacy `LibraryBloc` for the existing files deep-link) | Tab 2 | ✅ Done (M3 — V2 redesign) |
| `/search` | SearchScreen | — (mock data) | Tab 3 | ✅ Done (M3) |
| `/downloads` | DownloadsScreen | — (mock data via `MockData.downloads`) | Tab 4 | ✅ Done (M8) |
| `/profile` | ProfileScreen | — (hardcoded mock) | Tab 5 | ✅ Done (M8) |
| `/detail/:id` | DetailScreen | — (mock via `MockData.findById`) | Outside shell — full-screen deep link | ✅ Done (M4) |
| `/episodes/:id` | EpisodesScreen | — (mock) | Outside shell | ✅ Done (M4) |
| `/library-files/:id` | FilesScreen | `FilesCubit` | Outside shell — legacy deep link | ✅ Done |
| `/player` | PlayerScreen({file}) | `PlayerCubit` (singleton) | Outside shell | ✅ Done |
| `/player/resume` | PlayerScreen.resume() | `PlayerCubit` (singleton) | Outside shell — mini-player handoff | ✅ Done (M7) |
| `/notifications` | NotificationsScreen | `NotificationsCubit` (singleton) | Outside shell — pushed from Home bell icon | ✅ Done (M3 stub → M8 real-data) |
| `/upgrade` (push) | UpgradeScreen | — (stateless) | Outside shell | ✅ Done |

Auth guard: `go_router` `redirect` callback reads `SecureStorage` — unauthenticated users are redirected to `/connect`; authenticated users skip `/connect` and `/pairing` and land on `/home`.

Sign-out (Profile tab → red-tinted button → confirm dialog → accept) calls `playerCubit.dismiss()` → `apiClient.clearBearerToken()` → `secureStorage.deleteAll()` → `context.go(Routes.connect)`; the redirect guard handles the rest on the next navigation tick.

---

## Flutter Mobile Project Structure (Implemented post-M9)

```
apps/mobile/lib/
├── main.dart                    # setupInjector() → runApp()
├── app.dart                     # MaterialApp.router — AppTheme.dark + appRouter; BackgroundGradient mounted via builder
│
├── core/
│   ├── di/
│   │   └── injector.dart        # get_it: ApiClient, SecureStorage, all repos, PlayerCubit + NotificationsCubit lazy singletons (M7 + M8)
│   └── router/
│       └── app_router.dart      # GoRouter — StatefulShellRoute.indexedStack with 5 tab branches + outside-shell deep links
│
├── shared/
│   ├── theme/
│   │   └── app_theme.dart       # V2-pure post-M9 cutover; opaque Color(0xFF0F0C24) for InputDecorationTheme.fillColor
│   ├── data/
│   │   └── mock_data.dart       # MockMediaItem / MockCastMember / MockSeason / MockEpisode / MockDownload + fixture lists; MockData.findById(id); storage constants
│   └── widgets/
│       ├── background_gradient.dart  # M0 two-radial brand gradient over bgRoot — wired via MaterialApp.router builder
│       ├── mobile_shell.dart         # M2 Scaffold(body: navigationShell, bottomNavigationBar: Column(MiniPlayer + FluxBottomTabs))
│       ├── flux_mini_player.dart     # M7 64-px persistent bar — visible only on PlayerReady; tap → /player/resume; X → cubit.dismiss
│       ├── media_card.dart           # legacy (used by /library-files/:id); V2 token migration landed at M9
│       ├── status_badge.dart         # legacy; V2 token migration landed at M9
│       └── loading_overlay.dart      # legacy; V2 token migration landed at M9
│
└── features/
    ├── connect/      # mDNS + manual IP — V2 styling post-M9
    ├── auth/         # pairing flow — V2 styling post-M9
    ├── upgrade/      # tier comparison + activation guide — V2 + AppGradients.brand header
    │
    ├── home/         # M3 Discover — 3 rails (continue-watching / trending / recently-added), bell → /notifications
    ├── search/       # M3 — empty/active/no-results states, top-3 rail + sectioned results
    ├── library/      # M3 redesign — 6 filter chips + grid/list toggle + sort menu; legacy LibraryBloc + /library-files/:id retained
    ├── notifications/    # M3 stub → M8 real-data (NotificationsRepository + Cubit polling /api/v1/notifications every 5 s)
    │   ├── domain/repositories/notifications_repository.dart      # list/markRead/markAllRead/dismiss/liveStream
    │   ├── data/repositories/notifications_repository_impl.dart   # // TODO(WS): migrate to /ws/notifications when shared HMAC-bearer wrapper exists
    │   └── presentation/
    │       ├── cubit/{notifications_cubit.dart,notifications_state.dart}    # singleton-scoped, sealed class state, identity equality
    │       └── screens/notifications_screen.dart                            # Today/This week/Earlier buckets, category→icon+color, tap-to-markRead
    │
    ├── detail/       # M4 — hero + Play/Resume + Episodes + 4-up actions + collapsible synopsis + cast/crew/similar rails
    ├── episodes/     # M4 — season chip selector + episode rows
    ├── downloads/    # M8 — header storage indicator + Downloading cards + Available offline rows + FluxBottomSheet actions
    ├── profile/      # M8 — gradient avatar + PLUS pill + 3-stat row + 9 FluxRow sections + red Sign out → confirm → cubit.dismiss + storage.deleteAll + go(/connect)
    │
    └── player/
        ├── domain/entities/stream_start_response.dart
        ├── domain/repositories/player_repository.dart
        ├── data/repositories/player_repository_impl.dart
        ├── data/services/
        │   ├── webrtc_signaling_service.dart
        │   ├── pip_service.dart                          # Player polish — Android PIP method-channel wrapper (isSupported / enter)
        │   └── fluxora_audio_handler.dart                # Player polish — BaseAudioHandler sidecar; bind/detach on a media_kit.Player
        └── presentation/
            ├── controllers/player_controls_controller.dart     # M5 ChangeNotifier — visibility / lockMode / fitCover / 3 s auto-hide / drag-HUD scratchpad
            ├── cubit/{player_cubit.dart,player_state.dart}     # M7 singleton + restart-safe startStream + _disposeCurrentSession + dismiss(); Player polish: optional FluxoraAudioHandler param + WidgetsBindingObserver auto-pause on background when bg_playback_enabled=false; Phase 6: setTonemap(bool) restarts stream with tonemap flag while preserving position; _lastFileId/_lastFileName/_lastPosterUrl cached; PlayerReady gains hdrFormat/tonemapped/isHdrSource
            ├── widgets/flux_player_controls.dart                # M5 + M6 — top bar / center transport / progress bar / 8-up quick-actions / side rails / lock chip + double-tap ripple / long-press 2× peek / vertical drag brightness+volume / pinch fit / hold-to-unlock progress ring; Player polish — top-bar PIP icon button gated on PipService.isSupported(); Phase 6: hdrFormat/tonemapped/onTonemapChanged props; _HdrChip pill; _showOverflowMenu 3-dot bottom sheet with HDR tonemap Switch tile
            ├── sheets/{audio_subs_sheet,speed_sheet,sleep_sheet,quality_sheet,cast_sheet}.dart   # M6 — 5 bottom sheets via showFluxBottomSheet
            └── screens/player_screen.dart                       # M7 dual constructors: PlayerScreen({file}) + PlayerScreen.resume(); _MinimizeHandle drag-down → context.pop() ≥ 150 px; Player polish — WidgetsBindingObserver fires _maybeShowBackgroundPlaybackPrompt on first resume after auto-pause + passes file.posterUrl into cubit.startStream so the lockscreen card has artwork
```

---

## State Management Pattern

```
UI Event ──▶ BLoC/Cubit ──▶ Repository (interface) ──▶ ApiClient (fluxora_core)
                │                                              │
                └──────────── State emitted ◀──────────────────┘
```

- Use **Cubit** when there are no multi-event chains (connect discovery, pairing, file list)
- Use **Bloc** when events drive different state transitions (library — started vs refreshed)
- Never mix BLoC and Riverpod within a feature

---

## DI Registration Pattern

```dart
// Singletons — created once
getIt.registerSingleton<FlutterSecureStorage>(...)
getIt.registerSingleton<SecureStorage>(...)
getIt.registerSingleton<ApiClient>(ApiClient())  // dual-base; URLs set after restore

// Lazy singletons — created on first use
getIt.registerLazySingleton<LibraryRepository>(() => LibraryRepositoryImpl(...))

// Factories — fresh instance per BlocProvider
// BLoCs are NOT registered in get_it; created inline via BlocProvider
```

On app restart: `setupInjector()` reads `SecureStorage` (both `serverUrl` and `remoteUrl`) and calls `ApiClient.configure(localBaseUrl: …, remoteBaseUrl: …, bearerToken: …)` to restore credentials and routing before any repository is used.

---

## Routing Rules

- All routes defined in `app_router.dart` — never `Navigator.push()` directly
- Route paths: lowercase kebab-case (`/library/:id/files`)
- Route names: `const` string constants in `Routes` class
- Navigate with `context.go()` (replace stack) or `context.push()` (add to stack)
- Extra objects passed via `state.extra` (e.g. `DiscoveredServer`, library name string)

---

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| mDNS package | `multicast_dns` | Dart-native, no external process; PTR→SRV→A chain resolves full address |
| Android MulticastLock | `MethodChannel('dev.marshalx.fluxora/multicast')` | Android silently drops multicast without `WifiManager.MulticastLock`; acquired in `ConnectCubit.startDiscovery()`, released on close; non-fatal if unavailable (iOS/desktop) |
| ApiClient configure | Called in `ConnectScreen` on server select | Server URL must be set on `ApiClient` before any pairing request; done at navigation time, not at app start |
| UUID generation | Custom via `dart:math` + `Random.secure()` | Avoids adding `uuid` package for one use |
| Video player | `media_kit v1.2.6` | `better_player` incompatible with AGP 8+ |
| WebRTC | `flutter_webrtc ^1.4.1` — Phase 3 ✅ | `WebRtcSignalingService` + `NetworkPathDetector`; LAN detection skips negotiation; 8 s ICE timeout with HLS fallback |
| Smart path | `NetworkPathDetector.isLan()` (in `fluxora_core`) | Pure in-process /24 subnet check; no DNS, no ICMP; fails-safe to WAN. Used by `ApiClient` for dual-base routing and by `PlayerCubit` for the WebRTC vs HLS decision |
| Dual-base ApiClient | `ApiClient(localBaseUrl, remoteBaseUrl, lanCheck)` in `fluxora_core` | Per-request resolution: LAN → localBaseUrl, WAN → remoteBaseUrl; throws `NoRemoteConfiguredException` if off-LAN with no remote configured. Phase 3 of public-routing plan |
| Transport badge | `_TransportBadge` chip | Auto-hides after 5 s; HLS (dark chip) vs WebRTC (deep-purple chip + `cell_tower` icon); re-appears on ICE degradation |
| ICE degradation | `_handleSignalingDegradation()` in `PlayerCubit` | `SignalingState.failed` post-connection → `copyWith(streamPath: hls)` emitted; signaling closed; player uninterrupted (HLS was always underlying transport) |
| Resume banner guard | `_readyOnce` in `_PlayerViewState` | Prevents resume banner from re-firing when `PlayerReady` is re-emitted for transport switch |
| Poll interval | Configurable `Duration` on `PairCubit` | Default 3s in production; 30ms in tests — avoids slow test suite |
| Upgrade screen | `UpgradeScreen` (push, not go_router route) | Mobile cannot call `PATCH /settings` (localhost-only); screen shows tier plans + instructs user to activate key in Desktop Control Panel |
| Tier limit view | `_TierLimitView` in `player_screen.dart` | Replaces generic error on 429; gradient icon + `FilledButton` → `UpgradeScreen`, `OutlinedButton` → Go Back |
| `ApiClient.post` query params | `queryParameters: Map<String, dynamic>?` optional param added to `ApiClient.post()` | Allows callers (e.g. `PlayerRepository.startStream`) to pass URL query params (e.g. `?tonemap=true`) without hand-building the URL string. Dio merges the map into the request URL before dispatch. |
| `validate_token_or_local` | Files and library endpoints accept bearer token OR localhost | Desktop control panel is always on localhost; avoids needing a client pairing flow for the admin UI. Mobile clients still send a bearer token. |
| Dart 3.8+ null-aware map syntax | `{'key': ?nullableValue}` in `SettingsCubit.saveSettings` | Only includes a key in the PATCH body if the value is non-null. Available since Dart 3.8; project floor is `>=3.9.0`. |
| `_SettingsSheet` in player | Speed controls (0.5–2.0×), audio track picker, subtitle track picker | Exposed via bottom sheet from a settings button in the player controls overlay |

---

## Testing Approach

- **Unit tests** for all BLoCs and Cubits using `bloc_test` + `mocktail`
- Sealed state types tested with `isA<>()` matchers (not concrete equality)
- Data assertions in `verify:` callbacks after state check
- `PairCubit` timer tests use `pollInterval: Duration(milliseconds: 30)` + `wait:`
- No real network calls in any test — all repositories are mocked

```
Mobile test/ (27 tests)
├── features/
│   ├── connect/connect_cubit_test.dart           # 5 tests
│   ├── auth/pair_cubit_test.dart                 # 5 tests
│   ├── auth/auth_repository_impl_test.dart       # 3 tests (post-pair /info fetch + remote_url persistence)
│   ├── library/library_bloc_test.dart            # 6 tests
│   └── player/player_cubit_test.dart             # 8 tests
└── placeholder_test.dart

Desktop test/ (84 tests)
└── features/
    ├── dashboard/dashboard_cubit_test.dart                    # 3 tests ✅
    ├── clients/clients_cubit_test.dart                        # 7 tests ✅
    ├── settings/settings_cubit_test.dart                      # 17 tests ✅ (loadSettings + saveSettings + license_key PATCH + Remote Access — `loadSettings` populates `remoteUrl` from `/info`; `checkRemoteAccess` early-return paths)
    ├── notifications/notifications_cubit_test.dart            # 13 tests ✅ (start/markRead/markAllRead/dismiss happy + rethrow paths; live-stream new + duplicate-id ignore)
    ├── transcoding/encoder_status_panel_test.dart             # 9 tests ✅ (Slice A — pill rendering per status, sort order, failed-tooltip, banner severity → icon, ActiveEncoderStrip CPU/GPU pill + engine label)
    ├── transcoding/detected_hardware_card_test.dart           # 8 tests ✅ (Slice B — loading / failure / empty states, CPU + GPU tile rendering with vendor pills, MB-vs-GB VRAM formatting, refresh button visibility)
    ├── transcoding/encoder_priority_list_test.dart            # 7 tests ✅ (Slice C — empty-state copy, index pills, Primary pill on entry 0, remove-fires-onChanged, Add menu filters chained-out entries, Add appends to chain, "all in chain" hint)
    └── transcoding/fallback_history_panel_test.dart           # 6 tests ✅ (Slice C — render-nothing while loading / on failure / empty, header + reason chips, requested → actual arrow, 5-event display cap)
    └── (library/orders/activity/logs cubits tested via manual integration)
```

---

## Flutter Desktop Project Structure (Phases 1–5 — implemented)

```
apps/desktop/lib/
├── main.dart                    # setupInjector() → runApp()
├── app.dart                     # MaterialApp.router — AppTheme.dark + appRouter
│
├── core/
│   ├── di/
│   │   └── injector.dart        # get_it: ApiClient (localhost:8000), all repositories, OrdersCubit factory, SettingsCubit factory
│   └── router/
│       └── app_router.dart      # GoRouter + Routes + ShellRoute wrapping AppShell (Dart 3.8 wildcard params)
│
├── shared/
│   ├── theme/
│   │   └── app_theme.dart       # AppTheme.dark — Material 3 ThemeData + NavigationRailTheme
│   └── widgets/
│       ├── sidebar.dart         # AppShell + _Sidebar + _NavItem (Dashboard/Library/Clients/Licenses/Activity/Settings)
│       ├── stat_card.dart       # Dashboard stat card with icon + value + label
│       └── status_badge.dart    # ClientStatus badge (Approved/Pending/Rejected)
│
└── features/
    ├── dashboard/               # ✅ Implemented + M3 redesign (pixel-matched prototype)
    │   ├── domain/repositories/dashboard_repository.dart  # + restartServer() / stopServer()
    │   ├── data/repositories/dashboard_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/dashboard_cubit.dart  # load() fetches serverInfo + clients
    │       ├── cubit/dashboard_state.dart
    │       └── screens/dashboard_screen.dart  # MultiBlocProvider: Dashboard+Storage+RecentActivity+SystemStats
    │
    ├── clients/                 # ✅ Implemented
    │   ├── domain/repositories/clients_repository.dart
    │   ├── data/repositories/clients_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/clients_cubit.dart
    │       ├── cubit/clients_state.dart
    │       └── screens/clients_screen.dart  # M4 redesign: PageHeader + 4 StatTiles + search/filter row + 7-column table + 300px detail panel (approve/reject/revoke wired)
    │
    ├── library/                 # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/library_repository.dart
    │   ├── data/repositories/library_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/library_cubit.dart
    │       ├── cubit/library_state.dart
    │       └── screens/library_screen.dart  # Create/scan/upload/filter libraries
    │
    ├── orders/                  # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/orders_repository.dart
    │   ├── data/repositories/orders_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/orders_cubit.dart
    │       └── screens/licenses_screen.dart  # Polar orders with copyable license keys + tier color chips
    │
    ├── activity/                # ✅ Implemented (Phase 5 — active sessions, legacy name, DO NOT rename)
    │   ├── domain/repositories/activity_repository.dart
    │   ├── data/repositories/activity_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/activity_cubit.dart   # freezed state; now polls every 2 s via start()/stop() + Timer.periodic — active-sessions list refreshes live
    │       └── screens/activity_screen.dart  # Active stream sessions monitor
    │
    ├── storage/                 # ✅ M3 — storage breakdown for Dashboard donut
    │   ├── domain/repositories/storage_repository.dart
    │   ├── data/repositories/storage_repository_impl.dart   # GET /api/v1/library/storage-breakdown
    │   └── presentation/cubit/
    │       ├── storage_cubit.dart      # load() → StorageLoaded(breakdown)
    │       └── storage_state.dart      # StorageInitial|Loading|Loaded|Failure
    │
    ├── recent_activity/         # ✅ M3 — activity event log for Dashboard card
    │   ├── domain/repositories/recent_activity_repository.dart
    │   ├── data/repositories/recent_activity_repository_impl.dart   # GET /api/v1/activity?limit=4
    │   └── presentation/cubit/
    │       ├── recent_activity_cubit.dart   # load()/refresh() → RecentActivityLoaded([events])
    │       └── recent_activity_state.dart   # RecentActivityInitial|Loading|Loaded|Failure
    │
    ├── logs/                    # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/logs_repository.dart
    │   ├── data/repositories/logs_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/logs_cubit.dart
    │       ├── cubit/logs_state.dart
    │       └── screens/logs_screen.dart  # Live server log viewer
    │
    ├── groups/                  # ✅ M5 redesign
    │   ├── domain/repositories/groups_repository.dart
    │   ├── data/repositories/groups_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/groups_cubit.dart       # load, createGroup, updateGroup, deleteGroup, addMember, removeMember
    │       ├── cubit/groups_state.dart
    │       └── screens/groups_screen.dart    # PageHeader + 4 StatTiles + table + 300px detail panel + dialogs
    │
    ├── transcoding/             # ✅ M5 redesign
    │   ├── domain/repositories/transcoding_repository.dart
    │   ├── data/repositories/transcoding_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/transcoding_cubit.dart  # polls /api/v1/transcoding/status every 2 s
    │       ├── cubit/transcoding_state.dart
    │       ├── screens/transcoding_screen.dart        # 4 StatTiles + Active Sessions card; joins ActivityCubit
    │       └── screens/encoder_settings_screen.dart   # /transcoding/encoder; hardware selector + preset chips + CRF slider
    │
    └── settings/                # ✅ Implemented (Phases 2 + 5)
        ├── domain/repositories/settings_repository.dart
        ├── data/repositories/settings_repository_impl.dart
        └── presentation/
            ├── cubit/settings_cubit.dart   # loadSettings(), saveSettings(); transcoding fields; Dart 3.8 null-aware map syntax
            ├── cubit/settings_state.dart   # SettingsLoaded includes transcodingEncoder/Preset/Crf
            └── screens/settings_screen.dart  # URL + server name + tier + license key + transcoding encoder/preset/CRF + "View Licenses" button
```

### Desktop routes

| Route | Screen | State class | Status |
|-------|--------|-------------|--------|
| `/` | DashboardScreen | `DashboardCubit` + `StorageCubit` + `RecentActivityCubit` + `SystemStatsCubit` | ✅ Done (M3 redesign) |
| `/clients` | ClientsScreen | `ClientsCubit` | ✅ Done (M4 redesign) |
| `/library` | LibraryScreen | `LibraryCubit` | ✅ Done |
| `/licenses` | LicensesScreen | `OrdersCubit` | ✅ Done |
| `/groups` | GroupsScreen | `GroupsCubit` | ✅ Done (M5 redesign) |
| `/activity` | ActivityScreen | `RecentActivityCubit` (limit=200, live-poll) | ✅ Done (M5 redesign — replaced legacy) |
| `/transcoding` | TranscodingScreen | `TranscodingCubit` + `ActivityCubit` | ✅ Done (M5 redesign) |
| `/transcoding/encoder` | EncoderSettingsScreen | `SettingsCubit` + `TranscodingCubit` | ✅ Done (M5 redesign) |
| `/settings` | SettingsScreen | `SettingsCubit` | ✅ Done |
| `/showcase` | PrimitivesShowcaseScreen | — (stateless; M1 redesign primitives) | ✅ Done — renders outside `ShellRoute`; deep-link only |

Desktop uses `ShellRoute` with a fixed 200 px `_Sidebar` on the left and the page content in an `Expanded` right panel. No authentication required — all API calls are localhost-only (`require_local_caller`) or `validate_token_or_local`.
