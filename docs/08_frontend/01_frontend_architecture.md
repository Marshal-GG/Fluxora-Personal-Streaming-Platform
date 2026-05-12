# Frontend Architecture

> **Category:** Frontend  
> **Status:** Active - Updated 2026-05-12 (**Plan 20 — auto streaming mode + opt-in client-error fallback:** `StreamStartResponse` entity gains `streamingMode: String` field (default `'client-decode'`). Mobile `PlayerCubit` arms a 6 s error watcher **only when `response.streamingMode == 'auto'`**; other modes let player errors bubble unchanged. On any player error within the window, cubit calls `PlayerRepository.reportFallbackTranscode(sessionId, currentPositionSec)` → `POST /api/v1/stream/{session_id}/fallback-transcode`; on 200, reloads the playlist via `_player!.open(Media(playlistUrl))`. Watcher is cancelled on the first successful frame (`videoParams` first non-empty value from libmpv). New `PlayerRepository.reportFallbackTranscode` method in both mobile and desktop repositories. Desktop `_StreamingModeCard` upgraded from 2-option to 3-option: **Client decodes** (Recommended) → **Auto** (Mixed device pools) → **Server transcodes** (Legacy); cubit `streamingMode` default remains `'client-decode'`.) Earlier 2026-05-09 (**Player scrubber polish:** `_pendingValue` release-pin added to `flux_player_controls.dart::_ProgressBar` alongside the existing `_dragValue` (StatefulWidget conversion landed 2026-05-08); `_pendingValue` holds the released drag value across the seek-commit window so the slider doesn't snap to the player's pre-seek position for one paint after the user lifts their finger.  `seekTo` backward-out-of-playlist routing fix in `player_cubit.dart` (clamps below the playlist start now route through a server restart instead of an unbounded local seek that media_kit would silently floor to 0).  `isSeeking` cascaded through `player_screen.dart` so the bare-`isSeeking` path never clears the `_pendingValue` pin while the cubit is still mid-restart.) Earlier 2026-05-08 (**Mobile UX polish round:** trending rip-out (Home Browse strip + Search Browse chip group; new `Routes.libraryWithFilter` helper; `LibraryScreen.initialFilter` + `_filterFromSlug` consume the `?filter=` query param); "Start over" affordance on title detail (secondary `FluxButton` next to Resume → AlertDialog → `LibraryRepository.resetProgress(fileId)` → cubit reload); Groups M6 UX revision (Locked + Unlocked cards collapsed into one always-visible "My groups (N)" card with state badges; PIN entry reachable via tap on any LOCKED row; Visible Libraries card unchanged); `DetailCubit.emit` guarded against post-close to fix the navigate-back-mid-fetch crash visible in field logs.) Earlier 2026-05-07 (**Groups v2 + dedicated edit page + mobile UX:** desktop `apps/desktop/lib/features/groups/` extended with a dedicated 6-tab edit page at `/groups/new` + `/groups/:id/edit` (Overview + Members + Access + PIN + Activity + View As); legacy create/edit modal retired at M4 of `14_groups_management_page.md`; shared form widgets lifted to `widgets/group_form_widgets.dart`.  Operator-side picker for icon (12) + color (6) + concurrent-stream cap; list-page row + detail panel render the operator's picks.  Mobile `apps/mobile/lib/features/groups/` is brand-new — `GroupsRepository` + `MobileGroupsCubit` + `GroupsSection` (Locked / Unlocked / Visible Libraries cards on Profile) + `PinEntrySheet` + `PinEnrollmentSheet`.  Plans: [`13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md) + [`14_groups_management_page.md`](../10_planning/14_groups_management_page.md).  Earlier 2026-05-04 (**Phase 6 follow-ups:** Mobile HDR UI — `StreamStartResponse` Dart class gains `hdrFormat: String?` + `tonemapped: bool` fields. `PlayerRepository.startStream(fileId, {bool tonemap = false})`. `PlayerReady` state gains `hdrFormat`, `tonemapped`, and an `isHdrSource` convenience getter. New `PlayerCubit.setTonemap(bool enabled)` method: restarts the stream with the new flag while preserving the current playback position as the new `resumeSec`; uses `_lastFileId` / `_lastFileName` / `_lastPosterUrl` fields cached in `startStream`. `FluxPlayerControls` gains `hdrFormat`, `tonemapped`, `onTonemapChanged` constructor params. New `_HdrChip` widget: renders a violet pill (`HDR10` / `HLG` / `DV`) when the source is HDR and a neutral `SDR` pill when tonemapping is active; `null` `hdrFormat` hides the chip. Previously-dead 3-dot icon now opens `_showOverflowMenu()` — a modal bottom sheet with a "Tone-map HDR to SDR" `Switch` tile (hidden when source is SDR). `ApiClient.post()` gained a `queryParameters: Map<String, dynamic>?` parameter so callers can pass query params without hand-building the URL. **GPU UX Slice C:** Settings → Streaming gained an "Encoder priority chain (advanced)" `_SettingBlock` rendering the `EncoderPriorityList` drag-and-drop widget — operator reorders encoders, "+ Add encoder" popup filters out already-chained entries, "Primary" pill on entry 0; widget is controlled (parent owns the chain list). `SettingsCubit.saveSettings` extended with `transcodingChain: List<String>?` parameter — only PATCHed when the local list differs from the loaded snapshot via a `_listEquals` helper. `SettingsLoaded.transcodingChain` is loaded from the server response and sanitised through `_kEncoders` to drop unknown IDs. New `FallbackHistoryCubit` polls `/transcoding/fallback-history` every 5 s and renders the `FallbackHistoryPanel` below the active sessions card on the Transcoding screen — collapses to nothing when the ring buffer is empty; otherwise renders one row per recent event with a `requested → actual` arrow + reason chip (OK / Cap hit / All saturated / Unknown encoder), capped at 5 most recent. Active-sessions table row gained a per-session encoder pill — purple `h264_nvenc` etc. when transcoding, info `stream-copy` when remuxing — reading from the new `ActiveTranscodeSession.encoderUsed` field. New `FallbackEvent` + `FallbackHistory` freezed entities; new `Endpoints.transcodingFallbackHistory`; `TranscodingRepository.fallbackHistory()`. Desktop suite 71 → 84. **GPU UX Slice B:** Settings → Streaming gained a `DetectedHardwareCard` widget reading from a one-shot `HardwareCubit` against `/transcoding/devices`. **GPU UX Slice A:** Settings → Streaming tab gained `ActiveEncoderStrip`, `EncoderRecommendationBanner`, `EncoderStatusPanel` widgets reading from `TranscodingCubit`; `SettingsScreen` now wraps in `MultiBlocProvider` with both `SettingsCubit` and `TranscodingCubit`; `TranscodingCubit._tick()` fetches `/status` + `/advisor` per 2 s poll. `ActivityCubit` now polls `/stream/sessions` every 2 s (was one-shot) via `start()`/`stop()` methods + `Timer.periodic` — active-sessions list and per-session progress on the Transcoding screen refresh live. `ApiException.fromDioException` rewritten to parse FastAPI's `detail` field (string or Pydantic list of `{loc, msg, type, ctx}`) and render Pydantic-list entries as `<field>: <msg>` joined by `; `. `SettingsCubit.saveSettings` now distinguishes 4xx errors (server rejected payload — "Server URL saved, but the server rejected one of the other settings: $detail") from 5xx/connection failures. Settings → General `_save` only includes `license_key` in the PATCH body when the field has been edited from `_loadedSnapshot.licenseKey`. Encoder Settings screen passes `licenseKey: null` since it never edits the license. Earlier 2026-05-04: Player polish round: Picture-in-Picture on Android via a `dev.marshalx.fluxora/pip` Kotlin method channel + new `PipService` Dart wrapper + top-bar PIP button on `flux_player_controls.dart`; lockscreen / notification / Bluetooth-headset transport controls via `audio_service ^0.18.18` + new `FluxoraAudioHandler` sidecar that bridges `media_kit.Player` to the OS MediaSession; foreground-service declared in `AndroidManifest.xml` + `ic_stat_fluxora` notification icon; first-time "Keep playing in background?" prompt in `player_screen.dart` on app-resume after auto-pause, persisted via two new `SecureStorage` keys (`bg_playback_enabled`, `bg_playback_prompt_shown`); new `_BackgroundPlaybackToggleRow` inline switch on Profile screen replaces the stub Playback row. Earlier 2026-05-04: QR-pairing scanner (`mobile_scanner ^7.1.2` + `PairingUri` parser + `ScanQrScreen`) on `/scan-qr`; Phase A + B real-data backfill (3 new cubits + 4 new endpoints wired); Downloads tab hidden in v1; mDNS reusePort fix on Android. 2026-05-03: mobile redesign M0–M9 landed; mobile theme is now V2-pure — V1 palette + V1 typography deleted from `fluxora_core` at M9 cutover.)

