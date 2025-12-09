#!/usr/bin/env bash
set -e

APP_DIR="/opt/boleylapanel"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

# Generate passwords and secret key
MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
SECRET_KEY=$(openssl rand -hex 32)

# Create .env file
mkdir -p "$APP_DIR/backend"
cat > "$ENV_FILE" << EOF
SECRET_KEY=$SECRET_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleyla
MYSQL_PASSWORD=$MYSQL_PASSWORD
DATABASE_URL=mysql+pymysql://boleyla:$MYSQL_PASSWORD@mysql:3306/boleylapanel
EOF

echo ".env file created at $ENV_FILE"

# Create docker-compose.yml
cat > "$COMPOSE_FILE" << EOF
version: "3.9"

services:
  boleylapanel:
    build: ./backend
    restart: always
    env_file: .env
    ports:
      - "8000:8000"
    volumes:
      - /var/lib/boleylapanel:/var/lib/boleylapanel
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    env_file: .env
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-u", "root", "--password=\${MYSQL_ROOT_PASSWORD}"]
      start_period: 10s
      interval: 5s
      timeout: 5s
      retries: 55
EOF

echo "docker-compose.yml created at $COMPOSE_FILE"

# Build and start docker
cd "$APP_DIR/backend"
DOCKER_BUILDKIT=1 docker build --network=host -t boleylapanel .
cd "$APP_DIR"
docker compose up -d
docker compose ps
