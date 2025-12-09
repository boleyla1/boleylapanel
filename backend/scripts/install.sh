#!/usr/bin/env bash
set -e

# ===========================
# Configuration
# ===========================
INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
SOURCE_DIR="/root/boleylapanel"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"
DOCKERFILE="$APP_DIR/Dockerfile"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ===========================
# Helper Functions
# ===========================
colorized_echo() {
    local color=$1
    local text=$2
    case $color in
        "red") printf "${RED}${text}${NC}\n";;
        "green") printf "${GREEN}${text}${NC}\n";;
        "yellow") printf "${YELLOW}${text}${NC}\n";;
        "blue") printf "${BLUE}${text}${NC}\n";;
        "cyan") printf "${CYAN}${text}${NC}\n";;
        "magenta") printf "${MAGENTA}${text}${NC}\n";;
        *) echo "${text}";;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This script must be run as root."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
    elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager..."
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update -qq
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_package() {
    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE..."
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y install "$PACKAGE" >/dev/null 2>&1
    fi
}

install_docker() {
    if command -v docker &> /dev/null; then
        colorized_echo green "Docker is already installed"
        return
    fi

    colorized_echo blue "Installing Docker..."
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker >/dev/null 2>&1
    colorized_echo green "Docker installed successfully"
}

detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "docker compose not found"
        exit 1
    fi
}

generate_password() {
    openssl rand -base64 20 | tr -d "=+/" | cut -c1-20
}

# ===========================
# Installation Functions
# ===========================
install_dependencies() {
    colorized_echo blue "Installing required packages..."
    detect_os
    detect_and_update_package_manager

    for pkg in curl wget jq rsync git; do
        if ! command -v $pkg &> /dev/null; then
            install_package $pkg
        fi
    done

    colorized_echo green "Dependencies installed"
}

copy_project_files() {
    colorized_echo blue "Copying project files..."

    if [ ! -d "$SOURCE_DIR" ]; then
        colorized_echo red "Source directory not found: $SOURCE_DIR"
        exit 1
    fi

    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/logs"
    mkdir -p "$DATA_DIR/xray"
    mkdir -p "$DATA_DIR/config"
    mkdir -p "$DATA_DIR/backups"

    rsync -a --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' \
        --exclude='venv' --exclude='.venv' --exclude='.env' \
        --exclude='mysql_data' --exclude='logs' \
        "$SOURCE_DIR/" "$APP_DIR/"

    colorized_echo green "Project files copied"
}

fix_requirements() {
    colorized_echo blue "Updating requirements.txt (Pydantic V2)..."

    cat > "$APP_DIR/requirements.txt" <<'EOF'
# FastAPI & Web Framework
fastapi==0.115.6
uvicorn[standard]==0.34.0
python-multipart==0.0.20

# Database
sqlalchemy==2.0.36
alembic==1.14.0
pymysql==1.1.1
cryptography==44.0.0

# Pydantic V2 (Compatible)
pydantic==2.10.5
pydantic-settings==2.6.1
email-validator==2.2.0

# Authentication & Security
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
bcrypt==4.2.1

# Utilities
python-dotenv==1.0.1
httpx==0.28.1
jinja2==3.1.5
pyyaml>=6.0.2

# Logging
loguru==0.7.3
EOF

    colorized_echo green "requirements.txt updated"
}

update_dockerfile() {
    colorized_echo blue "Updating Dockerfile..."

    cat > "$DOCKERFILE" <<'EOF'
ARG PYTHON_VERSION=3.11

# ===========================
# Stage 1: Build Dependencies
# ===========================
FROM python:${PYTHON_VERSION}-slim AS build

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /build

# Install build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libc-dev \
        libffi-dev \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN python3 -m pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# ===========================
# Stage 2: Runtime Image
# ===========================
FROM python:${PYTHON_VERSION}-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy packages from build stage
COPY --from=build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# Copy application code
COPY . /app

EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=5)" || exit 1

# Run migrations and start
CMD ["sh", "-c", "alembic upgrade head && python scripts/init_db.py && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
EOF

    colorized_echo green "Dockerfile updated"
}

setup_docker_compose() {
    colorized_echo blue "Setting up docker-compose.yml..."

    cat > "$COMPOSE_FILE" <<'EOF'
version: "3.9"

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: boleylapanel-backend
    restart: unless-stopped
    env_file: .env
    ports:
      - "8000:8000"
    volumes:
      - /var/lib/boleylapanel:/var/lib/boleylapanel
      - /var/lib/boleylapanel/logs:/app/logs
      - /var/lib/boleylapanel/xray:/app/xray
      - /var/lib/boleylapanel/config:/app/config
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - boleylapanel-network

  mysql:
    image: mysql:8.0
    container_name: boleylapanel-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    command:
      - --bind-address=0.0.0.0
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --default-authentication-plugin=mysql_native_password
      - --innodb-buffer-pool-size=256M
      - --innodb-log-file-size=64M
      - --max_connections=200
    volumes:
      - /var/lib/boleylapanel/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - boleylapanel-network

networks:
  boleylapanel-network:
    driver: bridge
EOF

    colorized_echo green "docker-compose.yml created"
}

