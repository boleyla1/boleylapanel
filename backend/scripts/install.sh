#!/bin/bash

REPO_URL="https://github.com/boleyla1/boleylapanel"
INSTALL_DIR="/opt/boleylapanel"
SERVICE_FILE="/etc/systemd/system/boleylapanel.service"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

print() {
    echo -e "${BLUE}[BOLEYLA]${RESET} $1"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Run as root!"
    fi
}

install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print "Installing Docker..."
        curl -fsSL https://get.docker.com | sh || error "Failed to install Docker"
    else
        print "Docker found."
    fi

    if ! systemctl is-active --quiet docker; then
        systemctl enable --now docker || error "Failed to start Docker"
    fi
}

clone_or_update_repo() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR" || error "Failed to clone repository"
    else
        print "Updating existing installation..."
        cd "$INSTALL_DIR" || error "Failed to enter install directory"
        git pull || error "Git pull failed"
    fi
}

generate_env() {
    print "Creating .env file..."

    read -p "MySQL database name [boleylapanel]: " DB_NAME
    DB_NAME=${DB_NAME:-boleylapanel}

    read -p "MySQL user [boleylapanel]: " DB_USER
    DB_USER=${DB_USER:-boleylapanel}

    read -p "MySQL password: " DB_PASS

    cat <<EOF > "$INSTALL_DIR/.env"
MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASS
MYSQL_ROOT_PASSWORD=$DB_PASS
EOF

    print ".env created successfully."
}

start_containers() {
    print "Starting Docker containers..."

    cd "$INSTALL_DIR/backend" || error "backend directory not found"

    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found inside $INSTALL_DIR/backend"
    fi

    docker compose down --remove-orphans >/dev/null 2>&1
    docker compose up -d || error "Failed to start containers"
}

create_service() {
    print "Creating systemd service..."

    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=BoleylaPanel Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker compose -f $INSTALL_DIR/docker-compose.yml up -d
ExecStop=/usr/bin/docker compose -f $INSTALL_DIR/docker-compose.yml down
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable boleylapanel
    print "Service installed."
}

uninstall() {
    print "Stopping service..."
    systemctl stop boleylapanel 2>/dev/null
    systemctl disable boleylapanel 2>/dev/null
    rm -f "$SERVICE_FILE"

    print "Removing installation..."
    rm -rf "$INSTALL_DIR"

    print "Done."
    exit 0
}

update() {
    print "Updating BoleylaPanel..."
    clone_or_update_repo
    start_containers
    print "Update completed."
    exit 0
}

menu() {
    echo -e "
${GREEN}1) Install BoleylaPanel
2) Update
3) Uninstall
${RESET}
"
    read -p "Choose an option: " OPT

    case $OPT in
        1)
            check_root
            install_docker
            clone_or_update_repo
            generate_env
            start_containers
            create_service
            print "Installation completed."
            ;;
        2)
            update
            ;;
        3)
            uninstall
            ;;
        *)
            error "Invalid option."
            ;;
    esac
}


menu
