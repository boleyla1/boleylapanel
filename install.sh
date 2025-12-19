#!/usr/bin/env bash
set -e

APP_NAME="boleylapanel"
INSTALL_DIR="/opt"
APP_DIR="$INSTALL_DIR/$APP_NAME"
CLI_PATH="/usr/local/bin/$APP_NAME"
REPO_URL="https://github.com/boleyla1/boleylapanel.git"

echo "🚀 Installing BoleylaPanel CLI..."

if [ "$(id -u)" != "0" ]; then
  echo "❌ Run as root"
  exit 1
fi

# Docker
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

# docker compose
if ! docker compose version >/dev/null 2>&1; then
  echo "❌ docker compose not found"
  exit 1
fi

# Clone repo
if [ ! -d "$APP_DIR" ]; then
  git clone "$REPO_URL" "$APP_DIR"
else
  echo "ℹ️ Repo already exists"
fi

# Install CLI
install -m 755 "$APP_DIR/scripts/boleylapanel.sh" "$CLI_PATH"

echo "✅ Installed!"
echo "👉 Run: boleylapanel"