interactive_setup() {
    clear
    colorized_echo blue "═══════════════════════════════════════════"
    colorized_echo blue "    BoleylPanel Installation Wizard       "
    colorized_echo blue "═══════════════════════════════════════════"
    echo ""

    # Admin username
    read -p "$(echo -e ${YELLOW}Enter admin username [admin]: ${NC})" ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-admin}

    # Admin email
    read -p "$(echo -e ${YELLOW}Enter admin email [admin@example.com]: ${NC})" ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

    # Admin password
    while true; do
        read -sp "$(echo -e ${YELLOW}Enter admin password (leave empty for auto-generate): ${NC})" ADMIN_PASSWORD
        echo ""
        if [ -z "$ADMIN_PASSWORD" ]; then
            ADMIN_PASSWORD=$(generate_password)
            colorized_echo green "✓ Generated password: $ADMIN_PASSWORD"
            break
        elif [ ${#ADMIN_PASSWORD} -ge 8 ]; then
            break
        else
            colorized_echo red "Password must be at least 8 characters"
        fi
    done

    # Database configuration
    DB_USER="boleyla"
    DB_NAME="boleylapanel"
    DB_PASSWORD=$(generate_password)
    MYSQL_ROOT_PASSWORD=$(generate_password)

    # Security keys
    SECRET_KEY=$(openssl rand -hex 32)

    colorized_echo green "✓ Configuration completed"
    echo ""
}

create_env_file() {
    colorized_echo blue "Creating .env file..."

    cat > "$ENV_FILE" <<EOF
# ==============================================
# Application Settings
# ==============================================
APP_NAME=BoleylaPanel
APP_VERSION=1.0.0
APP_ENV=production
DEBUG=false
PROJECT_NAME=BoleylaPanel

# ==============================================
# Server Settings
# ==============================================
HOST=0.0.0.0
PORT=8000
API_V1_STR=/api/v1

# ==============================================
# Database Settings - MySQL
# ==============================================
DB_HOST=mysql
DB_PORT=3306
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# MySQL Root Password
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${DB_NAME}
MYSQL_USER=${DB_USER}
MYSQL_PASSWORD=${DB_PASSWORD}

# SQLAlchemy URL
SQLALCHEMY_DATABASE_URL=mysql+pymysql://${DB_USER}:${DB_PASSWORD}@mysql:3306/${DB_NAME}

# ==============================================
# Security Settings
# ==============================================
SECRET_KEY=${SECRET_KEY}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# ==============================================
# Admin Configuration
# ==============================================
ADMIN_USERNAME=${ADMIN_USER}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# ==============================================
# CORS Settings
# ==============================================
CORS_ORIGINS=["http://localhost:3000","http://localhost:8000"]

# ==============================================
# Xray Settings
# ==============================================
XRAY_CONFIG_TEMPLATE_PATH=/app/config/xray_template.json
XRAY_CONFIG_OUTPUT_PATH=/var/lib/boleylapanel/xray/output_configs
XRAY_SERVICE_NAME=XrayService
ENABLE_XRAY_SERVICE=true
XRAY_BASE_PORT=10000

# ==============================================
# File Upload Settings
# ==============================================
MAX_UPLOAD_SIZE=10485760
ALLOWED_EXTENSIONS=json,conf,txt

# ==============================================
# Logging
# ==============================================
LOG_LEVEL=INFO
LOG_FILE=/var/lib/boleylapanel/logs/app.log

# ==============================================
# Backup Settings
# ==============================================
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=7
BACKUP_PATH=/var/lib/boleylapanel/backups

# ==============================================
# Data Directory
# ==============================================
DATA_DIR=/var/lib/boleylapanel
EOF

    chmod 600 "$ENV_FILE"
    colorized_echo green ".env file created"
}

build_and_start() {
    colorized_echo blue "Building Docker images..."

    cd "$APP_DIR"
    detect_compose

    colorized_echo yellow "════════════════════════════════════════════"
    colorized_echo yellow " Building... This may take several minutes"
    colorized_echo yellow "════════════════════════════════════════════"

    $COMPOSE build --no-cache 2>&1 | tee /tmp/boleylapanel_build.log

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        colorized_echo green "✓ Build completed successfully"
    else
        colorized_echo red "✗ Build failed. Check /tmp/boleylapanel_build.log"
        exit 1
    fi

    colorized_echo yellow "Starting containers..."
    $COMPOSE up -d

    colorized_echo green "✓ Services started"
}

check_services() {
    colorized_echo yellow "Waiting for services to initialize..."
    sleep 25

    cd "$APP_DIR"

    colorized_echo blue "═══════════════════════════════════════════"
    colorized_echo blue " Service Status:"
    colorized_echo blue "═══════════════════════════════════════════"
    $COMPOSE ps

    echo ""
    colorized_echo blue "Recent Logs:"
    colorized_echo blue "═══════════════════════════════════════════"
    $COMPOSE logs --tail=40 backend
}

install_management_script() {
    colorized_echo blue "Installing management script..."

    cat > /usr/local/bin/boleylapanel <<'SCRIPT_EOF'
#!/bin/bash
APP_DIR="/opt/boleylapanel"
cd "$APP_DIR"

case "$1" in
    start)
        docker compose up -d
        ;;
    stop)
        docker compose down
        ;;
    restart)
        docker compose restart
        ;;
    logs)
        docker compose logs -f "${2:-backend}"
        ;;
    status)
        docker compose ps
        ;;
    update)
        docker compose pull
        docker compose up -d --build
        ;;
    *)
        echo "Usage: boleylapanel {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
