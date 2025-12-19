#!/usr/bin/env bash
set -e

APP_NAME="boleylapanel"
APP_DIR="/opt/$APP_NAME"
ENV_FILE="$APP_DIR/.env"

echo "🚀 Installing BoleylaPanel..."

# -------------------------------
# Helpers
# -------------------------------
die() {
  echo "❌ $1"
  exit 1
}

wait_for_mysql() {
  echo "⏳ Waiting for MySQL to be REALLY ready..."
  for i in {1..60}; do
    if docker compose exec -T db \
      mysql -h localhost -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
      -e "SELECT 1" &>/dev/null; then
      echo "✅ MySQL is ready"
      return
    fi
    sleep 2
  done
  die "MySQL not ready after timeout"
}

load_env() {
  export $(grep -v '^#' "$ENV_FILE" | xargs)
}

# -------------------------------
# Pre-flight
# -------------------------------
[ "$EUID" -ne 0 ] && die "Run as root"
[ ! -f "$ENV_FILE" ] && die ".env not found"

cd "$APP_DIR"
load_env

# -------------------------------
# Detect compose
# -------------------------------
if docker compose version &>/dev/null; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

# -------------------------------
# Start infrastructure
# -------------------------------
echo "🐳 Starting services..."
$COMPOSE up -d

# -------------------------------
# DB readiness
# -------------------------------
wait_for_mysql

# -------------------------------
# Migration (single source)
# -------------------------------
echo "🗄️ Running Alembic migrations..."
$COMPOSE exec -T backend alembic upgrade head

# -------------------------------
# Optional: init admin
# -------------------------------
echo "👤 Creating admin user (idempotent)..."
$COMPOSE exec -T backend python app/scripts/create_admin.py || true

echo
echo "✅ Installation completed successfully"
echo "🌐 Panel is available on port ${PORT:-8000}"
