#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

APP_NAME="boleylapanel"
APP_DIR="/opt/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

colorized_echo() {
    local color=$1
    shift
    case $color in
        red) echo -e "${RED}$*${NC}" ;;
        green) echo -e "${GREEN}$*${NC}" ;;
        yellow) echo -e "${YELLOW}$*${NC}" ;;
        blue) echo -e "${BLUE}$*${NC}" ;;
        cyan) echo -e "${CYAN}$*${NC}" ;;
        magenta) echo -e "${MAGENTA}$*${NC}" ;;
        *) echo "$*" ;;
    esac
}

clear
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                        ║${NC}"
echo -e "${GREEN}║      BoleylaPanle Auto Installer       ║${NC}"
echo -e "${GREEN}║                                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

check_running_as_root() {
    if [ "$EUID" -ne 0 ]; then
        colorized_echo red "❌ Please run with sudo"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    else
        colorized_echo red "Cannot detect operating system"
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
        centos|fedora|rhel)
            yum install -y -q $package
            ;;
        arch)
            pacman -S --noconfirm $package
            ;;
        *)
            colorized_echo red "Unsupported operating system"
            exit 1
            ;;
    esac
}

install_docker() {
    colorized_echo yellow "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    colorized_echo green "Docker installed successfully"
}

prompt_for_mysql_password() {
    colorized_echo cyan "This password will be used to access the MySQL database."
    colorized_echo cyan "If you do not enter a custom password, a secure 20-character password will be generated automatically."
    echo ""
    read -p "Enter password for MySQL user (or press Enter for auto-generation): " MYSQL_PASSWORD

    if [ -z "$MYSQL_PASSWORD" ]; then
        MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
        colorized_echo green "✓ A secure password has been generated automatically."
    fi

    colorized_echo green "✓ This password will be saved in .env file."
    sleep 2
}

check_running_as_root

if [ -d "$APP_DIR" ]; then
    colorized_echo yellow "⚠️  Previous installation detected at $APP_DIR"
    read -p "Do you want to override the previous installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Installation aborted"
        exit 1
    fi
    cd $APP_DIR 2>/dev/null && docker compose down 2>/dev/null || true
    rm -rf $APP_DIR
fi

detect_os

colorized_echo blue "📦 Checking required packages..."
if ! command -v curl &> /dev/null; then
    install_package curl
fi

if ! command -v git &> /dev/null; then
    install_package git
fi

if ! command -v docker &> /dev/null; then
    install_docker
fi

colorized_echo blue "🌐 Configuring Docker DNS..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
DOCKER_EOF
systemctl restart docker 2>/dev/null || true

colorized_echo blue "📥 Downloading project from GitHub..."
cd /opt
git clone https://github.com/boleyla1/boleylapanel.git
mkdir -p $DATA_DIR

colorized_echo blue "⚙️  Setting up docker-compose.yml with MySQL..."
cat > "$COMPOSE_FILE" << 'COMPOSE_EOF'
services:
  boleylapanel:
    build: ./backend
    restart: always
    env_file: .env
    ports:
      - "8000:8000"
    volumes:
      - /var/lib/boleylapanel:/var/lib/boleylapanel
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:lts
    env_file: .env
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_ROOT_HOST: '%'
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    command:
      - --mysqlx=OFF
      - --bind-address=127.0.0.1
      - --character_set_server=utf8mb4
      - --collation_server=utf8mb4_unicode_ci
      - --log-bin=mysql-bin
      - --binlog_expire_logs_seconds=1209600
      - --host-cache-size=0
      - --innodb-open-files=1024
      - --innodb-buffer-pool-size=256M
      - --innodb-log-file-size=64M
      - --innodb-log-files-in-group=2
      - --general_log=0
      - --slow_query_log=1
      - --slow_query_log_file=/var/lib/mysql/slow.log
      - --long_query_time=2
    volumes:
      - /var/lib/boleylapanel/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-u", "root", "--password=${MYSQL_ROOT_PASSWORD}"]
      start_period: 10s
      interval: 5s
      timeout: 5s
      retries: 55
COMPOSE_EOF

colorized_echo green "✓ docker-compose.yml created"

colorized_echo blue "⚙️  Creating .env file..."
prompt_for_mysql_password

MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20)
SECRET_KEY=$(openssl rand -hex 32)

cat > "$ENV_FILE" << ENV_EOF
# Application settings
SECRET_KEY=$SECRET_KEY
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# MySQL Database configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleyla
MYSQL_PASSWORD=$MYSQL_PASSWORD

