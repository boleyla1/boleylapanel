#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                        ║${NC}"
echo -e "${GREEN}║      BoleylaPanle Auto Installer       ║${NC}"
echo -e "${GREEN}║                                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}❌ Please run with sudo${NC}"
   exit 1
fi

if [ -d "/opt/boleylapanel" ]; then
    echo -e "${YELLOW}⚠️  Removing previous installation...${NC}"
    cd /opt/boleylapanel/backend 2>/dev/null && docker compose down 2>/dev/null || true
    rm -rf /opt/boleylapanel
fi

echo -e "${BLUE}📦 Downloading project from GitHub...${NC}"
cd /opt
git clone https://github.com/boleyla1/boleylapanel.git
cd /opt/boleylapanel/backend

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}🐳 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
fi

echo -e "${BLUE}🌐 Configuring DNS...${NC}"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
DOCKER_EOF
systemctl restart docker 2>/dev/null || true

if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚙️  Creating .env file...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        cat > .env << 'ENV_EOF'
DATABASE_URL=sqlite:///./boleylapanel.db
SECRET_KEY=$(openssl rand -hex 32)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
ENV_EOF
    fi
fi

echo -e "${GREEN}🔨 Building Docker images...${NC}"
docker compose build --no-cache

echo -e "${GREEN}🚀 Starting services...${NC}"
docker compose up -d

echo -e "${BLUE}📝 Installing management script...${NC}"
cat > /usr/local/bin/boleylapanel << 'SCRIPT_EOF'
#!/bin/bash
cd /opt/boleylapanel/backend
case "$1" in
    start) docker compose up -d ;;
    stop) docker compose down ;;
    restart) docker compose restart ;;
    logs) docker compose logs -f ;;
    status) docker compose ps ;;
    update)
        git pull
        docker compose down
        docker compose build --no-cache
        docker compose up -d
        ;;
    *)
        echo "Usage: boleylapanel {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x /usr/local/bin/boleylapanel

clear
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Installation completed!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
docker compose ps
echo ""
echo -e "${BLUE}📋 Management commands:${NC}"
echo -e "  ${GREEN}boleylapanel start${NC}   - Start service"
echo -e "  ${YELLOW}boleylapanel stop${NC}    - Stop service"
echo -e "  ${BLUE}boleylapanel restart${NC} - Restart service"
echo -e "  ${BLUE}boleylapanel logs${NC}    - View logs"
echo -e "  ${GREEN}boleylapanel status${NC}  - Check status"
echo -e "  ${YELLOW}boleylapanel update${NC}  - Update from GitHub"
echo ""
