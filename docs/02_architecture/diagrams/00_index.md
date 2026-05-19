# Architecture Diagrams — Index

> Visual map of the Fluxora system. Each file focuses on one view; together they cover the whole app.
>
> **Render with:** VS Code Markdown Preview + `bierner.markdown-mermaid` extension (`Ctrl+K V`) — or push to GitHub and view there.

---

## Reading order

Start at the top and drill down as needed.

| # | File | Scope |
|---|------|-------|
| 01 | [System Landscape](01_system_landscape.md) | Top-level: server, mobile, desktop, web, external services |
| 02 | [Server Architecture](02_server_architecture.md) | FastAPI internals — routers, services, models, DB |
| 03 | [Mobile Architecture](03_mobile_architecture.md) | Flutter mobile — features, state, navigation |
| 04 | [Desktop Architecture](04_desktop_architecture.md) | Flutter desktop control panel — IA, features, shell |
| 05 | [Shared Core](05_shared_core.md) | `packages/fluxora_core` — entities, network, storage, design tokens |
| 06 | [Data Model](06_data_model.md) | SQLite schema — ER diagram of every table |
| 07 | [Streaming Pipeline](07_streaming_pipeline.md) | Stream start → FFmpeg → playback (sequence + state) |
| 08 | [Pairing & Auth Flow](08_pairing_auth_flow.md) | mDNS discovery → pairing → token validation |
| 09 | [Library Scan & Thumbnails](09_library_scan_thumbnail.md) | Scan → ffprobe → TMDB → thumbnail worker |
| 10 | [Player Engines](10_player_engines.md) | ExoPlayer / media_kit abstraction + platform routing |
| 11 | [Deployment](11_deployment.md) | Build → distribute → install pipeline |

---

## Conventions used in these diagrams

| Symbol | Meaning |
|---|---|
| Rounded rect `(...)` | Entry / exit / external actor |
| Square rect `[...]` | Component, module, or screen |
| Diamond `{...}` | Decision / branch |
| Cylinder `[(...)]` | Persistent store (DB, file system, cache) |
| Subgraph | Logical grouping — process, app, layer |
| Solid arrow `-->` | Synchronous call / data flow |
| Dashed arrow `-.->` | Asynchronous / pub-sub / WebSocket |
| Dotted arrow `~~~` | Layout-only, no semantic relationship |

Colour coding (where applied):
- **Purple** — Fluxora-owned components
- **Amber** — third-party / external services
- **Red** — security boundary / sensitive surface
- **Grey** — deprecated / v1.1 stub

---

## Maintenance

When you ship something that changes the structure (new router, new service, new feature module, new table), update the relevant diagram. These files are checked into `docs/02_architecture/diagrams/` so they live with the code that describes them.

Don't try to keep every node 100% complete — focus on **load-bearing structure**. A diagram with the 20 important nodes is more useful than one with 200 nodes including every helper file.
