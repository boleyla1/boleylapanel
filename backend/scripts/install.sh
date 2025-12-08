#!/bin/bash
set -e

REPO_URL="https://github.com/boleyla1/boleylapanel.git"
INSTALL_DIR="boleylapanel"

echo "🚀 Installing BoleylaPanel Backend"

# Update prerequisites
sudo apt update
sudo apt install -y git curl wget unzip openssl

# Install Docker if missing
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
fi

# Install Docker Compose if missing
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Clone project
if [ ! -d "$INSTALL_DIR" ]; then
    git clone $REPO_URL $INSTALL_DIR
fi
cd $INSTALL_DIR/backend

# Create dirs
mkdir -p logs xray/configs

# User input
read -p "DB Name [boleyla_panel]: " DB_NAME
DB_NAME=${DB_NAME:-boleyla_panel}
read -p "DB User [boleyla]: " DB_USER
DB_USER=${DB_USER:-boleyla}

# DB Password with confirmation
while true; do
    read -sp "DB Password: " DB_PASSWORD
    echo ""
    read -sp "Confirm DB Password: " DB_PASSWORD_CONFIRM
    echo ""
    if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "❌ Passwords do not match! Try again."
    fi
done

JWT_SECRET=$(openssl rand -base64 32)

read -p "Admin Username [admin]: " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
read -p "Admin Email [admin@boleyla.local]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@boleyla.local}

# Admin Password with confirmation
while true; do
    read -sp "Admin Password: " ADMIN_PASSWORD
    echo ""
    read -sp "Confirm Admin Password: " ADMIN_PASSWORD_CONFIRM
    echo ""
    if [ "$ADMIN_PASSWORD" = "$ADMIN_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "❌ Passwords do not match! Try again."
    fi
done

# Write .env
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
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF

# Configure Docker DNS
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "dns": ["8.8.8.8","8.8.4.4","1.1.1.1"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

# Build & run
docker-compose build --network host
docker-compose up -d

# shellcheck disable=SC2034
for _ in {1..30}; do
    if docker-compose exec -T mysql mysqladmin ping -h"localhost" --silent 2>/dev/null; then break; fi
    sleep 2
done


# Migrations
docker-compose exec -T backend alembic upgrade head
docker-compose exec -T backend python scripts/init_db.py

echo "✅ Installation finished"
