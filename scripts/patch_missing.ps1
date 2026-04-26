$root = 'f:\AI Models\Projects\Fluxora'

# Creates a file with content, overwriting if exists
function nf([string]$rel, [string]$content = '') {
    $full = Join-Path $root $rel
    $dir  = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $full -Value $content -Encoding UTF8 -Force
}

# ── apps/server: config + Dockerfile ─────────────────────────────────────────
nf 'apps/server/config.py'   '# Pydantic BaseSettings — all configuration'
nf 'apps/server/Dockerfile'  'FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]'

# ── apps/server/database ──────────────────────────────────────────────────────
nf 'apps/server/database/db.py'                          '# SQLite connection, WAL mode init, migration runner'
nf 'apps/server/database/migrations/001_initial.sql'     '-- Initial schema: media_files, libraries, clients, user_settings'
nf 'apps/server/database/migrations/002_sessions.sql'    '-- Stream sessions table'

# ── apps/server/routers ───────────────────────────────────────────────────────
nf 'apps/server/routers/__init__.py'  ''
nf 'apps/server/routers/auth.py'      '# POST /auth/pair  POST /auth/approve  DELETE /auth/revoke'
nf 'apps/server/routers/files.py'     '# GET /files  GET /files/{id}'
nf 'apps/server/routers/library.py'   '# CRUD /library  POST /library/{id}/scan'
nf 'apps/server/routers/stream.py'    '# POST /stream/start  POST /stream/stop  GET /hls/{session}/{segment}'
nf 'apps/server/routers/ws.py'        '# WS /ws/events — real-time stream and client status'

# ── apps/server/services ─────────────────────────────────────────────────────
nf 'apps/server/services/__init__.py'         ''
nf 'apps/server/services/ffmpeg_service.py'   '# FFmpeg subprocess manager — HLS transcoding'
nf 'apps/server/services/library_service.py'  '# Directory scanning + TMDB enrichment'
nf 'apps/server/services/discovery_service.py' '# mDNS broadcast: _fluxora._tcp.local'
nf 'apps/server/services/auth_service.py'     '# Token generation, pairing approval, validation'
nf 'apps/server/services/webrtc_service.py'   '# STUN/TURN signaling for internet connections'

# ── apps/server/models ────────────────────────────────────────────────────────
nf 'apps/server/models/__init__.py'       ''
nf 'apps/server/models/media_file.py'     '# MediaFile Pydantic model'
nf 'apps/server/models/library.py'        '# Library Pydantic model'
nf 'apps/server/models/client.py'         '# Client Pydantic model'
nf 'apps/server/models/stream_session.py' '# StreamSession Pydantic model'
nf 'apps/server/models/settings.py'       '# UserSettings Pydantic model'

# ── apps/server/utils ─────────────────────────────────────────────────────────
nf 'apps/server/utils/__init__.py'   ''
nf 'apps/server/utils/file_utils.py' '# MIME detection, path helpers, file size formatting'
nf 'apps/server/utils/tmdb_client.py' '# TMDB REST API wrapper'

# ── apps/server/tests ─────────────────────────────────────────────────────────
nf 'apps/server/tests/__init__.py'      ''
nf 'apps/server/tests/conftest.py'      '# pytest fixtures: test DB, async client'
nf 'apps/server/tests/test_auth.py'     '# Auth endpoint tests'
nf 'apps/server/tests/test_files.py'    '# File listing tests'
nf 'apps/server/tests/test_library.py'  '# Library CRUD tests'
nf 'apps/server/tests/test_stream.py'   '# Stream start/stop tests'

# ── apps/mobile ───────────────────────────────────────────────────────────────
nf 'apps/mobile/pubspec.yaml' 'name: fluxora_mobile
description: Fluxora mobile client for iOS and Android
version: 0.1.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  fluxora_core:
    path: ../../packages/fluxora_core
  flutter_bloc: ^8.1.5
  go_router: ^13.0.0
  get_it: ^7.6.7
  better_player: ^0.0.84
  flutter_webrtc: ^0.10.0
  multicast_dns: ^0.3.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0'

nf 'apps/mobile/lib/main.dart'  '// Fluxora Mobile — entry point'

# ── apps/desktop ──────────────────────────────────────────────────────────────
nf 'apps/desktop/lib/app.dart'                         '// MaterialApp, theme, and router initialisation'
nf 'apps/desktop/lib/core/di/injector.dart'            '// get_it dependency injection setup'
nf 'apps/desktop/lib/core/router/app_router.dart'      '// go_router route definitions'
nf 'apps/desktop/lib/shared/widgets/sidebar.dart'      '// Navigation sidebar — control panel nav'
nf 'apps/desktop/lib/shared/widgets/stat_card.dart'    '// Dashboard stat card widget'
nf 'apps/desktop/lib/shared/widgets/data_table.dart'   '// Reusable sortable data table'
nf 'apps/desktop/lib/shared/widgets/status_badge.dart' '// Online / Idle / Offline badge'

# ── packages/fluxora_core/lib/entities ───────────────────────────────────────
nf 'packages/fluxora_core/lib/entities/media_file.dart'     '// MediaFile entity'
nf 'packages/fluxora_core/lib/entities/library.dart'        '// Library entity'
nf 'packages/fluxora_core/lib/entities/client.dart'         '// Client entity'
nf 'packages/fluxora_core/lib/entities/stream_session.dart' '// StreamSession entity'
nf 'packages/fluxora_core/lib/entities/server_info.dart'    '// ServerInfo entity — returned by GET /api/v1/info'

Write-Host ''
Write-Host 'Patch complete. Run verify.ps1 to confirm.'
