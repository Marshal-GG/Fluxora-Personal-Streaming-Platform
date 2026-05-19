# 05 — Shared Core

> `packages/fluxora_core` — every line of code shared between **mobile** and **desktop**. No platform-specific widgets. Imported via local path dependency.

---

## Package contents

```mermaid
graph TB
  classDef pkg fill:#7c3aed,stroke:#fff,color:#fff
  classDef ent fill:#a78bfa,stroke:#000,color:#000
  classDef net fill:#fde68a,stroke:#000,color:#000
  classDef store fill:#16a34a,stroke:#000,color:#fff
  classDef tok fill:#f59e0b,stroke:#000,color:#000

  Root[fluxora_core.dart<br/>barrel export]:::pkg

  subgraph Entities["entities/ — domain models"]
    direction LR
    E1[client]:::ent
    E2[client_list_item]:::ent
    E3[library]:::ent
    E4[library_storage_breakdown]:::ent
    E5[media_file]:::ent
    E6[server_info]:::ent
    E7[stream_session]:::ent
    E8[system_stats]:::ent
    E9[activity_event]:::ent
    E10[enums]:::ent
  end

  subgraph Network["network/"]
    N1[api_client<br/>Dio singleton + interceptors]:::net
    N2[endpoints<br/>every URL constant]:::net
    N3[api_exception]:::net
  end

  subgraph Storage["storage/"]
    S1[secure_storage<br/>flutter_secure_storage wrapper]:::store
  end

  subgraph Player["player/ (plan 24)"]
    P1[PlayerEngine<br/>abstract]:::pkg
    P2[ExoPlayerEngine<br/>Android via MethodChannel]:::pkg
    P3[MediaKitEngine<br/>libmpv]:::pkg
    P4[PlayerEngineFactory]:::pkg
  end

  subgraph DesignTokens["constants/ — design tokens"]
    direction LR
    C1[app_colors<br/>V2-only]:::tok
    C2[app_typography<br/>V2-only]:::tok
    C3[app_gradients<br/>brand/progress/upgrade/bg]:::tok
    C4[app_radii]:::tok
    C5[app_shadows]:::tok
    C6[app_spacing<br/>s2…s32 scale]:::tok
    C7[app_sizes<br/>legacy mobile]:::tok
  end

  Root --> Entities
  Root --> Network
  Root --> Storage
  Root --> Player
  Root --> DesignTokens
```

---

## Who imports what

```mermaid
graph LR
  classDef app fill:#7c3aed,stroke:#fff,color:#fff
  classDef pkg fill:#a78bfa,stroke:#000,color:#000

  Mobile[apps/mobile]:::app
  Desktop[apps/desktop]:::app
  Core[packages/fluxora_core]:::pkg

  Mobile -- pubspec path dep --> Core
  Desktop -- pubspec path dep --> Core

  Mobile -- imports --> ApiClient[ApiClient]
  Mobile -- imports --> Endpoints[Endpoints]
  Mobile -- imports --> Entities[Entities]
  Mobile -- imports --> SecStore[SecureStorage]
  Mobile -- imports --> Tokens[Design tokens]
  Mobile -- imports --> Player[PlayerEngine]

  Desktop -- imports --> ApiClient
  Desktop -- imports --> Endpoints
  Desktop -- imports --> Entities
  Desktop -- imports --> SecStore
  Desktop -- imports --> Tokens
  Desktop -- does NOT use --> Player
```

Desktop doesn't import `PlayerEngine` — control panel has no media playback surface.

---

## What goes in `fluxora_core` vs what stays in the app

```mermaid
flowchart TD
  Start([Where does this code go?]) --> Q1{Used by BOTH<br/>mobile AND desktop?}
  Q1 -- no --> StayApp[Stays in apps/&lt;app&gt;/lib/shared/]
  Q1 -- yes --> Q2{Uses platform-specific<br/>Flutter widgets?}
  Q2 -- yes --> StayApp
  Q2 -- no --> Q3{Pure Dart entity,<br/>API call, token, constant?}
  Q3 -- yes --> Core[packages/fluxora_core/]
  Q3 -- no --> Reconsider[Reconsider — likely belongs in app/shared]
```

> Rule of thumb: **if you can't use it without `flutter/material.dart`, it stays out of `fluxora_core`.** The package keeps a clean Flutter-agnostic core.

---

## API client + endpoint pattern

```mermaid
classDiagram
  class ApiClient {
    +Dio dio
    +String? baseUrl
    +String? bearerToken
    +void setBaseUrl(String)
    +void setBearer(String)
    +Future~Response~ get(path)
    +Future~Response~ post(path, data)
    +Future~Response~ patch(path, data)
    +Future~Response~ delete(path)
  }
  class Endpoints {
    <<static constants>>
    +String libraries
    +String streamStart
    +String libraryFolderSize
    +String libraryIndexFile
    +String libraryScanSubtree
    +String fileRegenerateThumbnail
    +String libraryResolveAbsolute
    +String libraryBrowse
    +String streamFallbackTranscode
    +String streamFallbackAudioTranscode
    +String streamAudioTrack
    +...
  }
  class SecureStorage {
    +Future~String?~ getToken()
    +Future~void~ setToken(String)
    +Future~void~ clear()
  }
  class ApiException {
    +int statusCode
    +String message
    +Object? body
  }
  ApiClient ..> ApiException : throws
  ApiClient ..> Endpoints : uses constants
  ApiClient ..> SecureStorage : reads bearer
```

---

## Brand assets — runtime copies

The package also carries runtime copies of brand assets that mobile/desktop pick up:

```
packages/fluxora_core/assets/brand/
├── fluxora_mark.png       # The mark glyph
├── fluxora_wordmark.png   # Wordmark
└── app_icon.ico           # Windows runner icon (also copied to apps/desktop/windows/runner/resources/)
```

The canonical masters live in `/assets/brand/` at the repo root. These are **synced derivatives** — see [`assets/README.md`](../../../assets/README.md) for the sync flow.

---

## Tests for fluxora_core

Currently `packages/fluxora_core/` has no test directory of its own — entities and ApiClient are exercised through the mobile and desktop tests that import them. If you add complex logic here, give it a `test/` directory.
