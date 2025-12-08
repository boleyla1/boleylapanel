#!/bin/bash

set -e

echo "🚀 BoleylaPanel Backend Installation"
echo "======================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed!"
    echo "Please install Docker Compose first"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p logs
mkdir -p xray/configs
echo "✅ Directories created"
echo ""

# Interactive Configuration
echo "📝 Configuration Setup"
echo "======================"
echo ""

# MySQL Configuration
echo "🗄️  MySQL Database Configuration:"
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

echo "✅ Database configuration saved"
echo ""

# JWT Secret Key
echo "🔐 JWT Configuration:"
echo "Generating secure secret key..."
JWT_SECRET=$(openssl rand -base64 32)
echo "✅ Secret key generated"
echo ""

# Admin User Configuration
echo "👤 Admin User Configuration:"
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

echo "✅ Admin configuration saved"
echo ""

# Create .env file
echo "📝 Creating .env file..."
cat > .env << EOF
# Database Configuration
DB_HOST=mysql
DB_PORT=3306
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}

# JWT Configuration
SECRET_KEY=${JWT_SECRET}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# API Configuration
API_V1_STR=/api/v1
PROJECT_NAME=BoleylaPanel

# Xray Configuration
XRAY_API_HOST=0.0.0.0
XRAY_API_PORT=10085

# Admin Configuration (for initial setup)
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF

echo "✅ .env file created"
echo ""

# Update docker-compose.yml with MySQL credentials
echo "🐋 Updating docker-compose.yml..."
sed -i "s/MYSQL_DATABASE=.*/MYSQL_DATABASE=${DB_NAME}/" docker-compose.yml || true
sed -i "s/MYSQL_USER=.*/MYSQL_USER=${DB_USER}/" docker-compose.yml || true
sed -i "s/MYSQL_PASSWORD=.*/MYSQL_PASSWORD=${DB_PASSWORD}/" docker-compose.yml || true
sed -i "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=${DB_PASSWORD}/" docker-compose.yml || true

# Build and start containers
echo "🐋 Building Docker containers..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d

# Wait for MySQL
echo "⏳ Waiting for MySQL to be ready..."
for i in {1..30}; do
    if docker-compose exec -T mysql mysqladmin ping -h"localhost" --silent; then
        echo "✅ MySQL is ready"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Run migrations
echo "📊 Running database migrations..."
docker-compose exec -T backend alembic upgrade head

# Create admin user
echo "👤 Creating admin user..."
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
echo "⚠️  IMPORTANT:"
echo "   1. Change admin password after first login"
echo "   2. Keep your .env file secure"
echo "   3. Regular backups recommended"
echo ""
echo "📝 Useful Commands:"
echo "   docker-compose logs -f          # View logs"
echo "   docker-compose restart          # Restart services"
echo "   docker-compose down             # Stop services"
echo ""
