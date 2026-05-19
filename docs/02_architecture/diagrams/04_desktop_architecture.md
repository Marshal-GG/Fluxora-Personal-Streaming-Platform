# 04 — Desktop Architecture

> Flutter desktop control panel at `apps/desktop/`. Windows / macOS / Linux. Used by the **operator** (server admin), not end users.

---

## Shell + IA (post plan 26 redesign)

```mermaid
graph TB
  classDef shell fill:#7c3aed,stroke:#fff,color:#fff
  classDef rail fill:#a78bfa,stroke:#000,color:#000
  classDef tab fill:#fde68a,stroke:#000,color:#000

  Main[main.dart<br/>windowManager.ensureInitialized<br/>TitleBarStyle.hidden]:::shell
  Main --> App[app.dart<br/>MaterialApp.router]:::shell
  App --> Router[core/router/app_router.dart<br/>ShellRoute → FluxShell]:::shell

  Router --> Shell[FluxShell]:::shell
  Shell --> TB[FluxTitlebar<br/>36 px drag region<br/>help + bell + native caption]:::rail
  Shell --> SB[FluxSidebar<br/>232 px nav rail<br/>7 flat items]:::rail
  Shell --> Status[FluxStatusBar<br/>28 px CPU/RAM/NET/UP]:::rail
  Shell --> Content[Content area]

  SB --> N1[Dashboard]:::tab
  SB --> N2[Library shell]:::tab
  SB --> N3[Clients]:::tab
  SB --> N4[Activity shell]:::tab
  SB --> N5[Settings]:::tab
  SB --> N6[Profile]:::tab
  SB --> N7[Subscription]:::tab

  N2 --> L1[Libraries tab]
  N2 --> L2[Convert tab]
  N2 --> L3[Transcoding tab]

  N4 --> A1[Sessions tab]
  N4 --> A2[Logs tab]
```

---

## Feature inventory

```mermaid
mindmap
  root((apps/desktop/<br/>17 features))
    Operator surface
      dashboard
      library
      clients
      groups
      activity
      transcoding
      logs
      settings
    Account
      subscription
      profile
      orders
    Cross-cutting
      notifications
      help
      storage
      recent_activity
      system_stats
      command_palette
```

---

## Shared widget primitives (V2)

```mermaid
graph LR
  classDef prim fill:#7c3aed,stroke:#fff,color:#fff
  classDef chart fill:#a78bfa,stroke:#000,color:#000

  subgraph Layout
    FShell[flux_shell]:::prim
    FTitle[flux_titlebar]:::prim
    FSide[flux_sidebar]:::prim
    FStat[flux_status_bar]:::prim
    PageH[page_header]:::prim
    SectionL[section_label]:::prim
  end

  subgraph Form
    FBtn[flux_button<br/>primary/secondary/ghost/danger]:::prim
    FCard[flux_card<br/>glassmorphic]:::prim
    FTab[flux_tab_bar]:::prim
    FText[flux_text_field]:::prim
    FSel[flux_select]:::prim
    FSw[flux_switch]:::prim
    FSli[flux_slider]:::prim
  end

  subgraph Display
    Pill[pill<br/>7-color semantics]:::prim
    Dot[status_dot]:::prim
    StatT[stat_tile]:::prim
    Spark[sparkline]:::chart
    Donut[storage_donut]:::chart
    Prog[flux_progress]:::prim
  end
```

All primitives are previewable at the `/showcase` dev route.

---

## State + DI

```mermaid
graph LR
  classDef di fill:#7c3aed,stroke:#fff,color:#fff
  classDef cubit fill:#a78bfa,stroke:#000,color:#000
  classDef repo fill:#fde68a,stroke:#000,color:#000
  classDef svc fill:#16a34a,stroke:#000,color:#fff

  Injector[core/di/injector.dart<br/>GetIt]:::di
  Injector --> ApiClient[ApiClient<br/>fluxora_core]:::repo
  Injector --> Repos[Every repository]:::repo
  Injector --> Cubits["Cubits<br/>(Library, Storage,<br/>Activity, Logs,<br/>Clients, Groups,<br/>Settings, Profile,<br/>Notifications, Orders,<br/>Recent, Sys-stats,<br/>CommandPalette)"]:::cubit
  Injector --> Events[LibraryEventsService<br/>WS subscriber]:::svc
  Events -. library_changed .-> LibCubit[LibraryCubit]
  Events -. storage_changed .-> StoreCubit[StorageCubit]
  Cubits --> Repos
  Repos --> ApiClient
```

`LibraryEventsService` listens on `/api/v1/ws/notifications` and demuxes ephemeral `{type:"event"}` frames into broadcast streams that the Library and Storage cubits subscribe to — replaced 15 s polling timers at plan 26 refinement (2026-05-16).

---

## Frameless window — Windows runner

```mermaid
graph TB
  classDef cpp fill:#7c3aed,stroke:#fff,color:#fff
  classDef rc fill:#a78bfa,stroke:#000,color:#000

  Main[main.cpp]:::cpp
  Main --> AUMID[SetCurrentProcessExplicitAppUserModelID<br/>Fluxora.Desktop<br/>for Aero Peek]:::cpp
  Main --> Win[win32_window.cpp]:::cpp
  Win --> MinSz[WM_GETMINMAXINFO<br/>floor 1332×720]:::cpp
  Win --> Theme[UpdateTheme]:::cpp
  Win --> Class[WNDCLASSEX<br/>hIcon + hIconSm]:::cpp
  Class --> Icon[resources/app_icon.ico<br/>runtime copy of brand master]:::rc
  Main --> RC[Runner.rc<br/>ProductName/CompanyName/FileDescription]:::rc
  RC --> Pubspec[version from pubspec.yaml]
  CMake[CMakeLists.txt] --> Libs[links dwmapi.lib + shell32.lib]:::cpp
```

---

## Test surface

| Area | Count (as of 2026-05-09) | Notes |
|---|---|---|
| Unit + bloc tests | 104 | `apps/desktop/test/features/` |
| Golden tests | Dashboard | Opt-in via `--tags=golden`; GetIt-mock recipe in `test/goldens/_README.md` |
| Folder browser cubit | +16 (plan 28) | history + folder-size cache + sort/view/search |

Total trending ~137 as of plan 28 Phase D ship.

---

## Connecting to the server

The desktop control panel is **always-local-operator** — it talks to `http://localhost:8000` (or whatever port the server is on). It does **not** use the LAN/WebRTC smart-switching logic the mobile app uses — there's no need; it's on the same machine.

Auth: bearer token from initial pair (or local-bypass when running on same host — see `validate_token_or_local` in `routers/deps.py`).

---

## Where to find planning history

- Plan 26 — IA redesign + Library shell + Activity shell (active)
- Plan 28 — Folder browser power features (archived 2026-05-16)
- Plan 27 — Per-file thumbnail generation (active)

See [`docs/10_planning/`](../../10_planning/) for the full set.
