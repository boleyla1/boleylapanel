#!/usr/bin/env bash
set -e

# رنگ‌ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# متغیرهای پروژه
REPO_URL="https://github.com/boleyla1/boleylapanel.git"
INSTALL_DIR="/opt/boleylapanel"
SERVICE_NAME="boleylapanel"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   BoleylaPANEL Installer v1.0${NC}"
echo -e "${BLUE}========================================${NC}"

# بررسی دسترسی Root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}❌ This script must be run as root!${NC}"
    exit 1
fi

# تشخیص سیستم‌عامل
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}❌ Cannot detect OS${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Detected OS: $OS${NC}"

# نصب Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⏳ Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# بررسی Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found!${NC}"
    exit 1
fi

# نصب Git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}⏳ Installing Git...${NC}"
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update && apt-get install -y git
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        yum install -y git
    fi
    echo -e "${GREEN}✓ Git installed${NC}"
fi

# پاکسازی نصب قبلی
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠ Previous installation found${NC}"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$INSTALL_DIR"
        docker compose down -v 2>/dev/null || true
        cd /
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✓ Previous installation removed${NC}"
    else
        echo -e "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
fi

# کلون کردن پروژه
echo -e "${YELLOW}⏳ Cloning repository...${NC}"
git clone "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo -e "${GREEN}✓ Repository cloned${NC}"

# بررسی فایل‌های ضروری
if [ ! -f "Dockerfile" ] || [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Required files not found!${NC}"
    exit 1
fi

# ایجاد فایل .env
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ .env created from .env.example${NC}"

        # تولید رمز تصادفی
        RANDOM_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
        sed -i "s/MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$RANDOM_PASSWORD/" .env
        sed -i "s/securepassword/$RANDOM_PASSWORD/g" .env

        echo -e "${YELLOW}⚠ Please edit .env file with your settings${NC}"
        echo -e "${YELLOW}Generated MySQL password: $RANDOM_PASSWORD${NC}"
    else
        echo -e "${RED}❌ .env.example not found!${NC}"
        exit 1
    fi
fi

# Build و اجرای کانتینرها
echo -e "${YELLOW}⏳ Building and starting containers...${NC}"
echo -e "${BLUE}This may take 5-10 minutes...${NC}"

docker compose up -d --build

# بررسی وضعیت
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 30

if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Installation completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}Services:${NC}"
    docker compose ps
    echo ""
    echo -e "${BLUE}Access:${NC}"
    echo -e "  • API: ${GREEN}http://localhost:8000${NC}"
    echo -e "  • Health: ${GREEN}http://localhost:8000/health${NC}"
    echo ""
    echo -e "${BLUE}Management:${NC}"
    echo -e "  • Logs: ${YELLOW}docker compose -f $INSTALL_DIR/docker-compose.yml logs -f${NC}"
    echo -e "  • Stop: ${YELLOW}docker compose -f $INSTALL_DIR/docker-compose.yml stop${NC}"
    echo -e "  • Start: ${YELLOW}docker compose -f $INSTALL_DIR/docker-compose.yml start${NC}"
    echo -e "  • Restart: ${YELLOW}docker compose -f $INSTALL_DIR/docker-compose.yml restart${NC}"
else
    echo -e "${RED}❌ Service failed to start!${NC}"
    echo -e "${YELLOW}Check logs:${NC}"
    docker compose logs
    exit 1
fi
