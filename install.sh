#!/usr/bin/env bash
set -e

# ═══════════════════════════════════════════════════════════════
#                    BolelaPanel Installer
#        Advanced Installation Script with Enhanced Features
# ═══════════════════════════════════════════════════════════════

INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"
CREDENTIALS_FILE="$APP_DIR/.credentials"
LOG_FILE="$APP_DIR/install.log"

# ═══════════════════════════════════════════════════════════════
#                         Color Functions
# ═══════════════════════════════════════════════════════════════

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

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    colorized_echo "$2" "$1"
}

# ═══════════════════════════════════════════════════════════════
#                      System Checks
# ═══════════════════════════════════════════════════════════════

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "⚠️  This script must be run as root (sudo su)"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        colorized_echo green "✓ Detected OS: $PRETTY_NAME"
    else
        colorized_echo red "✗ Cannot detect operating system"
        exit 1
    fi
}

check_system_requirements() {
    colorized_echo blue "Checking system requirements..."

    # Check RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 512 ]; then
        colorized_echo yellow "⚠️  Warning: Low RAM detected (${TOTAL_RAM}MB). Minimum 512MB recommended."
    else
        colorized_echo green "✓ RAM: ${TOTAL_RAM}MB"
    fi

    # Check disk space
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$FREE_SPACE" -lt 5 ]; then
        colorized_echo red "✗ Insufficient disk space. At least 5GB required."
        exit 1
    else
        colorized_echo green "✓ Free disk space: ${FREE_SPACE}GB"
    fi

    # Check internet connection
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        colorized_echo red "✗ No internet connection detected"
        exit 1
    else
        colorized_echo green "✓ Internet connection OK"
    fi
}

# ═══════════════════════════════════════════════════════════════
#                    Package Management
# ═══════════════════════════════════════════════════════════════

install_package() {
    local package=$1

    if command -v "$package" &> /dev/null; then
        colorized_echo green "✓ $package is already installed"
        return 0
    fi

    colorized_echo blue "Installing $package..."

    case $OS in
        ubuntu|debian)
            apt-get update -qq > /dev/null 2>&1
            apt-get install -y -qq "$package" > /dev/null 2>&1
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y "$package" > /dev/null 2>&1
            ;;
        fedora)
            dnf install -y "$package" > /dev/null 2>&1
            ;;
        arch|manjaro)
            pacman -S --noconfirm "$package" > /dev/null 2>&1
            ;;
        *)
            colorized_echo red "✗ Unsupported OS: $OS"
            exit 1
            ;;
    esac

    colorized_echo green "✓ $package installed successfully"
}

