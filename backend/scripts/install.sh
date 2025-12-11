#!/bin/bash

set -e

echo ""
echo "=========================================="
echo "   BoleylaPanel Installer (Hybrid Mode)"
echo "=========================================="
echo ""

# Detect or install Docker
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
fi

# Detect docker compose plugin
if ! docker compose version &> /dev/null; then
    echo "Docker Compose plugin not found. Installing..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) \
        -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
fi

INSTALL_PATH="/opt/boleylapanel"

echo ""
echo "Installation path: $INSTALL_PATH"
echo ""

if [ -d "$INSTALL_PATH" ]; then
    echo "Directory already exists: $INSTALL_PATH"
    echo -n "Do you want to overwrite it? (y/n): "
    read overwrite
    if [ "$overwrite" != "y" ]; then
        echo "Installation cancelled."
        exit 1
    fi
    rm -rf "$INSTALL_PATH"
fi

mkdir -p "$INSTALL_PATH"

echo ""
echo "Fetching latest project..."
git clone https://github.com/boleyla1/boleylapanel "$INSTALL_PATH"

cd "$INSTALL_PATH/backend"

# Interactive Hybrid ENV builder
echo ""
echo "=========================================="
echo "       Environment Configuration"
echo "=========================================="
echo ""

# Defaults
DEF_MYSQL_ROOT_PASS=$(openssl rand -base64 16)
DEF_MYSQL_USER="boleylapanel"
DEF_MYSQL_PASS=$(openssl rand -base64 16)
DEF_MYSQL_DB="boleylapanel"

read -p "MySQL root password [$DEF_MYSQL_ROOT_PASS]: " MYSQL_ROOT_PASSWORD
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$DEF_MYSQL_ROOT_PASS}

read -p "MySQL user [$DEF_MYSQL_USER]: " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-$DEF_MYSQL_USER}

read -p "MySQL user password [$DEF_MYSQL_PASS]: " MYSQL_PASSWORD
MYSQL_PASSWORD=${MYSQL_PASSWORD:-$DEF_MYSQL_PASS}

read -p "MySQL database name [$DEF_MYSQL_DB]: " MYSQL_DATABASE
MYSQL_DATABASE=${MYSQL_DATABASE:-$DEF_MYSQL_DB}

DATABASE_URL="mysql+pymysql://${MYSQL_USER}:${MYSQL_PASSWORD}@mysql:3306/${MYSQL_DATABASE}"

echo "Writing .env file..."
cat > .env <<EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}

DATABASE_URL=${DATABASE_URL}
EOF

echo ""
echo "ENV created successfully."
echo ""

echo "Starting containers..."

cd "$INSTALL_PATH"

docker compose up -d --build

echo ""
echo "=========================================="
echo "         Installation Completed"
echo "=========================================="
echo "Backend URL: http://<server-ip>:8000"
echo "MySQL User:  $MYSQL_USER"
echo "MySQL Pass:  $MYSQL_PASSWORD"
echo "Database:    $MYSQL_DATABASE"
echo ""
echo "Log viewer:"
echo "  docker logs -f boleylapanel-backend"
echo ""
