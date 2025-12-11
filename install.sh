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

    log "Creating environment file..."

    read -p "MySQL database name [boleylapanel]: " DB_NAME
    DB_NAME=${DB_NAME:-boleylapanel}

    read -p "MySQL user [boleylapanel]: " DB_USER
    DB_USER=${DB_USER:-boleylapanel}

    read -p "MySQL password: " DB_PASS

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
    working_dir: /app
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
    docker compose up -d || err "Failed to start containers"
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

    log "Removing installation folder..."
    rm -rf "$INSTALL_DIR"

    log "Done."
    exit 0
}

update_panel() {
    fetch_repo
    start_docker
    log "Updated successfully"
    exit 0
}

menu() {
    echo -e "
${GREEN}1) Install Panel
2) Update
3) Uninstall
4) Status
${RESET}
"
    read -p "Choose: " CH
    case $CH in
        1)
            require_root
            install_docker
            fetch_repo
            generate_env
            create_compose
            start_docker
            create_service
            log "BoleylaPanel installed successfully!"
            ;;
        2) update_panel ;;
        3) uninstall_all ;;
        4) docker ps ;;
        *) err "Invalid option" ;;
    esac
}

menu
