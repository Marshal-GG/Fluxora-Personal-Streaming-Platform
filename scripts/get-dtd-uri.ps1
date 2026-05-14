# Fetches the Dart Tooling Daemon (DTD) URI for the running Flutter app.
#
# Workflow:
#   1. Start the Flutter app (VS Code debug button or `flutter run` -- any way).
#   2. In VS Code: Ctrl+Shift+P -> "Dart: Copy DTD Uri to Clipboard".
#   3. Run this script. It reads the URI from the clipboard, validates the
#      shape (ws://127.0.0.1:PORT/TOKEN=), caches it to .claude/dtd_uri.txt,
#      and prints it to stdout.
#
# On a re-run without a fresh clipboard copy, falls back to the cached value
# and warns that it may be stale if the app was restarted since.
#
# Exit codes: 0 = URI printed, 1 = neither clipboard nor cache had a valid URI.

$ErrorActionPreference = 'Stop'

$repoRoot  = Resolve-Path (Join-Path $PSScriptRoot '..')
$cacheFile = Join-Path $repoRoot '.claude\dtd_uri.txt'
$cacheDir  = Split-Path $cacheFile -Parent

if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
}

$dtdPattern = '^ws://127\.0\.0\.1:\d+/[A-Za-z0-9_=+/-]+$'

$clipboard = ''
try {
    $clipboard = (Get-Clipboard -Raw).Trim()
} catch {
    $clipboard = ''
}

if ($clipboard -match $dtdPattern) {
    Set-Content -Path $cacheFile -Value $clipboard -Encoding ASCII -NoNewline
    Write-Output $clipboard
    exit 0
}

if (Test-Path $cacheFile) {
    $cached = (Get-Content -Path $cacheFile -Raw).Trim()
    if ($cached -match $dtdPattern) {
        Write-Warning "Using cached DTD URI -- may be stale if app was restarted since last copy."
        Write-Output $cached
        exit 0
    }
}

Write-Error "No valid DTD URI in clipboard or cache. Run 'Dart: Copy DTD Uri to Clipboard' in VS Code first."
exit 1
