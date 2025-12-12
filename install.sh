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
    [ "$(id -u)" = "0" ] || {
        colorized_echo red "❌ Run as root"
        exit 1
    }
}

detect_os() {
    . /etc/os-release
    colorized_echo green "✅ OS detected: $ID $VERSION_ID"
}

install_docker() {
    command -v docker >/dev/null && {
        colorized_echo green "✅ Docker already installed"
        return
    }
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
}

detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE="docker compose"
    else
        COMPOSE="docker-compose"
    fi
}

# =========================
# Install steps
# =========================
create_directories() {
    mkdir -p \
        "$APP_DIR/xray/output_configs" \
        "$APP_DIR/logs" \
        "$APP_DIR/backup" \
        "$DATA_DIR"
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
            MYSQL_PASSWORD=$(openssl rand -hex 16)
            break
        fi
        read -rsp "Confirm password: " CONFIRM
        echo
        [ "$MYSQL_PASSWORD" = "$CONFIRM" ] && break
        colorized_echo red "Passwords do not match"
    done

    MYSQL_ROOT_PASSWORD=$(openssl rand -hex 20)
}

ask_admin_info() {
    colorized_echo cyan "👤 Admin Account"

    read -rp "Admin username [admin]: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

    while true; do
        read -rsp "Admin password: " ADMIN_PASSWORD
        echo
        read -rsp "Confirm admin password: " CONFIRM
        echo
        [ "$ADMIN_PASSWORD" = "$CONFIRM" ] && break
        colorized_echo red "Passwords do not match"
    done
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
    command: --bind-address=127.0.0.1

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
    command: ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000"]

volumes:
  mysql_data:
EOF
}

start_services() {
    cd "$APP_DIR"
    $COMPOSE pull
    $COMPOSE up -d
}

wait_for_mysql() {
    colorized_echo yellow "⏳ Waiting for MySQL..."
    for i in {1..40}; do
        if docker exec boleylapanel-mysql \
            mysqladmin ping \
            -u root \
            -p"$MYSQL_ROOT_PASSWORD" \
            --silent; then
            return
        fi
        sleep 2
    done
    colorized_echo red "❌ MySQL failed"
    exit 1
}

run_migrations() {
    colorized_echo blue "📦 Initializing database"
    docker exec boleylapanel-backend python -m app.scripts.init_db || true
}

create_admin_user() {
    colorized_echo blue "👤 Creating admin user"

    docker exec boleylapanel-backend python - <<EOF
from app.db.session import SessionLocal
from app.services.user_service import create_user
from app.schemas.user import UserCreate

db = SessionLocal()
try:
    create_user(
        db=db,
        user=UserCreate(
            username="${ADMIN_USERNAME}",
            password="${ADMIN_PASSWORD}",
            is_admin=True
        )
    )
    print("✅ Admin user created")
except Exception as e:
    print("ℹ️ Admin user already exists or error:", e)
finally:
    db.close()
EOF
}

install_management_script() {
cat > /usr/local/bin/boleyla <<'EOF'
#!/usr/bin/env bash
APP_DIR="/opt/boleylapanel"
cd "$APP_DIR" || exit 1
docker compose "$@"
EOF
chmod +x /usr/local/bin/boleyla
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
    ask_admin_info
    generate_env_file
    generate_docker_compose
    install_management_script
    start_services
    wait_for_mysql
    run_migrations
    create_admin_user
    colorized_echo green "✅ BoleylaPanel installed successfully"
}

uninstall_command() {
    colorized_echo red "⚠️ Uninstalling BoleylaPanel"
    read -rp "Type yes to continue: " c
    [ "$c" = "yes" ] || exit 0

    docker rm -f boleylapanel-backend boleylapanel-mysql 2>/dev/null || true
    docker volume rm boleylapanel_mysql_data 2>/dev/null || true
    rm -rf "$APP_DIR" "$DATA_DIR" /usr/local/bin/boleyla

    colorized_echo green "✅ BoleylaPanel uninstalled"
}

# =========================
# Entrypoint
# =========================
case "$1" in
    install) install_command ;;
    uninstall) uninstall_command ;;
    *)
        echo "Usage: $0 install | uninstall"
        ;;
esac