---

## Framework & Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart 3+) |
| Architecture | Clean Architecture (Domain / Data / Presentation) |
| State Management | BLoC (`flutter_bloc`) — Cubit for simple state, Bloc for event-driven |
| HTTP Client | `ApiClient` (Dio) from `fluxora_core` |
| Video Playback | `media_kit ^1.2.6` + `media_kit_video ^2.0.1` + `media_kit_libs_video ^1.0.7` — full M5–M7 fullscreen player with controls + sheets + mini-player handoff |
| Audio Playback (M11 viewers) | `just_audio ^0.10.5` — drives `MusicPlayerCubit` for the full-screen `/music-player` route |
| Audio Service / Lockscreen | `audio_service ^0.18.18` — `FluxoraAudioHandler` sidecar bridges `media_kit.Player` to the OS MediaSession (lockscreen / notification card / Bluetooth-headset transport) |
| PDF Viewer (M11) | `pdfx ^2.9.2` — `/doc-viewer` |
| Photo Viewer (M11) | `photo_view ^0.15.0` — pinch-zoom + pan on `/photo-viewer` |
| QR Pairing Scanner (mobile) | `mobile_scanner ^7.1.2` — `/scan-qr` reads the canonical `fluxora://pair` payload |
| LAN Discovery | `multicast_dns` (Dart) — PTR→SRV→A resolution |
| WebRTC | `flutter_webrtc ^1.4.1` — Phase 3 ✅ (`WebRtcSignalingService`, LAN skip, transport badge, ICE degradation → HLS fallback) |
| Connectivity (mobile) | `connectivity_plus ^7.1.1` — referenced from `PlayerCubit` (Wi-Fi-only-streaming gate); the offline-screen watcher integration is v1.1 work |
| Storage (secrets) | `flutter_secure_storage ^9` (tokens, server URL, client ID) |
| Icons (mobile) | `lucide_icons_flutter ^3.1.13` — Lucide 1:1 mapping shared with the prototype |
| Brightness control | `screen_brightness ^2.1.7` — vertical-drag HUD on the player |
| Package metadata | `package_info_plus ^9.0.1` — read by `PrivacyScreen` and the About card |
| Path provider / Share | `path_provider ^2.1.5`, `share_plus ^12.0.2` — used by Privacy screen's cache + temp-download maintenance |
| Routing | `go_router` — mobile `^13.0.0`, desktop `^17.2.2`; mobile uses async auth redirect guard + `setupRouterUnauthorizedBridge()` for mid-session 401s |
| DI | `get_it` — mobile `^7.6.7`, desktop `^9.2.1`; lazy singletons for repos, factories for short-lived cubits, singletons for shell-scoped cubits (PlayerCubit, NotificationsCubit, RecentCubit, ContinueWatchingCubit, ProfileCubit, ProfileStatsCubit, MobileGroupsCubit) |
| External URLs (desktop) | `url_launcher ^6.3.2` — used by the Help screen's "Get Help" link rows; opens via `launchUrl(uri, mode: LaunchMode.externalApplication)` with `Logger`-wrapped failure paths. Single new dep added 2026-05-06; established Flutter-team package, no existing dep covered the need. |
| Frameless window (desktop) | `window_manager ^0.5.1` — M10 frameless titlebar |
| QR codes (desktop pair-device) | `qr_flutter ^4.1.0` |

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
  - **[`FluxGlassDialog`](../../apps/desktop/lib/shared/widgets/flux_glass_dialog.dart)** — **canonical replacement for Material `AlertDialog`**. Drop-in: `title` / `content` / `actions` slots, default `maxWidth: 480`, `blurSigma: 20`. Wraps in `Dialog(transparent) → ClipRRect → BackdropFilter(blur 20) → Container(surfaceGlass + border)`. Used by all 3 library-screen dialogs (Delete confirm, Add/Edit form, Filters), the startup [`UpgradeDialog`](../../apps/desktop/lib/features/subscription/presentation/widgets/upgrade_dialog.dart), the [Pair-Device dialog](../../apps/desktop/lib/features/clients/presentation/widgets/pair_device_dialog.dart), and (since 2026-05-06) every dialog on the [Groups screen](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart) — Create / Edit / Add-Member / 2× Delete confirm. **If you need a modal, use this — never `AlertDialog`.** Affirmative actions render as `FilledButton(backgroundColor: AppColors.violet)`; destructive as `AppColors.red`.
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
| `flux_progress.dart` | `FluxProgress({value, height, color, trackColor})` | 400 ms `TweenAnimationBuilder` width animation; gradient fill |
| `stat_tile.dart` | `StatTile({icon, label, value, sub, color, iconBg, accent})` | Wraps `FluxCard`; 44 × 44 icon badge + label/value/sub stack |
| `sparkline.dart` | `Sparkline({data, color, height, strokeWidth})` | `CustomPainter` with single open path |
| `storage_donut.dart` | `StorageDonut({segments, centerText, unitText, size, strokeWidth})` + `StorageDonutSegment` | `CustomPainter` `drawArc` per segment, -90° start |
| `page_header.dart` | `PageHeader({title, subtitle, actions})` | Standard screen header — owns vertical padding only |
| `flux_glass_dialog.dart` | `FluxGlassDialog({title, content, actions, maxWidth, blurSigma})` | **Canonical Material `AlertDialog` replacement.** See Design System note above; do not introduce new `AlertDialog` instances. |
| `flux_glass_menu.dart` | `FluxGlassMenu` + `FluxGlassMenuItem<T>` | Drop-in `PopupMenuButton` replacement with single-`BackdropFilter` blur covering all items. |
| `flux_titlebar.dart` | `FluxTitlebar` | M10 36 px frameless-window titlebar (Win 11 caption-button geometry; macOS traffic-light positioning). |
| `flux_status_bar.dart` | `FluxStatusBar` | 24 px bottom status strip — Server Status dot + uptime + CPU/RAM/streams readouts via `SystemStatsCubit`; mounted by `FluxShell` below the page content. |
| `flux_shell.dart`, `flux_sidebar.dart` | `FluxShell`, `FluxSidebar` | App shell + 200 px collapsible sidebar — owns the shared `SettingsCubit` + `SystemStatsCubit` + `NotificationsCubit`, mounts the notifications slide-over panel and the Cmd+K command-palette overlay, drives the once-per-launch `UpgradeDialog`. |
| `flux_tab_bar.dart` | `FluxTabBar` | M4 tabbed control used by Library, Logs, Subscription, etc. |
| `flux_text_field.dart`, `flux_select.dart`, `flux_switch.dart`, `flux_slider.dart` | M6 form primitives | Violet-glass-styled drop-in replacements for Material form widgets. |

