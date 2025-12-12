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

DATABASE_TYPE="mysql"
INSTALL_FRONTEND=false

colorized_echo() {
    local color=$1
    local text=$2
    case $color in
        red) printf "${RED}${text}${NC}\n";;
        green) printf "${GREEN}${text}${NC}\n";;
        yellow) printf "${YELLOW}${text}${NC}\n";;
        blue) printf "${BLUE}${text}${NC}\n";;
        cyan) printf "${CYAN}${text}${NC}\n";;
        *) echo "${text}";;
    esac
}

check_running_as_root() {
    [ "$(id -u)" = "0" ] || {
        colorized_echo red "❌ This script must be run as root."
        exit 1
    }
}

detect_os() {
    [ -f /etc/os-release ] || {
        colorized_echo red "❌ Unsupported OS"
        exit 1
    }
    . /etc/os-release
    colorized_echo green "✅ Detected OS: $ID $VERSION_ID"
}

install_docker() {
    command -v docker &>/dev/null && {
        colorized_echo green "✅ Docker already installed"
        return
    }
    colorized_echo blue "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
}

detect_compose() {
    if docker compose version &>/dev/null; then
        COMPOSE="docker compose"
    elif docker-compose version &>/dev/null; then
        COMPOSE="docker-compose"
    else
        colorized_echo red "❌ Docker Compose not found"
        exit 1
    fi
}

create_directories() {
    mkdir -p "$APP_DIR" "$DATA_DIR" \
             "$APP_DIR/xray/output_configs" \
             "$APP_DIR/logs" \
             "$APP_DIR/backup"
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
        [ -z "$MYSQL_PASSWORD" ] && {
            MYSQL_PASSWORD="$(openssl rand -base64 24 | tr -d '=+/' | head -c20)"
            break
        }
        read -rsp "Confirm password: " CONFIRM
        echo ""
        [ "$MYSQL_PASSWORD" = "$CONFIRM" ] && break
        colorized_echo red "❌ Passwords do not match"
    done

    MYSQL_ROOT_PASSWORD="$(openssl rand -base64 32 | tr -d '=+/' | head -c25)"
}

generate_env_file() {
cat > "$ENV_FILE" <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

SECRET_KEY=$(openssl rand -hex 32)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
EOF
chmod 600 "$ENV_FILE"
}

generate_docker_compose() {
cat > "$COMPOSE_FILE" <<'EOF'
services:
  mysql:
    image: mysql:8.0
    container_name: boleylapanel-mysql
    restart: unless-stopped
    network_mode: host
    env_file: .env
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password --bind-address=127.0.0.1
    healthcheck:
      test: ["CMD","mysqladmin","ping","-h","127.0.0.1","-u","${MYSQL_USER}","--password=${MYSQL_PASSWORD}"]
      interval: 5s
      timeout: 5s
      retries: 30

  backend:
    image: boleyla1/boleylapanel-backend:latest
    container_name: boleylapanel-backend
    restart: unless-stopped
    network_mode: host
    depends_on:
      mysql:
        condition: service_healthy
    env_file: .env
    volumes:
      - ./xray/output_configs:/app/xray/output_configs
      - ./logs:/app/logs
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000

volumes:
  mysql_data:
EOF
}

install_management_script() {
cat > /usr/local/bin/boleyla <<'EOF'
#!/usr/bin/env bash
set -e
APP_DIR="/opt/boleylapanel"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

detect_compose() {
    docker compose version &>/dev/null && COMPOSE="docker compose" || COMPOSE="docker-compose"
}

detect_compose
cd "$APP_DIR" || exit 1

case "$1" in
  up|start)   $COMPOSE up -d ;;
  down|stop) $COMPOSE down ;;
  restart)   $COMPOSE restart ;;
  status)    $COMPOSE ps ;;
  logs) shift; $COMPOSE logs -f "$@";;
  update)    $COMPOSE pull && $COMPOSE up -d --force-recreate --remove-orphans ;;
  uninstall) bash install.sh uninstall ;;
  *) echo "Usage: boleyla up|down|restart|status|logs|update|uninstall" ;;
esac
EOF
chmod +x /usr/local/bin/boleyla
}

wait_for_mysql() {
    for i in {1..30}; do
        docker exec boleylapanel-mysql mysqladmin ping -h127.0.0.1 \
          -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" &>/dev/null && return
        sleep 2
    done
    colorized_echo red "❌ MySQL not ready"
    exit 1
}

run_migrations() {
    docker exec boleylapanel-backend python -m app.scripts.init_db
}

start_services() {
    $COMPOSE pull
    $COMPOSE up -d
}

install_command() {
    check_running_as_root

    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "⚠️ Existing installation found"
        read -rp "Overwrite? (yes/no): " c
        [ "$c" = "yes" ] || exit 1
    fi

    detect_os
    install_docker
    detect_compose
    create_directories
    ask_database_info
    generate_env_file
    generate_docker_compose
    install_management_script
    start_services
    wait_for_mysql
    run_migrations

    colorized_echo green "✅ BoleylaPanel installed successfully"
    echo "Use: boleyla up | boleyla status | boleyla logs"
}

uninstall_command() {
    detect_compose
    cd "$APP_DIR" || exit 0
    $COMPOSE down -v
    rm -rf "$APP_DIR" "$DATA_DIR"
    rm -f /usr/local/bin/boleyla
    colorized_echo green "✅ Uninstalled"
}

case "$1" in
  install) install_command ;;
  uninstall) uninstall_command ;;
  *) echo "Usage: $0 install | uninstall" ;;
esac
