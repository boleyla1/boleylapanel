#!/bin/bash

# 1. ساخت دایرکتوری‌ها
mkdir -p /opt/boleylapanel /var/lib/boleylapanel/mysql

# 2. ساخت Dockerfile با Mirror سریع
cat > /opt/boleylapanel/Dockerfile <<'EOF'
FROM python:3.11-slim

# Force IPv4 + Use Fast Mirror
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 && \
    sed -i 's|deb.debian.org|mirrors.kernel.org/debian|g' /etc/apt/sources.list.d/debian.sources

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-libmysqlclient-dev \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# 3. ساخت requirements.txt
cat > /opt/boleylapanel/requirements.txt <<'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
pymysql==1.1.0
cryptography==41.0.7
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
pydantic==2.5.0
pydantic-settings==2.1.0
EOF

# 4. ساخت .env
MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
MYSQL_USER_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)

cat > /opt/boleylapanel/.env <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleylapanel
MYSQL_PASSWORD=$MYSQL_USER_PASSWORD
SQLALCHEMY_DATABASE_URL=mysql+pymysql://boleylapanel:$MYSQL_USER_PASSWORD@127.0.0.1:3306/boleylapanel
SECRET_KEY=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin
EOF

# 5. ساخت docker-compose.yml
cat > /opt/boleylapanel/docker-compose.yml <<'EOF'
services:
  boleylapanel:
    image: boleylapanel:latest
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    network_mode: host
    env_file: .env
    volumes:
      - /var/lib/boleylapanel:/var/lib/boleylapanel
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    restart: always
    network_mode: host
    command:
      - --bind-address=127.0.0.1
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - /var/lib/boleylapanel/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
EOF

# 6. ساخت main.py
cat > /opt/boleylapanel/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="Boleylapanel")

@app.get("/")
async def root():
    return JSONResponse({"message": "Boleylapanel is running!", "status": "ok"})

@app.get("/health")
async def health():
    return JSONResponse({"status": "healthy"})
EOF

# 7. Build & Run
cd /opt/boleylapanel
echo "Starting build with fast mirror..."
DOCKER_BUILDKIT=1 docker compose up -d --build --pull

echo "================================"
echo "Credentials saved in: /opt/boleylapanel/.env"
echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
echo "MySQL User Password: $MYSQL_USER_PASSWORD"
echo "================================"
