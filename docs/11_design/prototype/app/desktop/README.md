# Fluxora Desktop — Flutter Port Spec

> **Read this first.** This README is the source of truth for porting `Fluxora Desktop.html` (a high-fidelity React/JSX design prototype) to a production **Flutter Desktop** app (Windows / macOS / Linux). The HTML prototype is a *design artifact*, not a runnable codebase — its job is to nail down every screen, panel, and visual token so a Flutter team (Claude Code or human) can implement it deterministically.
>
> If a detail isn't here, **the HTML is canonical**. Open `Fluxora Desktop.html` in a browser and inspect every screen pixel-for-pixel.
>
> **Companion doc:** `app/mobile/README.md` is the Flutter port spec for the mobile client. The two share `app/shared/`.

---

## 1 · Product overview

**Fluxora Desktop** is the *server-side* counterpart to the mobile client. It is the application you install on a home server, NAS, or workstation that **hosts** your media library and exposes it to all clients (phones, tablets, TVs, browsers). Equivalent surface area: Plex Server settings UI, Jellyfin admin dashboard, qBittorrent's WebUI — but for media hosting.

It is **not** primarily a media-playback app — it's a **management console**. Operators use it to:

- Monitor server health (CPU, memory, disk, network, active streams)
- Manage libraries (folders to scan, metadata sources, artwork)
- See connected clients and what they're watching
- Group clients (Family / Friends / Work / Guests) with per-group access policies
- Watch a live activity feed
- Manage transcodes (in-progress + queued + encoder settings)
- Read server logs
- Configure server settings (network, security, storage, notifications)
- Manage the user's Fluxora subscription, billing, and profile

The mobile app from `app/mobile/` is one of the *clients* this server serves.

Target platforms (Flutter Desktop):
- **Windows** 10/11
- **macOS** 12+ (Apple Silicon + Intel)
- **Linux** (X11 + Wayland)

A web build (`flutter build web`) is *also* viable for a remote admin UI; design is web-friendly.

---

## 2 · Source-of-truth files

The HTML prototype is split across small JSX files. Read them in this order (paths are relative to **the project root**, since this README lives in `app/desktop/`):

```
Fluxora Desktop.html                         ← entry point; lists script load order + window chrome CSS
app/shared/data/fluxora-data.jsx             ← FluxData: movies, libraries, clients, groups, activity, logs, transcodes, cpuSpark
app/shared/data/fluxora-data-2.jsx           ← FluxData2: invoices, music, docs, photos, logFiles, shortcuts
app/shared/components/icons.jsx              ← Icon system (lucide-flavored, 1.6 stroke)
app/shared/components/logo.jsx               ← Fluxora wordmark + monogram
app/shared/components/primitives.jsx         ← Shared cross-platform primitives (StatusDot, etc.)
app/shared/components/tweaks-panel.jsx       ← Design-only Tweaks UI; skip for porting
app/desktop/components/sidebar.jsx           ← Left rail (nav + system status + upgrade card + user)
app/desktop/components/topbar.jsx            ← Title bar / breadcrumb / status footer
app/desktop/screens/*.jsx                    ← One file per primary screen
app/desktop/pages/*.jsx                      ← Sub-pages reachable from the screens (encoder settings, billing, etc.)
app/desktop/app.jsx                          ← Final composition: window chrome + sidebar + route table
```

When in doubt, `app/desktop/app.jsx` shows the exact route table and which sub-pages each top-level screen exposes.

---

## 3 · Brand & design tokens

The desktop and mobile apps **share the same brand DNA**. Token values match `app/mobile/README.md` §3 — refer to it for the canonical color, typography, radius, and shadow tables.

The few desktop-only deviations:

### 3.1 Window chrome

The HTML prototype renders inside a faux-window. **In Flutter Desktop, drop the prototype's title bar entirely** and use the OS-native title bar (or a custom one via [`bitsdojo_window`](https://pub.dev/packages/bitsdojo_window) if you want the integrated look). The prototype's chrome exists only because it runs in a browser.

If you do build a custom title bar, match these specs:

- Height **36px**, full-width
- Background `rgba(6,4,16,0.9)` with bottom border `rgba(255,255,255,0.04)`
- Left: Fluxora wordmark (13px tall) + tagline `· Stream. Sync. Anywhere.` in `#64748B`
- Right cluster: help (`?`), notifications (bell w/ purple dot indicator), then the OS window controls (minimize / maximize / close)

### 3.2 App-window backdrop

The whole window has a glassy gradient + blur:

