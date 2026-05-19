# 03 — Mobile Architecture

> Flutter app at `apps/mobile/`. Android + iOS. Talks to `packages/fluxora_core` for shared code.

---

## App skeleton — entry to first frame

```mermaid
graph TB
  classDef root fill:#7c3aed,stroke:#fff,color:#fff
  classDef feat fill:#a78bfa,stroke:#000,color:#000
  classDef shared fill:#fde68a,stroke:#000,color:#000

  M[main.dart]:::root --> A[app.dart<br/>MaterialApp.router]:::root
  A --> Theme[AppTheme.dark]:::shared
  A --> BG[BackgroundGradient builder]:::shared
  A --> Router[core/router/app_router.dart]:::root
  Router --> Shell[StatefulShellRoute.indexedStack<br/>4 tab branches]:::root
  Shell --> THome[Home tab]:::feat
  Shell --> TLib[Library tab]:::feat
  Shell --> TSearch[Search tab]:::feat
  Shell --> TProfile[Profile tab]:::feat
  Router -. deep links .-> Outside["Outside-shell routes:<br/>/splash /connect /pairing<br/>/player /detail /episodes<br/>/notifications /upgrade<br/>/account /playback-prefs<br/>/scan-qr /reconnect<br/>/offline /xray /group-watch<br/>/doc-viewer /photo-viewer<br/>/music-player /library-files"]:::feat
```

---

## Feature modules (Clean Architecture per feature)

```mermaid
graph LR
  classDef onb fill:#7c3aed,stroke:#fff,color:#fff
  classDef core fill:#a78bfa,stroke:#000,color:#000
  classDef v11 fill:#6b7280,stroke:#374151,color:#fff,stroke-dasharray: 4 4

  subgraph Onboarding["Onboarding & connection"]
    Splash[splash_screen]:::onb
    Connect[connect: mDNS + manual IP]:::onb
    Auth[auth: pairing flow]:::onb
  end

  subgraph BrowseConsume["Browse & consume"]
    Home[home: Continue-watching + Browse + Recently-added]:::core
    Search[search]:::core
    Library[library: filter by kind/library]:::core
    Detail[detail: hero + cast + rails]:::core
    Episodes[episodes: season + episodes list]:::core
    Files[files: categorized rails per kind]:::core
  end

  subgraph Player["Player & viewers"]
    PlayerF[player: video via PlayerEngine]:::core
    DocViewer[viewer/doc_viewer: pdfx]:::core
    PhotoViewer[viewer/photo_viewer]:::core
    MusicPlayer[viewer/music_player: just_audio]:::core
  end

  subgraph UserSurface["User surface"]
    Profile[profile: settings hub]:::core
    Account[profile/account: edit display name]:::core
    Privacy[profile/privacy: device + caches]:::core
    Playback[profile/playback-prefs]:::core
    Groups[groups: PIN modals + group rows]:::core
    Notif[notifications: REST polling]:::core
    Upgrade[upgrade: tier comparison]:::core
  end

  subgraph V11Stubs["v1.1 stubs (hidden / opacity'd)"]
    Downloads[downloads]:::v11
    Offline[offline]:::v11
    XRay[xray]:::v11
    GroupWatch[group_watch]:::v11
  end
```

---

## Per-feature internal structure (Clean Architecture)

```mermaid
graph TB
  classDef pres fill:#7c3aed,stroke:#fff,color:#fff
  classDef dom fill:#a78bfa,stroke:#000,color:#000
  classDef dat fill:#fde68a,stroke:#000,color:#000

  subgraph Feature["feature/<name>/"]
    direction TB
    P[presentation/]:::pres
    P --> P1[screens/]
    P --> P2[cubit/ or bloc/]
    P --> P3[widgets/]
    P --> P4[sheets/]
    P --> Pctrl[controllers/]

    D[domain/]:::dom
    D --> D1[repositories/ interface]
    D --> D2[entities/]
    D --> D3[usecases/]

    Dat[data/]:::dat
    Dat --> Dat1[repositories/ impl]
    Dat --> Dat2[datasources/]
    Dat --> Dat3[dto/]

    P --> D
    Dat --> D
  end
```

