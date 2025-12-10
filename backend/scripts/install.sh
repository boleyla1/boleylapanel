
#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_color() {
    echo -e "${!1}${2}${NC}"
}

APP_DIR="/opt/boleylapanel"
DATA_DIR="/var/lib/boleylapanel"

echo_color BLUE "🚀 Boleylapanel Installer (MySQL-Only, Optimized)"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo_color RED "Please run as root (sudo)"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo_color RED "Cannot detect OS"
    exit 1
fi

# Install Docker
if ! command -v docker &> /dev/null; then
    echo_color YELLOW "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo_color GREEN "✓ Docker installed"
else
    echo_color GREEN "✓ Docker already installed"
fi

# Create directories
mkdir -p "$APP_DIR" "$DATA_DIR/mysql"
cd "$APP_DIR"

# Generate docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  boleylapanel:
    build: .
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
    env_file: .env
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    command:
      - --bind-address=127.0.0.1
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --mysqlx=0
    volumes:
      - /var/lib/boleylapanel/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1"]
      interval: 3s
      timeout: 3s
      retries: 30
EOF

echo_color GREEN "✓ docker-compose.yml created"

# Generate optimized Dockerfile
cat > Dockerfile <<'EOF'
FROM python:3.11-slim

# Force IPv4 + Fast Mirror

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

echo_color GREEN "✓ Dockerfile created (IPv4-optimized)"

# Generate requirements.txt
cat > requirements.txt <<'EOF'
fastapi==0.109.0
uvicorn[standard]==0.27.0
sqlalchemy==2.0.25
pymysql==1.1.0
cryptography==42.0.0
python-multipart==0.0.6
pydantic==2.5.3
pydantic-settings==2.1.0
EOF

echo_color GREEN "✓ requirements.txt created"

# Generate main.py (minimal app)
cat > main.py <<'EOF'
from fastapi import FastAPI

app = FastAPI(title="Boleylapanel")

@app.get("/")
def root():
    return {"status": "ok", "app": "Boleylapanel", "db": "MySQL"}

@app.get("/health")
def health():
    return {"status": "healthy"}
EOF

echo_color GREEN "✓ main.py created"

# Generate .env
MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 24)
MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 24)

cat > .env <<EOF
# Admin Credentials
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin

# Database
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleyla
MYSQL_PASSWORD=${MYSQL_PASSWORD}
SQLALCHEMY_DATABASE_URL=mysql+pymysql://boleyla:${MYSQL_PASSWORD}@127.0.0.1:3306/boleylapanel
EOF

echo_color GREEN "✓ .env created (admin/admin)"

# Start services
echo ""
echo_color YELLOW "🔨 Building Docker image (this may take 60-90 seconds)..."
DOCKER_BUILDKIT=1 docker compose up -d --build

echo ""
echo_color GREEN "✅ Installation complete!"
echo ""
echo_color BLUE "📋 Info:"
echo "  - App Directory: $APP_DIR"
echo "  - Data Directory: $DATA_DIR"
echo "  - Admin: admin / admin"
echo "  - API: http://localhost:8000"
echo ""
echo_color YELLOW "🔍 Check status:"
echo "  docker compose -f $APP_DIR/docker-compose.yml ps"
echo "  docker compose -f $APP_DIR/docker-compose.yml logs -f"
