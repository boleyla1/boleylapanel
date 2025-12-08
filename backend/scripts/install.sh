#!/bin/bash
set -e

REPO_URL="https://github.com/boleyla1/boleylapanel.git"
INSTALL_DIR="boleylapanel"

echo "🚀 BoleylaPanel Backend Installation"
echo "======================================"
echo ""

# Update and install prerequisites
echo "📦 Installing prerequisites..."
sudo apt update
sudo apt install -y git curl wget unzip openssl
echo "✅ Prerequisites installed"
echo ""

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    echo "🐳 Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed"
fi

# Install Docker Compose if not installed
if ! command -v docker-compose &> /dev/null; then
    echo "🐋 Docker Compose not found. Installing..."
    DOCKER_COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
fi

# Clone repository if not exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📥 Cloning repository..."
    git clone $REPO_URL $INSTALL_DIR
    cd $INSTALL_DIR/backend
    echo "✅ Repository cloned"
else
    cd $INSTALL_DIR/backend
    echo "✅ Repository already exists, skipping clone"
fi
echo ""

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p logs xray/configs
echo "✅ Directories created"
echo ""

# Interactive Configuration
echo "📝 Configuration Setup"
read -p "Database Name [boleyla_panel]: " DB_NAME
DB_NAME=${DB_NAME:-boleyla_panel}

read -p "Database User [boleyla]: " DB_USER
DB_USER=${DB_USER:-boleyla}

while true; do
    read -sp "Database Password: " DB_PASSWORD
    echo ""
    if [ -z "$DB_PASSWORD" ]; then
        echo "❌ Password cannot be empty!"
    else
        read -sp "Confirm Password: " DB_PASSWORD_CONFIRM
        echo ""
        if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
            break
        else
            echo "❌ Passwords do not match!"
        fi
    fi
done

# JWT secret
JWT_SECRET=$(openssl rand -base64 32)

# Admin user
read -p "Admin Username [admin]: " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
read -p "Admin Email [admin@boleyla.local]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@boleyla.local}

while true; do
    read -sp "Admin Password: " ADMIN_PASSWORD
    echo ""
    if [ ${#ADMIN_PASSWORD} -lt 6 ]; then
        echo "❌ Password must be at least 6 characters!"
    else
        read -sp "Confirm Password: " ADMIN_PASSWORD_CONFIRM
        echo ""
        if [ "$ADMIN_PASSWORD" = "$ADMIN_PASSWORD_CONFIRM" ]; then
            break
        else
            echo "❌ Passwords do not match!"
        fi
    fi
done

# Create .env
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

echo "✅ .env file created"
echo ""

# Build and start containers
echo "🐋 Building Docker containers..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d

# Wait for MySQL
echo "⏳ Waiting for MySQL to be ready..."
for i in {1..30}; do
    if docker-compose exec -T mysql mysqladmin ping -h"localhost" --silent 2>/dev/null; then
        echo "✅ MySQL is ready"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Run migrations and init admin
docker-compose exec -T backend alembic upgrade head
docker-compose exec -T backend python scripts/init_db.py

echo ""
echo "======================================"
echo "✅ Installation completed successfully!"
echo "======================================"
echo ""
echo "📌 Access Information:"
echo "   API URL: http://localhost:8000"
echo "   API Docs: http://localhost:8000/docs"
echo ""
echo "🔐 Admin Credentials:"
echo "   Username: ${ADMIN_USERNAME}"
echo "   Email: ${ADMIN_EMAIL}"
echo "   Password: [hidden]"
echo ""
