#!/bin/bash

APP_NAME="boleylapanel"
INSTALL_DIR="/opt/$APP_NAME"
REPO_URL="https://github.com/boleyla1/boleylapanel"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

BLUE="\e[34m"
RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

log() { echo -e "${BLUE}[$APP_NAME]${RESET} $1"; }
err() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

require_root() {
    if [[ $EUID -ne 0 ]]; then err "Run as root"; fi
}

# ---------------------------------------------------------
#                  DNS FIX (Marzban Style)
# ---------------------------------------------------------
fix_dns() {
    log "Checking & fixing system DNS..."

    # Ensure resolv.conf
    if [ ! -f /etc/resolv.conf ] || ! grep -q "nameserver" /etc/resolv.conf; then
        log "Rebuilding /etc/resolv.conf"
        echo "nameserver 1.1.1.1" > /etc/resolv.conf
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    fi

    # Enable systemd-resolved (if available)
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now systemd-resolved >/dev/null 2>&1 || true
        if [ -f /run/systemd/resolve/resolv.conf ]; then
            ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
        fi
    fi

    # Docker daemon DNS
    log "Configuring Docker daemon DNS..."
    mkdir -p /etc/docker
    cat <<EOF > /etc/docker/daemon.json
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
EOF

    systemctl restart docker >/dev/null 2>&1 || true
    sleep 2

    # Test DNS inside Docker
    log "Testing DNS inside Docker..."
    if ! docker run --rm busybox nslookup google.com >/dev/null 2>&1; then
        err "DNS resolution FAILED inside Docker. Check VPS DNS."
    fi

    log "DNS is OK ✔"
}

# ---------------------------------------------------------
#                  INSTALL DOCKER
# ---------------------------------------------------------
install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com | sh || err "Docker installation failed"
    fi
    systemctl enable --now docker || true
}

# ---------------------------------------------------------
#              FETCH OR UPDATE GIT REPO
# ---------------------------------------------------------
fetch_repo() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR" || err "Failed clone"
    else
        log "Updating repository..."
        cd "$INSTALL_DIR" || err "Failed to enter install dir"
        git pull
    fi
}

# ---------------------------------------------------------
#                ENV GENERATION
# ---------------------------------------------------------
generate_env() {
    DB_NAME="boleyla"
    DB_USER="boleyla"
    DB_PASS="$(openssl rand -hex 12)"

cat <<EOF > "$INSTALL_DIR/mysql.env"
MYSQL_ROOT_PASSWORD=$DB_PASS
MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASS
EOF

    log "mysql.env created ✔"
}

# ---------------------------------------------------------
#               DOCKER COMPOSE CREATION
# ---------------------------------------------------------
create_compose() {
cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:

  mysql:
    image: mysql:8.0
    container_name: boleyla-mysql
    restart: unless-stopped
    env_file:
      - ./mysql.env
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

    log "docker-compose.yml created ✔"
}

# ---------------------------------------------------------
#              START DOCKER COMPOSE
# ---------------------------------------------------------
start_docker() {
    cd "$INSTALL_DIR" || err "Install directory missing"
    docker compose up -d --build || err "Docker start failed"
    log "Docker containers started ✔"
}

# ---------------------------------------------------------
#                SYSTEMD SERVICE
# ---------------------------------------------------------
create_service() {
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=BoleylaPanel
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
    log "Systemd service installed ✔"
}

# ---------------------------------------------------------
#                UNINSTALL
# ---------------------------------------------------------
uninstall_panel() {
    systemctl stop "$APP_NAME" 2>/dev/null || true
    systemctl disable "$APP_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    rm -rf "$INSTALL_DIR"
    log "Panel uninstalled successfully ✔"
    exit 0
}

# ---------------------------------------------------------
#                  UPDATE
# ---------------------------------------------------------
update_panel() {
    fix_dns
    fetch_repo
    start_docker
    log "Panel updated ✔"
    exit 0
}

# ---------------------------------------------------------
#                 MAIN INSTALL
# ---------------------------------------------------------
install_panel() {
    require_root
    fix_dns
    install_docker
    fetch_repo
    generate_env
    create_compose
    start_docker
    create_service
    log "Installation completed successfully ✔"
}

# ---------------------------------------------------------
#                 CLI MODE
# ---------------------------------------------------------
case "$1" in
    install)
        install_panel
        ;;
    update)
        update_panel
        ;;
    uninstall)
        uninstall_panel
        ;;
    *)
        echo -e "${GREEN}Usage:${RESET}"
        echo "  bash install.sh install"
        echo "  bash install.sh update"
        echo "  bash install.sh uninstall"
        echo
        echo "Pipe Mode:"
        echo "  curl -fsSL $REPO_URL/raw/main/install.sh | bash -s install"
        exit 1
        ;;
esac