SCRIPT_EOF

    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "Management script installed"
}

display_summary() {
    local SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

    clear
    colorized_echo green "═══════════════════════════════════════════════"
    colorized_echo green "   ✓ BoleylPanel Installation Complete!     "
    colorized_echo green "═══════════════════════════════════════════════"
    echo ""
    colorized_echo cyan "🌐 Panel Access:"
    colorized_echo cyan "   URL:      http://${SERVER_IP}:8000"
    colorized_echo cyan "   API Docs: http://${SERVER_IP}:8000/docs"
    colorized_echo cyan "   Username: ${ADMIN_USER}"
    colorized_echo cyan "   Password: ${ADMIN_PASSWORD}"
    echo ""
    colorized_echo yellow "🔐 Database Credentials:"
    colorized_echo yellow "   User:     ${DB_USER}"
    colorized_echo yellow "   Password: ${DB_PASSWORD}"
    colorized_echo yellow "   Root:     ${MYSQL_ROOT_PASSWORD}"
    echo ""
    colorized_echo blue "📁 Installation Paths:"
    colorized_echo blue "   App:    ${APP_DIR}"
    colorized_echo blue "   Data:   ${DATA_DIR}"
    colorized_echo blue "   Config: ${ENV_FILE}"
    echo ""
    colorized_echo magenta "🛠️  Management Commands:"
    colorized_echo magenta "   boleylapanel start    - Start services"
    colorized_echo magenta "   boleylapanel stop     - Stop services"
    colorized_echo magenta "   boleylapanel restart  - Restart services"
    colorized_echo magenta "   boleylapanel logs     - View logs"
    colorized_echo magenta "   boleylapanel status   - Check status"
    colorized_echo magenta "   boleylapanel update   - Update panel"
    echo ""
    colorized_echo green "═══════════════════════════════════════════════"
    echo ""
    colorized_echo yellow "⚠️  IMPORTANT: Save these credentials securely!"
    echo ""
}

# ===========================
# Main Installation
# ===========================
main() {
    check_running_as_root

    clear
    colorized_echo blue "═══════════════════════════════════════════════"
    colorized_echo blue "      BoleylPanel Installation Script        "
    colorized_echo blue "═══════════════════════════════════════════════"
    echo ""

    # Check if already installed
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "⚠️  BoleylPanel is already installed"
        read -p "Override previous installation? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Installation cancelled"
            exit 0
        fi
        colorized_echo yellow "Removing previous installation..."
        cd "$APP_DIR" && docker compose down -v >/dev/null 2>&1 || true
        rm -rf "$APP_DIR"
    fi

    # Installation steps
    colorized_echo blue "[1/11] Installing dependencies..."
    install_dependencies

    colorized_echo blue "[2/11] Checking Docker..."
    install_docker

    colorized_echo blue "[3/11] Copying project files..."
    copy_project_files

    colorized_echo blue "[4/11] Fixing requirements..."
    fix_requirements

    colorized_echo blue "[5/11] Updating Dockerfile..."
    update_dockerfile

    colorized_echo blue "[6/11] Setting up docker-compose..."
    setup_docker_compose

    colorized_echo blue "[7/11] Interactive configuration..."
    interactive_setup

    colorized_echo blue "[8/11] Creating environment file..."
    create_env_file

    colorized_echo blue "[9/11] Building and starting..."
    build_and_start

    colorized_echo blue "[10/11] Checking services..."
    check_services

    colorized_echo blue "[11/11] Installing management script..."
    install_management_script

    display_summary
}

main "$@"
