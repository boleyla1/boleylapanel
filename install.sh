#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"
REPO_URL="https://github.com/boleyla1/boleylapanel.git"

colorized_echo() {
    local color=$1
    local text=$2
    case $color in
        "red") printf "\e[91m${text}\e[0m\n";;
        "green") printf "\e[92m${text}\e[0m\n";;
        "yellow") printf "\e[93m${text}\e[0m\n";;
        "blue") printf "\e[94m${text}\e[0m\n";;
        "magenta") printf "\e[95m${text}\e[0m\n";;
        "cyan") printf "\e[96m${text}\e[0m\n";;
        *) echo "${text}";;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
    elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
    elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y
        $PKG_MANAGER install -y epel-release
    elif [ "$OS" == "Fedora"* ]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update
    elif [ "$OS" == "Arch" ]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_package() {
    if [ -z $PKG_MANAGER ]; then
        detect_and_update_package_manager
    fi
    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y install "$PACKAGE"
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        $PKG_MANAGER install -y "$PACKAGE"
    elif [ "$OS" == "Fedora"* ]; then
        $PKG_MANAGER install -y "$PACKAGE"
    elif [ "$OS" == "Arch" ]; then
        $PKG_MANAGER -S --noconfirm "$PACKAGE"
    fi
}

install_docker() {
    colorized_echo blue "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    colorized_echo green "Docker installed successfully"
}

detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "docker compose not found"
        exit 1
    fi
}

is_boleylapanel_installed() {
    if [ -d $APP_DIR ]; then
        return 0
    else
        return 1
    fi
}

is_boleylapanel_up() {
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q)" ]; then
        return 1
    else
        return 0
    fi
}

install_boleylapanel_script() {
    colorized_echo blue "Installing boleylapanel management script"
    cat > /usr/local/bin/boleylapanel << 'BOLEYLAPANEL_SCRIPT'
#!/bin/bash
bash <(curl -sL https://raw.githubusercontent.com/boleyla1/boleylapanel/main/install.sh) "$@"
BOLEYLAPANEL_SCRIPT
    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "Management script installed. Use: boleylapanel [command]"
}

prompt_for_admin_credentials() {
    colorized_echo cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    colorized_echo cyan "   Admin User Configuration"
    colorized_echo cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    read -p "Enter admin username [admin]: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

    colorized_echo yellow "Enter admin password (or press Enter for auto-generated):"
    read -s ADMIN_PASSWORD
    echo

    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 16)
        colorized_echo green "Auto-generated password: $ADMIN_PASSWORD"
    fi

    read -p "Enter admin email [admin@boleylapanel.local]: " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@boleylapanel.local}

    colorized_echo green "Admin credentials configured"
    sleep 2
}

generate_env_file() {
    colorized_echo blue "Generating environment configuration..."

    DB_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
    DB_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
    SECRET_KEY=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

    cat > "$ENV_FILE" << EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel_db
MYSQL_USER=boleylapanel_user
MYSQL_PASSWORD=$DB_PASSWORD

# Backend Configuration
DB_HOST=boleylapanel-mysql
DB_PORT=3306
DB_NAME=boleylapanel_db
DB_USER=boleylapanel_user
DB_PASSWORD=$DB_PASSWORD

# Admin Configuration
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD
ADMIN_EMAIL=$ADMIN_EMAIL

# Application Configuration
SECRET_KEY=$SECRET_KEY
DEBUG=false
BACKEND_PORT=8000
FRONTEND_PORT=3000
EOF

    chmod 600 "$ENV_FILE"
    colorized_echo green "Environment file created at $ENV_FILE"
}

