# Fluxora Mobile — Flutter Port Spec

> **Read this first.** This README is the source of truth for porting `Fluxora Mobile.html` (a high-fidelity React/JSX design prototype) to a production **Flutter** app. The HTML prototype is a *design artifact*, not a runnable codebase — its job is to nail down every screen, interaction, and visual token so a Flutter team (Claude Code or human) can implement it deterministically.
>
> If a detail isn't here, **the HTML is canonical**. Open `Fluxora Mobile.html` in a browser and use the design canvas to inspect every artboard pixel-for-pixel.

---

## 1 · Product overview

**Fluxora** is a self-hosted media server *and* client, in the Plex / Jellyfin / Emby category — but expanded beyond video to all file types. The **mobile app** has two modes the user can switch between:

1. **Client mode** (default) — connect to a Fluxora server (LAN or remote), browse libraries, stream/play media, download for offline.
2. **Host mode** — turn the phone *itself* into a server. Pair friends/family, share libraries, manage auth.

Supported media types (all first-class):

| Type | Examples | Player |
| ---- | -------- | ------ |
| **Movies** | `.mkv`, `.mp4`, `.avi` | Full video player (portrait + landscape) |
| **TV shows** | episodic with seasons | Same player + episode picker |
| **Music** | `.flac`, `.mp3`, `.m4a`, `.wav` | Album-art + scrubber + queue |
| **Photos** | `.jpg`, `.png`, `.heic` | Full-bleed gallery viewer |
| **Documents** | `.pdf`, `.docx`, `.xlsx`, `.md` | Page viewer + search |
| **Books / PDFs** | `.pdf`, `.epub` | Reader |

Key features: cast/Chromecast, X-Ray (cast & crew while watching), Group Watch (synced parties), offline downloads, hardware transcoding when hosting, end-to-end encryption with 2FA + invite codes.

---

## 2 · Source-of-truth files

The HTML prototype is split across small JSX files. Read them in this order (paths are relative to **the project root**, since this README lives in `app/mobile/`):

```
Fluxora Mobile.html                          ← entry point; lists script load order
app/shared/data/fluxora-data.jsx             ← FluxData: movies, libraries, clients, groups, activity, logs
app/shared/data/fluxora-data-2.jsx           ← FluxData2: invoices, movies (w/ posters), shows, music, docs, photos, shortcuts
app/shared/components/icons.jsx              ← Icon system (lucide-flavored SVGs, 1.6 stroke)
app/shared/components/logo.jsx               ← Wordmark + monogram
app/shared/components/primitives.jsx         ← Shared cross-platform primitives (used by desktop too)
app/mobile/components/mobile-primitives.jsx  ← Mobile-only: M (theme tokens), Phone shell, BottomTabs, MAppBar, MChip, Poster
app/mobile/design-canvas.jsx                 ← Just the canvas wrapper; skip for porting
app/mobile/screens/*.jsx                     ← One file per screen / screen group
app/mobile/mobile-app.jsx                    ← Final composition; lists every screen + the phone shell wrappers it uses
```

When in doubt, `mobile-app.jsx` shows exactly which screens exist and how each is mounted (with/without status bar, with/without bottom tabs, portrait/landscape, etc.).

> **Companion docs.** `app/desktop/README.md` is the matching Flutter port spec for the desktop app — read it if you're also porting Fluxora's server-management surface.

---

## 3 · Brand & design tokens

All values live in `app/mobile/components/mobile-primitives.jsx` as the `M` object. **Copy these verbatim into a Flutter `ThemeData` + a `FluxColors` constants class.**

### 3.1 Colors

| Token | Hex / rgba | Usage |
| --- | --- | --- |
| `bg` | `#08061A` | App background (deep purple-black) |
| `bgRaised` | `#0F0C24` | Elevated cards, modals |
| `bgCard` | `rgba(20,18,38,0.85)` | Card surface w/ slight transparency over gradient bg |
| `border` | `rgba(255,255,255,0.06)` | Default 1px borders |
| `borderStrong` | `rgba(255,255,255,0.12)` | Emphasized borders (focused inputs, etc.) |
| `fg` | `#F1F5F9` | Primary text |
| `fgMuted` | `#94A3B8` | Secondary text |
| `fgDim` | `#64748B` | Tertiary text, disabled |
| `accent` | `#A855F7` | Primary brand purple |
| `accent2` | `#8B5CF6` | Gradient partner for accent (use w/ accent in linear gradients) |
| `accentSoft` | `rgba(168,85,247,0.16)` | Tinted backgrounds, chips |
| `cyan` | `#22D3EE` | Secondary accent |
| `pink` | `#EC4899` | Tertiary accent (music, highlights) |
| `success` | `#10B981` | Online, paid, approved |
| `warn` | `#F59E0B` | Pending, throttled |
| `danger` | `#EF4444` | Errors, destructive actions |

