# Component Architecture

> **Category:** Architecture  
> **Status:** Active — Updated 2026-04-28

---

## Component Map

```
┌─────────────────── PC SERVER ───────────────────┐
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  File API   │  │   Streaming Engine       │   │
│  │  Browser    │  │   (FFmpeg → HLS)         │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  Library    │  │   Auth / Session Mgmt   │   │
│  │  Manager    │  │                         │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  mDNS/      │  │   WebRTC Signaling      │   │
│  │  Zeroconf   │  │   (STUN/TURN mgmt)      │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  SQLite DB (metadata, library, sessions) │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘

┌──────────────── FLUTTER CLIENT ─────────────────┐
│                                                  │
│  Presentation Layer                              │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────┐  │
│  │ Home /   │ │ Library  │ │ Player Screen   │  │
│  │ Connect  │ │ Browser  │ │ (HLS Playback)  │  │
│  └──────────┘ └──────────┘ └─────────────────┘  │
│                                                  │
│  Domain Layer (Use Cases)                        │
│  ┌────────────────────────────────────────────┐  │
│  │ StreamFile │ BrowseFiles │ DiscoverServer  │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Data Layer (Repositories + Sources)             │
│  ┌───────────────┐  ┌────────────────────────┐   │
│  │ HTTP API Repo │  │ mDNS / WebRTC Source   │   │
│  └───────────────┘  └────────────────────────┘   │
└─────────────────────────────────────────────────┘

┌──────────────── PC CONTROL PANEL ───────────────┐
│  Flutter Desktop App                             │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────┐  │
│  │ Server   │ │ Active   │ │ Library / User  │  │
│  │ Settings │ │ Streams  │ │ Management      │  │
│  └──────────┘ └──────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## Component Descriptions

### File API Browser
- **Responsibility:** Exposes server file system as REST endpoints; handles file listing, search, directory navigation
- **Interfaces:** `GET /files`, `GET /files/{path}`
- **Dependencies:** OS file system, SQLite (for library index)

### Streaming Engine (FFmpeg → HLS)
- **Responsibility:** Takes a file path, spawns FFmpeg subprocess, produces HLS segments served over HTTP
- **Interfaces:** `GET /stream/{file_id}` → returns `.m3u8` playlist URL
- **Dependencies:** FFmpeg binary, temp segment storage

### Library Manager
- **Responsibility:** Indexes media directories, fetches metadata from TMDB, stores in SQLite
- **Interfaces:** `POST /library/scan`, `GET /library/{type}`
- **Dependencies:** TMDB API, SQLite, file system

### Auth / Session Management
- **Responsibility:** Token-based auth, session storage, permission enforcement
- **Interfaces:** `POST /auth/token`, middleware on all routes
- **Dependencies:** SQLite (sessions table)

### mDNS / Zeroconf Discovery
- **Responsibility:** Broadcasts server presence on LAN, responds to client discovery queries
- **Interfaces:** UDP multicast (internal), `GET /info` (HTTP for confirmation)
- **Dependencies:** Zeroconf Python library

### WebRTC Signaling
- **Responsibility:** Coordinates offer/answer exchange between client and server for P2P connection setup
- **Interfaces:** WebSocket `/ws/signal`
- **Dependencies:** STUN server (external), TURN server (external or self-hosted)

### Flutter Client — Presentation Layer
- **Responsibility:** UI screens (Home, Connect, Browser, Player, Settings)
- **State Management:** BLoC or Riverpod
- **Dependencies:** Domain use cases

### Flutter Client — Domain Layer
- **Use Cases:** `StreamFileUseCase`, `BrowseFilesUseCase`, `DiscoverServerUseCase`, `AuthUseCase`
- **Pure Dart** — no framework dependencies

### Flutter Client — Data Layer
- **Repositories:** `FileRepository`, `StreamRepository`, `ServerDiscoveryRepository`
- **Sources:** HTTP (Dio), mDNS (Dart Zeroconf), WebRTC (flutter_webrtc)

### PC Control Panel (Flutter Desktop)
- **Responsibility:** Server-side dashboard — monitor server health, manage clients (approve/reject/revoke), browse the library with TMDB metadata and resume indicators, configure server connection
- **Screens implemented:** Dashboard (stats) · Clients (pairing management) · Library (file list + filter chips + resume bar) · Settings (server URL config + About)
- **Interfaces:** HTTP to FastAPI server; URL configurable at runtime via Settings screen (persisted in `flutter_secure_storage`)
- **State management:** BLoC (Cubit) with GetIt DI
- **Routes:** `/` (Dashboard) · `/clients` (Clients) · `/library` (Library) · `/settings` (Settings)

---

## Communication Patterns

| From | To | Protocol | Pattern |
|------|----|----------|---------|
| Flutter Client | FastAPI Server (LAN) | HTTP REST | Request/Response |
| Flutter Client | FastAPI Server (LAN) | HLS over HTTP | Streaming |
| Flutter Client | STUN Server | UDP | WebRTC ICE |
| Flutter Client | TURN Server | UDP/TCP | WebRTC Relay |
| FastAPI Server | FFmpeg | Subprocess pipe | Internal process |
| FastAPI Server | SQLite | SQLite3 | Query/Write |
| FastAPI Server | TMDB API | HTTPS REST | Request/Response |
| FastAPI Server | Zeroconf | UDP multicast | Broadcast |
| PC Control Panel | FastAPI Server | HTTP REST | Request/Response |