```css
background: rgba(8,6,26,0.85);
backdrop-filter: blur(40px);
/* over the body's:
  radial-gradient(1200px circle at 0%   0%,   rgba(168,85,247,0.12), transparent 50%),
  radial-gradient(1000px circle at 100% 100%, rgba(34,211,238,0.06), transparent 50%),
  #08061A
*/
```

In Flutter, layer:
1. A `Stack` root.
2. Solid `#08061A` Container at the back.
3. Two `RadialGradient` containers positioned top-left & bottom-right.
4. The actual app shell on top, with a translucent overlay `rgba(8,6,26,0.85)`.

Skip the `backdrop-filter: blur(40px)` — that effect requires window transparency (set up via `bitsdojo_window` or `window_manager`); on platforms where it's unavailable, the radial gradients alone are visually sufficient.

### 3.3 Layout grid

- **Sidebar:** 232px fixed-width.
- **Content max-width:** none — content scales with window. Most screens use a 1-2 column responsive grid that stops adding columns at ~1600px.
- **Min window size:** 1100×720. Below that, switch to a "use the mobile app" empty state (or hide the sidebar).
- **Default window size:** 1440×900.

### 3.4 Status footer

Pinned to the bottom of the main window (below the content), an always-visible 28px-tall strip showing:
- Server status dot + "Server Running"
- Active streams count (`<n> active streams`)
- CPU % (live ticking, monospace)
- RAM in use
- Disk read/write
- Network up/down

Background `rgba(6,4,16,0.9)`, top border `rgba(255,255,255,0.04)`, JetBrains Mono for the numeric readouts at 11px.

---

## 4 · Information architecture

The desktop app has **9 top-level screens** + **6 sub-pages** + **3 overlays**. Top-level screens are reachable from the sidebar; sub-pages are reachable from inside their parent screen; overlays are reachable from anywhere.

### 4.1 Sidebar (top-level navigation)

| Order | Route id | Label | Sidebar icon | Default landing |
| ----- | -------- | ----- | ------------ | --------------- |
| 1 | `dashboard`     | Dashboard      | `dashboard`  | yes (initial route) |
| 2 | `library`       | Library        | `library`    |  |
| 3 | `clients`       | Clients        | `clients`    |  |
| 4 | `groups`        | Groups         | `groups`     |  |
| 5 | `activity`      | Activity       | `activity`   |  |
| 6 | `transcoding`   | Transcoding    | `transcode`  |  |
| 7 | `logs`          | Logs           | `logs`       |  |
| 8 | `settings`      | Settings       | `settings`   |  |
| 9 | `subscription`  | Subscription   | `crown`      |  |

The sidebar also contains:
- **System Status panel** (server-running w/ uptime, LAN IP, internet status)
- **Upgrade-to-Pro card** (links → `subscription`)
- **User footer button** (avatar + email; clicks → `profile`)

### 4.2 Sub-pages (reachable from a parent screen)

