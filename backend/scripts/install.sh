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

configure_dns() {
    colorized_echo blue "Configuring DNS for Docker..."

    # Stop systemd-resolved
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true

    # Configure /etc/resolv.conf
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

    chattr +i /etc/resolv.conf 2>/dev/null || true

    # Configure Docker daemon
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF

    systemctl restart docker 2>/dev/null || true
    colorized_echo green "DNS configured successfully"
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

    for pkg in curl wget jq rsync git openssl; do
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

FROM python:${PYTHON_VERSION}-slim AS build

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libc-dev \
        libffi-dev \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

FROM python:${PYTHON_VERSION}-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY --from=build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

COPY . /app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["sh", "-c", "alembic upgrade head && python scripts/init_db.py && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
EOF

    colorized_echo green "Dockerfile updated"
}

create_docker_compose() {
    colorized_echo blue "Creating docker-compose.yml..."

    cat > "$COMPOSE_FILE" <<'EOF'
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: boleylapanel-backend
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "8000:8000"
    volumes:
      - ./app:/app/app
      - ${DATA_DIR:-/var/lib/boleylapanel}:/var/lib/boleylapanel
    depends_on:
      mysql:
        condition: service_healthy
    dns:
      - 8.8.8.8
      - 8.8.4.4
    networks:
      - boleylapanel-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  mysql:
    image: mysql:8.0
    container_name: boleylapanel-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-boleylapanel}
      MYSQL_USER: ${MYSQL_USER:-boleylapanel}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --innodb-buffer-pool-size=256M
      --max-connections=200
    dns:
      - 8.8.8.8
      - 8.8.4.4
    networks:
      - boleylapanel-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  mysql_data:

networks:
  boleylapanel-network:
    driver: bridge
EOF

    colorized_echo green "docker-compose.yml created"
}

create_env_file() {
    colorized_echo blue "Creating .env file..."

    read -p "Enter admin username [admin]: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

    read -sp "Enter admin password: " ADMIN_PASSWORD
    echo
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(generate_password)
        colorized_echo yellow "Generated admin password: $ADMIN_PASSWORD"
    fi

    MYSQL_ROOT_PASSWORD=$(generate_password)
    MYSQL_PASSWORD=$(generate_password)
    JWT_SECRET=$(generate_password)

    cat > "$ENV_FILE" <<EOF
# Application
APP_NAME=BoleylPanel
DATA_DIR=/var/lib/boleylapanel

# Admin User
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD

# Database
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleylapanel
MYSQL_PASSWORD=$MYSQL_PASSWORD
DATABASE_URL=mysql+pymysql://boleylapanel:$MYSQL_PASSWORD@mysql:3306/boleylapanel

# JWT
JWT_SECRET_KEY=$JWT_SECRET
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=43200

# Xray
XRAY_EXECUTABLE_PATH=/var/lib/boleylapanel/xray/xray
EOF

    colorized_echo green ".env file created"
}

install_management_script() {
    colorized_echo blue "Installing management script..."

    cat > /usr/local/bin/boleylapanel <<'SCRIPT'
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
        git pull
        docker compose down
        docker compose build --no-cache
        docker compose up -d
        ;;
    *)
        echo "Usage: boleylapanel {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
SCRIPT

    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "Management script installed (use: boleylapanel {start|stop|restart|logs|status|update})"
}

# ===========================
# Main Installation
# ===========================
main() {
    colorized_echo cyan "=================================="
    colorized_echo cyan "   BoleylPanel Installer"
    colorized_echo cyan "=================================="

    check_running_as_root
    install_dependencies
    install_docker
    detect_compose
    configure_dns

    copy_project_files
    fix_requirements
    update_dockerfile
    create_docker_compose
    create_env_file
    install_management_script

    colorized_echo blue "Building and starting containers..."
    cd "$APP_DIR"
    $COMPOSE build --no-cache
    $COMPOSE up -d

    colorized_echo green "=================================="
    colorized_echo green "Installation completed!"
    colorized_echo cyan "Panel URL: http://$(curl -s ifconfig.me):8000"
    colorized_echo cyan "Username: $ADMIN_USERNAME"
    colorized_echo cyan "Password: $ADMIN_PASSWORD"
    colorized_echo green "=================================="
    colorized_echo yellow "Management commands:"
    colorized_echo yellow "  boleylapanel start   - Start services"
    colorized_echo yellow "  boleylapanel stop    - Stop services"
    colorized_echo yellow "  boleylapanel logs    - View logs"
    colorized_echo yellow "  boleylapanel restart - Restart services"
    colorized_echo yellow "  boleylapanel status  - Check status"
    colorized_echo green "=================================="
}

main "$@"
