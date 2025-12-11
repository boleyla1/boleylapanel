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
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

require_root() {
    if [[ $EUID -ne 0 ]]; then err "This script must be run as root"; fi
}

# ---------------------------------------------------------
#              DETECT NAT FAILURE (Marzban Style)
# ---------------------------------------------------------
detect_nat() {
    log "Detecting Docker NAT capability..."

    # Test if containers can reach internet via NAT
    if docker run --rm --network bridge alpine ping -c1 8.8.8.8 >/dev/null 2>&1; then
        log "Docker NAT is working ✔"
        USE_HOST_NETWORK=false
    else
        warn "Docker NAT is BLOCKED on this VPS!"
        warn "Switching to Host Network Mode (like Marzban)"
        USE_HOST_NETWORK=true
    fi
}

# ---------------------------------------------------------
#                  DNS FIX (Marzban Style)
# ---------------------------------------------------------
fix_dns() {
    log "Checking & fixing system DNS..."

    # Ensure resolv.conf exists and has nameservers
    if [ ! -f /etc/resolv.conf ] || ! grep -q "nameserver" /etc/resolv.conf 2>/dev/null; then
        log "Rebuilding /etc/resolv.conf"
        echo "nameserver 1.1.1.1" > /etc/resolv.conf
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    fi

    # Enable systemd-resolved if available
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true

        if [ -f /run/systemd/resolve/resolv.conf ]; then
            ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null || true
        fi
    fi

    # Configure Docker daemon DNS (without dns-options for compatibility)
    log "Configuring Docker daemon DNS..."
    mkdir -p /etc/docker

    cat <<EOF > /etc/docker/daemon.json
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
EOF

    # Restart Docker daemon
    if systemctl is-active --quiet docker; then
        systemctl restart docker || err "Failed to restart Docker daemon"
        sleep 3
    fi

    # Test DNS resolution
    log "Testing DNS resolution..."
    if ! docker run --rm alpine ping -c1 google.com >/dev/null 2>&1; then
        warn "DNS test failed, but continuing (may use host network)"
    else
        success "DNS is working ✔"
    fi
}

# ---------------------------------------------------------
#              INSTALL DEPENDENCIES
# ---------------------------------------------------------
install_dependencies() {
    log "Installing dependencies..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y -qq curl git openssl netcat-openbsd || err "Failed to install dependencies"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl git openssl nc || err "Failed to install dependencies"
    else
        err "Unsupported package manager"
    fi
}

# ---------------------------------------------------------
#                  INSTALL DOCKER
# ---------------------------------------------------------
install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com | sh || err "Docker installation failed"
        systemctl enable docker
        systemctl start docker
        sleep 2
    else
        log "Docker is already installed ✔"
    fi

    # Verify Docker is running
    if ! systemctl is-active --quiet docker; then
        systemctl start docker || err "Failed to start Docker"
    fi
}

# ---------------------------------------------------------
#              FETCH OR UPDATE GIT REPO
# ---------------------------------------------------------
fetch_repo() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR" || err "Failed to clone repository"
    else
        log "Updating repository..."
        cd "$INSTALL_DIR" || err "Failed to enter install directory"
        git fetch origin
        git reset --hard origin/main
        git pull origin main
    fi
}

# ---------------------------------------------------------
#                ENV GENERATION
# ---------------------------------------------------------
generate_env() {
    local ENV_FILE="$INSTALL_DIR/.env"

    if [ -f "$ENV_FILE" ]; then
        log ".env already exists, skipping generation"
        return
    fi

    log "Generating .env file..."

    local DB_NAME="boleyla"
    local DB_USER="boleyla"
    local DB_PASS="$(openssl rand -hex 16)"
    local DB_ROOT_PASS="$(openssl rand -hex 16)"

cat <<EOF > "$ENV_FILE"
# MySQL Configuration
MYSQL_ROOT_PASSWORD=$DB_ROOT_PASS
MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASS

# Backend Configuration
DATABASE_URL=mysql+pymysql://$DB_USER:$DB_PASS@mysql:3306/$DB_NAME

# Network Mode
USE_HOST_NETWORK=$USE_HOST_NETWORK
EOF

    success ".env created ✔"
}