| Sub-page id | Reached from | File |
| ----------- | ------------ | ---- |
| `library-tabs` | `library` (folder card click) | `pages/library-tabs.jsx` |
| `encoder` | `transcoding` (encoder settings button) | `pages/encoder.jsx` |
| `logs-tabs` | `logs` (a row's "Open" action) | `pages/logs-tabs.jsx` |
| `settings-tabs` | `settings` (any settings sub-section) | `pages/settings-tabs.jsx` |
| `billing` | `subscription` (View invoices) | `pages/billing.jsx` |
| `manage-sub` | `subscription` (Manage plan) | `pages/manage-sub.jsx` |
| `profile` | sidebar user footer | `pages/profile.jsx` |
| `help` | title-bar `?` icon | `pages/help.jsx` |

### 4.3 Overlays (modals / panels — not routes)

| Overlay | Trigger | File |
| ------- | ------- | ---- |
| **Notifications panel** | title-bar bell | `pages/notifications.jsx` |
| **Tweaks panel** *(design-only)* | toolbar Tweaks toggle | `app/shared/components/tweaks-panel.jsx` — **don't ship** |
| **Command palette** *(spec'd, not yet implemented)* | `Ctrl/⌘ K` | n/a |

### 4.4 Navigation map

```
                ┌──────── sidebar ────────┐
                ▼                          ▼
            dashboard ─┬──► clients ─► (client detail panel)
                       ├──► library  ─► library-tabs (Movies | Shows | Music | Photos | Documents)
                       ├──► groups   ─► (group editor inline)
                       ├──► activity ─► (filter by type)
                       ├──► transcoding ─► encoder (settings sub-page)
                       ├──► logs     ─► logs-tabs (filter by source / level)
                       ├──► settings ─► settings-tabs (Network · Storage · Security · Notifications · Advanced)
                       └──► subscription ─┬─► billing (invoices)
                                          └─► manage-sub (change plan)

  (any screen) ──[bell]──► notifications-panel
              ──[user]──► profile
              ──[?]─────► help
              ──[Ctrl K]─► command-palette  (planned)
```

---

## 5 · Per-screen specs

Below: enough to build each screen without reading the JSX. For pixel-level fidelity, refer to the matching JSX file.

### 5.1 Dashboard (`dashboard`) → `screens/dashboard.jsx`

The home screen. 4-up KPI cards across the top, then split below.

- **KPI cards (4):** Active Streams, CPU Usage (with sparkline from `FluxData.cpuSpark`), Memory, Disk Used. Each: large number, small label, tiny delta vs yesterday, accent-colored sparkline / progress bar.
- **Live activity feed** (left, 60% width): scrollable list of `FluxData.activity` items, each with colored icon, title, sub, "X min ago".
- **Quick stats** (right, 40%): library counts (movies, shows, music, photos), top-watched today, transcode load.
- **Now streaming rail** (bottom, full-width): horizontal cards of currently-active sessions with poster + client name + progress bar.
- **Refresh:** the prop `tick` increments every 1.1s — re-render any "live" widget. In Flutter, replace with a `Timer.periodic` Riverpod provider.

### 5.2 Library (`library`) → `screens/library.jsx`

Manage which folders Fluxora indexes.

- Header: "Libraries" title + "+ Add Library" button (gradient).
- Grid of library cards from `FluxData.libraries` (Movies, TV Shows, Music, Documents, Photos, Anime). Each card: colored icon (per library `color`), name, files count, size, folder path (monospace), last-scan timestamp, "Scan now" + "Edit" buttons.
- Click a card → `library-tabs` sub-page with tabs: Overview · Files · Metadata · Artwork · Settings.
- Empty card at end: "Add a new library".

### 5.3 Clients (`clients`) → `screens/clients.jsx`

Two-pane layout.

- **Left:** searchable + filterable list of `FluxData.clients`. Each row: status dot, platform icon (iphone/android/laptop/tablet/tv), name, OS, IP, last-active. Active row highlighted with `accentSoft` bg.
- **Right (detail panel):** when a client is selected — large card with avatar, name, OS, IP, sessions count, watch time, first connected date.
  - If currently streaming: poster + title + quality + progress bar + Stop Stream button.
  - Action buttons: Disconnect, Block, Send message.
- Empty right panel: "Select a client" prompt.

### 5.4 Groups (`groups`) → `screens/groups.jsx`

Manage user groups (access control).

- Two-pane like Clients.
- **Left:** list of `FluxData.groups` rows showing: colored icon, name, sub, members count, access type (Full / Limited / View Only / No Access), status dot, restricted-flag.
- **Right (group editor):** members list (from `FluxData.groupMembers`), libraries this group can access (toggle list), permissions (download / cast / x-ray / group-watch), invite new member.
- "+ New Group" button top-right.

### 5.5 Activity (`activity`) → `screens/activity.jsx`

Real-time event log.

- Filter chips at top: All · Streams · Clients · Transcodes · Scans · System · Warnings.
- Time scope dropdown: Last hour / Last 24h / Last 7 days / All.
- Vertical timeline of `FluxData.activity` items with colored vertical bar on the left + icon bubble + title + sub + relative time.
- Auto-prepend new items at top (use the `tick` ticker from app shell).

### 5.6 Transcoding (`transcoding`) → `screens/transcoding.jsx`

Live transcode queue + encoder settings.

- **Active transcodes** section: rows from `FluxData.transcodes` (status === "active"). Each row: title, client, source format, target format, **progress bar** (driven by `progress` field), live FPS, speed multiplier, Cancel button.
- **Queued** section: same shape, status === "queued".
- **Encoder settings** card top-right or as button → opens `encoder` sub-page.
- **Encoder sub-page (`pages/encoder.jsx`):** form fields for hardware-acceleration (NVENC / QuickSync / VAAPI / VideoToolbox / CPU), bitrate strategy, max simultaneous transcodes, segment length, etc. Save / Cancel buttons.

### 5.7 Logs (`logs`) → `screens/logs.jsx`

Server log viewer.

- **Top toolbar:** level filter chips (All · INFO · WARN · ERROR), source dropdown, search input, time scope, Pause/Resume tail toggle, Download .log button.
- **Log table** (monospace): rows from `FluxData.logs` — timestamp · level (color-coded badge) · source · message. Sticky header. Virtualized list (use `flutter_listview` or built-in `ListView.builder`).
- ERROR rows have left red bar; WARN have amber bar.
- Click a row → expand inline with full stack/JSON.
- "Open in tabs" → `logs-tabs` sub-page with one tab per log file from `FluxData2.logFiles`.

### 5.8 Settings (`settings`) → `screens/settings.jsx`

Server configuration.

- Sectioned page (single column or 2-col on wide windows). Sections + their typical fields:
  - **Server identity:** name, port, public hostname.
  - **Network:** LAN-only toggle, remote-access via Fluxora relay, NAT-PMP, custom port forwarding rules.
  - **Storage:** library scan schedule, metadata cache size, thumbnail quality, transcode temp dir.
  - **Security:** require sign-in, password policy, 2FA enforcement, allowed IP ranges, session timeout.
  - **Notifications:** email on errors, on new connections, on storage warnings; webhook URL.
  - **Advanced:** developer mode, log verbosity, telemetry opt-out.
- Each section can be expanded into its own `settings-tabs` page for richer editing.

### 5.9 Subscription (`subscription`) → `screens/subscription.jsx`

Plan management.

- Hero card: current plan badge, next renewal date, payment method, Manage / Cancel.
- 3-up plan cards (Free / Plus / Pro) with feature checklist; current plan highlighted.
- "View invoices" button → `billing` sub-page.
- "Manage plan" button → `manage-sub` sub-page with plan-change form.

### 5.10 Sub-page · Billing (`billing`) → `pages/billing.jsx`

- Table from `FluxData2.invoices`: ID · Date · Description · Amount · Status (Paid / Refund) · Method.
- Each row: download invoice (PDF) button.
- Top: payment method card with last-4 digits, expiry, "Update card".

### 5.11 Sub-page · Manage subscription (`manage-sub`) → `pages/manage-sub.jsx`

- Plan selector (Free / Plus / Pro).
- Billing-cycle toggle (Monthly / Annual − save 16%).
- Order summary on the right: line items, total, Confirm change button.

### 5.12 Sub-page · Profile (`profile`) → `pages/profile.jsx`

- Avatar + display name + email.
- Sections: Account, Linked devices, API tokens (show + revoke), Sign-in QR, Theme, Sign out.

### 5.13 Sub-page · Help (`help`) → `pages/help.jsx`

- Search-the-docs input.
- Quick links: Getting started · Library setup · Networking · Transcoding · FAQ · Contact support.
- Keyboard-shortcuts table from `FluxData2.shortcuts` (groups: Global, Navigation, Streaming).

### 5.14 Overlay · Notifications (`notifications`) → `pages/notifications.jsx`

- Slide-in right panel, ~360px wide, full-height.
- Tabs: All · Unread · Mentions.
- Sectioned by Today / This week / Earlier.
- Each row: colored icon, title, sub, timestamp, unread dot, mark-as-read X.
- Footer: "Mark all read", "Notification settings →".

---

## 6 · Component inventory

Reusable widgets to build first, in order of dependency:

### 6.1 Shell

| Component | Flutter analog | Notes |
| --- | --- | --- |
| **Title bar** | Custom widget + `bitsdojo_window` | Or skip entirely and use OS-native chrome (recommended). |
| **Sidebar** | Custom `Drawer`-like widget | 232px fixed, scrollable nav, system-status panel pinned bottom, upgrade card + user footer below. |
| **NavItem** | Custom `InkWell` row | Active state: `bg=accentSoft`, border `accent` 30%, text `#E9D5FF`, weight 600. Hover: `bg=rgba(255,255,255,0.03)`. |
| **StatusBar (footer)** | `Container` 28px tall | See §3.4. |
| **Page scaffold** | A common widget that takes title + actions and lays out a screen with consistent padding (24/28px) and breathing room. |

### 6.2 Display widgets

| Component | Description |
| --- | --- |
| **KPI card** | Large number, label, sparkline (use `fl_chart` or custom `CustomPaint`), trend delta. |
| **Sparkline** | 40-point line over `cpuSpark`. Stroke `accent`, fill = vertical gradient from accent to transparent. |
| **StatusDot** | 8×8 circle with glow shadow. Variants: `online` (`#10B981`), `idle` (`#F59E0B`), `offline` (`#64748B`), `active` (pulsing `#A855F7`). Already implemented in `app/shared/components/primitives.jsx`. |
| **Library card** | 240px tall card, icon top-left, name + meta, action buttons bottom. Uses `hoverable-card` CSS class — port to `MouseRegion` + state-driven decoration. |
| **Client / Group row** | Multi-column row with avatar/icon, name, status dot, IP, last-active, hoverable. Use `Row` with constrained-width children. |
| **Activity item** | Vertical timeline cell: colored vertical bar + icon bubble + title/sub + rel time. |
| **Log row** | Monospace 11px row with color-coded level badge, sticky header in viewport. |
| **Transcode row** | Title + client + source→target + progress bar + FPS + speed + cancel. |

### 6.3 Form widgets

- **Primary button:** height 36, radius 8, gradient `linear-gradient(135deg, #8B5CF6, #A855F7)`, white text, weight 600, font 13px.
- **Secondary button:** same metrics, `bg=rgba(255,255,255,0.04)`, border `rgba(168,85,247,0.4)`, text `#E2E8F0`. Hover: `bg=rgba(168,85,247,0.10)`.
- **Ghost button:** transparent bg, `#94A3B8` text, no border. Hover: `bg=rgba(255,255,255,0.03)`.
- **Toolbar icon button (`tbBtn`):** 26×26, radius 6, `bg=rgba(255,255,255,0.03)`, border `rgba(255,255,255,0.05)`.
- **Window control button (`winBtn`):** transparent, no border, just an icon — desktop-only.
- **Text input:** height 32–36, radius 8, `bg=rgba(255,255,255,0.04)`, border `rgba(255,255,255,0.06)` (focused: `rgba(168,85,247,0.5)`).
- **Switch:** native Cupertino-style; tint = accent.
- **Tabs:** underline-style, active = accent underline + bold + white text, inactive = `fgMuted`.

### 6.4 Tooltips & menus

Hover tooltips for icon-only buttons (Help, Notifications, window controls). Use the [`tooltip`](https://api.flutter.dev/flutter/material/Tooltip-class.html) widget; restyle decoration to match: `bg=rgba(15,12,36,0.96)`, text `#E2E8F0`, radius 6, padding `6 10`.

Right-click context menus on rows (e.g. log row → Copy / Export / Pin) via [`flutter_context_menu`](https://pub.dev/packages/flutter_context_menu) or a custom `PopupMenuButton`.

---

## 7 · Mock data shapes

The desktop pulls from the same shared mocks as mobile (`window.FluxData`, `window.FluxData2` in the JSX). See `app/mobile/README.md` §6 for the full Dart model contracts. Desktop-specific shapes:

### 7.1 `Client` (extends mobile)

```dart
class Client {
  final String id;
  final String name;
  final String os;             // "iOS 17.4", "Windows 11", ...
  final ClientType type;       // Mobile | Desktop | Tablet | TV
  final String ip;             // "192.168.1.101"
  final ClientStatus status;   // online | idle | offline
  final String lastActive;     // "Now", "5m ago", ...
  final StreamSession? stream; // current playback (if any)
  final int? sessions;         // total sessions count
  final String? watchTime;     // "18h 45m"
  final String? firstConn;     // "May 18, 2025 10:15 AM"
  final String platformIcon;   // "iphone" | "android" | "laptop" | "tablet" | "tv"
}

class StreamSession {
  final String title;
  final String quality;        // "1080p HDR", "720p (Transcoding)"
  final double progress;       // 0..1
  final String? watched;       // "45m of 2h 28m"
}
```

### 7.2 `Group`

```dart
class Group {
  final String id;
  final String name;
  final String sub;
  final int members;
  final String access;         // "Full Access" | "Limited Access" | "View Only" | "No Access" | "Custom"
  final String created;
  final GroupStatus status;    // active | pending | inactive
  final String icon;           // "users" | "briefcase" | "crown" | "user" | "shield"
  final String color;          // hex
  final bool restricted;
}
```

### 7.3 `ActivityItem`

```dart
class ActivityItem {
  final int id;
  final String type;           // "stream" | "client" | "transcode" | "scan" | "system" | "warning"
  final String title;
  final String msg;
  final String sub;
  final String ago;
  final String color;          // hex (per-type accent)
  final String icon;
}
```

### 7.4 `LogLine`

```dart
class LogLine {
  final String time;           // "2025-05-21 15:42:31.123"
  final LogLevel level;        // INFO | WARN | ERROR | DEBUG
  final String source;         // "Server" | "Database" | "Network" | "Streaming" | ...
  final String msg;
}
```

### 7.5 `Transcode`

```dart
class Transcode {
  final String id;
  final String title;
  final String client;
  final String source;         // "4K HEVC", "1080p"
  final String target;         // "720p H.264"
  final double progress;       // 0..1
  final int fps;
  final double speed;          // 1.4× realtime
  final TranscodeStatus status;// active | queued | done | failed
}
```

### 7.6 `Invoice`

```dart
class Invoice {
  final String id;             // "INV-2025-0521"
  final String date;
  final String desc;
  final String amount;         // "$4.99" or "-$10.00"
  final InvoiceStatus status;  // Paid | Refund | Pending
  final String method;         // "Visa ····4242"
}
```

---

## 8 · Recommended Flutter Desktop architecture

> Guidelines, not law. Pick what fits your team.

### 8.1 Stack

- **Flutter** 3.22+ (Desktop stable), **Dart** 3.4+.
- **Window management:** [`bitsdojo_window`](https://pub.dev/packages/bitsdojo_window) *or* [`window_manager`](https://pub.dev/packages/window_manager) for custom title bar / size / minimize-to-tray.
- **State:** Riverpod v2 (or Bloc).
- **Routing:** `go_router` — match the route ids from §4. Sub-pages are nested routes; overlays are *not* routes.
- **Models:** `freezed` + `json_serializable`.
- **Networking:** `dio` + `retrofit`. The desktop server is itself the backend — but the *admin UI* still makes local API calls to the server daemon (typically `localhost:port`) over REST + WebSocket. Use a WebSocket for live activity, transcode progress, and logs tail.
- **Charts / sparklines:** [`fl_chart`](https://pub.dev/packages/fl_chart) for KPI sparklines and the activity timeline.
- **Tables / virtualized lists:** built-in `ListView.builder` is fine for ≤10k rows; for log tail use [`scrollable_positioned_list`](https://pub.dev/packages/scrollable_positioned_list).
- **System tray:** [`tray_manager`](https://pub.dev/packages/tray_manager) — menu items: Open Fluxora, Pause Server, Quit.
- **Notifications (OS):** [`local_notifier`](https://pub.dev/packages/local_notifier).
- **Hotkeys:** [`hotkey_manager`](https://pub.dev/packages/hotkey_manager) for global shortcuts (Ctrl K command palette, Ctrl B sidebar toggle — see `FluxData2.shortcuts`).
- **Fonts/Icons:** `google_fonts` (Inter + JetBrains Mono), `lucide_icons`.

### 8.2 Folder layout

```
lib/
  app.dart                       ← MaterialApp.router + theme + WindowManager init
  main.dart                      ← runApp + bitsdojo_window setup
  theme/
    flux_colors.dart             ← M tokens (shared with mobile)
    flux_text_styles.dart
    flux_theme.dart
    flux_gradients.dart
  router/
    app_router.dart              ← go_router with route names = §4 ids
    routes.dart
  shell/
    main_window.dart             ← Title bar + Sidebar + content area + StatusBar
    title_bar.dart
    sidebar/
      sidebar.dart
      nav_item.dart
      system_status_panel.dart
      upgrade_card.dart
      user_footer.dart
    status_bar.dart
  shared/
    widgets/
      kpi_card.dart
      sparkline.dart
      status_dot.dart
      flux_button.dart
      flux_text_field.dart
      flux_tabs.dart
      flux_table.dart
      hoverable_card.dart
      empty_state.dart
    models/
      client.dart  group.dart  activity_item.dart  log_line.dart
      transcode.dart  invoice.dart  library_entry.dart  ...
    data/
      mock_data.dart             ← port FluxData + FluxData2 verbatim for seed
    services/
      server_api.dart            ← REST client (dio + retrofit)
      server_socket.dart         ← WebSocket for live tails
      hotkeys.dart
      tray.dart
      notifications.dart
  features/
    dashboard/   dashboard_page.dart   dashboard_provider.dart
    library/     library_page.dart     library_tabs_page.dart
    clients/     clients_page.dart     client_detail_panel.dart
    groups/      groups_page.dart      group_editor_panel.dart
    activity/    activity_page.dart
    transcoding/ transcoding_page.dart encoder_page.dart
    logs/        logs_page.dart        logs_tabs_page.dart  log_row.dart
    settings/    settings_page.dart    settings_tabs_page.dart
    subscription/subscription_page.dart billing_page.dart  manage_sub_page.dart
    profile/     profile_page.dart
    help/        help_page.dart
    notifications_panel/  notifications_panel.dart
    command_palette/      command_palette.dart   ← v2
```

### 8.3 Routing (go_router sketch)

```dart
final router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(                            // sidebar shell
      builder: (ctx, state, child) => MainWindow(child: child),
      routes: [
        GoRoute(path: '/dashboard',    name: 'dashboard',    builder: ...),
        GoRoute(path: '/library',      name: 'library',      builder: ...,
          routes: [
            GoRoute(path: 'tabs/:tab', name: 'library-tabs', builder: ...),
          ],
        ),
        GoRoute(path: '/clients',      name: 'clients',      builder: ...),
        GoRoute(path: '/groups',       name: 'groups',       builder: ...),
        GoRoute(path: '/activity',     name: 'activity',     builder: ...),
        GoRoute(path: '/transcoding',  name: 'transcoding',  builder: ...,
          routes: [
            GoRoute(path: 'encoder',   name: 'encoder',      builder: ...),
          ],
        ),
        GoRoute(path: '/logs',         name: 'logs',         builder: ...,
          routes: [
            GoRoute(path: 'tabs',      name: 'logs-tabs',    builder: ...),
          ],
        ),
        GoRoute(path: '/settings',     name: 'settings',     builder: ...,
          routes: [
            GoRoute(path: 'tabs/:tab', name: 'settings-tabs',builder: ...),
          ],
        ),
        GoRoute(path: '/subscription', name: 'subscription', builder: ...,
          routes: [
            GoRoute(path: 'billing',   name: 'billing',      builder: ...),
            GoRoute(path: 'manage',    name: 'manage-sub',   builder: ...),
          ],
        ),
        GoRoute(path: '/profile',      name: 'profile',      builder: ...),
        GoRoute(path: '/help',         name: 'help',         builder: ...),
      ],
    ),
  ],
);
```

Notifications panel is launched with `showFluxNotificationsPanel(context)` — it slides in from the right; not a route.

### 8.4 State (Riverpod sketch)

Live data streams (tick @ 1Hz–1.1Hz in the prototype) become Stream providers driven by WebSocket events:

```dart
final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) {
  return ref.watch(serverSocketProvider).statsStream;
});

final activityFeedProvider = StreamProvider<List<ActivityItem>>((ref) {
  return ref.watch(serverSocketProvider).activityStream;
});

final logsTailProvider = StreamProvider<List<LogLine>>((ref) {
  return ref.watch(serverSocketProvider).logsStream;
});
```

Static data (libraries, groups, settings) goes through `FutureProvider` / `NotifierProvider` against the REST API.

---

## 9 · Behaviors & motion

| Behavior | Spec |
| --- | --- |
| **Hoverable card** | All cards: `transition: all 200ms ease`. On hover, border becomes `rgba(168,85,247,0.4)`, bg becomes `rgba(168,85,247,0.05)`. Implement with `MouseRegion` + an `AnimatedContainer`. |
| **Sidebar nav transition** | Active state has 100ms ease-in for bg/border/color changes. |
| **Sidebar collapse** | (Planned) 232 → 56px collapse on `Ctrl B`. Show only icons; tooltips on hover. |
| **Live tickers** | Sparklines, KPI numbers, log tail update at ~1Hz. **Do not flicker** the whole row — animate the new value with a `TweenAnimationBuilder`. |
| **Status dots** | `online` static, `active` pulses (1s ease-in-out scale 1.0 → 1.2 with halo). |
| **Activity feed** | New items slide in from top with 200ms ease-out + brief 300ms accent flash on the colored bar. |
| **Log tail** | New rows appear at bottom; auto-scroll only if user is at bottom (sticky tail). User scroll-up pauses tailing → show "Tailing paused — jump to live" pill. |
| **Tab switch** | Crossfade 120ms. |
| **Page transitions** | None — sub-page swap is instant within the same shell. |
| **Window resize** | Sidebar fixed; content reflows. Below 1100px wide, sidebar collapses automatically. |

---

## 10 · Keyboard shortcuts

Source of truth: `FluxData2.shortcuts`. Implement via `hotkey_manager` (global) + `Shortcuts/Actions` widgets (in-app focus).

| Group | Action | Combo |
| --- | --- | --- |
| Global | Open Command Palette | `Ctrl/⌘ K` |
| Global | Show Shortcuts | `Ctrl/⌘ /` |
| Global | Toggle Sidebar | `Ctrl/⌘ B` |
| Global | Search Library | `Ctrl/⌘ F` |
| Global | Quick Settings | `Ctrl/⌘ ,` |
| Navigation | Dashboard | `G then D` |
| Navigation | Library | `G then L` |
| Navigation | Clients | `G then C` |
| Navigation | Activity | `G then A` |
| Navigation | Settings | `G then S` |
| Streaming | Pause/Resume Active | `Space` |
| Streaming | Stop All Streams | `Ctrl/⌘ Shift X` |
| Streaming | Restart Server | `Ctrl/⌘ Shift R` |
| Streaming | Clear Cache | `Ctrl/⌘ Shift K` |

The Help page (`pages/help.jsx`) renders this same table; keep them synced via a single source.

---

## 11 · Platform integration

### 11.1 System tray

- Tray icon (Fluxora monogram, white over transparent).
- Menu:
  - **Open Fluxora** — restore window
  - **Server: Running ✓** — submenu: Pause / Restart / Stop
  - **Active streams: 3** (read-only)
  - ──
  - **Quick Settings** → opens settings page
  - **Help** → opens help page
  - ──
  - **Quit Fluxora**
- Click on icon → toggle main window visibility.

### 11.2 Window behavior

- Close button → minimize to tray (configurable; default true on Win/Linux, off on macOS).
- macOS: support full-screen mode + traffic-light buttons in custom chrome.
- Remember last window size + position across launches (use `shared_preferences`).

### 11.3 Auto-start

- macOS: LaunchAgents plist.
- Windows: registry entry under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
- Linux: `~/.config/autostart/fluxora.desktop`.
- Toggle in Settings → Advanced.

### 11.4 OS notifications

Use `local_notifier` for:
- Server errors
- New client first-connect
- Storage low warnings
- Transcode failures

---

## 12 · Out of scope for first release

These exist (or are stubbed) in the prototype but ship later:
- **Command palette** (`Ctrl K`) — designed only.
- **Sidebar collapse / icon-only mode** — designed, not wired.
- **In-app "Update available" flow** — design TBD.
- **Multi-server management** — current UI assumes one local server. Adding remote-server picker = v2.
- **Plugin marketplace** — out of scope.
- **i18n** — English-only at launch; structure strings via `flutter_intl` from day one to ease the eventual port.

---

## 13 · Acceptance criteria (a port is "done" when…)

1. App launches into Dashboard with a live (mock or real) feed, KPI sparklines tick at ~1Hz.
2. All 9 sidebar items navigate to functional screens.
3. Each sub-page (`library-tabs`, `encoder`, `logs-tabs`, `settings-tabs`, `billing`, `manage-sub`, `profile`, `help`) is reachable from its parent and back-navigates correctly.
4. Notifications panel opens from the title-bar bell, slides in from the right, and lists items.
5. Custom title bar (or OS chrome) shows the wordmark, tagline, help/bell icons, and window controls (close → tray on Win/Linux).
6. Status footer is always visible and updates from a live stat stream.
7. The Logs page tails the server log over WebSocket; pause-on-scroll behavior works.
8. Transcoding page shows an active job with live progress + FPS + speed.
9. Hoverable cards and `NavItem` active states match the prototype.
10. All hotkeys from §10 are wired.
11. App lives in the system tray; closing the window minimizes to tray (per §11.1, configurable).
12. All `M.*` color tokens are referenced via `FluxColors`, not hardcoded.
13. Window remembers size + position across restart.
14. Dashboard fully renders < 1.5s on a typical dev machine.

---

## 14 · How to inspect the prototype

```bash
# Open in any modern browser
open "Fluxora Desktop.html"
```

Tips:
- Resize the browser window to see how the layout responds.
- Open dev tools, hover any element to read its computed styles — all sizes are absolute px.
- Sidebar nav switches the route via React state in `app/desktop/app.jsx`. Each route id corresponds to a screen file in `app/desktop/screens/` or a sub-page in `app/desktop/pages/`.

---

## 15 · Glossary

| Term | Meaning |
| --- | --- |
| **Server** | The desktop app itself — hosts libraries and serves clients. |
| **Client** | A device consuming media from this server. |
| **Library** | A typed collection (movies, shows, music, photos, docs) on disk. |
| **Direct play** | Streaming a file as-is, no re-encoding. |
| **Transcode** | Live re-encoding for clients that can't direct-play the source. |
| **NVENC / QuickSync / VAAPI / VideoToolbox** | Hardware-accelerated transcoding APIs (Nvidia / Intel / Linux / Apple). |
| **WebRTC relay** | Fallback path for remote clients when direct connection fails. |
| **Group** | A collection of clients with shared access policies. |
| **Tail** | Live-following a log file as new lines are written. |

---

*This document was written by the prototype's designer for a Flutter Desktop implementation team. Questions or contradictions: trust the JSX files in `app/desktop/`.*
