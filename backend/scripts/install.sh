#!/usr/bin/env bash
set -e

# Configuration
GITHUB_REPO="boleyla1/boleylapanel"
GITHUB_BRANCH="main"
APP_NAME="boleylapanel"
APP_DIR="/opt/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
ENV_FILE="$APP_DIR/.env"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
TEMP_CLONE_DIR="/tmp/boleylapanel_clone"

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

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This script must be run as root."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_package() {
    local package=$1
    colorized_echo blue "Installing $package..."
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        apt-get update -qq
        apt-get install -y -qq "$package"
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        yum install -y "$package"
    else
        colorized_echo red "Unsupported OS for package installation"
        exit 1
    fi
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        colorized_echo blue "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
        colorized_echo green "Docker installed successfully"
    else
        colorized_echo green "Docker is already installed"
    fi
}

clone_project() {
    colorized_echo blue "Cloning BoleylPanel from GitHub..."

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        detect_os
        install_package git
    fi

    # Remove temp directory if exists
    rm -rf "$TEMP_CLONE_DIR"

    # Clone the repository
    if ! git clone -b "$GITHUB_BRANCH" "https://github.com/$GITHUB_REPO.git" "$TEMP_CLONE_DIR"; then
        colorized_echo red "Failed to clone repository from GitHub"
        exit 1
    fi

    colorized_echo green "Project cloned successfully"
}

setup_directories() {
    colorized_echo blue "Setting up directories..."

    # Create application directory
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"

    # Copy backend files
    if [ -d "$TEMP_CLONE_DIR/backend" ]; then
        rsync -av --exclude='__pycache__' --exclude='*.pyc' \
            "$TEMP_CLONE_DIR/backend/" "$APP_DIR/"
    else
        colorized_echo red "Backend directory not found in cloned repository"
        exit 1
    fi

    colorized_echo green "Directories setup completed"
}

fix_requirements() {
    colorized_echo blue "Fixing requirements.txt for Pydantic V2..."

    cat > "$APP_DIR/requirements.txt" <<'EOF'
fastapi==0.115.6
uvicorn[standard]==0.34.0
pydantic==2.10.5
pydantic-settings==2.7.0
sqlalchemy==2.0.36
alembic==1.14.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.20
pymysql==1.1.1
cryptography==44.0.0
httpx==0.28.1
jdatetime==5.0.0
EOF

    colorized_echo green "requirements.txt updated"
}

create_dockerfile() {
    colorized_echo blue "Creating optimized Dockerfile..."

    cat > "$APP_DIR/Dockerfile" <<'EOF'
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /var/lib/boleylapanel

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8000/health', timeout=5.0)" || exit 1

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    colorized_echo green "Dockerfile created"
}

create_docker_compose() {
    colorized_echo blue "Creating docker-compose.yml..."

    cat > "$COMPOSE_FILE" <<'EOF'
services:
  backend:
    build: .
    container_name: boleylapanel-backend
    restart: always
    ports:
      - "8000:8000"
    env_file:
      - .env
    volumes:
      - boleylapanel-data:/var/lib/boleylapanel
    depends_on:
      mysql:
        condition: service_healthy
    dns:
      - 8.8.8.8
      - 8.8.4.4
    networks:
      - boleylapanel-network

  mysql:
    image: mysql:8.4
    container_name: boleylapanel-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --bind-address=0.0.0.0
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$$MYSQL_ROOT_PASSWORD"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - boleylapanel-network

volumes:
  boleylapanel-data:
  mysql-data:

networks:
  boleylapanel-network:
    driver: bridge
EOF

    colorized_echo green "docker-compose.yml created"
}

generate_passwords() {
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-40)
}

prompt_admin_credentials() {
    colorized_echo blue "====================================="
    colorized_echo blue "  BoleylPanel Admin Setup"
    colorized_echo blue "====================================="

    read -p "Enter admin username [admin]: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

    read -sp "Enter admin password (leave empty for auto-generate): " ADMIN_PASSWORD
    echo

    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)
        colorized_echo yellow "Generated admin password: $ADMIN_PASSWORD"
    fi
}

create_env_file() {
    colorized_echo blue "Creating .env file..."

    generate_passwords
    prompt_admin_credentials

    cat > "$ENV_FILE" <<EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel
MYSQL_USER=boleylapanel
MYSQL_PASSWORD=$MYSQL_PASSWORD

# SQLAlchemy Database URL
SQLALCHEMY_DATABASE_URL=mysql+pymysql://boleylapanel:${MYSQL_PASSWORD}@mysql:3306/boleylapanel

# JWT Configuration
JWT_SECRET_KEY=$JWT_SECRET
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=43200

# Admin Configuration
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD

# Application Settings
DEBUG=False
EOF

    colorized_echo green ".env file created"
}

install_management_script() {
    colorized_echo blue "Installing management script..."

    cat > /usr/local/bin/boleylapanel <<'SCRIPT'
#!/bin/bash
APP_DIR="/opt/boleylapanel"
cd "$APP_DIR" || exit 1

case "$1" in
    start)
        docker compose up -d
        ;;
    stop)
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
    update)
        docker compose pull
        docker compose up -d --build
        ;;
    *)
        echo "Usage: boleylapanel {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
SCRIPT

    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "Management script installed: boleylapanel"
}

start_services() {
    colorized_echo blue "Building and starting services..."
    cd "$APP_DIR"

    if docker compose up -d --build; then
        colorized_echo green "Services started successfully!"
    else
        colorized_echo red "Failed to start services"
        exit 1
    fi
}

cleanup() {
    colorized_echo blue "Cleaning up temporary files..."
    rm -rf "$TEMP_CLONE_DIR"
}

print_success_message() {
    colorized_echo green "====================================="
    colorized_echo green "  BoleylPanel Installation Complete!"
    colorized_echo green "====================================="
    echo ""
    colorized_echo blue "Access Panel: http://YOUR_SERVER_IP:8000"
    echo ""
    colorized_echo yellow "Admin Credentials:"
    echo "  Username: $ADMIN_USERNAME"
    echo "  Password: $ADMIN_PASSWORD"
    echo ""
    colorized_echo cyan "Management Commands:"
    echo "  boleylapanel start    - Start services"
    echo "  boleylapanel stop     - Stop services"
    echo "  boleylapanel restart  - Restart services"
    echo "  boleylapanel logs     - View logs"
    echo "  boleylapanel status   - Check status"
    echo "  boleylapanel update   - Update from GitHub"
    echo ""
}

# Main installation flow
main() {
    check_running_as_root
    detect_os
    install_docker
    clone_project
    setup_directories
    fix_requirements
    create_dockerfile
    create_docker_compose
    create_env_file
    install_management_script
    start_services
    cleanup
    print_success_message
}

main "$@"
