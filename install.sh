#!/usr/bin/env bash
set -e

# =========================
# Colors
# =========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =========================
# Variables
# =========================
INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

# =========================
# Helpers
# =========================
colorized_echo() {
    local color=$1
    local text=$2
    case $color in
        red) printf "${RED}${text}${NC}\n";;
        green) printf "${GREEN}${text}${NC}\n";;
        yellow) printf "${YELLOW}${text}${NC}\n";;
        blue) printf "${BLUE}${text}${NC}\n";;
        cyan) printf "${CYAN}${text}${NC}\n";;
        *) echo "$text";;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "❌ Run this script as root"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        colorized_echo green "✅ OS detected: $ID $VERSION_ID"
    else
        colorized_echo red "❌ Unsupported OS"
        exit 1
    fi
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        colorized_echo green "✅ Docker already installed"
        return
    fi
    colorized_echo blue "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
}

detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE="docker compose"
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE="docker-compose"
    else
        colorized_echo red "❌ Docker Compose not found"
        exit 1
    fi
}

# =========================
# Install steps
# =========================
create_directories() {
    mkdir -p "$APP_DIR" "$DATA_DIR"
    mkdir -p "$APP_DIR/xray/output_configs" "$APP_DIR/logs" "$APP_DIR/backup"
}

ask_database_info() {
    colorized_echo cyan "🔧 MySQL Configuration"

    read -rp "Database name [boleylapanel]: " MYSQL_DATABASE
    MYSQL_DATABASE=${MYSQL_DATABASE:-boleylapanel}

    read -rp "Database user [boleyla]: " MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-boleyla}

    while true; do
        read -rsp "Database password (empty = auto-generate): " MYSQL_PASSWORD
        echo
        if [ -z "$MYSQL_PASSWORD" ]; then
            MYSQL_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
            break
        fi
        read -rsp "Confirm password: " CONFIRM
        echo
        [ "$MYSQL_PASSWORD" = "$CONFIRM" ] && break
        colorized_echo red "Passwords do not match"
    done

    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
}

generate_env_file() {
    SECRET_KEY=$(openssl rand -hex 32)

    cat > "$ENV_FILE" <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

SECRET_KEY=$SECRET_KEY
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
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password --bind-address=127.0.0.1

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
    volumes:
      - ./xray/output_configs:/app/xray/output_configs
      - ./logs:/app/logs

volumes:
  mysql_data:
EOF
}

install_management_script() {
cat > /usr/local/bin/boleyla <<'EOF'
#!/usr/bin/env bash
APP_DIR="/opt/boleylapanel"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

detect_compose() {
    docker compose version >/dev/null 2>&1 && COMPOSE="docker compose" || COMPOSE="docker-compose"
}

detect_compose
cd "$APP_DIR" || exit 1

case "$1" in
  up|start) $COMPOSE up -d ;;
  down|stop) $COMPOSE down ;;
  restart) $COMPOSE restart ;;
  logs) shift; $COMPOSE logs -f ;;
  status) $COMPOSE ps ;;
  update)
    $COMPOSE pull
    $COMPOSE up -d --force-recreate --pull always --remove-orphans
    ;;
esac
EOF
chmod +x /usr/local/bin/boleyla
}

start_services() {
    cd "$APP_DIR"
    $COMPOSE pull
    $COMPOSE up -d
}

wait_for_mysql() {
    colorized_echo yellow "⏳ Waiting for MySQL..."
    for i in {1..30}; do
        if docker exec boleylapanel-mysql mysqladmin ping \
           -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; then
            return
        fi
        sleep 2
    done
    colorized_echo red "❌ MySQL not ready"
    exit 1
}

run_migrations() {
    docker exec boleylapanel-backend python -m app.scripts.init_db
}

# =========================
# Commands
# =========================
install_command() {
    check_running_as_root
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
    colorized_echo green "✅ Installation completed"
}

uninstall_command() {
    check_running_as_root
    detect_compose

    colorized_echo red "⚠️ This will REMOVE BoleylaPanel completely"
    read -rp "Type 'yes' to continue: " confirm
    [ "$confirm" != "yes" ] && exit 0

    [ -f "$COMPOSE_FILE" ] && $COMPOSE -f "$COMPOSE_FILE" down -v --remove-orphans || true
    docker ps -a --filter "name=boleylapanel" -q | xargs -r docker rm -f
    docker images | awk '/boleyla/ {print $3}' | xargs -r docker rmi -f
    docker volume ls --filter "name=boleylapanel" -q | xargs -r docker volume rm
    rm -rf "$APP_DIR" "$DATA_DIR" /usr/local/bin/boleyla

    colorized_echo green "✅ Uninstalled successfully"
}

# =========================
# Entrypoint
# =========================
case "$1" in
    install) install_command ;;
    uninstall) uninstall_command ;;
    *)
        echo "Usage:"
        echo "  $0 install"
        echo "  $0 uninstall"
        ;;
esac