install_docker() {
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        colorized_echo green "✓ Docker is already installed (v$DOCKER_VERSION)"
        return 0
    fi

    colorized_echo blue "Installing Docker..."
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1

    systemctl enable docker > /dev/null 2>&1
    systemctl start docker

    # Add current user to docker group if not root
    if [ "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
        colorized_echo yellow "⚠️  Please log out and back in for Docker group changes to take effect"
    fi

    colorized_echo green "✓ Docker installed successfully"
}

detect_compose() {
    if docker compose version &>/dev/null; then
        COMPOSE='docker compose'
        COMPOSE_VERSION=$(docker compose version --short)
    elif docker-compose version &>/dev/null; then
        COMPOSE='docker-compose'
        COMPOSE_VERSION=$(docker-compose version --short)
    else
        colorized_echo red "✗ Docker Compose not found"
        exit 1
    fi

    colorized_echo green "✓ Docker Compose detected (v$COMPOSE_VERSION)"
}

# ═══════════════════════════════════════════════════════════════
#                    Configuration Generation
# ═══════════════════════════════════════════════════════════════

generate_random_string() {
    openssl rand -hex "${1:-16}"
}

create_env() {
    colorized_echo blue "Creating environment configuration..."

    # Generate secure random passwords
    MYSQL_ROOT_PASSWORD=$(generate_random_string 24)
    MYSQL_PASSWORD=$(generate_random_string 24)
    SECRET_KEY=$(generate_random_string 32)
    JWT_SECRET=$(generate_random_string 32)

    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")

    cat > "$ENV_FILE" << EOF
# ═══════════════════════════════════════════════════════════════
#                    BolelaPanel Configuration
#              Generated: $(date '+%Y-%m-%d %H:%M:%S')
# ═══════════════════════════════════════════════════════════════

# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleyla
MYSQL_USER=boleylapanel
MYSQL_PASSWORD=$MYSQL_PASSWORD

# Application Configuration
SECRET_KEY=$SECRET_KEY
JWT_SECRET_KEY=$JWT_SECRET
APP_NAME=$APP_NAME
PORT=8000
DEBUG=false

# Server Configuration
SERVER_IP=$SERVER_IP
ALLOWED_HOSTS=$SERVER_IP,localhost,127.0.0.1

# Security
SESSION_TIMEOUT=3600
MAX_LOGIN_ATTEMPTS=5
TOKEN_EXPIRE_MINUTES=30

# Backup Configuration (Optional)
BACKUP_ENABLED=false
BACKUP_RETENTION_DAYS=7

# Logging
LOG_LEVEL=INFO
EOF

    chmod 600 "$ENV_FILE"
    colorized_echo green "✓ Environment configuration created"
    log_message "Environment file created with secure credentials" "green"
}

create_docker_compose() {
    colorized_echo blue "Creating Docker Compose configuration..."

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
      TZ: Asia/Tehran
    volumes:
      - mysql_data:/var/lib/mysql
      - ./backup:/backup
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    command: --default-authentication-plugin=mysql_native_password --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

  backend:
    image: boleyla1/boleylapanel-backend:latest
    container_name: ${APP_NAME:-boleylapanel}-backend
    restart: unless-stopped
    ports:
      - "${PORT:-8000}:8000"
    environment:
      DATABASE_URL: mysql+pymysql://${MYSQL_USER}:${MYSQL_PASSWORD}@db:3306/${MYSQL_DATABASE}
      SECRET_KEY: ${SECRET_KEY}
      JWT_SECRET_KEY: ${JWT_SECRET_KEY}
      DEBUG: ${DEBUG:-false}
      LOG_LEVEL: ${LOG_LEVEL:-INFO}
      TZ: Asia/Tehran
    volumes:
      - ./logs:/app/logs
      - ./data:/app/data
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    command: >
      sh -c "
        echo '🔄 Waiting for database connection...' &&
        python -c 'import time; time.sleep(5)' &&
        echo '📦 Running database migrations...' &&
        alembic upgrade head &&
        echo '🚀 Starting application server...' &&
        uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level info
      "

volumes:
  mysql_data:
    driver: local

networks:
  app-network:
    driver: bridge
EOF

    colorized_echo green "✓ Docker Compose configuration created"
}

# ═══════════════════════════════════════════════════════════════
#                    Service Management
# ═══════════════════════════════════════════════════════════════

pull_images() {
    colorized_echo blue "Pulling Docker images..."
    cd "$APP_DIR"
    $COMPOSE pull
    colorized_echo green "✓ Docker images pulled successfully"
}

start_services() {
    colorized_echo blue "Starting services..."
    cd "$APP_DIR"
    $COMPOSE up -d

    # Wait a moment for containers to initialize
    sleep 5

    colorized_echo green "✓ Services started successfully"
}

wait_for_mysql() {
    colorized_echo blue "Waiting for MySQL to be ready..."

    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if $COMPOSE exec -T db mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
            colorized_echo green "✓ MySQL is ready!"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    colorized_echo red "✗ MySQL failed to start within timeout"
    $COMPOSE logs db
    return 1
}

run_migrations() {
    colorized_echo blue "Running database migrations..."

    cd "$APP_DIR"
    if $COMPOSE exec -T backend alembic upgrade head; then
        colorized_echo green "✓ Database migrations completed"
        return 0
    else
        colorized_echo red "✗ Migration failed"
        $COMPOSE logs backend
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
#                    Admin User Creation
# ═══════════════════════════════════════════════════════════════

create_admin_user() {
    colorized_echo blue "Creating admin user..."

    # Generate random admin password
    ADMIN_PASSWORD=$(generate_random_string 12)

    $COMPOSE exec -T backend python << PYTHON_SCRIPT
from app.db.database import get_db
from app.models.user import User
from app.core.security import get_password_hash
from datetime import datetime
import sys

def create_admin():
    db = next(get_db())
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        if not admin:
            admin = User(
                username="admin",
                email="admin@boleylapanel.local",
                hashed_password=get_password_hash("${ADMIN_PASSWORD}"),
                is_active=True,
                is_superuser=True,
                created_at=datetime.utcnow()
            )
            db.add(admin)
            db.commit()
            print("✓ Admin user created successfully")
        else:
            print("✓ Admin user already exists")
        return 0
    except Exception as e:
        print(f"✗ Error creating admin: {e}")
        return 1
    finally:
        db.close()

sys.exit(create_admin())
PYTHON_SCRIPT

    # Save credentials securely
    cat > "$CREDENTIALS_FILE" << EOF
═══════════════════════════════════════════════════════════════
                    BolelaPanel Credentials
           Generated: $(date '+%Y-%m-%d %H:%M:%S')
═══════════════════════════════════════════════════════════════

Username: admin
Password: ${ADMIN_PASSWORD}

Panel URL: http://$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP"):8000

⚠️  IMPORTANT: Change the default password after first login!
⚠️  Keep this file secure and delete it after saving credentials.

═══════════════════════════════════════════════════════════════
EOF

    chmod 600 "$CREDENTIALS_FILE"

    colorized_echo green "✓ Admin credentials saved to $CREDENTIALS_FILE"
}

# ═══════════════════════════════════════════════════════════════
#                    CLI Tool Installation
# ═══════════════════════════════════════════════════════════════

install_cli() {
    colorized_echo blue "Installing management CLI..."

    cat > /usr/local/bin/boleylapanel << 'EOFCLI'
#!/bin/bash

APP_DIR="/opt/boleylapanel"
COMPOSE="docker compose"

show_help() {
    cat << EOF
═══════════════════════════════════════════════════════════════
                BolelaPanel Management CLI
═══════════════════════════════════════════════════════════════

Usage: boleylapanel [command]

Commands:
  start             Start all services
  stop              Stop all services
  restart           Restart all services
  status            Show service status
  logs [service]    Show logs (backend/db/all)
  update            Update to latest version
  backup            Create database backup
  restore <file>    Restore database from backup
  shell             Open backend shell
  db-shell          Open MySQL shell
  clean             Clean unused Docker resources
  uninstall         Remove BolelaPanel completely
  help              Show this help message

Examples:
  boleylapanel start
  boleylapanel logs backend
  boleylapanel backup

═══════════════════════════════════════════════════════════════
EOF
}

case "$1" in
    start)
        cd "$APP_DIR" && $COMPOSE up -d
        echo "✓ Services started"
        ;;
    stop)
        cd "$APP_DIR" && $COMPOSE down
        echo "✓ Services stopped"
        ;;
    restart)
        cd "$APP_DIR" && $COMPOSE restart
        echo "✓ Services restarted"
        ;;
    status)
        cd "$APP_DIR" && $COMPOSE ps
        ;;
    logs)
        cd "$APP_DIR"
        if [ -z "$2" ]; then
            $COMPOSE logs -f
        else
            $COMPOSE logs -f "$2"
        fi
        ;;
    update)
        cd "$APP_DIR"
        $COMPOSE pull
        $COMPOSE up -d --force-recreate
        echo "✓ Updated to latest version"
        ;;
    backup)
        BACKUP_FILE="$APP_DIR/backup/backup_$(date +%Y%m%d_%H%M%S).sql"
        cd "$APP_DIR"
        $COMPOSE exec -T db mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" boleylapanel_db > "$BACKUP_FILE"
        echo "✓ Backup created: $BACKUP_FILE"
        ;;
    restore)
        if [ -z "$2" ]; then
            echo "✗ Usage: boleylapanel restore <backup_file>"
            exit 1
        fi
        cd "$APP_DIR"
        $COMPOSE exec -T db mysql -u root -p"${MYSQL_ROOT_PASSWORD}" boleylapanel_db < "$2"
        echo "✓ Database restored from: $2"
        ;;
    shell)
        cd "$APP_DIR" && $COMPOSE exec backend bash
        ;;
    db-shell)
        cd "$APP_DIR" && $COMPOSE exec db mysql -u root -p
        ;;
    clean)
        docker system prune -af --volumes
        echo "✓ Cleaned unused Docker resources"
        ;;
    uninstall)
        read -p "⚠️  This will remove BolelaPanel completely. Continue? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$APP_DIR" && $COMPOSE down -v
            rm -rf "$APP_DIR"
            rm -f /usr/local/bin/boleylapanel
            echo "✓ BolelaPanel uninstalled"
        fi
        ;;
    help|*)
        show_help
        ;;
