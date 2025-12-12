#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

# Default values
DATABASE_TYPE="mysql"
INSTALL_FRONTEND=false

colorized_echo() {
    local color=$1
    local text=$2
    case $color in
        "red") printf "${RED}${text}${NC}\n";;
        "green") printf "${GREEN}${text}${NC}\n";;
        "yellow") printf "${YELLOW}${text}${NC}\n";;
        "blue") printf "${BLUE}${text}${NC}\n";;
        "cyan") printf "${CYAN}${text}${NC}\n";;
        *) echo "${text}";;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "❌ This script must be run as root."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        colorized_echo red "❌ Unsupported operating system"
        exit 1
    fi
    colorized_echo green "✅ Detected OS: $OS $OS_VERSION"
}

install_docker() {
    if command -v docker &> /dev/null; then
        colorized_echo green "✅ Docker is already installed"
        return
    fi

    colorized_echo blue "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    colorized_echo green "✅ Docker installed successfully"
}

detect_compose() {
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version &> /dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "❌ Docker Compose not found"
        exit 1
    fi
}

create_directories() {
    colorized_echo blue "📁 Creating directories..."
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$APP_DIR/xray/output_configs"
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/backup"
    colorized_echo green "✅ Directories created"
}

generate_docker_compose() {
    colorized_echo blue "📝 Generating docker-compose.yml..."

    cat > "$COMPOSE_FILE" <<'EOF'
services:
  mysql:
    image: mysql:8.0
    container_name: boleylapanel-mysql
    restart: unless-stopped
    network_mode: host
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password --bind-address=127.0.0.1 --port=3306

  backend:
    image: boleyla1/boleylapanel-backend:latest
    container_name: boleylapanel-backend
    restart: unless-stopped
    network_mode: host
    depends_on:
      - mysql
    environment:
      DATABASE_URL: mysql+pymysql://${MYSQL_USER}:${MYSQL_PASSWORD}@127.0.0.1:3306/${MYSQL_DATABASE}
      SECRET_KEY: ${SECRET_KEY}
      ALGORITHM: HS256
      ACCESS_TOKEN_EXPIRE_MINUTES: 30
    volumes:
      - ./xray/output_configs:/app/xray/output_configs
      - ./logs:/app/logs

volumes:
  mysql_data:
EOF

    colorized_echo green "✅ docker-compose.yml created"
}
ask_database_info() {
    colorized_echo cyan "🔧 Database Configuration"

    read -rp "Database name [boleylapanel]: " MYSQL_DATABASE
    MYSQL_DATABASE=${MYSQL_DATABASE:-boleylapanel}

    read -rp "Database user [boleyla]: " MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-boleyla}

    while true; do
        read -rsp "Database password (leave empty to auto-generate): " MYSQL_PASSWORD
        echo ""
        if [ -n "$MYSQL_PASSWORD" ]; then
            read -rsp "Confirm database password: " MYSQL_PASSWORD_CONFIRM
            echo ""
            if [ "$MYSQL_PASSWORD" = "$MYSQL_PASSWORD_CONFIRM" ]; then
                break
            else
                colorized_echo red "❌ Passwords do not match"
            fi
        else
            MYSQL_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
            break
        fi
    done

    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    colorized_echo green "✅ Database configuration collected"
}

generate_env_file() {
    colorized_echo blue "🔐 Generating .env file..."

    # Generate random passwords
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    SECRET_KEY=$(openssl rand -hex 32)

    cat > "$ENV_FILE" <<EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleyla
MYSQL_PASSWORD=$MYSQL_PASSWORD

# Backend Configuration
SECRET_KEY=$SECRET_KEY
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
EOF

    chmod 600 "$ENV_FILE"
    colorized_echo green "✅ .env file created with secure passwords"
}

install_management_script() {
    colorized_echo blue "📜 Installing management script..."

    cat > /usr/local/bin/boleyla <<'SCRIPT_EOF'
#!/bin/bash
set -e

APP_DIR="/opt/boleylapanel"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

colorized_echo() {
    local color=$1
    local text=$2
    case $color in
        red) printf "\e[91m${text}\e[0m\n";;
        green) printf "\e[92m${text}\e[0m\n";;
        yellow) printf "\e[93m${text}\e[0m\n";;
        blue) printf "\e[94m${text}\e[0m\n";;
        cyan) printf "\e[96m${text}\e[0m\n";;
        *) echo "${text}";;
    esac
}

detect_compose() {
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version &> /dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "Docker Compose not found"
        exit 1
    fi
}

detect_compose
cd "$APP_DIR" || exit 1

