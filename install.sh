#!/usr/bin/env bash
set -e

APP_NAME="boleylapanel"
APP_DIR="/opt/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"

# تابع رنگی
colorized_echo() {
    local color=$1
    local text=$2
    case $color in
        "red") printf "\e[91m${text}\e[0m\n";;
        "green") printf "\e[92m${text}\e[0m\n";;
        "yellow") printf "\e[93m${text}\e[0m\n";;
        "blue") printf "\e[94m${text}\e[0m\n";;
        *) echo "${text}";;
    esac
}

# تشخیص محیط
detect_environment() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        colorized_echo yellow "🪟 محیط ویندوز شناسایی شد"
        IS_WINDOWS=true
        APP_DIR="$(pwd)"
    else
        colorized_echo blue "🐧 محیط لینوکس شناسایی شد"
        IS_WINDOWS=false

        # چک کردن root
        if [ "$(id -u)" != "0" ]; then
            colorized_echo red "❌ این اسکریپت باید با sudo اجرا شود"
            exit 1
        fi
    fi
}

# نصب Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        if [ "$IS_WINDOWS" = true ]; then
            colorized_echo yellow "لطفاً Docker Desktop را از docker.com نصب کنید"
            exit 1
        else
            colorized_echo blue "📦 نصب Docker..."
            curl -fsSL https://get.docker.com | sh
            systemctl start docker
            systemctl enable docker
        fi
    fi
    colorized_echo green "✅ Docker نصب شده است"
}

# تنظیم دایرکتوری
setup_directory() {
    if [ "$IS_WINDOWS" = false ]; then
        mkdir -p "$APP_DIR"
        mkdir -p "$DATA_DIR"
        cd "$APP_DIR"
    fi
    colorized_echo green "✅ دایرکتوری آماده شد: $APP_DIR"
}

# دانلود فایل‌ها
download_files() {
    colorized_echo blue "📥 دانلود فایل‌های پروژه..."

    # docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: mysql:8.0
    container_name: boleylapanel-db
    restart: unless-stopped
    networks:
      - boleylapanel
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD:-secret_root_password}
      MYSQL_DATABASE: ${DB_NAME:-boleylapanel}
      MYSQL_USER: ${DB_USER:-boleyla}
      MYSQL_PASSWORD: ${DB_PASSWORD:-secret_password}
    volumes:
      - db_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: boleyla1/boleylapanel:latest
    container_name: boleylapanel-backend
    restart: unless-stopped
    networks:
      - boleylapanel
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: "mysql+pymysql://${DB_USER:-boleyla}:${DB_PASSWORD:-secret_password}@db:3306/${DB_NAME:-boleylapanel}"
      DB_HOST: db
      DB_PORT: 3306
    env_file:
      - .env
    volumes:
      - backend_data:/app/data
    depends_on:
      db:
        condition: service_healthy

networks:
  boleylapanel:
    driver: bridge

volumes:
  db_data:
  backend_data:
EOF
    fi

    # .env
    if [ ! -f ".env" ]; then
        cat > .env << 'EOF'
DB_HOST=db
DB_PORT=3306
DB_NAME=boleylapanel
DB_USER=boleyla
DB_PASSWORD=secret_password

DATABASE_URL=mysql+pymysql://boleyla:secret_password@db:3306/boleylapanel

JWT_SECRET_KEY=your-super-secret-key
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=43200

XRAY_EXECUTABLE_PATH=/usr/local/bin/xray
XRAY_ASSETS_PATH=/usr/local/share/xray
XRAY_SUBSCRIPTION_URL_PREFIX=https://example.com
EOF
    fi

    colorized_echo green "✅ فایل‌ها آماده شدند"
}

# نصب CLI (فقط لینوکس)
install_cli() {
    if [ "$IS_WINDOWS" = false ]; then
        colorized_echo blue "📦 نصب CLI..."
        cat > /usr/local/bin/boleylapanel << 'EOFCLI'
#!/usr/bin/env bash
APP_DIR="/opt/boleylapanel"
cd "$APP_DIR" || exit 1

case "$1" in
    up)
        docker compose up -d
        ;;
    down)
        docker compose down
        ;;
    restart)
        docker compose restart
        ;;
    logs)
        docker compose logs -f "${2:-backend}"
        ;;
    status)
        docker compose ps
        ;;
    *)
        echo "Usage: boleylapanel {up|down|restart|logs|status}"
        ;;
esac
EOFCLI
        chmod +x /usr/local/bin/boleylapanel
        colorized_echo green "✅ CLI نصب شد: boleylapanel"
    else
        colorized_echo yellow "⚠️ CLI فقط برای لینوکس"
    fi
}

# اجرای سرویس‌ها
start_services() {
    colorized_echo blue "🚀 راه‌اندازی سرویس‌ها..."
    docker compose pull
    docker compose up -d

    colorized_echo green "✅ نصب با موفقیت انجام شد!"
    colorized_echo blue "🌐 پنل در http://localhost:8000 در دسترس است"

    if [ "$IS_WINDOWS" = false ]; then
        colorized_echo yellow "💡 برای مدیریت: boleylapanel {up|down|logs|status}"
    else
        colorized_echo yellow "💡 برای مدیریت: docker compose {up|down|logs|ps}"
    fi
}

# اجرای نصب
main() {
    colorized_echo blue "=================================="
    colorized_echo blue "  نصب BoleylaPanel"
    colorized_echo blue "=================================="

    detect_environment
    install_docker
    setup_directory
    download_files
    install_cli
    start_services
}

main
