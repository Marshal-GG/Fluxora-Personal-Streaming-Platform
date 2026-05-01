#!/usr/bin/env bash
# Devcontainer post-create hook.
# Runs once after the container is built. Pull deps for every workspace
# component so a fresh container is ready to develop / run tests immediately.

set -euo pipefail

echo "▶ Installing Python deps for apps/server..."
cd /workspaces/Fluxora/apps/server || exit 1
pip install --upgrade pip setuptools wheel
pip install -e ".[dev]"
cd /workspaces/Fluxora

echo "▶ Pulling Flutter packages (fluxora_core)..."
(cd packages/fluxora_core && flutter pub get) || true

echo "▶ Pulling Flutter packages (apps/mobile)..."
(cd apps/mobile && flutter pub get) || true

echo "▶ Pulling Flutter packages (apps/desktop)..."
(cd apps/desktop && flutter pub get) || true

echo "▶ Installing Node deps for apps/web_landing..."
(cd apps/web_landing && npm ci) || true

echo "▶ Verifying tool versions..."
python --version
flutter --version | head -1
node --version
ffmpeg -version | head -1
cloudflared --version

echo ""
echo "✓ Devcontainer ready."
echo ""
echo "  Server:    cd apps/server && uvicorn main:app --reload --host 0.0.0.0 --port 8080"
echo "  Web:       cd apps/web_landing && npm run dev"
echo "  Tests:     cd apps/server && python -m pytest -q"
echo "  Mobile:    flutter test (from apps/mobile or apps/desktop)"
echo ""
echo "  Secrets are mounted from your host's ~/.fluxora at /home/vscode/.fluxora"
echo "  — make sure the host file exists and has TOKEN_HMAC_KEY set."