download_files() {
    colorized_echo blue "Downloading BoleylاPanel files..."

    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"

    cd "$APP_DIR"
    git clone "$REPO_URL" temp
    mv temp/* temp/.* . 2>/dev/null || true
    rm -rf temp

    colorized_echo green "Files downloaded successfully"
}

up_boleylapanel() {
    $COMPOSE -f $COMPOSE_FILE up -d --remove-orphans
}

down_boleylapanel() {
    $COMPOSE -f $COMPOSE_FILE down
}

create_admin_user() {
    colorized_echo blue "Creating admin user..."

    $COMPOSE -f $COMPOSE_FILE exec -T backend python - << PYTHON_SCRIPT
import os
import sys
from sqlalchemy import create_engine, text
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

try:
    db_user = os.getenv('DB_USER')
    db_password = os.getenv('DB_PASSWORD')
    db_host = os.getenv('DB_HOST')
    db_name = os.getenv('DB_NAME')

    DATABASE_URL = f"mysql+pymysql://{db_user}:{db_password}@{db_host}:3306/{db_name}"
    engine = create_engine(DATABASE_URL)

    with engine.connect() as conn:
        admin_username = os.getenv('ADMIN_USERNAME')
        admin_password = os.getenv('ADMIN_PASSWORD')
        admin_email = os.getenv('ADMIN_EMAIL')

        hashed_password = pwd_context.hash(admin_password)

        conn.execute(text("DELETE FROM users WHERE username = :username"), {"username": admin_username})
        conn.commit()

        conn.execute(
            text("""
                INSERT INTO users (username, password, email, is_admin, is_active, created_at)
                VALUES (:username, :password, :email, 1, 1, NOW())
            """),
            {"username": admin_username, "password": hashed_password, "email": admin_email}
        )
        conn.commit()

    print("✅ Admin user created")
    sys.exit(0)
except Exception as e:
    print(f"❌ Error: {str(e)}")
    sys.exit(1)
PYTHON_SCRIPT
}

install_command() {
    check_running_as_root

    if is_boleylapanel_installed; then
        colorized_echo yellow "BoleylاPanel is already installed at $APP_DIR"
        read -p "Do you want to reinstall? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Installation cancelled"
            exit 1
        fi
        uninstall_command
    fi

    detect_os

    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi

    if ! command -v git >/dev/null 2>&1; then
        install_package git
    fi

    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi

    detect_compose

    download_files
    prompt_for_admin_credentials
    generate_env_file

    colorized_echo blue "Starting containers..."
    up_boleylapanel

    colorized_echo yellow "Waiting for MySQL to be ready (20 seconds)..."
    sleep 20

    create_admin_user

    install_boleylapanel_script

    show_success_message
}

show_success_message() {
    local SERVER_IP=$(hostname -I | awk '{print $1}')

    colorized_echo green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    colorized_echo cyan "   BoleylاPanel Installed Successfully! 🎉"
    colorized_echo green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    colorized_echo yellow "Panel URL: http://$SERVER_IP:3000"
    colorized_echo yellow "API URL: http://$SERVER_IP:8000"
    echo
    colorized_echo cyan "Admin Username: $ADMIN_USERNAME"
    colorized_echo cyan "Admin Password: $ADMIN_PASSWORD"
    echo
    colorized_echo magenta "Useful commands:"
    colorized_echo blue "  boleylapanel up       - Start services"
    colorized_echo blue "  boleylapanel down     - Stop services"
    colorized_echo blue "  boleylapanel restart  - Restart services"
    colorized_echo blue "  boleylapanel logs     - View logs"
    colorized_echo blue "  boleylapanel status   - Check status"
    colorized_echo green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

up_command() {
    if ! is_boleylapanel_installed; then
        colorized_echo red "BoleylاPanel is not installed!"
        exit 1
    fi

    detect_compose

    if is_boleylapanel_up; then
        colorized_echo yellow "BoleylاPanel is already running"
        exit 0
    fi

    up_boleylapanel
    colorized_echo green "BoleylاPanel started successfully"
}

down_command() {
    if ! is_boleylapanel_installed; then
        colorized_echo red "BoleylاPanel is not installed!"
        exit 1
    fi

    detect_compose

    if ! is_boleylapanel_up; then
        colorized_echo yellow "BoleylاPanel is already down"
        exit 0
    fi

    down_boleylapanel
    colorized_echo green "BoleylاPanel stopped successfully"
}

restart_command() {
    if ! is_boleylapanel_installed; then
        colorized_echo red "BoleylاPanel is not installed!"
        exit 1
    fi

    detect_compose
    down_boleylapanel
    up_boleylapanel
    colorized_echo green "BoleylاPanel restarted successfully"
}

logs_command() {
    if ! is_boleylapanel_installed; then
        colorized_echo red "BoleylاPanel is not installed!"
        exit 1
    fi

    detect_compose
    $COMPOSE -f $COMPOSE_FILE logs -f
}

status_command() {
    if ! is_boleylapanel_installed; then
        colorized_echo red "Not Installed"
        exit 1
    fi

    detect_compose

    if ! is_boleylapanel_up; then
        colorized_echo blue "Down"
        exit 1
    fi

    colorized_echo green "Up"
    $COMPOSE -f $COMPOSE_FILE ps
}

uninstall_command() {
    check_running_as_root

    if ! is_boleylapanel_installed; then
        colorized_echo red "BoleylاPanel is not installed!"
        exit 1
    fi

    read -p "Are you sure you want to uninstall BoleylاPanel? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Uninstall cancelled"
        exit 1
    fi

    detect_compose

    if is_boleylapanel_up; then
        down_boleylapanel
    fi

    colorized_echo yellow "Removing files..."
    rm -rf "$APP_DIR"
    rm -rf "$DATA_DIR"
    rm -f /usr/local/bin/boleylapanel

    colorized_echo green "BoleylاPanel uninstalled successfully"
}

usage() {
    colorized_echo cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    colorized_echo magenta "   BoleylاPanel Management"
    colorized_echo cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    colorized_echo yellow "Commands:"
    echo "  install    - Install BoleylاPanel"
    echo "  up         - Start services"
    echo "  down       - Stop services"
    echo "  restart    - Restart services"
    echo "  logs       - View logs"
    echo "  status     - Check status"
    echo "  uninstall  - Remove BoleylاPanel"
    echo
}

case "$1" in
    install)
        install_command
        ;;
    up)
        up_command
        ;;
    down)
        down_command
        ;;
    restart)
        restart_command
        ;;
    logs)
        logs_command
        ;;
    status)
        status_command
        ;;
    uninstall)
        uninstall_command
        ;;
    *)
        usage
        exit 1
        ;;
esac
