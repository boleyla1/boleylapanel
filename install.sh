#!/usr/bin/env bash
set -euo pipefail

########################################
# HARD SAFETY: recover from broken cwd #
########################################
if ! pwd >/dev/null 2>&1; then
  echo "⚠️  Current working directory is invalid. Switching to /"
  cd /
else
  cd /
fi

########################################
# Constants
########################################
APP_NAME="boleylapanel"
INSTALL_DIR="/opt"
APP_DIR="$INSTALL_DIR/$APP_NAME"
CLI_PATH="/usr/local/bin/$APP_NAME"
COMPOSE_URL="https://raw.githubusercontent.com/boleyla1/boleylapanel/main/docker-compose.yml"
CLI_URL="https://raw.githubusercontent.com/boleyla1/boleylapanel/main/scripts/boleylapanel.sh"
ENV_TEMPLATE_URL="https://raw.githubusercontent.com/boleyla1/boleylapanel/main/.env.example"

echo "🚀 Installing BoleylaPanel (Pull-based)..."

########################################
# Root check
########################################
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This installer must be run as root"
  exit 1
fi

########################################
# Docker check/install
########################################
if ! command -v docker >/dev/null 2>&1; then
  echo "📦 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "❌ docker compose not found after Docker install"
  exit 1
fi

########################################
# Create app directory
########################################
mkdir -p "$APP_DIR"

########################################
# Download compose file
########################################
echo "📥 Downloading docker-compose.yml..."
curl -fsSL "$COMPOSE_URL" -o "$APP_DIR/docker-compose.yml"

########################################
# .env setup
########################################
if [ ! -f "$APP_DIR/.env" ]; then
  echo "📝 Creating .env from template..."
  curl -fsSL "$ENV_TEMPLATE_URL" -o "$APP_DIR/.env"
  echo "⚠️  Please edit $APP_DIR/.env before starting"
else
  echo "ℹ️  .env already exists, skipping"
fi

########################################
# Download CLI
########################################
echo "📥 Downloading CLI..."
curl -fsSL "$CLI_URL" -o "$CLI_PATH"
chmod +x "$CLI_PATH"

########################################
# Pull images
########################################
echo "🐳 Pulling Docker images..."
cd "$APP_DIR"
docker compose pull

########################################
# Final
########################################
echo ""
echo "✅ BoleylaPanel installed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Edit configuration: nano $APP_DIR/.env"
echo "   2. Start services: boleylapanel up"
echo "   3. Check status: boleylapanel status"
echo ""
