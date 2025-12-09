#!/usr/bin/env bash
set -e

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== نصب خودکار BoleylaPanle ===${NC}"

# بررسی root
if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}لطفا با sudo اجرا کنید${NC}"
   exit 1
fi

# حذف نصب قبلی
if [ -d "/opt/boleylapanel" ]; then
    echo -e "${YELLOW}حذف نصب قبلی...${NC}"
    cd /opt/boleylapanel/backend 2>/dev/null && docker compose down 2>/dev/null || true
    rm -rf /opt/boleylapanel
fi

# کلون پروژه
echo -e "${GREEN}دانلود پروژه از GitHub...${NC}"
cd /opt
git clone https://github.com/boleyla1/boleylapanel.git
cd /opt/boleylapanel/backend

# نصب Docker (اگر نیست)
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}نصب Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
fi

# تنظیم DNS (رفع مشکل Trixie)
echo -e "${GREEN}تنظیم DNS...${NC}"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
DOCKER_EOF
systemctl restart docker 2>/dev/null || true

# اصلاح Dockerfile (استفاده از Mirror سریع)
echo -e "${GREEN}اصلاح Dockerfile...${NC}"
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM python:3.12-slim

WORKDIR /app

# استفاده از Mirror ایران برای سرعت بالا
RUN echo "deb https://mirror.arvancloud.ir/debian trixie main" > /etc/apt/sources.list && \
    echo "deb https://mirror.arvancloud.ir/debian trixie-updates main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
DOCKERFILE_EOF

# بررسی .env
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}ایجاد فایل .env...${NC}"
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

# ساخت و اجرای کانتینرها
echo -e "${GREEN}ساخت Docker Images (ممکنه چند دقیقه طول بکشه)...${NC}"
docker compose build --no-cache

echo -e "${GREEN}اجرای سرویس‌ها...${NC}"
docker compose up -d

# ایجاد اسکریپت مدیریت
echo -e "${GREEN}نصب اسکریپت مدیریت...${NC}"
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
        echo "استفاده: boleylapanel {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x /usr/local/bin/boleylapanel

# نمایش وضعیت
echo -e "${GREEN}✅ نصب کامل شد!${NC}"
echo ""
docker compose ps
echo ""
echo -e "${GREEN}دستورات مدیریت:${NC}"
echo "  boleylapanel start   - اجرای سرویس"
echo "  boleylapanel stop    - توقف سرویس"
echo "  boleylapanel restart - ریستارت"
echo "  boleylapanel logs    - مشاهده لاگ‌ها"
echo "  boleylapanel status  - وضعیت سرویس"
echo "  boleylapanel update  - به‌روزرسانی از GitHub"
