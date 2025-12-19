#!/usr/bin/env bash
set -e

########################################
# Constants
########################################
INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

GITHUB_REPO="boleyla1/boleylapanel"
COMPOSE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/docker-compose.yml"
ENV_TEMPLATE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/.env.example"
CLI_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/scripts/boleylapanel.sh"

########################################
# Utility Functions
########################################
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
    if [ -z "$PKG_MANAGER" ]; then
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
    if [ -d "$APP_DIR" ]; then
        return 0
    else
        return 1
    fi
}

########################################
# Installation
########################################
install_boleylapanel() {
    # Root check
    check_running_as_root

    # OS detection
    detect_os

    # Check if already installed
    if is_boleylapanel_installed; then
        colorized_echo red "BoleylaPanel is already installed at $APP_DIR"
        read -p "Do you want to override the previous installation? (yes/no) "
        if [[ ! "$REPLY" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
    fi

    detect_and_update_package_manager

    # Install dependencies
    if ! command -v jq >/dev/null 2>&1; then
        install_package jq
    fi
    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi
    if ! command -v git >/dev/null 2>&1; then
        install_package git
    fi

    # Install Docker
    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi

    detect_compose

    # Create directories
    colorized_echo blue "Creating directories..."
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"

    # Download files
    colorized_echo blue "Downloading docker-compose.yml..."
    curl -fsSL "$COMPOSE_URL" -o "$COMPOSE_FILE"

    # Setup .env
    if [ ! -f "$ENV_FILE" ]; then
        colorized_echo blue "Creating .env from template..."
        curl -fsSL "$ENV_TEMPLATE_URL" -o "$ENV_FILE"

        # Generate random passwords
        colorized_echo yellow "Generating secure passwords..."
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 24)
        ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 24)
        JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

        # Update .env with generated passwords
        sed -i "s|secure_password|${DB_PASSWORD}|g" "$ENV_FILE"
        sed -i "s|root_password_here|${ROOT_PASSWORD}|g" "$ENV_FILE"
        sed -i "s|your-super-secret-jwt-key-change-this|${JWT_SECRET}|g" "$ENV_FILE"

        colorized_echo green "✅ Passwords generated and saved to .env"
    else
        colorized_echo yellow ".env already exists, skipping"
    fi

    # Install CLI
    colorized_echo blue "Installing CLI..."
    curl -fsSL "$CLI_URL" -o "/usr/local/bin/$APP_NAME"
    chmod +x "/usr/local/bin/$APP_NAME"

    # Pull images
    colorized_echo blue "Pulling Docker images..."
    cd "$APP_DIR"
    $COMPOSE pull

    # Success message
    echo ""
    colorized_echo green "🎉 BoleylaPanel installed successfully!"
    echo ""
    colorized_echo cyan "📝 Next steps:"
    echo "   1. Review config: nano $ENV_FILE"
    echo "   2. Start services: $APP_NAME up -d"
    echo "   3. Check status: $APP_NAME status"
    echo "   4. View logs: $APP_NAME logs"
    echo ""
    colorized_echo yellow "⚠️  Default admin credentials:"
    echo "   Username: admin"
    echo "   Password: changeme123"
    echo ""
    colorized_echo magenta "🔒 IMPORTANT: Change admin password after first login!"
    echo ""
}

########################################
# Run Installation
########################################
install_boleylapanel