# SQLAlchemy Database URL
DATABASE_URL=mysql+pymysql://boleyla:${MYSQL_PASSWORD}@mysql:3306/boleylapanel
ENV_EOF

colorized_echo green "✓ .env file created with MySQL configuration"

colorized_echo blue "🔨 Building Docker images..."
cd $APP_DIR
docker compose build --no-cache

colorized_echo blue "🚀 Starting services..."
docker compose up -d

colorized_echo blue "📝 Installing management script..."
cat > /usr/local/bin/boleylapanel << 'SCRIPT_EOF'
#!/bin/bash
APP_DIR="/opt/boleylapanel"
cd $APP_DIR

colorized_echo() {
    local color=$1
    shift
    case $color in
        red) echo -e "\033[0;31m$@\033[0m" ;;
        green) echo -e "\033[0;32m$@\033[0m" ;;
        yellow) echo -e "\033[1;33m$@\033[0m" ;;
        blue) echo -e "\033[0;34m$@\033[0m" ;;
        *) echo "$@" ;;
    esac
}

case "$1" in
    start)
        colorized_echo blue "Starting BoleylaPanle..."
        docker compose up -d
        colorized_echo green "✓ BoleylaPanle started"
        ;;
    stop)
        colorized_echo yellow "Stopping BoleylaPanle..."
        docker compose down
        colorized_echo green "✓ BoleylaPanle stopped"
        ;;
    restart)
        colorized_echo blue "Restarting BoleylaPanle..."
        docker compose restart
        colorized_echo green "✓ BoleylaPanle restarted"
        ;;
    logs)
        docker compose logs -f
        ;;
    status)
        docker compose ps
        ;;
    update)
        colorized_echo blue "Updating BoleylaPanle..."
        git pull
        docker compose down
        docker compose build --no-cache
        docker compose up -d
        colorized_echo green "✓ BoleylaPanle updated successfully"
        ;;
    uninstall)
        read -p "Are you sure you want to uninstall BoleylaPanle? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo yellow "Uninstalling BoleylaPanle..."
            docker compose down -v
            cd /opt
            rm -rf /opt/boleylapanel
            rm -rf /var/lib/boleylapanel
            rm -f /usr/local/bin/boleylapanel
            colorized_echo green "✓ BoleylaPanle uninstalled"
        fi
        ;;
    backup)
        colorized_echo blue "Creating backup..."
        BACKUP_DIR="/var/backups/boleylapanel"
        mkdir -p $BACKUP_DIR
        BACKUP_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"

        # Backup MySQL database
        docker compose exec -T mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} boleylapanel > /tmp/db_backup.sql

        # Create archive
        tar -czf $BACKUP_FILE -C /opt boleylapanel -C /tmp db_backup.sql
        rm /tmp/db_backup.sql

        colorized_echo green "✓ Backup created: $BACKUP_FILE"
        ;;
    *)
        echo "Usage: boleylapanel {start|stop|restart|logs|status|update|uninstall|backup}"
        echo ""
        echo "Commands:"
        echo "  start      - Start BoleylaPanle services"
        echo "  stop       - Stop BoleylaPanle services"
        echo "  restart    - Restart BoleylaPanle services"
        echo "  logs       - View real-time logs"
        echo "  status     - Check services status"
        echo "  update     - Update from GitHub"
        echo "  uninstall  - Remove BoleylaPanle completely"
        echo "  backup     - Create database backup"
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x /usr/local/bin/boleylapanel

sleep 3
clear
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Installation completed!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
colorized_echo blue "📊 Services Status:"
docker compose ps
echo ""
colorized_echo cyan "📋 Management Commands:"
echo -e "  ${GREEN}boleylapanel start${NC}     - Start services"
echo -e "  ${YELLOW}boleylapanel stop${NC}      - Stop services"
echo -e "  ${BLUE}boleylapanel restart${NC}   - Restart services"
echo -e "  ${BLUE}boleylapanel logs${NC}      - View logs"
echo -e "  ${GREEN}boleylapanel status${NC}    - Check status"
echo -e "  ${YELLOW}boleylapanel update${NC}    - Update from GitHub"
echo -e "  ${RED}boleylapanel uninstall${NC} - Uninstall"
echo -e "  ${CYAN}boleylapanel backup${NC}    - Create backup"
echo ""
colorized_echo green "🎉 Access panel at: http://YOUR_SERVER_IP:8000"
echo ""