**Rule:** presentation depends on domain. data implements domain. domain depends on nothing.

---

## State + dependency injection

```mermaid
graph LR
  classDef di fill:#7c3aed,stroke:#fff,color:#fff
  classDef cubit fill:#a78bfa,stroke:#000,color:#000
  classDef repo fill:#fde68a,stroke:#000,color:#000
  classDef core fill:#16a34a,stroke:#000,color:#fff

  Injector[core/di/injector.dart<br/>GetIt lazy singletons]:::di
  Injector --> ApiClient[ApiClient<br/>Dio + interceptors]:::core
  Injector --> SecStore[SecureStorage]:::core
  Injector --> Repos["Repositories<br/>(auth, library, files,<br/>profile, notifications,<br/>groups, ...)"]:::repo
  Injector --> Cubits["Cubits / Blocs<br/>(PlayerCubit,<br/>NotificationsCubit,<br/>ProfileCubit, ProfileStatsCubit,<br/>MobileGroupsCubit)"]:::cubit
  Repos --> ApiClient
  Repos --> SecStore
  Cubits --> Repos
  Screens[Feature screens] --> Cubits
```

`ApiClient`, `SecureStorage`, and most repositories live in `packages/fluxora_core`. See [05_shared_core.md](05_shared_core.md).

---

## Navigation map — visible tabs + key deep links

```mermaid
stateDiagram-v2
  [*] --> Splash
  Splash --> Connect : first launch
  Splash --> Home : token valid
  Connect --> Pairing : pick server
  Pairing --> Home : approved

  state "Bottom tabs (StatefulShell)" as Shell {
    Home --> Detail : tap item
    Home --> Notifications : bell
    Library --> Detail
    Library --> LibraryFiles : tap library
    Search --> Detail
    Profile --> Account
    Profile --> Privacy
    Profile --> Playback
    Profile --> Upgrade
  }

  Detail --> Player : Play
  Detail --> Episodes : Episodes
  Episodes --> Player

  LibraryFiles --> Player : video
  LibraryFiles --> DocViewer : pdf
  LibraryFiles --> PhotoViewer : image
  LibraryFiles --> MusicPlayer : audio

  Player --> XRay : top-bar chip (stub)
  Player --> GroupWatch : overflow (stub)
```

---

## Player engine selection (mobile-side)

```mermaid
flowchart TB
  classDef android fill:#16a34a,stroke:#000,color:#fff
  classDef ios fill:#3b82f6,stroke:#000,color:#fff
  classDef abstract fill:#7c3aed,stroke:#fff,color:#fff

  Cubit[PlayerCubit] --> Factory[PlayerEngineFactory.create]:::abstract
  Factory --> Q{Platform?}
  Q -- Android --> Q2{_kForceMediaKitOnAndroid?}
  Q2 -- no default --> Exo[ExoPlayerEngine<br/>Media3 1.10.1<br/>+ TonemappingRenderersFactory]:::android
  Q2 -- yes operator escape --> MK1[MediaKitEngine<br/>libmpv]:::ios
  Q -- iOS --> MK2[MediaKitEngine<br/>libmpv]:::ios
  Exo --> Surface[Android Surface texture]
  MK1 --> Surface
  MK2 --> Surface
```

See [10_player_engines.md](10_player_engines.md) for the full class diagram.

---

## Mobile-only direct deps (key ones)

| Package | Purpose |
|---|---|
| `media_kit` | libmpv-based player (desktop + iOS + Android-rollback) |
| `pdfx` | PDF viewer |
| `photo_view` | Pinch-zoom images |
| `just_audio` + `audio_service` | Audio playback + lockscreen |
| `mobile_scanner` | QR pairing |
| `screen_brightness` | Player brightness gesture |
| `connectivity_plus` | Wi-Fi-only streaming gate |
| `cached_network_image` | Thumbnail/poster cache |
| `share_plus` | Share-sheet for "other" file kinds |
| `lucide_icons_flutter` | Icon set |
| `google_fonts` | Typography |

Everything cross-platform lives in `packages/fluxora_core` — see [05_shared_core.md](05_shared_core.md).
