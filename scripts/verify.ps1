$root = 'f:\AI Models\Projects\Fluxora'

$checks = @(
    'apps/server/main.py',
    'apps/server/config.py',
    'apps/server/requirements.txt',
    'apps/server/requirements-dev.txt',
    'apps/server/Dockerfile',
    'apps/server/fluxora_server.spec',
    'apps/server/database/db.py',
    'apps/server/database/migrations/001_initial.sql',
    'apps/server/database/migrations/002_sessions.sql',
    'apps/server/routers/__init__.py',
    'apps/server/routers/auth.py',
    'apps/server/routers/files.py',
    'apps/server/routers/library.py',
    'apps/server/routers/stream.py',
    'apps/server/routers/ws.py',
    'apps/server/services/__init__.py',
    'apps/server/services/ffmpeg_service.py',
    'apps/server/services/library_service.py',
    'apps/server/services/discovery_service.py',
    'apps/server/services/auth_service.py',
    'apps/server/services/webrtc_service.py',
    'apps/server/models/__init__.py',
    'apps/server/models/media_file.py',
    'apps/server/models/library.py',
    'apps/server/models/client.py',
    'apps/server/models/stream_session.py',
    'apps/server/models/settings.py',
    'apps/server/utils/__init__.py',
    'apps/server/utils/file_utils.py',
    'apps/server/utils/tmdb_client.py',
    'apps/server/tests/__init__.py',
    'apps/server/tests/conftest.py',
    'apps/server/tests/test_auth.py',
    'apps/server/tests/test_files.py',
    'apps/server/tests/test_library.py',
    'apps/server/tests/test_stream.py',
    'apps/mobile/pubspec.yaml',
    'apps/mobile/lib/main.dart',
    'apps/mobile/lib/app.dart',
    'apps/mobile/lib/core/di/injector.dart',
    'apps/mobile/lib/core/router/app_router.dart',
    'apps/mobile/lib/shared/widgets/media_card.dart',
    'apps/mobile/lib/shared/widgets/status_badge.dart',
    'apps/mobile/lib/shared/widgets/loading_overlay.dart',
    'apps/mobile/lib/shared/theme/app_theme.dart',
    'apps/desktop/pubspec.yaml',
    'apps/desktop/lib/main.dart',
    'apps/desktop/lib/app.dart',
    'apps/desktop/lib/core/di/injector.dart',
    'apps/desktop/lib/core/router/app_router.dart',
    'apps/desktop/lib/shared/widgets/sidebar.dart',
    'apps/desktop/lib/shared/widgets/stat_card.dart',
    'apps/desktop/lib/shared/widgets/data_table.dart',
    'apps/desktop/lib/shared/widgets/status_badge.dart',
    'apps/desktop/lib/shared/theme/app_theme.dart',
    'packages/fluxora_core/pubspec.yaml',
    'packages/fluxora_core/lib/fluxora_core.dart',
    'packages/fluxora_core/lib/entities/media_file.dart',
    'packages/fluxora_core/lib/entities/library.dart',
    'packages/fluxora_core/lib/entities/client.dart',
    'packages/fluxora_core/lib/entities/stream_session.dart',
    'packages/fluxora_core/lib/entities/server_info.dart',
    'packages/fluxora_core/lib/network/api_client.dart',
    'packages/fluxora_core/lib/network/endpoints.dart',
    'packages/fluxora_core/lib/network/api_exception.dart',
    'packages/fluxora_core/lib/storage/secure_storage.dart',
    'packages/fluxora_core/lib/constants/app_colors.dart',
    'packages/fluxora_core/lib/constants/app_typography.dart',
    'packages/fluxora_core/lib/constants/app_sizes.dart',
    '.github/workflows/server_ci.yml',
    '.github/workflows/mobile_ci.yml',
    '.github/workflows/desktop_ci.yml',
    'scripts/build_server.ps1',
    'scripts/build_server.sh',
    'scripts/build_mobile.sh',
    'scripts/build_desktop.sh',
    'scripts/release.sh',
    '.gitignore'
)

$missing = @()
$ok      = 0

foreach ($rel in $checks) {
    $full = "$root/$rel"
    if (Test-Path $full) {
        $ok++
    } else {
        $missing += $rel
    }
}

Write-Host ""
Write-Host "✅ Present : $ok / $($checks.Count)"
if ($missing.Count -gt 0) {
    Write-Host "❌ Missing : $($missing.Count)"
    $missing | ForEach-Object { Write-Host "   - $_" }
} else {
    Write-Host "🎉 All files accounted for."
}
