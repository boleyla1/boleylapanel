#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

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
        colorized_echo red "This script must be run as root."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        colorized_echo red "Cannot detect OS"
        exit 1
    fi
}

install_package() {
    local package=$1
    colorized_echo blue "Installing $package..."

    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq $package
            ;;
        centos|rhel|almalinux)
            yum install -y $package
            ;;
        fedora)
            dnf install -y $package
            ;;
        *)
            colorized_echo red "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

install_docker() {
    if command -v docker &> /dev/null; then
        colorized_echo green "Docker is already installed"
        return
    fi

    colorized_echo blue "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    colorized_echo green "Docker installed successfully"
}

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

generate_random_string() {
    openssl rand -hex 16
}

create_env() {
    colorized_echo blue "Creating .env file..."

    MYSQL_ROOT_PASSWORD=$(generate_random_string)
    MYSQL_PASSWORD=$(generate_random_string)
    SECRET_KEY=$(generate_random_string)

    cat > "$ENV_FILE" << EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel_db
MYSQL_USER=boleylapanel
MYSQL_PASSWORD=$MYSQL_PASSWORD

# Application Configuration
SECRET_KEY=$SECRET_KEY
PORT=8000
APP_NAME=boleylapanel
EOF

    colorized_echo green ".env file created with random credentials"
}

create_docker_compose() {
    colorized_echo blue "Creating docker-compose.yml..."

    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  db:
    image: mysql:8.0
    container_name: ${APP_NAME:-boleylapanel}-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: boleyla1/boleylapanel-backend:latest
    container_name: ${APP_NAME:-boleylapanel}-backend
    restart: unless-stopped
    ports:
      - "${PORT:-8000}:8000"
    environment:
      DATABASE_URL: mysql+aiomysql://${MYSQL_USER}:${MYSQL_PASSWORD}@db:3306/${MYSQL_DATABASE}
      SECRET_KEY: ${SECRET_KEY}
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network
    command: >
      sh -c "
        echo 'Waiting for database...' &&
        sleep 10 &&
        alembic upgrade head &&
        uvicorn app.main:app --host 0.0.0.0 --port 8000
      "

volumes:
  mysql_data:

networks:
  app-network:
    driver: bridge
EOF

    colorized_echo green "docker-compose.yml created successfully"
}

wait_for_mysql() {
    colorized_echo blue "Waiting for MySQL to be ready..."
    for i in {1..30}; do
        if $COMPOSE exec -T db mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
            colorized_echo green "MySQL is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    colorized_echo red "MySQL failed to start"
    return 1
}

create_admin_user() {
    colorized_echo blue "Creating admin user..."

    $COMPOSE exec -T backend python << 'PYTHON_SCRIPT'
from app.db.database import get_db
from app.models.user import User
from app.core.security import get_password_hash
from datetime import datetime

def create_admin():
    db = next(get_db())
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        if not admin:
            admin = User(
                username="admin",
                email="admin@example.com",
                hashed_password=get_password_hash("admin123"),
                is_active=True,
                is_superuser=True,
                created_at=datetime.utcnow()
            )
            db.add(admin)
            db.commit()
            print("✓ Admin user created: admin/admin123")
        else:
            print("✓ Admin user already exists")
    except Exception as e:
        print(f"✗ Error: {e}")
    finally:
        db.close()

create_admin()
PYTHON_SCRIPT

    echo "admin:admin123" > "$APP_DIR/.credentials"
    chmod 600 "$APP_DIR/.credentials"

    colorized_echo green "Admin credentials saved to $APP_DIR/.credentials"
}

install_cli() {
    colorized_echo blue "Installing CLI tool..."

    cat > /usr/local/bin/boleylapanel << 'EOF'
#!/bin/bash
cd /opt/boleylapanel && docker compose "$@"
EOF

    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "CLI installed: boleylapanel [command]"
}

install_command() {
    check_running_as_root
    detect_os

    colorized_echo blue "========================================="
    colorized_echo cyan "   BolelaPanel Installation Started"
    colorized_echo blue "========================================="

    colorized_echo blue "Installing dependencies..."
    install_package "curl"
    install_package "git"
    install_docker
    detect_compose

    colorized_echo blue "Creating directories..."
    mkdir -p "$APP_DIR"

    create_env
    create_docker_compose

    cd "$APP_DIR"

    colorized_echo blue "Starting services..."
    $COMPOSE up -d

    wait_for_mysql || exit 1

    colorized_echo blue "Running migrations..."
    $COMPOSE exec -T backend alembic upgrade head

    create_admin_user
    install_cli

    colorized_echo green "========================================="
    colorized_echo green "✓ Installation completed successfully!"
    colorized_echo green "========================================="
    colorized_echo cyan "Access panel at: http://$(curl -s ifconfig.me):8000"
    colorized_echo cyan "Admin credentials: admin/admin123"
    colorized_echo yellow "Credentials saved in: $APP_DIR/.credentials"
}

install_command