esac
EOFCLI

    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "✓ CLI tool installed: boleylapanel [command]"
}

# ═══════════════════════════════════════════════════════════════
#                    Firewall Configuration
# ═══════════════════════════════════════════════════════════════

configure_firewall() {
    colorized_echo blue "Configuring firewall..."

    if command -v ufw &> /dev/null; then
        ufw allow 8000/tcp > /dev/null 2>&1
        colorized_echo green "✓ UFW: Port 8000 opened"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8000/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        colorized_echo green "✓ Firewalld: Port 8000 opened"
    else
        colorized_echo yellow "⚠️  No firewall detected. Please manually open port 8000"
    fi
}

# ═══════════════════════════════════════════════════════════════
#                    Post-Installation
# ═══════════════════════════════════════════════════════════════

show_success_message() {
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

    clear
    cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           ✨ BolelaPanel Installed Successfully! ✨           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

📍 Access Information:
   URL: http://${server_ip}:8000

🔐 Admin Credentials:
   Username: admin
   Password: Check $CREDENTIALS_FILE

🛠️  Management Commands:
   boleylapanel start    - Start services
   boleylapanel stop     - Stop services
   boleylapanel logs     - View logs
   boleylapanel help     - Show all commands

📁 Important Paths:
   Config: $APP_DIR
   Logs: $APP_DIR/logs
   Backups: $APP_DIR/backup

⚠️  Security Recommendations:
   1. Change the default admin password immediately
   2. Delete $CREDENTIALS_FILE after saving credentials
   3. Enable firewall rules if not already configured
   4. Keep the system and Docker updated

📚 Documentation:
   https://github.com/boleyla1/boleylapanel

═══════════════════════════════════════════════════════════════

🎉 Happy panel management!

EOF
}

