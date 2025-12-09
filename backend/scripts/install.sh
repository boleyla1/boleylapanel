#!/usr/bin/env bash
set -e

# ====== Colors ======
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
GIT_REPO="https://github.com/boleyla1/boleylapanel.git"

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

install_package() {
    local package=$1
    if ! command -v $package &> /dev/null; then
        colorized_echo blue "Installing $package..."
        apt-get update -qq
        apt-get install -y -qq $package
    fi
}

prompt_for_mysql_password() {
    colorized_echo cyan "Enter password for MySQL user (or press Enter for auto-generation): "
    read -r MYSQL_PASSWORD
    if [ -z "$MYSQL_PASSWORD" ]; then
        MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
        colorized_echo green "✓ Auto-generated MySQL password: $MYSQL_PASSWORD"
    fi
}

# ====== Main ======
check_running_as_root

# نصب پیش‌نیازها
for pkg in curl git docker docker-compose; do
    install_package $pkg
done

# دانلود پروژه اگر موجود نیست
if [ ! -d "$APP_DIR" ]; then
    colorized_echo blue "📥 Cloning project..."
    cd /opt
    git clone "$GIT_REPO"
fi

mkdir -p "$DATA_DIR"
cd "$APP_DIR"

# ساخت docker-compose.yml
cat > "$COMPOSE_FILE" << 'EOF'
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
    image: mysql:8.0
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
EOF
colorized_echo green "✓ docker-compose.yml created"

# ساخت .env
prompt_for_mysql_password
MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
SECRET_KEY=$(openssl rand -hex 32)
cat > "$ENV_FILE" << EOF
SECRET_KEY=$SECRET_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleyla
MYSQL_PASSWORD=$MYSQL_PASSWORD
DATABASE_URL=mysql+pymysql://boleyla:${MYSQL_PASSWORD}@mysql:3306/boleylapanel
EOF
colorized_echo green "✓ .env file created"

# بررسی وجود Dockerfile
if [ ! -f "./backend/Dockerfile" ]; then
    colorized_echo red "❌ Dockerfile not found in backend/"
    exit 1
fi

# ساخت Docker image
colorized_echo blue "🔨 Building Docker image..."
cd ./backend
DOCKER_BUILDKIT=1 docker build --network=host -t boleylapanel .

# راه‌اندازی سرویس‌ها
colorized_echo blue "🚀 Starting services..."
cd "$APP_DIR"
docker compose up -d

colorized_echo green "🎉 Installation completed!"
docker compose ps