`FluxButton` and `FluxChip` (replaces the old `Pill`) are shared cross-platform — they live in `packages/fluxora_core/lib/widgets/` (see "Shared widgets — `packages/fluxora_core/lib/widgets/`" below). Mobile and desktop both consume the same widget; do not re-fork them under `apps/*/lib/shared/widgets/`.

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

### Shared widgets — `packages/fluxora_core/lib/widgets/`

Cross-platform primitives consumed by both `apps/mobile` and `apps/desktop`. Lifted to core during the M1 redesign so the mobile redesign could adopt the desktop shape without re-implementing it.

| File | Widget(s) | Notes |
|------|-----------|-------|
| `flux_button.dart` | `FluxButton` + `FluxButtonVariant` + `FluxButtonSize` | 6 variants × 3 sizes; no Material ripple; hover via `MouseRegion` + `setState`. Pixel-matched to the prototype `Button` component. |
| `flux_chip.dart` | `FluxChip` + `FluxChipColor` | Compact inline badge with colour variant + optional leading icon. Replaces the legacy `Pill` (renamed during the M1 lift; old `pill.dart` removed). |
| `flux_text_field.dart` | `FluxTextField` | Violet-glass-styled `TextFormField` replacement; consistent across mobile bottom-sheet forms and desktop dialogs. |
| `flux_app_bar.dart` | `FluxAppBar` | Mobile-shape `SliverAppBar`/`AppBar` with eyebrow + h1 + optional leading/trailing actions. Used by every full-screen mobile route (Connect / Account / Privacy / Playback / Upgrade / X-Ray / Group Watch / viewers). |
| `flux_bottom_sheet.dart` | `showFluxBottomSheet({title, child})` | Modal bottom sheet styled on `bgRaised` with V2 chrome. Used by player sheets, manual-IP entry, group PIN modals, etc. |
| `flux_bottom_tabs.dart` | `FluxBottomTabs` | Mobile bottom-nav bar — 4 tabs (Home / Library / Search / Profile). Mounted by `mobile_shell.dart` underneath the persistent `FluxMiniPlayer`. |
| `flux_poster.dart` | `FluxPoster` | Aspect-locked poster surface; falls back to a deterministic `AppGradientPlaceholders` gradient + initials when `posterUrl` is null. |
| `flux_row.dart` | `FluxRow` | Tappable settings-style list row with leading icon + label + optional value + trailing chevron. Used by the Profile screen's 9-row settings list. |
| `flux_section_header.dart` | `FluxSectionHeader` | Eyebrow + h2 group header used above mobile rails / cards. |

### Showcase route

[`apps/desktop/lib/shared/showcase/primitives_showcase_screen.dart`](../../apps/desktop/lib/shared/showcase/primitives_showcase_screen.dart) renders every redesign primitive in every variant on the `bgRoot` background. Routed at `/showcase` outside the `ShellRoute` so it sits on a clean canvas for visual diff against the prototype. Kept post-M9 as an ongoing reference surface — useful when mobile starts referencing the same primitives.

---

## Screen / Route Map — Flutter Mobile (Implemented post-M9)

The redesign reorganised mobile around a 5-tab shell (`StatefulShellRoute.indexedStack`) plus auth-gate + deep-link routes that bypass the shell. Tab branches preserve state across switches; tapping the active tab pops to its branch root.