# ═══════════════════════════════════════════════════════════════
#                    Main Installation
# ═══════════════════════════════════════════════════════════════

main() {
    # Initial setup
    check_running_as_root
    detect_os

    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # Header
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              🚀 BolelaPanel Installation Script 🚀            ║
║                     Version 1.0.0                             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF

    log_message "Starting BolelaPanel installation..." "blue"

    # System checks
    check_system_requirements

    # Install dependencies
    colorized_echo blue "\n📦 Installing dependencies..."
    install_package "curl"
    install_package "git"
    install_package "openssl"
    install_docker
    detect_compose

    # Create directories
    colorized_echo blue "\n📁 Creating directory structure..."
    mkdir -p "$APP_DIR"
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/backup"
    mkdir -p "$APP_DIR/data"
    mkdir -p "$DATA_DIR"

    # Generate configuration
    colorized_echo blue "\n⚙️  Generating configuration..."
    create_env
    create_docker_compose

    # Pull and start services
    colorized_echo blue "\n🐳 Setting up Docker services..."
    pull_images
    start_services

    # Wait for services
    colorized_echo blue "\n⏳ Waiting for services to initialize..."
    wait_for_mysql || exit 1

    # Run migrations
    colorized_echo blue "\n📊 Setting up database..."
    run_migrations || exit 1

    # Create admin user
    colorized_echo blue "\n👤 Creating admin user..."
    create_admin_user

    # Install CLI
    colorized_echo blue "\n🔧 Installing management tools..."
    install_cli

    # Configure firewall
    configure_firewall

    # Success message
    log_message "Installation completed successfully!" "green"
    show_success_message
}

# Run main function
main
