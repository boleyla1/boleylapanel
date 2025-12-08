#!/bin/bash
set -e

REPO_URL="https://github.com/boleyla1/boleylapanel.git"
INSTALL_DIR="boleylapanel"

echo "🚀 BoleylaPanel Backend Installation"
echo ""

############################################
# Network Checks
############################################
echo "🌐 Checking network connectivity..."
if ! command -v host &>/dev/null; then
    echo "📦 Installing DNS utility..."
    sudo apt update
    sudo apt install -y dnsutils
fi
if ! host google.com &>/dev/null; then
    echo "❌ DNS resolution failed! Fix DNS manually."
    exit 1
fi
if ! ping -c 1 1.1.1.1 &>/dev/null; then
    echo "❌ No internet connection!"
    exit 1
fi
echo "✅ Network OK"
echo ""

############################################
# Install prerequisites
############################################
echo "📦 Installing prerequisites..."
sudo apt update
sudo apt install -y git curl wget unzip openssl
echo "✅ Prerequisites installed"
echo ""

############################################
# Install Docker if needed
############################################
if ! command -v docker &> /dev/null; then
    echo "🐳 Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed"
fi

############################################
# Install Docker Compose if needed
############################################
if ! command -v docker-compose &> /dev/null; then
    echo "🐋 Docker Compose not found. Installing..."
    DOCKER_COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
fi

############################################
# Clone repository
############################################
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📥 Cloning repository..."
    git clone $REPO_URL $INSTALL_DIR
fi
cd $INSTALL_DIR/backend

############################################
# Create directories
############################################
mkdir -p logs xray/configs

############################################
# Interactive Configuration
############################################
read -p "Database Name [boleyla_panel]: " DB_NAME
DB_NAME=${DB_NAME:-boleyla_panel}
read -p "Database User [boleyla]: " DB_USER
DB_USER=${DB_USER:-boleyla}
while true; do
    read -sp "Database Password: " DB_PASSWORD
    echo ""
    read -sp "Confirm Password: " DB_PASSWORD_CONFIRM
    echo ""
    [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ] && [ -n "$DB_PASSWORD" ] && break
    echo "❌ Passwords do not match or empty!"
done
JWT_SECRET=$(openssl rand -base64 32)
read -p "Admin Username [admin]: " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
read -p "Admin Email [admin@boleyla.local]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@boleyla.local}
while true; do
    read -sp "Admin Password: " ADMIN_PASSWORD
    echo ""
    read -sp "Confirm Password: " ADMIN_PASSWORD_CONFIRM
    echo ""
    [ "$ADMIN_PASSWORD" = "$ADMIN_PASSWORD_CONFIRM" ] && [ ${#ADMIN_PASSWORD} -ge 6 ] && break
    echo "❌ Passwords do not match or too short!"
done

############################################
# Write .env file
############################################
cat > .env << EOF
DB_HOST=mysql
DB_PORT=3306
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
SECRET_KEY=${JWT_SECRET}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
API_V1_STR=/api/v1
PROJECT_NAME=BoleylaPanel
XRAY_API_HOST=0.0.0.0
XRAY_API_PORT=10085
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF

############################################
# Docker build and run
############################################
docker-compose build
docker-compose up -d

############################################
# Wait for MySQL
############################################
for i in {1..30}; do
    if docker-compose exec -T mysql mysqladmin ping -h"localhost" --silent &>/dev/null; then break; fi
    sleep 2
done

############################################
# Run migrations
############################################
docker-compose exec -T backend alembic upgrade head
docker-compose exec -T backend python scripts/init_db.py

echo "✅ Installation completed successfully!"
