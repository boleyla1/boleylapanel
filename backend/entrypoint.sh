#!/usr/bin/env sh
set -e

echo "Waiting for database..."
until nc -z "$DB_HOST" "$DB_PORT"; do
  sleep 1
done

alembic upgrade head

exec uvicorn backend.app.main:app \
  --host 0.0.0.0 \
  --port 8000 \
  --proxy-headers