| Route | Screen | State class | Branch / Outside-shell | Status |
|-------|--------|-------------|------------------------|--------|
| `/splash` | SplashScreen | — (stateless) | Outside shell — auth gate (initial location). Two CTAs route to `/connect` and `/scan-qr`; authenticated users are bounced straight to `/home` by `_guardRedirect`. | ✅ Done (M12, 2026-05-08) |
| `/connect` | ConnectScreen | `ConnectCubit` | Outside shell — auth gate. Rebuilt at M12 (2026-05-08) on V2 tokens — `FluxAppBar` + `BrandLoader` + glass `_ServerTile`s + bottom CTAs as `FluxButton` + manual entry as a `FluxBottomSheet`. | ✅ Done (M12 reskin) |
| `/pairing` | PairingScreen | `PairCubit` | Outside shell — auth gate. Polished at M12 (2026-05-08) — two `CircularProgressIndicator` instances replaced with `BrandLoader`. | ✅ Done (M12 polish) |
| `/reconnect` | ReconnectScreen | — (stateless; re-fires `POST /auth/request-pair` against the saved server) | Outside shell — auth gate. Reached when the bearer token is dead but `client_id` + `server_url` are still in secure storage; the unauthorized-stream bridge in `app_router.dart` routes here mid-session. | ✅ Done (Phase A backfill §9.2) |
| `/scan-qr` | ScanQrScreen | — (stateful camera surface backed by `mobile_scanner ^7.1.2`) | Outside shell — auth gate. Reads the canonical `fluxora://pair?host=&port=&name=` payload via the `PairingUri` parser. | ✅ Done |
| `/home` | HomeScreen | `RecentCubit` + `ContinueWatchingCubit` (Phase A + B real-data; Browse strip is static layout per 2026-05-08 trending rip-out) | Tab 1 | ✅ Done (M3) |
| `/library` | LibraryScreen({initialFilter}) | `LibraryBloc` (real-data Phase A); `?filter=` query param routes from Home Browse strip + Search Browse chips | Tab 2 | ✅ Done (M3 — V2 redesign) |
| `/search` | SearchScreen | `SearchCubit` (Phase B real-data via `GET /files/search`); empty-state Browse chip group routes to `Routes.libraryWithFilter(slug)` | Tab 3 | ✅ Done (M3) |
| `/profile` | ProfileScreen | `ProfileCubit` + `ProfileStatsCubit` + `MobileGroupsCubit` — real-data via `/auth/clients/me` + `/auth/clients/me/stats` + `/auth/clients/me/visible-libraries` (Phase A + B + Groups v2 M6); sign-out calls `AuthRepository.revokeMe()` server-side before local teardown (audit §17.3 #3, 2026-05-08) | Tab 4 (Downloads tab hidden in v1 — Profile is the 4th branch) | ✅ Done (M8 + M6 + audit) |
| `/detail/:id` | DetailScreen | `DetailCubit` (Phase A real-data via `GET /files/{id}`); "Start over" button → `LibraryRepository.resetProgress` (streaming pipeline §4.10, 2026-05-08); `emit` guarded against post-close (audit §17.3 #11, 2026-05-08) | Outside shell — full-screen deep link | ✅ Done (M4) |
| `/episodes/:id` | EpisodesScreen | — (mock; Phase D backfill replaces with `GET /shows/{tmdb_show_id}/episodes`) | Outside shell | ✅ Done (M4) |
| `/library-files/:id` | FilesScreen | `FilesCubit` | Outside shell — legacy deep link | ✅ Done |
| `/player` | PlayerScreen({file}) | `PlayerCubit` (singleton) | Outside shell | ✅ Done |
| `/player/resume` | PlayerScreen.resume() | `PlayerCubit` (singleton) | Outside shell — mini-player handoff | ✅ Done (M7) |
| `/notifications` | NotificationsScreen | `NotificationsCubit` (singleton) | Outside shell — pushed from Home bell icon; REST polling `/api/v1/notifications` every 5 s. | ✅ Done (M3 stub → M8 real-data) |
| `/offline` | OfflineScreen | — (UI shell only; no live connectivity detector wired in v1 — `connectivity_plus ^7.1.1` is in `pubspec.yaml` but the watcher integration is v1.1 work) | Outside shell | ✅ Done (M10 slice 1, 2026-05-08) |
| `/xray` | XRayScreen | — (UI shell with static cast + trivia; live ML deferred to v1.1) | Outside shell — pushed from player top-bar chip | ✅ Done (M10 slice 2, 2026-05-08) |
| `/group-watch` | GroupWatchScreen | — (UI shell; multi-client sync deferred to Phase 5+; **NOT** the same as Client Groups / Groups v2) | Outside shell — pushed from player overflow menu | ✅ Done (M10 slice 3, 2026-05-08) |
| `/doc-viewer` | DocViewerScreen | — (stateless; `pdfx ^2.9.2`) | Outside shell — M11 beyond-video viewers | ✅ Done (M11) |
| `/photo-viewer` | PhotoViewerScreen | — (stateless; `photo_view ^0.15.0`) | Outside shell — M11 beyond-video viewers | ✅ Done (M11) |
| `/music-player` | MusicPlayerScreen | `MusicPlayerCubit` (`just_audio ^0.10.5`) | Outside shell — M11 beyond-video viewers | ✅ Done (M11) |
| `/upgrade` | UpgradeScreen | — (stateless) | Outside shell — pushed from Profile → Subscription row + from player tier-limit `PlayerTierLimit` state. | ✅ Done (settings remediation §M1, 2026-05-08) |
| `/account` | AccountScreen | `ProfileCubit` (singleton — preferred for the Identity card + read-only fields) | Outside shell — pushed from Profile → Account row. Display-name editor opens a `FluxBottomSheet` calling `AuthRepository.updateMe()` → `PATCH /auth/clients/me`. | ✅ Done (settings remediation §M2 + §M2.5, 2026-05-08) |
| `/privacy` | PrivacyScreen | — (stateless; `FutureBuilder`s read SecureStorage + `package_info_plus`) | Outside shell — pushed from Profile → Privacy & security row. Device-info readout + Clear in-app image cache + Clear temp downloads + Sessions note. | ✅ Done (settings remediation §M4, 2026-05-08) |
| `/playback-prefs` | PlaybackPrefsScreen | — (stateless; persists prefs via `SecureStorage` keys read by `PlayerCubit`) | Outside shell — pushed from Profile → Playback row. Background playback / Wi-Fi-only streaming / Max quality / Autoplay-next / Subtitles default. | ✅ Done (settings remediation §M3, 2026-05-08) |
| `/downloads` | DownloadsScreen | — (mock; tab hidden in v1 per real-data backfill plan §5 row 4 — file kept in tree for v1.1 restoration) | Outside shell route currently unregistered — only the screen file is referenced | ⏸ Hidden in v1 |

Auth guard (`_guardRedirect` in `apps/mobile/lib/core/router/app_router.dart`): public routes are `/splash`, `/connect`, `/pairing`, `/reconnect`, `/scan-qr`. Authenticated users hitting `/splash`, `/connect` or `/pairing` are bounced to `/home`; `/reconnect` is exempt so an authenticated user can re-pair without being reflected back. Unauthenticated users hitting any non-public route are redirected to `/splash` (was `/connect` pre-M12). The `setupRouterUnauthorizedBridge()` helper subscribes to `ApiClient.unauthorizedStream` so a 401 from any in-flight request mid-session bumps the user to `/reconnect` (skipped while already on a pairing-flow surface).

Sign-out (Profile tab → red-tinted button → confirm dialog → accept) calls `AuthRepository.revokeMe()` (server-side `DELETE /auth/clients/me`, audit §17.3 #3) → `playerCubit.dismiss()` → `apiClient.clearBearerToken()` → `secureStorage.deleteAll()` → `context.go(Routes.splash)`; the redirect guard handles the rest on the next navigation tick.

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
│       ├── gradients.dart            # AppGradientPlaceholders — deterministic LinearGradient palette consumed by FluxPoster fallbacks, mini-player, avatar chip; lifted from MockData at Phase A so it survives the mock shrinkage
│       ├── media_card.dart           # legacy (used by /library-files/:id); V2 token migration landed at M9
│       ├── status_badge.dart         # legacy; V2 token migration landed at M9
│       └── loading_overlay.dart      # legacy; V2 token migration landed at M9
│
└── features/
    ├── onboarding/   # M12 ✅ 2026-05-08 — `splash_screen.dart`: 104-px glow `FluxoraMark` + wordmark + "Stream. Sync. Anywhere." tagline + 3-dot pagination + two CTAs (Connect to a server primary → /connect, Scan a QR code secondary → /scan-qr).  Auth-gate `initialLocation` is now `/splash`; unauthenticated users land here, authenticated users are bounced to /home
    ├── connect/      # mDNS + manual IP — M12 rebuild ✅ 2026-05-08: `FluxAppBar` ("Find your server") + eyebrow/h1/body header block + `BrandLoader` while scanning + glass `_ServerTile`s with `LucideIcons.server` + bottom CTAs as `FluxButton` (Scan QR primary + Enter manually secondary opening a `FluxBottomSheet` with `FluxTextField` IP+port form).  Houses `connect_screen.dart` + `scan_qr_screen.dart` (camera-backed `mobile_scanner` capture surface) + `domain/pairing_uri.dart` (parser for the `fluxora://pair?host=&port=&name=` URI rendered by the desktop control panel's QR code).
    ├── auth/         # pairing + reconnect — M12 polish ✅ 2026-05-08: two `CircularProgressIndicator` instances replaced with `BrandLoader` (56 px / 32 px); email-collection / pending / rejected / error panels were already V2-styled.  Houses `pairing_screen.dart` (`PairCubit` polling `/auth/request-pair`) + `reconnect_screen.dart` (Phase A backfill §9.2 — re-fires pair against the saved server when the bearer token is dead but `client_id` + `server_url` are still in secure storage; subscribed to via `setupRouterUnauthorizedBridge()`).  The original M12 plan row's "email + password + 2FA TOTP" scope was honestly cut — Fluxora has no credential auth, only operator-approval pairing
    ├── upgrade/      # tier comparison + activation guide — V2 + AppGradients.brand header (state lives in `cubit/upgrade_state.dart`)
    │
    ├── home/         # M3 Discover — Continue-watching hero rail + 4-up Browse strip (Movies/Shows/Music/Documents → Routes.libraryWithFilter) + Recently-added rail; bell → /notifications.  2026-05-08 trending rip-out replaced the middle Trending rail with the Browse strip per mobile redesign plan §17.2
    ├── search/       # M3 — empty/active/no-results states, top-3 rail + sectioned results.  2026-05-08 trending rip-out replaced "Trending searches" chip group with a "Browse" chip group routing through Routes.libraryWithFilter
    ├── library/      # M3 redesign — 6 filter chips + grid/list toggle + sort menu; LibraryScreen now accepts initialFilter via ?filter= query param so Home + Search Browse chips can pre-filter the tab; legacy LibraryBloc + /library-files/:id retained
    ├── offline/     # M10 first slice (✅ 2026-05-08) — `OfflineScreen` shell renders prototype `EmptyOfflineScreen` (84-px violet-glow circle + LucideIcons.wifiOff + "You're offline" body quoting serverName + "Retry connection" FluxButton).  Route registered at `Routes.offline = '/offline'`; `connectivity_plus ^7.1.1` is now in `pubspec.yaml` (added with the M11 viewers landing) but the live watcher → router-push integration is still v1.1 work.  Prototype's "Open downloads" secondary button not ported since Downloads tab is hidden in v1
    ├── xray/        # M10 second slice (✅ 2026-05-08) — `XRayScreen` shell renders prototype `XRayScreen` (`extras.jsx` line 378): `FluxAppBar` "X-Ray · {title}" + violet "Static preview" pill + "IN THIS SCENE · 3" + 3 mock cast rows + "TRIVIA" + 2 mock trivia cards.  Entry point: `LucideIcons.scienceOutlined`-style chip in `_TopBar` of `flux_player_controls.dart` between HDR badge and PIP button.  Route at `Routes.xray = '/xray'` accepts `extra:` as either `MediaFile` or `String` title; falls back to "X-Ray" when null.  Static fixtures (`_mockCast`, `_mockTrivia`) replaced by TMDB credits + scene-time cues in v1.1 / Phase C of the real-data backfill plan
    ├── group_watch/ # M10 third slice (✅ 2026-05-08) — `GroupWatchScreen` shell renders prototype `GroupWatchScreen` (`extras.jsx` line 278): `FluxAppBar` "Group Watch" + violet "Sync engine ships in v1.1" pill + 200-px hero card (deep-blue gradient + LIVE eyebrow + source title) + "IN THE ROOM · 4" + 4 mock person rows + invite-link card (monospace placeholder URL + violet copy button → real Clipboard write + SnackBar) + Leave button + "Resume for everyone" FluxButton (SnackBar — sync engine deferred to Phase 5+).  Entry point: `Group Watch` ListTile in `flux_player_controls.dart::_showOverflowMenu` overflow sheet.  Route at `Routes.groupWatch = '/group-watch'` accepts `extra: String` source title.  **Note: this is the multi-client party-watch feature, NOT "Client Groups" / Groups v2.**  Static fixtures live until the sync engine lands in Phase 5+
    ├── notifications/    # M3 stub → M8 real-data (NotificationsRepository + Cubit polling /api/v1/notifications every 5 s)
    │   ├── domain/repositories/notifications_repository.dart      # list/markRead/markAllRead/dismiss/liveStream
    │   ├── data/repositories/notifications_repository_impl.dart   # // TODO(WS): migrate to /ws/notifications when shared HMAC-bearer wrapper exists
    │   └── presentation/
    │       ├── cubit/{notifications_cubit.dart,notifications_state.dart}    # singleton-scoped, sealed class state, identity equality
    │       └── screens/notifications_screen.dart                            # Today/This week/Earlier buckets, category→icon+color, tap-to-markRead
    │
    ├── detail/       # M4 — hero + Play/Resume + Episodes + 4-up actions + collapsible synopsis + cast/crew/similar rails.  2026-05-08: secondary "Start over" FluxButton next to Resume when resumeSec > 0 → AlertDialog confirm → LibraryRepository.resetProgress(fileId) → cubit reload + SnackBar (streaming pipeline plan §4.10).  DetailCubit.emit guarded against post-close to prevent navigate-back-mid-fetch crashes
    ├── episodes/     # M4 — season chip selector + episode rows
    ├── downloads/    # M8 — header storage indicator + Downloading cards + Available offline rows + FluxBottomSheet actions; route currently unregistered (tab hidden in v1) but the screen file ships in tree
    ├── viewer/       # M11 beyond-video viewers (✅ 2026-05-08) — three full-screen surfaces routed outside the shell, each accepting a `MediaFile` via `extra:`.  `screens/doc_viewer_screen.dart` (PDF preview backed by `pdfx ^2.9.2`) · `screens/photo_viewer_screen.dart` (pinch-zoom + pan via `photo_view ^0.15.0`) · `screens/music_player_screen.dart` (full-screen audio player driven by `MusicPlayerCubit` + `just_audio ^0.10.5`).  Library + Files screens dispatch to the right viewer based on `MediaFile.kind`
    ├── profile/      # M8 — gradient avatar + PLUS pill + 3-stat row + GroupsSection (M6 mobile groups UX) + 9 FluxRow sections + red Sign out → confirm dialog → revokeMe + cubit.dismiss + storage.deleteAll + go(Routes.splash).  M12 settings rebuild (✅ 2026-05-08) added three sub-screens — `screens/account_screen.dart` (`/account` — display-name editor over PATCH /auth/clients/me + read-only device/server/version), `screens/privacy_screen.dart` (`/privacy` — device-info readout + Clear in-app image cache + Clear temp downloads), `screens/playback_prefs_screen.dart` (`/playback-prefs` — bg-playback / Wi-Fi-only streaming / max-quality / autoplay-next / subtitles-default; persisted via `SecureStorage` keys read by `PlayerCubit`).  Cubits: `cubit/profile_cubit.dart` (singleton; `/auth/clients/me`) + `cubit/profile_stats_cubit.dart` (singleton; `/auth/clients/me/stats`)
    │
    ├── groups/       # ✅ Plan 13 §M4 + §M6 + §M8 mobile (2026-05-07); §M6 UX revision 2026-05-08 — Profile-screen group surfaces + PIN modals
    │   ├── domain/repositories/groups_repository.dart            # Mobile-shaped — myVisibleLibraries / grantStatus / enter / enroll / changePin / lock; GroupGrantStatus + GroupGrantIssued + GroupEnrollmentState domain types
    │   ├── data/repositories/groups_repository_impl.dart         # REST over shared ApiClient; 404 on grantStatus → null (group deleted while looking at it)
    │   └── presentation/
    │       ├── cubit/groups_cubit.dart       # MobileGroupsCubit — load + refreshSilent + enter + enroll + changePin + lock + lockAll(); singleton-scoped via GetIt so cards survive bottom-tab hops; emit() guarded against post-close
    │       ├── cubit/groups_state.dart       # MobileGroupsLoaded with lockedGroups + unlockedGroups filtered getters (still exposed for tests + external consumers); MobileGroupRow with enrollmentState routing helper
    │       └── widgets/
    │           ├── groups_section.dart       # 2026-05-08 UX revision: single "My groups (N)" card replaces the Locked + Unlocked split — every membership renders with a LOCKED / UNLOCKED / OPEN state badge; rows sort Locked → Unlocked → Open; tap a Locked row → PIN entry sheet; Unlocked rows keep the "Lock" text-button; "Lock all" surfaces in trailing slot when 2+ unlocked.  Plus the unchanged Visible Libraries card.  Section self-hides only when groups + libraryIds are both empty (was: any of three filtered lists empty)
    │           └── pin_modals.dart           # PinEntrySheet (single field; copy adapts to pin_model) + PinEnrollmentSheet (two-field set+confirm; M8 first-time enrollment); _kObviousPins mirror of server `_OBVIOUS_PINS` blocklist for snappy client-side feedback
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
            ├── cubit/{player_cubit.dart,player_state.dart}     # M7 singleton + restart-safe startStream + _disposeCurrentSession + dismiss(); Player polish: optional FluxoraAudioHandler param + WidgetsBindingObserver auto-pause on background when bg_playback_enabled=false; Phase 6: setTonemap(bool) restarts stream with tonemap flag while preserving position; _lastFileId/_lastFileName/_lastPosterUrl cached; PlayerReady gains hdrFormat/tonemapped/isHdrSource + isSeeking + playlistOffsetSec; 2026-05-09 (commit `f609287`): backward `seekTo` targets that fall below the current playlist start now route through a server restart instead of an unbounded local seek that media_kit would silently floor to 0 — cubit emits `isSeeking: true` immediately so the scrubber pin stays stable across the debounce
            ├── widgets/flux_player_controls.dart                # M5 + M6 — top bar / center transport / progress bar / 8-up quick-actions / side rails / lock chip + double-tap ripple / long-press 2× peek / vertical drag brightness+volume / pinch fit / hold-to-unlock progress ring; Player polish — top-bar PIP icon button gated on PipService.isSupported(); Phase 6: hdrFormat/tonemapped/onTonemapChanged props; _HdrChip pill; _showOverflowMenu 3-dot bottom sheet with HDR tonemap Switch tile; M10 X-Ray (✅ 2026-05-08): `onXRay: VoidCallback?` prop + new science-flask icon button in `_TopBar` between the HDR badge and the PIP button — null hides the chip; M10 Group Watch (✅ 2026-05-08): `onGroupWatch: VoidCallback?` prop + new "Group Watch" `ListTile` (groups icon) in `_showOverflowMenu`; empty-menu guard now fires only when both tonemap + group-watch are unavailable.  Scrubber state lives on the stateful `_ProgressBar` (`StatefulWidget` conversion landed 2026-05-08): `_dragValue` follows the user's finger during drag, then on release rolls into `_pendingValue` (added 2026-05-09 commit `f609287`) which holds the released drag value across the seek-commit window so the slider never snaps back to the player's pre-seek position for one paint after the user lifts their finger.  Pin clears once the player's reported position lands within ε of the target, or via the fallback timer
            ├── sheets/{audio_subs_sheet,speed_sheet,sleep_sheet,quality_sheet,cast_sheet}.dart   # M6 — 5 bottom sheets via showFluxBottomSheet
            └── screens/player_screen.dart                       # M7 dual constructors: PlayerScreen({file}) + PlayerScreen.resume(); _MinimizeHandle drag-down → context.pop() ≥ 150 px; Player polish — WidgetsBindingObserver fires _maybeShowBackgroundPlaybackPrompt on first resume after auto-pause + passes file.posterUrl into cubit.startStream so the lockscreen card has artwork; 2026-05-09 cascades the cubit's `isSeeking` flag through to `_ProgressBar` so the bare-`isSeeking` path never clears the `_pendingValue` pin while the cubit is mid-restart
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
Mobile test/ (78 tests)
├── features/
│   ├── connect/connect_cubit_test.dart           # ConnectCubit discovery + manual entry
│   ├── connect/pairing_uri_test.dart             # PairingUri parser cases (canonical / missing host / port out of range / etc.)
│   ├── auth/pair_cubit_test.dart                 # PairCubit polling state machine
│   ├── auth/auth_repository_impl_test.dart       # post-pair /info fetch + remote_url persistence
│   ├── library/library_bloc_test.dart            # LibraryBloc start / refresh
│   ├── groups/groups_cubit_test.dart             # MobileGroupsCubit load/refresh/enter/enroll/lock
│   └── player/player_cubit_test.dart             # startStream + restart + dismiss + seekTo routing + tonemap restart + auto-fallback watcher arm/cancel (plan 20)
├── storage/secure_storage_playback_prefs_test.dart   # bg-playback / Wi-Fi-only / max-quality / autoplay-next / subtitles defaults
└── placeholder_test.dart

Desktop test/ (104 tests)
├── features/
│   ├── dashboard/dashboard_cubit_test.dart                    # ✅
│   ├── clients/clients_cubit_test.dart                        # ✅
│   ├── settings/settings_cubit_test.dart                      # ✅ (loadSettings + saveSettings + license_key PATCH + Remote Access — `loadSettings` populates `remoteUrl` from `/info`; `checkRemoteAccess` early-return paths)
│   ├── notifications/notifications_cubit_test.dart            # ✅ (start/markRead/markAllRead/dismiss happy + rethrow paths; live-stream new + duplicate-id ignore)
│   ├── transcoding/encoder_status_panel_test.dart             # ✅ (Slice A — pill rendering per status, sort order, failed-tooltip, banner severity → icon, ActiveEncoderStrip CPU/GPU pill + engine label)
│   ├── transcoding/detected_hardware_card_test.dart           # ✅ (Slice B — loading / failure / empty states, CPU + GPU tile rendering with vendor pills, MB-vs-GB VRAM formatting, refresh button visibility)
│   ├── transcoding/encoder_priority_list_test.dart            # ✅ (Slice C — empty-state copy, index pills, Primary pill on entry 0, remove-fires-onChanged, Add menu filters chained-out entries, Add appends to chain, "all in chain" hint)
│   ├── transcoding/fallback_history_panel_test.dart           # ✅ (Slice C — render-nothing while loading / on failure / empty, header + reason chips, requested → actual arrow, 5-event display cap)
│   └── transcode/transcode_cubit_test.dart                    # ✅ Plan 18 — 14 tests covering loadCandidates emit-order, selectFiles, startTranscode (POST /queue + refresh), cancelJob (DELETE + refresh), retryJob (POST /retry + refresh), 2 s polling lifecycle, selection auto-strip after queue
├── goldens/m3_dashboard_golden_test.dart                       # M3 dashboard golden snapshot via golden_toolkit
└── placeholder_test.dart
└── (library/orders/activity/logs cubits tested via manual integration)

Core packages/fluxora_core/test/ (8 tests)
└── network/api_client_test.dart                # dual-base routing (LAN vs WAN), unauthorized-stream emission, bearer-token header injection
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
│   │   └── injector.dart        # get_it: ApiClient (localhost:8000), all repositories, OrdersCubit + SettingsCubit + SystemStatsCubit + NotificationsCubit + ProfileCubit factories
│   └── router/
│       └── app_router.dart      # GoRouter + Routes + ShellRoute wrapping FluxShell (Dart 3.8 wildcard params); /showcase intentionally outside the ShellRoute so primitives sit on a clean canvas
│
├── shared/
│   ├── theme/
│   │   └── app_theme.dart       # AppTheme.dark — Material 3 ThemeData wired through V2 tokens (bgRoot scaffold, violet primary, opaque bgRaised for AppBar/Card/SnackBar/InputDecoration)
│   ├── showcase/
│   │   └── primitives_showcase_screen.dart   # /showcase — every redesign primitive in every variant on bgRoot for visual diff
│   └── widgets/                              # see "Primitives" table above for the full catalog (FluxCard, StatTile, Sparkline, StatusDot, FluxProgress, StorageDonut, PageHeader, FluxGlassDialog, FluxGlassMenu, FluxTitlebar, FluxStatusBar, FluxShell, FluxSidebar, FluxTabBar, plus the M6 form primitives FluxTextField/FluxSelect/FluxSwitch/FluxSlider).  FluxButton + FluxChip live in `packages/fluxora_core/lib/widgets/` (cross-platform).
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
    │       └── screens/clients_screen.dart  # M4 redesign: PageHeader + 4 StatTiles (Active Streams reads from SystemStatsCubit since 2026-05-06) + search/filter row + 7-column table (IP cell reads c.lastIp; Current Stream reads c.activeSession.mediaTitle) + 300px detail panel (approve/reject/revoke wired; emerald _ActiveSessionBlock when activeSession non-null)
    │
    ├── library/                 # ✅ Implemented (Phase 5)
    │   ├── domain/repositories/library_repository.dart
    │   ├── data/repositories/library_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/library_cubit.dart
    │       ├── cubit/library_state.dart
    │       └── screens/library_screen.dart  # Create/scan/upload/filter libraries
    │
    ├── orders/                  # ✅ Implemented (Phase 5) — screen retired at M9 cleanup; OrdersCubit consumed by SubscriptionScreen.Billing tab
    │   ├── domain/repositories/orders_repository.dart
    │   ├── data/repositories/orders_repository_impl.dart
    │   └── presentation/
    │       └── cubit/orders_cubit.dart  # consumed by SubscriptionScreen.Billing — order list + portal-url + license-key copy
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
    ├── groups/                  # ✅ M5 redesign + v2 content-spaces (2026-05-07) + dedicated edit page
    │   ├── domain/repositories/groups_repository.dart   # CRUD + add/remove member + clearMemberPin + visibleLibrariesAs (View As) + resetAllGrants (M7 bulk reset)
    │   ├── data/repositories/groups_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/groups_cubit.dart       # load + createGroup/updateGroup (with v2 + M8 + M7 fields: pin/pinMode/pinModel/icon/color/maxConcurrentStreams) + deleteGroup + addMember(s)/removeMember + clearMemberPin + loadMembers(includePinState)
    │       ├── cubit/groups_state.dart
    │       ├── screens/groups_screen.dart    # List page — PageHeader + 4 StatTiles + table + 300 px detail panel.  Row + Edit buttons navigate to GroupEditScreen; legacy create/edit modal retired
    │       ├── screens/group_edit_screen.dart   # Dedicated 6-tab page at /groups/new + /groups/:id/edit — Overview (Identity + icon/color picker + Danger Zone) / Members (with enrollment-state badges) / Access (restrictions + concurrent stream cap) / PIN (shared/per-client picker + entry/edit) / Activity (group-scoped event feed) / View As (operator debug — render visible libraries as the target client)
    │       └── widgets/group_form_widgets.dart  # Lifted at M4 of `14_groups_management_page.md`: PinSection / GroupRestrictionsForm / TimeWindowPicker / LibraryAllowlistPicker / AdvisoryFieldsSection / SectionToggleHeader / AddMemberDialog / formatTimeWindow — public-named so both pages can consume them (Dart privacy is library-scoped, not file-scoped)
    │
    ├── transcoding/             # ✅ M5 redesign
    │   ├── domain/repositories/transcoding_repository.dart
    │   ├── data/repositories/transcoding_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/transcoding_cubit.dart  # polls /api/v1/transcoding/status every 2 s
    │       ├── cubit/transcoding_state.dart
    │       ├── screens/transcoding_screen.dart        # 4 StatTiles + Active Sessions card; joins ActivityCubit
    │       └── screens/encoder_settings_screen.dart   # /transcoding/encoder; hardware selector + preset chips + CRF slider; **plan 20:** 3-option `_StreamingModeCard` (Client decodes Recommended / Auto Mixed-device-pools / Server transcodes Legacy) replaces the prior 2-option card
    │
    ├── transcode/               # ✅ Plan 18 (2026-05-09) + plan 19 close-out (2026-05-09) + close-out fixes (2026-05-10) — user-driven library transcode
    │   ├── domain/entities/{transcode_candidate.dart, transcode_job.dart, transcode_storage.dart}    # Equatable; TranscodeJobStatus enum; TranscodeStorage + TranscodeStorageCodecBreakdown + TranscodeStorageLibraryBreakdown (per-library N + GB feeds the library-delete confirmation)
    │   ├── domain/repositories/transcode_repository.dart
    │   ├── data/repositories/transcode_repository_impl.dart                  # GET /candidates · POST /queue (preset arg) · GET /jobs · DELETE /jobs/{id} · POST /jobs/{id}/retry · GET /storage
    │   └── presentation/
    │       ├── cubit/{transcode_cubit.dart, transcode_state.dart}            # sealed-union state (Initial/Loaded with candidates+jobs+selectedFileIds+expandedPaths+queuePreset+storage/Failure); split timers (2 s `/jobs` + 5 s `/storage`); selection auto-strips ids that left the candidate list (post-queue)
    │       ├── screens/transcode_screen.dart                                  # 3 TabBar + TabView (Candidates / Queue / History) with `_StorageStrip` mounted above the TabBar — entry from FluxSidebar between Library and Clients
    │       └── widgets/{candidates_tab,queue_tab,history_tab}.dart + {storage_strip,queue_dialog,folder_tree}.dart  # Candidates + History tabs use folder-grouped tree (`buildFolderTree<T>` is `Expando`-memoised on the leaves list reference so 5000+-candidate trees don't recompute per build); `showQueueDialog` opens FluxGlassDialog with 3-radio preset chooser (smaller / recommended (default) / mastering) + live "Estimated total" + cache-root readout; `_StorageStrip` polls `/storage` every 5 s with cache root + free disk + per-codec chips; `openPathInFileManager` uses `url_launcher`'s `launchUrl(Uri.file(path))` (cleaner cross-platform behaviour than the previous `Process.start("explorer", ...)` shape — Windows explorer returned non-zero exit on success in some cases)
    │
    ├── settings/                # ✅ Implemented (Phases 2 + 5)
    │   ├── domain/repositories/settings_repository.dart
    │   ├── data/repositories/settings_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/settings_cubit.dart   # loadSettings()/saveSettings(); transcoding fields + 13 §7.10 extended-settings fields (defaultLibraryView, scanLibrariesOnStartup, generateThumbnails, preferredMode, enableMdns, enableWebrtc, relayServerUrl, defaultQuality, aiSegmentDurationSeconds, enablePairingRequired, sessionTimeoutMinutes, enableLogExport, customServerUrl); Dart 3.8 null-aware map syntax for diff-only PATCH
    │   ├── cubit/settings_state.dart   # SettingsLoaded carries every column the UI seeds from
    │   └── screens/settings_screen.dart  # 6 tabs (General/Network/Streaming/Security/Advanced/About). Network tab is StatelessWidget — preferredMode/mDNS/WebRTC/relay live on parent _SettingsViewState so they participate in load + save. _SystemInfoCard reads SystemStatsCubit for live "Server Status" row (Running/Degraded/Unreachable/Checking). Max Concurrent Streams renders as FluxChip + Tooltip — tier-locked, points to Subscription screen for upgrade. About tab has _AboutProductCard (replaces legacy "Credits") + _LinksCard via _ExternalLinkRow (url_launcher). View Issued Licenses navigates to /subscription (was the deleted /licenses route).
    │
    ├── subscription/            # ✅ M7 redesign — replaces the deleted /licenses route
    │   └── presentation/
    │       ├── screens/subscription_screen.dart    # /subscription — 3 tabs (Plans / Billing / Manage); reuses OrdersCubit (Billing tab) + SettingsCubit (Manage tab; license-key activation)
    │       └── widgets/upgrade_dialog.dart         # FluxGlassDialog mounted by FluxShell once per launch on first SettingsLoaded when tier != ultimate; "Maybe Later" / "View Plans" → /subscription
    │
    ├── profile/                 # ✅ Operator profile — read-only-ish identity surface
    │   ├── domain/repositories/profile_repository.dart
    │   ├── data/repositories/profile_repository_impl.dart
    │   └── presentation/
    │       ├── cubit/{profile_cubit.dart, profile_state.dart}   # ProfileCubit factory in DI
    │       └── screens/profile_screen.dart    # /profile
    │
    ├── help/                    # ✅ Help screen — external links (`url_launcher ^6.3.2`)
    │   └── presentation/screens/help_screen.dart    # /help
    │
    ├── command_palette/         # ✅ Cmd+K modal mounted by FluxShell
    │   ├── domain/command.dart
    │   ├── data/command_registry.dart
    │   └── presentation/
    │       ├── notifier/command_palette_notifier.dart    # ChangeNotifier — open() / close() + selected index; shared with FluxShell's Stack
    │       └── widgets/command_palette_overlay.dart      # 600 × ~420 px frosted-glass card; Up/Down navigates, Enter executes, Esc closes; navigation cmds call GoRouter.go, action cmds invoke a VoidCallback
    │
    ├── notifications/           # ✅ Bell + slide-over panel — see Design System notes for the full audit
    │   ├── domain/repositories/notifications_repository.dart
    │   ├── data/repositories/notifications_repository_impl.dart    # 5 s REST poll; `?unread=true` query-param name; `seen` set capped at 500 entries (FIFO)
    │   └── presentation/
    │       ├── cubit/{notifications_cubit.dart, notifications_state.dart}   # factory; mutation methods rethrow on transport failure (panel surfaces SnackBar)
    │       └── widgets/notifications_panel.dart    # slide-over inside FluxShell's Stack; 220 ms easeOutCubic SlideTransition; tap row → close before context.go(route)
    │
    └── system_stats/            # ✅ Shared system-telemetry cubit
        ├── domain/repositories/system_stats_repository.dart
        ├── data/repositories/system_stats_repository_impl.dart    # GET /api/v1/info/stats every 1.1 s
        └── presentation/cubit/{system_stats_cubit.dart, system_stats_state.dart}   # one shared factory; sidebar / status bar / Dashboard sparklines / Settings _SystemInfoCard / Clients screen all read this
```

### Desktop routes

| Route | Screen | State class | Status |
|-------|--------|-------------|--------|
| `/` | DashboardScreen | `DashboardCubit` + `StorageCubit` + `RecentActivityCubit` + `SystemStatsCubit` | ✅ Done (M3 redesign) |
| `/clients` | ClientsScreen | `ClientsCubit` | ✅ Done (M4 redesign) |
| `/library` | LibraryScreen | `LibraryCubit` | ✅ Done |
| `/subscription` | SubscriptionScreen (Plans / Billing / Manage tabs) | `OrdersCubit` + `SettingsCubit` | ✅ Done (M7 redesign — replaces deleted `/licenses`) |
| `/groups` | GroupsScreen | `GroupsCubit` | ✅ Done (M5 redesign) |
| `/groups/new` | GroupEditScreen.create() | `GroupsCubit` (page-scoped) | ✅ Done 2026-05-07 (plan 14 M1) |
| `/groups/:id/edit` | GroupEditScreen.edit(id: …) | `GroupsCubit` (page-scoped) | ✅ Done 2026-05-07 (plan 14 M1-M5) |
| `/activity` | ActivityScreen | `RecentActivityCubit` (limit=200, live-poll) | ✅ Done (M5 redesign — replaced legacy) |
| `/transcoding` | TranscodingScreen | `TranscodingCubit` + `ActivityCubit` | ✅ Done (M5 redesign) |
| `/transcoding/encoder` | EncoderSettingsScreen | `SettingsCubit` + `TranscodingCubit` | ✅ Done (M5 redesign) |
| `/transcode` | TranscodeScreen (Candidates / Queue / History tabs) | `TranscodeCubit` (factory; 2 s `/jobs` polling) | ✅ Done 2026-05-09 (plan 18 M5) |
| `/settings` | SettingsScreen | `SettingsCubit` | ✅ Done |
| `/profile` | ProfileScreen | `ProfileCubit` (factory) | ✅ Done |
| `/help` | HelpScreen | — (stateless; external "Get Help" link rows via `url_launcher`) | ✅ Done |
| `/showcase` | PrimitivesShowcaseScreen | — (stateless; M1 redesign primitives) | ✅ Done — renders outside `ShellRoute`; deep-link only |

Desktop uses `ShellRoute` with `FluxShell` wrapping every page — `FluxSidebar` (200 px collapsible nav rail) on the left, `FluxTitlebar` (M10 frameless titlebar) on top, `FluxStatusBar` (24 px telemetry strip) on the bottom, and the page content in the middle. The shell also mounts the notifications slide-over panel + the Cmd+K command-palette overlay in its `Stack`. No authentication required — all API calls are localhost-only (`require_local_caller`) or `validate_token_or_local`.
