#!/usr/bin/env bash
set -e

echo "⏳ Waiting for database..."

python - <<'EOF'
import time, socket, sys
from sqlalchemy import create_engine
from app.config import settings

for i in range(60):
    try:
        engine = create_engine(settings.database_url, pool_pre_ping=True)
        with engine.connect() as conn:
            conn.execute("SELECT 1")
        print("✅ Database is ready")
        sys.exit(0)
    except Exception as e:
        print(f"⏳ DB not ready ({i}/60): {e}")
        time.sleep(2)

print("❌ Database is not reachable")
sys.exit(1)
EOF

echo "🗄️ Running migrations (if needed)..."
alembic upgrade head || true

echo "🚀 Starting backend..."
exec "$@"