case "$1" in
    up|start)
        colorized_echo blue "🚀 Starting BoleylaPanel..."
        $COMPOSE -f "$COMPOSE_FILE" up -d
        colorized_echo green "✅ BoleylaPanel started successfully"
        ;;
    down|stop)
        colorized_echo blue "🛑 Stopping BoleylaPanel..."
        $COMPOSE -f "$COMPOSE_FILE" down
        colorized_echo green "✅ BoleylaPanel stopped"
        ;;
    restart)
        colorized_echo blue "🔄 Restarting BoleylaPanel..."
        $COMPOSE -f "$COMPOSE_FILE" restart
        colorized_echo green "✅ BoleylaPanel restarted"
        ;;
    logs)
        shift
        $COMPOSE -f "$COMPOSE_FILE" logs -f "$@"
        ;;
    status)
        $COMPOSE -f "$COMPOSE_FILE" ps
        ;;
   update)
    colorized_echo blue "📥 Updating BoleylaPanel..."

    $COMPOSE -f "$COMPOSE_FILE" pull

    $COMPOSE -f "$COMPOSE_FILE" up -d \
        --force-recreate \
        --pull always \
        --remove-orphans

    colorized_echo green "✅ BoleylaPanel updated successfully"
    ;;
    uninstall)
        echo "⚠️  This will remove all data. Are you sure? (yes/no)"
        read -r confirm
        if [ "$confirm" = "yes" ]; then
            colorized_echo blue "🗑️  Uninstalling BoleylaPanel..."
            $COMPOSE -f "$COMPOSE_FILE" down -v
            rm -rf "$APP_DIR"
            rm -f /usr/local/bin/boleyla
            colorized_echo green "✅ BoleylaPanel uninstalled"
        else
            colorized_echo yellow "Uninstall cancelled"
        fi
        ;;
    *)
        colorized_echo cyan "╔════════════════════════════════════════╗"
        colorized_echo cyan "║      BoleylaPanel Management CLI       ║"
        colorized_echo cyan "╚════════════════════════════════════════╝"
        echo ""
        colorized_echo yellow "Available commands:"
        echo "  boleyla start      - Start services"
        echo "  boleyla stop       - Stop services"
        echo "  boleyla restart    - Restart services"
        echo "  boleyla logs       - Show logs (optional: service name)"
        echo "  boleyla status     - Show status of services"
        echo "  boleyla update     - Update to latest version"
        echo "  boleyla uninstall  - Remove BoleylaPanel completely"
        echo ""
        ;;
esac
SCRIPT_EOF

    chmod +x /usr/local/bin/boleyla
    colorized_echo green "✅ Management script installed: boleyla"
}

start_services() {
    colorized_echo blue "🚀 Starting services..."
    cd "$APP_DIR"
    $COMPOSE -f "$COMPOSE_FILE" pull
    $COMPOSE -f "$COMPOSE_FILE" up -d

    colorized_echo yellow "⏳ Waiting for services to be ready..."
    sleep 15

    if $COMPOSE -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        colorized_echo green "✅ BoleylaPanel started successfully!"
    else
        colorized_echo red "⚠️  Some services may not be running. Check logs: boleyla logs"
    fi
}

show_final_message() {
    local SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

    echo ""
    colorized_echo green "╔════════════════════════════════════════╗"
    colorized_echo green "║   BoleylaPanel Installation Complete   ║"
    colorized_echo green "╚════════════════════════════════════════╝"
    echo ""
    colorized_echo cyan "📍 Installation Directory: $APP_DIR"
    colorized_echo cyan "📊 API Documentation: http://$SERVER_IP:8000/docs"
    colorized_echo cyan "🔐 Database: MySQL (credentials in .env)"
    echo ""
    colorized_echo yellow "Useful Commands:"
    echo "  boleyla start      - Start services"
    echo "  boleyla stop       - Stop services"
    echo "  boleyla logs       - View logs"
    echo "  boleyla status     - Check status"
    echo "  boleyla update     - Update panel"
    echo ""
    colorized_echo green "╚════════════════════════════════════════╝"
    echo ""
}

install_command() {
    colorized_echo blue "╔════════════════════════════════════════╗"
    colorized_echo blue "║   Installing BoleylaPanel VPN Panel    ║"
    colorized_echo blue "╚════════════════════════════════════════╝"
    echo ""

    check_running_as_root
    detect_os
    install_docker
    detect_compose
    create_directories
    generate_docker_compose
    generate_env_file
    install_management_script
    start_services
    show_final_message
}

# Parse arguments
case "$1" in
    install)
        shift
        # Parse additional arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --database)
                    DATABASE_TYPE="$2"
                    shift 2
                    ;;
                --with-frontend)
                    INSTALL_FRONTEND=true
                    shift
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        install_command
        ;;
    *)
        colorized_echo red "Usage: $0 install [--database mysql] [--with-frontend]"
        exit 1
        ;;
esac
