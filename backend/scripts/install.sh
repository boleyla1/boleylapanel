#!/usr/bin/env bash
set -e

# Configuration
INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

# Colors
colorized_echo() {
    local color=$1
    shift
    case $color in
        red) printf "\e[91m%s\e[0m\n" "$*";;
        green) printf "\e[92m%s\e[0m\n" "$*";;
        yellow) printf "\e[93m%s\e[0m\n" "$*";;
        blue) printf "\e[94m%s\e[0m\n" "$*";;
        magenta) printf "\e[95m%s\e[0m\n" "$*";;
        cyan) printf "\e[96m%s\e[0m\n" "$*";;
        *) echo "$*";;
    esac
}

# Check root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This script must be run as root"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

# Install package
install_package() {
    local package=$1
    colorized_echo blue "Installing $package..."

    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        apt-get update -qq && apt-get install -y -qq "$package"
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        yum install -y "$package"
    else
        colorized_echo red "Unsupported OS for package installation"
        exit 1
    fi
}

# Install Docker
install_docker() {
    if ! command -v docker &>/dev/null; then
        colorized_echo blue "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
        colorized_echo green "Docker installed successfully"
    fi
}

# Detect Docker Compose
detect_compose() {
    if docker compose version &>/dev/null; then
        COMPOSE='docker compose'
    elif docker-compose version &>/dev/null; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "Docker Compose not found"
        exit 1
    fi
}

# Generate password
generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20
}

# Create directories
create_directories() {
    colorized_echo blue "Creating directories..."
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR/mysql"
    colorized_echo green "Directories created"
}

# Create docker-compose.yml
create_compose_file() {
    colorized_echo blue "Creating docker-compose.yml..."

    cat > "$COMPOSE_FILE" <<'EOF'
services:
  boleylapanel:
    image: boleylapanel:latest
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    network_mode: host
    env_file: .env
    volumes:
      - /var/lib/boleylapanel:/var/lib/boleylapanel
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    restart: always
    network_mode: host
    command:
      - --bind-address=127.0.0.1
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --max_connections=500
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - /var/lib/boleylapanel/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
EOF

    colorized_echo green "docker-compose.yml created"
}

# Create Dockerfile
create_dockerfile() {
    colorized_echo blue "Creating Dockerfile..."

    cat > "$APP_DIR/Dockerfile" <<'EOF'
FROM python:3.11-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-libmysqlclient-dev \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install Python packages
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Expose port
EXPOSE 8000

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    colorized_echo green "Dockerfile created"
}

# Create requirements.txt
create_requirements() {
    colorized_echo blue "Creating requirements.txt..."

    cat > "$APP_DIR/requirements.txt" <<'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
pymysql==1.1.0
cryptography==41.0.7
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
pydantic==2.5.0
pydantic-settings==2.1.0
EOF

    colorized_echo green "requirements.txt created"
}

# Create .env file
create_env_file() {
    colorized_echo blue "Creating .env file..."

    local mysql_root_pass=$(generate_password)
    local mysql_user_pass=$(generate_password)

    cat > "$ENV_FILE" <<EOF
# MySQL Configuration
MYSQL_ROOT_PASSWORD=$mysql_root_pass
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleylapanel
MYSQL_PASSWORD=$mysql_user_pass

# Database URL
SQLALCHEMY_DATABASE_URL=mysql+pymysql://boleylapanel:$mysql_user_pass@127.0.0.1:3306/boleylapanel

# App Configuration
SECRET_KEY=$(generate_password)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin
EOF

    colorized_echo green ".env file created"
    colorized_echo yellow "Default credentials: admin / admin"
    colorized_echo yellow "Please change the password after first login!"
}

# Create main.py (simple example)
create_main_app() {
    colorized_echo blue "Creating main application..."

    cat > "$APP_DIR/main.py" <<'EOF'
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="Boleylapanel")

@app.get("/")
async def root():
    return JSONResponse({"message": "Boleylapanel is running!", "status": "ok"})

@app.get("/health")
async def health():
    return JSONResponse({"status": "healthy"})
EOF

    colorized_echo green "Application created"
}

# Install management script
install_management_script() {
    colorized_echo blue "Installing management script..."

    cat > /usr/local/bin/boleylapanel <<'SCRIPT'
#!/bin/bash
APP_DIR="/opt/boleylapanel"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

case "$1" in
    up)
        cd "$APP_DIR" && docker compose up -d
        ;;
    down)
        cd "$APP_DIR" && docker compose down
        ;;
    restart)
        cd "$APP_DIR" && docker compose restart
        ;;
    logs)
        cd "$APP_DIR" && docker compose logs -f "${@:2}"
        ;;
    update)
        cd "$APP_DIR" && docker compose pull && docker compose up -d --build
        ;;
    backup)
        timestamp=$(date +%Y%m%d_%H%M%S)
        docker exec boleylapanel-mysql-1 mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" boleylapanel > "/var/lib/boleylapanel/backup_${timestamp}.sql"
        echo "Backup saved: /var/lib/boleylapanel/backup_${timestamp}.sql"
        ;;
    uninstall)
        read -p "Are you sure you want to remove Boleylapanel? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            cd "$APP_DIR" && docker compose down -v
            rm -rf /opt/boleylapanel /var/lib/boleylapanel /usr/local/bin/boleylapanel
            echo "Boleylapanel uninstalled successfully"
        fi
        ;;
    *)
        echo "Usage: boleylapanel {up|down|restart|logs|update|backup|uninstall}"
        exit 1
        ;;
esac
SCRIPT

    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "Management script installed"
}

# Main installation
main() {
    check_root
    detect_os

    colorized_echo cyan "================================"
    colorized_echo cyan "  Boleylapanel Installation"
    colorized_echo cyan "================================"

    # Check if already installed
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Boleylapanel is already installed"
        read -p "Do you want to reinstall? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
        rm -rf "$APP_DIR"
    fi

    # Install dependencies
    install_docker
    detect_compose

    # Create files
    create_directories
    create_compose_file
    create_dockerfile
    create_requirements
    create_env_file
    create_main_app
    install_management_script

    # Build and start
    colorized_echo blue "Building and starting services..."
    cd "$APP_DIR"
    $COMPOSE up -d --build

    colorized_echo green "================================"
    colorized_echo green "Installation completed!"
    colorized_echo green "================================"
    colorized_echo yellow "Management commands:"
    colorized_echo cyan "  boleylapanel up       - Start services"
    colorized_echo cyan "  boleylapanel down     - Stop services"
    colorized_echo cyan "  boleylapanel restart  - Restart services"
    colorized_echo cyan "  boleylapanel logs     - View logs"
    colorized_echo cyan "  boleylapanel update   - Update panel"
    colorized_echo cyan "  boleylapanel backup   - Backup database"
    colorized_echo cyan "  boleylapanel uninstall - Remove panel"
}

main
