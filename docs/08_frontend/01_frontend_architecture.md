# Frontend Architecture

> **Category:** Frontend  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

## Framework & Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| Architecture | Clean Architecture (Domain / Data / Presentation) |
| State Management | BLoC or Riverpod (TBD, confirm at Phase 2 start) |
| HTTP Client | Dio |
| Video Playback | `better_player` or `media_kit` |
| Discovery | Dart `zeroconf` package |
| WebRTC | `flutter_webrtc` |
| Storage (local) | `flutter_secure_storage` (tokens), `shared_preferences` (settings) |

---

## Two Client Targets

| Target | Purpose |
|--------|---------|
| **Flutter Mobile** (Android/iOS) | End-user streaming client |
| **Flutter Desktop** (Windows/macOS/Linux) | PC control panel / server management |

---

## Design System

- **Color Palette:** Dark-mode primary — deep navy + electric teal accent (TBD, finalize in Phase 2)
- **Typography:** `Inter` or `Outfit` (Google Fonts)
- **Component Library:** Custom widget library (no Material over-reliance)
- **Theming:** `ThemeData` with `ColorScheme`, dark mode default

---

## Screen / Page Map — Flutter Mobile Client

| Route | Screen | Description |
|-------|--------|-------------|
| `/` | Connect / Home | Discover or manually enter server |
| `/browse` | File Browser | Navigate server file system |
| `/library` | Library | Browse indexed media (movies, TV, music) |
| `/media/{id}` | Media Detail | Metadata, cast, description, play button |
| `/player` | Player | Full-screen HLS video/audio player |
| `/settings` | Settings | App settings, paired servers list |

---

## Screen / Page Map — PC Control Panel (Flutter Desktop)

| Route | Screen | Description |
|-------|--------|-------------|
| `/` | Dashboard | Server status, active streams, quick stats |
| `/streams` | Active Streams | List of current streaming sessions |
| `/library` | Library Manager | Add/remove/scan libraries |
| `/clients` | Client Manager | Approve/revoke paired devices |
| `/settings` | Settings | Transcoding, concurrency, subscription |

---

## Flutter Project Structure

```
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── network/           # Dio setup, interceptors
│   └── utils/
│
├── features/
│   ├── discovery/         # Server discovery (mDNS + manual)
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   │
│   ├── auth/              # Client pairing + token management
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   │
│   ├── file_browser/      # Browse server files
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   │
│   ├── library/           # Indexed media library view
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   │
│   ├── player/            # HLS player screen
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   │
│   └── settings/          # App settings
│       ├── domain/
│       ├── data/
│       └── presentation/
│
└── main.dart
```

---

## State Management Flow

```
UI Event ──▶ BLoC/Cubit ──▶ Use Case ──▶ Repository ──▶ Data Source
                │                                              │
                └──────────── State emitted ◀─────────────────┘
```

---

## Key Technical Challenges

| Challenge | Solution |
|-----------|---------|
| mDNS on Android/iOS | Use Dart `zeroconf` package; fallback to manual IP entry |
| WebRTC complexity | Encapsulate in `ServerDiscoveryRepository`; use `flutter_webrtc` plugin |
| HLS playback quality | Use `media_kit` for better codec support vs `video_player` |
| Large file lists | Paginated API + lazy-loading list views |
| Background stream continuity | Use foreground service (Android) / background audio session (iOS) |