# ---------------------------------------------------------
#           DOCKER COMPOSE CREATION (NAT-Safe)
# ---------------------------------------------------------
create_compose() {
    log "Creating docker-compose.yml..."

    if [ "$USE_HOST_NETWORK" = true ]; then
        # HOST NETWORK MODE (Marzban Style)
cat <<'EOF' > "$INSTALL_DIR/docker-compose.yml"
services:
  mysql:
    image: mysql:8.0
    container_name: boleyla-mysql
    restart: unless-stopped
    network_mode: host
    env_file: .env
    volumes:
      - ./mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password --bind-address=127.0.0.1

  backend:
    build: ./backend
    container_name: boleyla-backend
    restart: unless-stopped
    network_mode: host
    env_file: .env
    depends_on:
      - mysql
    volumes:
      - ./backend:/app
    command: ["sh", "-c", "sleep 10 && alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
EOF
    else
        # BRIDGE NETWORK MODE (Normal NAT)
cat <<'EOF' > "$INSTALL_DIR/docker-compose.yml"
services:
  mysql:
    image: mysql:8.0
    container_name: boleyla-mysql
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./mysql_data:/var/lib/mysql
    networks:
      - boleylanet
    command: --default-authentication-plugin=mysql_native_password

  backend:
    build: ./backend
    container_name: boleyla-backend
    restart: unless-stopped
    env_file: .env
    depends_on:
      - mysql
    ports:
      - "8000:8000"
    networks:
      - boleylanet
    volumes:
      - ./backend:/app
    command: ["sh", "-c", "sleep 10 && alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]

networks:
  boleylanet:
    driver: bridge
EOF
    fi

    success "docker-compose.yml created ✔"
}

# ---------------------------------------------------------
#              START DOCKER COMPOSE
# ---------------------------------------------------------
start_docker() {
    cd "$INSTALL_DIR" || err "Install directory missing"

    log "Building and starting containers..."
    docker compose down >/dev/null 2>&1 || true
    docker compose up -d --build || err "Docker compose failed"

    sleep 5

    # Check if containers are running
    if docker ps | grep -q "boleyla-backend"; then
        success "Containers are running ✔"
    else
        err "Containers failed to start. Check logs: docker compose logs"
    fi
}

# ---------------------------------------------------------
#              SYSTEMD SERVICE
# ---------------------------------------------------------
create_service() {
    log "Creating systemd service..."

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
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$APP_NAME" || warn "Failed to enable service"
    success "Systemd service installed ✔"
}

# ---------------------------------------------------------
#                    SHOW INFO
# ---------------------------------------------------------
show_info() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║         BoleylaPanel Installed Successfully!          ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BLUE}📍 Installation Directory:${RESET} $INSTALL_DIR"
    echo -e "${BLUE}🌐 Backend API:${RESET} http://YOUR_SERVER_IP:8000"
    echo -e "${BLUE}📋 API Docs:${RESET} http://YOUR_SERVER_IP:8000/docs"
    echo
    echo -e "${YELLOW}🔧 Useful Commands:${RESET}"
    echo -e "  ${BLUE}•${RESET} View logs:      ${GREEN}cd $INSTALL_DIR && docker compose logs -f${RESET}"
    echo -e "  ${BLUE}•${RESET} Restart:        ${GREEN}cd $INSTALL_DIR && docker compose restart${RESET}"
    echo -e "  ${BLUE}•${RESET} Stop:           ${GREEN}cd $INSTALL_DIR && docker compose down${RESET}"
    echo -e "  ${BLUE}•${RESET} Update:         ${GREEN}bash <(curl -sL $REPO_URL/raw/main/install.sh) update${RESET}"
    echo -e "  ${BLUE}•${RESET} Uninstall:      ${GREEN}bash <(curl -sL $REPO_URL/raw/main/install.sh) uninstall${RESET}"
    echo

    if [ "$USE_HOST_NETWORK" = true ]; then
        echo -e "${YELLOW}⚠️  Network Mode: HOST (NAT disabled on this VPS)${RESET}"
    else
        echo -e "${GREEN}✔  Network Mode: BRIDGE (NAT working)${RESET}"
    fi
    echo
}

# ---------------------------------------------------------
#                    UNINSTALL
# ---------------------------------------------------------
uninstall_panel() {
    require_root

    log "Uninstalling BoleylaPanel..."

    # Stop service
    systemctl stop "$APP_NAME" 2>/dev/null || true
    systemctl disable "$APP_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload

    # Stop and remove containers
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        docker compose down -v 2>/dev/null || true
    fi

    # Remove installation directory
    rm -rf "$INSTALL_DIR"

    success "Panel uninstalled successfully ✔"
    exit 0
}

# ---------------------------------------------------------
#                      UPDATE
# ---------------------------------------------------------
update_panel() {
    require_root

    log "Updating BoleylaPanel..."

    fix_dns
    detect_nat
    fetch_repo
    generate_env
    create_compose
    start_docker

    success "Panel updated successfully ✔"
    show_info
    exit 0
}

# ---------------------------------------------------------
#                  MAIN INSTALL
# ---------------------------------------------------------
install_panel() {
    require_root

    log "Starting BoleylaPanel installation..."
    echo

    install_dependencies
    install_docker
    fix_dns
    detect_nat
    fetch_repo
    generate_env
    create_compose
    start_docker
    create_service

    show_info
}

# ---------------------------------------------------------
#                    CLI MODE
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
        echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║              BoleylaPanel Installer v1.3              ║${RESET}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
        echo
        echo -e "${YELLOW}Usage:${RESET}"
        echo -e "  ${BLUE}bash install.sh install${RESET}      - Install BoleylaPanel"
        echo -e "  ${BLUE}bash install.sh update${RESET}       - Update to latest version"
        echo -e "  ${BLUE}bash install.sh uninstall${RESET}    - Remove BoleylaPanel"
        echo
        echo -e "${YELLOW}One-Line Install:${RESET}"
        echo -e "  ${GREEN}bash <(curl -sL https://raw.githubusercontent.com/boleyla1/boleylapanel/main/install.sh) install${RESET}"
        echo
        exit 1
        ;;
esac
