#!/bin/bash

APP_NAME="boleylapanel"
INSTALL_DIR="/opt/$APP_NAME"
REPO_URL="https://github.com/boleyla1/boleylapanel"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

BLUE="\e[34m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

log() { echo -e "${BLUE}[$APP_NAME]${RESET} $1"; }
err() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }
fix_dns() {
    log "Checking & fixing DNS issues..."

    # Fix system DNS
    if [ ! -f /etc/resolv.conf ] || ! grep -q "nameserver" /etc/resolv.conf; then
        log "Rebuilding /etc/resolv.conf"
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    fi

    # Enable systemd-resolved
    if ! systemctl is-active --quiet systemd-resolved; then
        log "Enabling systemd-resolved..."
        systemctl enable --now systemd-resolved || true
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi

    # Fix Docker daemon DNS
    mkdir -p /etc/docker
    echo '{
  "dns": ["8.8.8.8", "1.1.1.1"]
}' > /etc/docker/daemon.json

    log "Restarting Docker..."
    systemctl restart docker || true

    sleep 2

    # Test DNS inside docker
    if ! docker run --rm busybox nslookup google.com >/dev/null 2>&1; then
        err "DNS resolution is still failing inside Docker. Manual check needed."
    fi

    log "DNS is working correctly!"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then err "Run as root"; fi
}

install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com | sh || err "Docker installation failed"
    fi
    systemctl enable --now docker >/dev/null 2>&1
}

fetch_repo() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR" || err "Clone failed"
    else
        log "Updating repository..."
        cd "$INSTALL_DIR" || err "Cannot cd to install dir"
        git pull
    fi
}

generate_env() {
    mkdir -p "$INSTALL_DIR"

    DB_NAME="boleylapanel"
    DB_USER="boleylapanel"
    DB_PASS="$(openssl rand -hex 12)"

cat <<EOF > "$INSTALL_DIR/mysql.env"
MYSQL_ROOT_PASSWORD=$DB_PASS
MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASS
EOF

    log "mysql.env created"
}

create_compose() {
cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
version: "3.9"

services:

  mysql:
    image: mysql:8.0
    container_name: boleyla-mysql
    restart: unless-stopped
    env_file: ./mysql.env
    volumes:
      - ./mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"
    command: --default-authentication-plugin=mysql_native_password

  backend:
    build: ./backend
    container_name: boleyla-backend
    restart: unless-stopped
    depends_on:
      - mysql
    environment:
      DATABASE_URL: "mysql+pymysql://\${MYSQL_USER}:\${MYSQL_PASSWORD}@mysql:3306/\${MYSQL_DATABASE}"
    ports:
      - "8000:8000"
    command: ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
    volumes:
      - ./backend:/app

EOF

    log "docker-compose.yml created"
}

start_docker() {
    cd "$INSTALL_DIR" || err "Install directory missing"
    docker compose up -d --build || err "Failed to start containers"
}

create_service() {
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=BoleylaPanel Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$APP_NAME"
    log "Systemd service installed"
}

uninstall_all() {
    log "Stopping service..."
    systemctl stop "$APP_NAME" 2>/dev/null
    systemctl disable "$APP_NAME" 2>/dev/null
    rm -f "$SERVICE_FILE"
    rm -rf "$INSTALL_DIR"

    log "Uninstalled successfully"
    exit 0
}

update_panel() {
    fetch_repo
    start_docker
    log "Updated successfully"
    exit 0
}

install_panel() {
    require_root
    fix_dns      # ← اضافه شده
    install_docker
    fetch_repo
    generate_env
    create_compose
    start_docker
    create_service
}

# --------------------------
#           CLI MODE
# --------------------------

case "$1" in
    install)
        install_panel
        ;;
    update)
        update_panel
        ;;
    uninstall)
        uninstall_all
        ;;
    *)
        echo -e "${GREEN}Usage:${RESET}"
        echo "  bash install.sh install"
        echo "  bash install.sh update"
        echo "  bash install.sh uninstall"
        echo
        echo "Pipe mode:"
        echo "  curl -fsSL $REPO_URL/raw/main/install.sh | bash -s install"
        exit 1
        ;;
esac