**Background gradient** (apply to scaffold/body, *not* status bar):

```
radial-gradient(120% 60% at 0% 0%, rgba(168,85,247,0.18), transparent 50%),
radial-gradient(100% 60% at 100% 100%, rgba(34,211,238,0.10), transparent 50%),
#08061A
```

In Flutter, build this with a stack: `#08061A` solid + two `RadialGradient` containers positioned absolutely.

### 3.2 Typography

Font family: **Inter** (weights 400, 500, 600, 700, 800). On Flutter use the [`google_fonts`](https://pub.dev/packages/google_fonts) package or bundle Inter locally. JetBrains Mono is also loaded but only used for very rare numeric/monospace contexts (timestamps in logs).

Type scale used across the app (rem-free; values are absolute px):

| Role | Size | Weight | LineHt | Letter |
| --- | --- | --- | --- | --- |
| Display title | 22 | 800 | 1.15 | -0.3 |
| Screen title (app bar) | 17 | 700 | 1.2 | -0.1 |
| Section heading | 14 | 700 | 1.3 | 0 |
| Section eyebrow | 11 | 700 | 1.2 | 1.4 (UPPERCASE) |
| Body | 13.5 | 500/600 | 1.5 | 0 |
| Body small | 12 | 500 | 1.4 | 0 |
| Caption | 11 | 500 | 1.4 | 0 |
| Tab label | 10.5 | 500/700 | 1 | 0.1 |
| Status bar time | 14 | 600 | 1 | 0.2 |

### 3.3 Radii, spacing, elevation

- **Border radii:** 6 (chip), 8 (small button), 9 (icon button), 10 (input), 12 (card), 14 (raised card), 18 (album art), 38 (phone bezel — design only). Buttons/cards: prefer 10–14.
- **Spacing scale:** 4, 6, 8, 10, 12, 14, 18, 22, 28. Cards typically padded `14px`. Screen edge padding `16–22px`.
- **Shadows:** soft & dark.
  - Card: `0 6px 22px rgba(0,0,0,0.45), inset 0 0 0 1px rgba(255,255,255,0.06)`
  - Floating button / album art: `0 10px 30px rgba(168,85,247,0.5)` for accent, `0 20px 50px rgba(0,0,0,0.6)` for neutral.
- **Icon stroke:** **1.6px** lucide-style. Map to Flutter using [`flutter_lucide`](https://pub.dev/packages/flutter_lucide) or [`lucide_icons`](https://pub.dev/packages/lucide_icons). Icon-name mapping table below.

### 3.4 Icon mapping (HTML → Flutter Lucide)

The HTML uses an internal `<Icon name="…">` registry (see `app/shared/components/icons.jsx`). Flutter equivalents:

| HTML name | Lucide icon | HTML name | Lucide icon |
| --- | --- | --- | --- |
| `dashboard` | `LucideIcons.layoutDashboard` | `home` | use `dashboard` |
| `library` | `LucideIcons.bookOpen` | `search` | `LucideIcons.search` |
| `download` | `LucideIcons.download` | `upload` | `LucideIcons.upload` |
| `user` / `users` | `LucideIcons.user` / `users` | `bell` | `LucideIcons.bell` |
| `play` / `pause` / `stop` | `LucideIcons.play` / `pause` / `square` | `chevron` | `LucideIcons.chevronRight` |
| `chevronL` | `LucideIcons.chevronLeft` | `chevronD` | `LucideIcons.chevronDown` |
| `movie` | `LucideIcons.film` | `tv` | `LucideIcons.tv` |
| `music` | `LucideIcons.music` | `photo` | `LucideIcons.image` |
| `doc` / `file` | `LucideIcons.fileText` / `file` | `book` | `LucideIcons.book` |
| `folder` | `LucideIcons.folder` | `globe` | `LucideIcons.globe` |
| `shield` / `shieldCheck` | `LucideIcons.shield` / `shieldCheck` | `key` | `LucideIcons.key` |
| `qr` | `LucideIcons.qrCode` | `cpu` | `LucideIcons.cpu` |
| `bolt` / `zap` | `LucideIcons.zap` | `eye` | `LucideIcons.eye` |
| `refresh` | `LucideIcons.refreshCcw` | `trash` | `LucideIcons.trash2` |
| `moreH` | `LucideIcons.moreHorizontal` | `wifi` | `LucideIcons.wifi` |
| `server` | `LucideIcons.server` | `mail` | `LucideIcons.mail` |
| `creditCard` | `LucideIcons.creditCard` | `info` | `LucideIcons.info` |
| `alert` / `warn` | `LucideIcons.alertTriangle` | `check` | `LucideIcons.check` |
| `x` | `LucideIcons.x` | `plus` / `minus` | `LucideIcons.plus` / `minus` |
| `list` | `LucideIcons.list` | `grid` | `LucideIcons.layoutGrid` |
| `filter` | `LucideIcons.filter` | `sun` / `moon` | `LucideIcons.sun` / `moon` |

For anything missing, pick the visually-closest Lucide icon — the design intent is "thin-stroke utility icon," not a specific glyph.

---

## 4 · Information architecture

Fluxora Mobile has **28 screens** + **1 flow diagram**, organized into 9 sections in the prototype canvas. Each screen has a stable id used in the canvas — **use that id as the Flutter route name**.

### 4.1 Section-by-section

#### § 1 · Onboarding (entry)
| # | Route id | Title | Phone shell |
| - | -------- | ----- | ----------- |
| 01 | `splash` | Splash / Sign-in | Status bar + nav pill |
| 02 | `server` | Server picker | Status bar only |

#### § 2 · Discover
| # | Route id | Title | Bottom tab |
| - | -------- | ----- | ---------- |
| 03 | `home` | Home / Discover | `home` |
| 04 | `library` | Library | `library` |
| 05 | `search` | Search | `search` |
| 06 | `notifications` | Notifications | none (modal-style) |

#### § 3 · Title detail & playback
| # | Route id | Title | Notes |
| - | -------- | ----- | ----- |
| 07 | `detail` | Title Detail | Movie/show landing |
| 08 | `episodes` | Episodes list (TV) | Season picker + episode rows |
| 09 | `player-portrait` | Player · Portrait | `bg=#000`, status fg `#fff` |
| 10 | `mini-player` | Home with mini-player (PiP) | Home tab + bottom mini-player |

#### § 4 · Landscape player + legend
| # | Route id | Title | Notes |
| - | -------- | ----- | ----- |
| 11 | `player-landscape` | Player · Landscape | `orientation: landscape`, no status bar |
| 12 | `legend` | Player legend | **Spec only**, do not ship — annotated reference for designers |

#### § 5 · Modal sheets (bottom sheets shown over the player)
| # | Route id | Title |
| - | -------- | ----- |
| 13 | `audio-subs` | Audio & subtitles |
| 14 | `quality` | Streaming quality |
| 15 | `speed` | Playback speed |
| 16 | `sleep` | Sleep timer |
| 17 | `cast` | Cast picker |

#### § 6 · Features
| # | Route id | Title |
| - | -------- | ----- |
| 18 | `xray` | X-Ray panel (cast & crew while playing) |
| 19 | `group-watch` | Group Watch (synced party) |
| 20 | `offline` | Offline / empty state |

#### § 7 · Library management & account
| # | Route id | Title | Bottom tab |
| - | -------- | ----- | ---------- |
| 21 | `downloads` | Downloads | `downloads` |
| 22 | `profile` | Profile / Account | `profile` |

#### § 8 · Beyond video — every file type
| # | Route id | Title |
| - | -------- | ----- |
| 23 | `files-browser` | All files (categorized + recents) |
| 24 | `doc-viewer` | PDF / document viewer |
| 25 | `photo-viewer` | Photo viewer (full-bleed) |
| 26 | `music-player` | Music player (now playing) |

#### § 9 · Phone as a server
| # | Route id | Title |
| - | -------- | ----- |
| 27 | `host-server` | Host a server |
| 28 | `signin` | Sign-in / 2FA |

### 4.2 Navigation map (which screen leads where)

```
splash ──► signin ──► server ──► home (default tab)
                              └► host-server   (alt: become a server)

home ──► detail ──► player-portrait ⇄ player-landscape (rotate)
     │            └► episodes (if show) ──► player-portrait
     │
     ├► mini-player (when something is playing in background)
     └► music-player (if music tile)

library ──► detail | files-browser (per category)
files-browser ──► doc-viewer | photo-viewer | music-player

search ──► detail
notifications ◄── from app bar bell icon (any tab)

profile ──► host-server, signin (if signed out)
downloads ──► detail (resumes offline)

— While player is open —
player-portrait ──► [audio-subs | quality | speed | sleep | cast] (bottom sheets)
player-portrait ──► xray (side panel) | group-watch (modal)
```

The flow diagram artboard (`flow-diagram` in the canvas) renders this graphically; reference it during routing implementation.

---

## 5 · Component inventory

These are the **reusable widgets you will build first** in Flutter. Each maps to JSX components in the prototype.

### 5.1 Shell components

| HTML component | Flutter analog | Behavior |
| --- | --- | --- |
| `<Phone>` | *(prototype only — drop)* | The phone bezel exists only because the prototype runs in a browser. In Flutter the OS provides this. |
| `<PhoneStatusBar>` | `SystemUiOverlayStyle` | Use `SystemChrome.setSystemUIOverlayStyle` with light icons on dark; let OS handle. |
| `<BottomTabs>` | `BottomNavigationBar` *or* custom | 5 items: Home, Library, Search, Downloads, Profile. Active = `accent` color + bold; inactive = `fgDim`. Background `rgba(8,6,20,0.92)` with `BackdropFilter` blur 20. |
| `<MAppBar>` | `AppBar` (custom theme) | Height 52, `bg=rgba(8,6,20,0.85)` w/ blur 20, bottom border `border`. Supports `leading`, `trailing`, optional `onBack`. `transparent` variant has no bg/border (used over hero images, video). |

### 5.2 Display widgets

| Component | Description / props |
| --- | --- |
| `<Poster>` | Poster card with: `art` (gradient fallback), `img` (network image), `qual` badge top-left, title+year overlay bottom. Sizes vary: 116×174 (rail), 150×220 (hero), full-width (detail). Always w/ inset 1px border + bottom shadow. |
| `<MChip>` | Pill: `padding 7px 14px`, `radius 999`, `fontSize 12.5`, weight 600. Active = accent border + `accentSoft` bg + light purple text. |
| `<Row>` (settings row) | Defined in `extras.jsx`. Icon (left, in `accentSoft` square 36×36), label + sub stacked, optional `right` (chevron, switch, badge). Padding 12–14px, divider between rows. |
| Mini-player bar | At bottom of any tabbed screen. ~64px tall, poster 48×48 left, title+sub middle, play/close right. Tap → player. |
| Section eyebrow + heading | UPPERCASE 11px eyebrow in `fgDim`, then 14px bold. Used everywhere. |

### 5.3 Form widgets

- **Text input:** height 48, radius 10, `bg=rgba(255,255,255,0.04)`, border `border` (focused: `accentSoft`). 13.5px text.
- **Primary button:** height 48, radius 10, `linear-gradient(135deg, #8B5CF6, #A855F7)` background, white text, weight 700. Use `Container` with `BoxDecoration` + `LinearGradient`.
- **Secondary button:** same metrics, `bg=rgba(255,255,255,0.03)`, border `border`, fg text.
- **Destructive button:** `bg=rgba(239,68,68,0.10)`, border `rgba(239,68,68,0.3)`, text `#F87171`.
- **Switch:** native Cupertino-style; tint = accent.
- **Slider:** track `rgba(255,255,255,0.08)`, fill = `linear-gradient(90deg, #8B5CF6, #A855F7)`, thumb white 14×14 with shadow.

### 5.4 Bottom sheets

All five player sheets share this skeleton:

```
- Phantom backdrop: rgba(0,0,0,0.55)
- Sheet: bg=#0F0C24 → top radius 18, padding 16-20
- Drag handle: 40×4 rgba(255,255,255,0.18) centered top
- Title row: 17/700
- Options as rows with check on selected (accent)
```

In Flutter use `showModalBottomSheet` with `isScrollControlled: true` and a custom `shape`.

---

## 6 · Mock data shapes

The prototype uses JS objects on `window.FluxData` and `window.FluxData2`. Translate these to Dart **freezed/json_serializable** models. Field names are the contract — keep them.

### 6.1 `Movie`

```dart
class Movie {
  final String id;            // optional in FluxData2; required for routing
  final String title;
  final int year;
  final String runtime;       // human, e.g. "2h 28m"  (FluxData uses minutes int)
  final double rating;        // 0..10
  final String? genre;        // "Sci-Fi · Thriller"
  final String quality;       // "1080p", "1080p HDR", "4K HDR", "720p"
  final String? art;          // CSS gradient string — parse to LinearGradient (see §6.5)
  final String? img;          // TMDB poster URL
}
```

### 6.2 `Show`

```dart
class Show {
  final String title;
  final int seasons;
  final int episodes;
  final double rating;
  final String quality;
  final String? art;
  final String? img;
}
```

### 6.3 `Album` (music)

```dart
class Album {
  final String title;
  final String artist;
  final int year;
  final int tracks;
  final String art;           // gradient
}
```

### 6.4 `LibraryEntry`, `Client`, `Group`, `ActivityItem`, `LogLine`, `Transcode`, `Invoice`

See `fluxora-data.jsx` and `fluxora-data-2.jsx` for full shape. Build a Dart model per type; field names are kept verbatim.

### 6.5 Parsing CSS gradient strings

Many records carry `art` strings like `"linear-gradient(135deg, #1a0f2e, #3a1a5a 40%, #6b3aa6 100%)"`. Either:

- **Recommended:** Pre-process the data file at build time into `LinearGradient` objects (angle → `begin`/`end`, stops → `colors` + `stops`).
- **Quick path:** Use a parser package (e.g. `simple_gradient_text`) or write a tiny parser. Angle conversion: `135deg → Alignment.topLeft → Alignment.bottomRight`.

### 6.6 Image loading

All `img` fields are HTTPS URLs from `image.tmdb.org`. Use `cached_network_image`. **Always** show the gradient `art` as a placeholder *and* fallback on error — this is design-critical. The poster card never shows a broken-image icon.

---

## 7 · Per-screen specs

Below is enough to build each screen without reading the JSX. For pixel-level fidelity, refer to the matching JSX file.

### 7.1 Splash / Sign-in (`splash`) → `screens/splash.jsx`
- Centered Fluxora wordmark over the gradient bg.
- Tagline + two CTAs: **Sign in** (primary, full-width) and **Set up a server** (secondary).
- Footer: version + tiny "Privacy · Terms".
- On launch: splash for ~800ms then push `signin` if no token, else `home`.

### 7.2 Server picker (`server`) → `screens/extras.jsx::ServerPickerScreen`
- App bar "Choose a server".
- Top: "On this network" with discovered LAN servers (icon `server`, name, IP, latency badge). Pulse-animate the indicator dot.
- Below: "Recently used" + "Add manually" + "Sign in to a remote server".
- Tap → connects → routes to `home`.

### 7.3 Home (`home`) → `screens/home.jsx`
- App bar: avatar (left), Fluxora logo center, bell + cast (right).
- **Continue watching** rail (poster 116×174, progress bar 3px at bottom, resume time chip).
- **Trending now** rail.
- **Recently added** rail (use FluxData2.movies).
- **Your music** mini-rail (square album art).
- **Documents** quick-access tiles (file-type icon + name + size).
- Pull-to-refresh ⇒ re-fetch home feed.

### 7.4 Library (`library`) → `screens/library.jsx`
- App bar "Library".
- Filter chips: All · Movies · Shows · Music · Photos · Documents (horizontally scrollable).
- View toggle: grid / list.
- Sort: Recently added / A-Z / Year / Rating.
- Grid: 3-up posters with title + year underneath.

### 7.5 Search (`search`) → `screens/search.jsx`
- App bar with text field "Search Fluxora", scan/voice icons trailing.
- Empty state: "Recent searches", "Try" suggestion chips, popular categories.
- Active state: top-3 results horizontally scrollable, then sectioned (Movies, Shows, People).

### 7.6 Notifications (`notifications`) → `screens/extras.jsx::NotificationsScreen`
- App bar with back + "Mark all read".
- Grouped: Today / This week / Earlier.
- Each row: round colored icon, title, sub, timestamp, unread dot.

### 7.7 Detail (`detail`) → `screens/detail.jsx`
- Hero (full bleed, ~340px): backdrop image + dark gradient + title + meta (year · rating · duration · quality badge).
- Primary button: ▶ Play (gradient).
- Secondary: + Watchlist · Download · Share · Cast.
- Synopsis (3 lines, "more" expand).
- Cast row (avatar + name + role).
- Crew · Trailers · Similar titles · Reviews.

### 7.8 Episodes (`episodes`) → `screens/extras.jsx::EpisodesScreen`
- App bar with show title.
- Season selector chips.
- Episode list rows: thumbnail 120×68 + title + date + duration + progress bar.

### 7.9 Player · Portrait (`player-portrait`) → `screens/player-portrait.jsx`
- Black bg. Top: app bar (transparent, back, episode title + time-left, more).
- Center: large play/pause + skip ±10s.
- Bottom: scrubber (chapter markers visible), audio/subs, quality, speed, cast, x-ray, sleep buttons.
- Auto-hide controls after 3s; tap restores.

### 7.10 Mini-player (`mini-player`) → `screens/extras.jsx::HomeWithMiniPlayer`
- Home tab + persistent 64px bar above bottom nav.
- Poster 48×48 left, title + sub middle, play + x right.
- Tap bar → expands to full player.

### 7.11 Player · Landscape (`player-landscape`) → `screens/player-landscape.jsx`
- 892×412. No status bar.
- Same controls, but laid out as horizontal strips.

### 7.12 Player legend (`legend`)
- **Don't ship.** Designer's reference of gestures.

### 7.13 Bottom-sheet pickers (`audio-subs`, `quality`, `speed`, `sleep`, `cast`) → `screens/extras.jsx`
- All share the skeleton in §5.4.
- **Audio & subs:** two tabs (Audio / Subtitles), each with selectable rows incl. language and codec.
- **Quality:** Auto / 4K / 1080p / 720p / 480p; current selection has check.
- **Speed:** 0.5×, 0.75×, 1× (default), 1.25×, 1.5×, 2×.
- **Sleep:** Off, 15min, 30min, End of episode, Custom…
- **Cast:** discovered devices (TV, speaker, browser); tap → connect.

### 7.14 X-Ray (`xray`) → `screens/extras.jsx::XRayScreen`
- Side panel that slides in over the player.
- "On screen now": cast members in current scene (avatar, name, role, more).
- "Music in this scene", "Trivia", "Goofs".

### 7.15 Group Watch (`group-watch`) → `screens/extras.jsx::GroupWatchScreen`
- Hero: "Watching together".
- Avatars in a row at top. Reaction tray. Chat below.
- Sync status indicator (everyone within 1s).

### 7.16 Offline (`offline`) → `screens/extras.jsx::EmptyOfflineScreen`
- Empty illustration (use placeholder svg).
- Message: "You're offline" + "Showing downloads only".
- CTA: "View Downloads".

### 7.17 Downloads (`downloads`) → `screens/downloads.jsx`
- App bar "Downloads" + storage indicator.
- Tabs: All / Active / Completed.
- Rows: thumbnail + title + status (downloading 62%, paused, ready) + size.
- Per-row menu: pause/resume, delete, play offline.

### 7.18 Profile (`profile`) → `screens/profile.jsx`
- Hero: avatar, display name, plan badge.
- Sections (each a `Row`): Account, Server connections, Playback, Downloads, Notifications, Privacy & security, Appearance (theme), Help, About, Sign out.

### 7.19 All files (`files-browser`) → `screens/extras2.jsx::FileBrowserScreen`
- Categories grid 2-up: Movies, TV Shows, Music, Photos, Documents, Books & PDFs (each w/ count + size).
- "Recent files" list.

### 7.20 Document viewer (`doc-viewer`) → `screens/extras2.jsx::DocViewerScreen`
- App bar with download + more.
- Page area on dark; page itself white "paper" w/ shadow.
- Bottom toolbar: prev page, page indicator (1 / N), next page, search.

### 7.21 Photo viewer (`photo-viewer`) → `screens/extras2.jsx::PhotoViewerScreen`
- Black bg. Full-bleed photo (use `cached_network_image` + `InteractiveViewer` for pinch-zoom).
- Top: x, filename + date+index, more.
- Bottom: Share, Edit, Info, Save, Delete.

### 7.22 Music player (`music-player`) → `screens/extras2.jsx::MusicPlayerScreen`
- Vertical gradient bg `#1a0820 → #08061A`.
- App bar: chevronD + more.
- 280×280 album art with deep shadow.
- Title + artist + album.
- Scrubber (current / total time).
- Controls: shuffle, prev, play/pause (64px gradient circle), next, queue.

### 7.23 Host a server (`host-server`) → `screens/extras2.jsx::HostServerScreen`
- "Running" hero card (green w/ pulse dot, server name, IP, client count, uptime).
- Sections w/ Row stack:
  - **Authentication:** Password (on), 2FA (on), Pair via QR, Invite codes (3 active).
  - **Sharing:** Remote access (on), Friends & family, Shared libraries.
  - **Performance:** Hardware transcode (on), Background streaming (off).
- Destructive button at bottom: Stop server.

### 7.24 Sign-in / 2FA (`signin`) → `screens/extras2.jsx::SignInScreen`
- Eyebrow + greeting + connecting-to label.
- Email + Password fields; primary button.
- Divider "OR".
- Two secondary buttons: Scan QR to sign in, Use 6-digit invite code.
- Footer: Terms & Privacy.

---

## 8 · Recommended Flutter architecture

> These are guidelines; pick what your team is comfortable with. The prototype is **routing-** and **state-agnostic**.

### 8.1 Stack

- **Flutter** 3.22+ with **Dart** 3.4+
- **State management:** [Riverpod](https://riverpod.dev/) v2 (or Bloc). One provider per feature.
- **Routing:** [go_router](https://pub.dev/packages/go_router) — match the route ids from §4.1.
- **Models:** `freezed` + `json_serializable`.
- **Networking:** `dio` + `retrofit`. Backend is the Fluxora server (REST/WebSocket — TBD by backend team).
- **Local storage:** `drift` for offline downloads metadata, `flutter_secure_storage` for tokens.
- **Media:**
  - Video: [`media_kit`](https://pub.dev/packages/media_kit) (libmpv-based, supports HEVC/HDR) — preferred over `video_player`.
  - Audio: [`just_audio`](https://pub.dev/packages/just_audio) + `audio_service` for background.
  - Image cache: `cached_network_image`.
  - PDF: `pdfx` or `syncfusion_flutter_pdfviewer`.
  - Photo zoom: `photo_view` or `InteractiveViewer`.
- **Cast:** `flutter_cast_video` for Chromecast; AirPlay via platform channel on iOS.
- **Auth/2FA:** TOTP via `otp` package; QR via `mobile_scanner`.
- **Fonts/Icons:** `google_fonts` (Inter), `lucide_icons`.

### 8.2 Folder layout

```
lib/
  app.dart                       ← MaterialApp.router + theme
  main.dart                      ← runApp
  theme/
    flux_colors.dart             ← M tokens from §3
    flux_text_styles.dart        ← type scale from §3.2
    flux_theme.dart              ← ThemeData wiring
    flux_gradients.dart          ← parsed gradients + bg gradient
  router/
    app_router.dart              ← go_router config; route name = canvas id
    routes.dart                  ← const route names
  shared/
    widgets/
      flux_app_bar.dart          ← MAppBar
      flux_bottom_tabs.dart      ← BottomTabs
      flux_chip.dart             ← MChip
      flux_poster.dart           ← Poster
      flux_row.dart              ← Settings row
      flux_button.dart           ← Primary/secondary/destructive
      flux_text_field.dart
      flux_section_header.dart
      flux_mini_player.dart
      flux_bottom_sheet.dart     ← skeleton in §5.4
    models/
      movie.dart  show.dart  album.dart  client.dart  ...
    data/
      mock_data.dart             ← port FluxData + FluxData2 verbatim for now
  features/
    onboarding/  splash_page.dart  signin_page.dart  server_picker_page.dart
    home/        home_page.dart    home_provider.dart
    library/     library_page.dart
    search/      search_page.dart
    detail/      detail_page.dart  episodes_page.dart
    player/      player_portrait_page.dart  player_landscape_page.dart
                 sheets/audio_subs_sheet.dart  quality_sheet.dart  speed_sheet.dart
                          sleep_sheet.dart  cast_sheet.dart
                 xray_panel.dart  group_watch_page.dart
    files/       files_browser_page.dart  doc_viewer_page.dart
                 photo_viewer_page.dart   music_player_page.dart
    downloads/   downloads_page.dart  download_service.dart
    profile/     profile_page.dart  notifications_page.dart  invoices_page.dart
    host/        host_server_page.dart  invite_code_page.dart
```

### 8.3 Theming

```dart
final fluxTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: FluxColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: FluxColors.accent,           // #A855F7
    secondary: FluxColors.cyan,           // #22D3EE
    surface: FluxColors.bgRaised,         // #0F0C24
    error: FluxColors.danger,
  ),
  textTheme: fluxTextTheme,               // from §3.2
  fontFamily: GoogleFonts.inter().fontFamily,
  splashFactory: InkRipple.splashFactory,
);
```

Pair with the radial-gradient background in a global `Stack` that wraps the router's `Scaffold`s.

### 8.4 Routing

```dart
final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash',          name: 'splash',          builder: ...),
    GoRoute(path: '/signin',          name: 'signin',          builder: ...),
    GoRoute(path: '/server',          name: 'server',          builder: ...),
    ShellRoute(                       // bottom-tab shell
      builder: (ctx, state, child) => TabbedShell(child: child),
      routes: [
        GoRoute(path: '/home',        name: 'home',            ...),
        GoRoute(path: '/library',     name: 'library',         ...),
        GoRoute(path: '/search',      name: 'search',          ...),
        GoRoute(path: '/downloads',   name: 'downloads',       ...),
        GoRoute(path: '/profile',     name: 'profile',         ...),
      ],
    ),
    GoRoute(path: '/detail/:id',      name: 'detail',          ...),
    GoRoute(path: '/episodes/:id',    name: 'episodes',        ...),
    GoRoute(path: '/player/:id',      name: 'player-portrait', ...),
    GoRoute(path: '/files',           name: 'files-browser',   ...),
    GoRoute(path: '/files/doc/:id',   name: 'doc-viewer',      ...),
    GoRoute(path: '/files/photo/:id', name: 'photo-viewer',    ...),
    GoRoute(path: '/files/music/:id', name: 'music-player',    ...),
    GoRoute(path: '/host',            name: 'host-server',     ...),
    GoRoute(path: '/notifications',   name: 'notifications',   ...),
    GoRoute(path: '/xray/:id',        name: 'xray',            ...),
    GoRoute(path: '/group-watch/:id', name: 'group-watch',     ...),
  ],
);
```

Bottom sheets are not routes — they are launched with `showFluxBottomSheet(...)`.

### 8.5 State (Riverpod sketch)

Auth, current server, current playback session, downloads, and user settings each get their own `Notifier`. Example:

```dart
final playbackProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(
  PlaybackNotifier.new,
);

class PlaybackState {
  final Movie? title;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool isPlaying;
  final SubtitleTrack? subs;
  final AudioTrack? audio;
  final Quality quality;
  // ...
}
```

The mini-player listens to the same `playbackProvider`.

---

## 9 · Behaviors & motion

| Behavior | Spec |
| --- | --- |
| Pull-to-refresh | On Home, Library, Downloads, Notifications. Use accent-colored `RefreshIndicator`. |
| Bottom-tab switching | Crossfade 150ms. Selected icon scales 1.0 → 1.05 with weight bump to 700. |
| Pressed states | `InkWell` / `GestureDetector` with `splashColor: accentSoft`, `highlightColor: rgba(255,255,255,0.04)`. |
| Player auto-hide | Controls fade out 250ms after 3s idle; tap anywhere on video → fade in. |
| Skeleton loading | While fetching, show `Shimmer` (opacity 0.06 → 0.12 stripes) on poster cards and rows. |
| Pull-down on player | Drag handle on player → swipes down → minimizes to mini-player. |
| Rotation | Auto-rotate enabled in `player-portrait` only. Other screens: portrait-locked. |
| Status bar | `SystemUiOverlayStyle.light` everywhere except photo viewer w/ explicit `dark` icon variant if photo is bright (skip if too complex). |
| Haptics | Light impact on tab switch, selection, and primary button press. |

---

## 10 · Accessibility

- Minimum hit-target **44×44px** (already enforced in design).
- Every icon-only button needs a `Semantics(label: ...)`.
- Color contrast: `fg` on `bg` = ✅ AAA. `fgMuted` on `bg` = AA. **Never use `fgDim` for body text.**
- Player controls expose seek/skip via screen reader.
- Subtitle rendering must support OS-level captions style settings.
- Honor system text-scale up to 1.3× (cap to keep layout); fonts in design are `px`-equivalent, so scale via `MediaQuery.textScaleFactor.clamp(1.0, 1.3)`.

---

## 11 · Out of scope for first release

These exist in the prototype but ship later:
- Group Watch (full impl — complex sync).
- Casting to AirPlay (iOS-only, separate ticket).
- Phone-as-server **transcoding** (ship hosting w/ direct-play only first; transcode v2).
- X-Ray live cast detection from frame ML (use static metadata for now).
- 6-digit invite code redemption flow (UI exists, backend wiring v2).

---

## 12 · Acceptance criteria (a port is "done" when…)

1. Every route id from §4.1 resolves to a screen visually matching its prototype artboard.
2. All five bottom tabs are reachable; state survives backgrounding.
3. The player plays an HLS stream from a Fluxora server, with seek, audio/subs picking, quality switch, speed, sleep timer, cast, x-ray.
4. A movie can be downloaded, paused, resumed, and played offline.
5. Sign-in flow works with email+password and 2FA (TOTP).
6. The host-server screen toggles a real LAN-discoverable server (binary; on/off).
7. PDF, photo, music viewers each render their respective file types.
8. All `M.*` color tokens are referenced via `FluxColors`, not hardcoded.
9. All icons resolve via the mapping in §3.4.
10. Lighthouse-equivalent (perf): home loads to interactive < 1.5s on a Pixel 6.

---

## 13 · How to inspect the prototype

```bash
# Open the prototype in any modern browser
open "Fluxora Mobile.html"
```

Use the design canvas:
- **Pan:** drag empty space.
- **Zoom:** ⌘/Ctrl + scroll. Pinch on trackpad.
- **Focus an artboard:** double-click → fullscreen overlay; arrow keys cycle, Esc exits.
- **Read the source for any screen:** every label like `"03 · Home / Discover"` corresponds to a JSX file in `app/mobile/screens/`.

For pixel measurements: open browser devtools and inspect the DOM inside the artboard's iframe-like container. All sizes are absolute px (not rem).

---

## 14 · Glossary

| Term | Meaning |
| --- | --- |
| **Server** | A device running the Fluxora server daemon. Hosts libraries, transcodes, auth. |
| **Client** | A device consuming media. The mobile app is one. |
| **Library** | A typed collection (movies, shows, music, photos, docs). One server can host many. |
| **Direct play** | Streaming the original file as-is. |
| **Transcode** | Server re-encodes on the fly because client can't direct-play. |
| **Group Watch** | Synced playback session shared by 2+ clients with chat + reactions. |
| **X-Ray** | Cast-and-crew sidebar shown live during playback. |
| **Mini-player (PiP)** | 64px persistent bar above the bottom tabs while something plays in background. |
| **Invite code** | 6-digit code generated by a host; lets a friend pair without a password. |

---

*This document was written by the prototype's designer for a Flutter implementation team. Questions or contradictions: trust the JSX files in `app/mobile/`.*
