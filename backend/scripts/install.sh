#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_NAME="boleylapanel"
APP_DIR="/opt/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

colorized_echo() {
    local color=$1
    shift
    case $color in
        red) echo -e "${RED}$*${NC}" ;;
        green) echo -e "${GREEN}$*${NC}" ;;
        yellow) echo -e "${YELLOW}$*${NC}" ;;
        blue) echo -e "${BLUE}$*${NC}" ;;
        cyan) echo -e "${CYAN}$*${NC}" ;;
        *) echo "$*" ;;
    esac
}

check_running_as_root() {
    if [ "$EUID" -ne 0 ]; then
        colorized_echo red "❌ Please run with sudo"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    else
        colorized_echo red "Cannot detect operating system"
        exit 1
    fi
}

install_package() {
    local package=$1
    colorized_echo blue "Installing $package..."
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq $package
            ;;
        centos|fedora|rhel)
            yum install -y -q $package
            ;;
        arch)
            pacman -S --noconfirm $package
            ;;
        *)
            colorized_echo red "Unsupported operating system"
            exit 1
            ;;
    esac
}

prompt_for_mysql_password() {
    colorized_echo cyan "This password will be used to access the MySQL database."
    colorized_echo cyan "If you do not enter a custom password, a secure 20-character password will be generated automatically."
    echo ""
    read -p "Enter password for MySQL user (or press Enter for auto-generation): " MYSQL_PASSWORD

    if [ -z "$MYSQL_PASSWORD" ]; then
        MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
        colorized_echo green "✓ A secure password has been generated automatically."
    fi
    colorized_echo green "✓ This password will be saved in .env file."
    sleep 1
}

# ====== Main ======
check_running_as_root

if [ -d "$APP_DIR" ]; then
    colorized_echo yellow "⚠️  Previous installation detected at $APP_DIR"
    read -p "Do you want to override the previous installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Installation aborted"
        exit 1
    fi
    cd $APP_DIR 2>/dev/null && docker compose down 2>/dev/null || true
    rm -rf $APP_DIR
fi

detect_os

colorized_echo blue "📦 Checking required packages..."
for pkg in curl git docker; do
    if ! command -v $pkg &> /dev/null; then
        install_package $pkg
    fi
done

colorized_echo blue "📥 Preparing backend directory..."

# اگر backend خالیه یا Dockerfile موجود نیست، پروژه رو clone کن
if [ ! -f "$APP_DIR/backend/Dockerfile" ]; then
    colorized_echo yellow "⚠️  backend directory is empty or Dockerfile missing. Cloning project..."
    rm -rf "$APP_DIR"
    git clone https://github.com/boleyla1/boleylapanel.git "$APP_DIR"
fi

# بررسی اینکه Dockerfile موجوده
if [ ! -f "$APP_DIR/backend/Dockerfile" ]; then
    colorized_echo red "❌ Dockerfile not found in backend. Cannot build Docker image."
    exit 1
fi

colorized_echo green "✓ backend directory ready for Docker build"

mkdir -p $DATA_DIR

colorized_echo blue "⚙️  Setting up docker-compose.yml with MySQL..."
cat > "$COMPOSE_FILE" << 'COMPOSE_EOF'
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
    image: mysql:lts
    env_file: .env
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-u", "root", "--password=${MYSQL_ROOT_PASSWORD}"]
      start_period: 10s
      interval: 5s
      timeout: 5s
      retries: 55
COMPOSE_EOF
colorized_echo green "✓ docker-compose.yml created"

colorized_echo blue "⚙️  Creating .env file..."
prompt_for_mysql_password
MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
SECRET_KEY=$(openssl rand -hex 32)
cat > "$ENV_FILE" << ENV_EOF
SECRET_KEY=$SECRET_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleyla
MYSQL_PASSWORD=$MYSQL_PASSWORD
DATABASE_URL=mysql+pymysql://boleyla:${MYSQL_PASSWORD}@mysql:3306/boleylapanel
ENV_EOF
colorized_echo green "✓ .env file created with MySQL configuration"

colorized_echo blue "🔨 Building Docker image..."
cd $APP_DIR/backend
DOCKER_BUILDKIT=1 docker build --network=host -t boleylapanel .

colorized_echo blue "🚀 Starting services..."
cd $APP_DIR
docker compose up -d

colorized_echo green "🎉 Installation completed!"
docker compose ps
