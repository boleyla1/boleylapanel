#!/bin/bash
set -e

echo "Waiting for database..."
while ! nc -z mysql 3306; do
  sleep 1
done

echo "Running migrations..."
alembic upgrade head

echo "Starting BoleylaPanel..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
