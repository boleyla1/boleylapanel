#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
REPO_URL="https://github.com/boleyla1/boleylapanel.git"

# Functions
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        print_message $RED "❌ This script must be run as root (use sudo)"
        exit 1
    fi
}

check_system() {
    print_message $BLUE "🔍 Checking system requirements..."

    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        print_message $GREEN "✅ OS: $OS"
    else
        print_message $RED "❌ Unsupported operating system"
        exit 1
    fi
}

install_dependencies() {
    print_message $BLUE "📦 Installing dependencies..."

    # Update package manager
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y curl git
    elif command -v yum &> /dev/null; then
        yum update -y -q
        yum install -y curl git
    else
        print_message $RED "❌ Package manager not supported"
        exit 1
    fi

    print_message $GREEN "✅ Dependencies installed"
}

install_docker() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        print_message $GREEN "✅ Docker already installed"
        return
    fi

    print_message $BLUE "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com | sh

    # Start Docker service
    systemctl start docker
    systemctl enable docker

    print_message $GREEN "✅ Docker installed successfully"
}

clone_repository() {
    print_message $BLUE "📥 Downloading Boleyla Panel..."

    # Remove old installation if exists
    if [ -d "$APP_DIR" ]; then
        print_message $YELLOW "⚠️  Old installation found, backing up..."
        mv "$APP_DIR" "${APP_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi

    # Clone repository
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"

    print_message $GREEN "✅ Repository cloned successfully"
}

generate_env_file() {
    print_message $BLUE "⚙️  Generating configuration file..."

    # Generate random passwords
    DB_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
    DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
    ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 12)

    # Create .env file
    cat > "$APP_DIR/.env" << EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD
MYSQL_DATABASE=boleylapanel_db
MYSQL_USER=boleylapanel_user
MYSQL_PASSWORD=$DB_PASSWORD

# Backend Configuration
DB_HOST=boleylapanel-mysql
DB_PORT=3306
DB_NAME=boleylapanel_db
DB_USER=boleylapanel_user
DB_PASSWORD=$DB_PASSWORD

# Admin Configuration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD
ADMIN_EMAIL=admin@boleylapanel.local

# Application Configuration
SECRET_KEY=$(openssl rand -base64 32)
DEBUG=false
BACKEND_PORT=8000
FRONTEND_PORT=3000
EOF

    chmod 600 "$APP_DIR/.env"
    print_message $GREEN "✅ Configuration file created"
}

setup_containers() {
    print_message $BLUE "🚀 Starting containers..."

    cd "$APP_DIR"

    # Build and start containers
    docker-compose build --no-cache
    docker-compose up -d

    print_message $YELLOW "⏳ Waiting for MySQL to be ready..."
    sleep 20

    # Check container status
    if docker-compose ps | grep -q "Up"; then
        print_message $GREEN "✅ Containers started successfully"
    else
        print_message $RED "❌ Failed to start containers"
        docker-compose logs
        exit 1
    fi
}

create_admin_user() {
    print_message $BLUE "👤 Creating admin user..."

    # Load environment variables
    source "$APP_DIR/.env"

    # Create admin user via backend container
    docker-compose exec -T backend python - << PYTHON_SCRIPT
import os
import sys
from sqlalchemy import create_engine, text
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

db_host = os.getenv('DB_HOST', 'boleylapanel-mysql')
db_user = os.getenv('DB_USER')
db_password = os.getenv('DB_PASSWORD')
db_name = os.getenv('DB_NAME')

admin_username = os.getenv('ADMIN_USERNAME', 'admin')
admin_password = os.getenv('ADMIN_PASSWORD')
admin_email = os.getenv('ADMIN_EMAIL', 'admin@boleylapanel.local')

try:
    DATABASE_URL = f"mysql+pymysql://{db_user}:{db_password}@{db_host}:3306/{db_name}"
    engine = create_engine(DATABASE_URL)

    with engine.connect() as conn:
        # Hash password
        hashed_password = pwd_context.hash(admin_password)

        # Delete existing admin
        conn.execute(text("DELETE FROM users WHERE username = :username"), {"username": admin_username})
        conn.commit()

        # Insert new admin
        conn.execute(
            text("""
                INSERT INTO users (username, password, email, is_admin, is_active, created_at)
                VALUES (:username, :password, :email, 1, 1, NOW())
            """),
            {
                "username": admin_username,
                "password": hashed_password,
                "email": admin_email
            }
        )
        conn.commit()

    print("✅ Admin user created successfully")
    sys.exit(0)

except Exception as e:
    print(f"❌ Error: {str(e)}")
    sys.exit(1)
PYTHON_SCRIPT

    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ Admin user created successfully"
    else
        print_message $RED "❌ Failed to create admin user"
        exit 1
    fi
}

show_credentials() {
    source "$APP_DIR/.env"

    print_message $GREEN "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message $CYAN "🎉 Boleyla Panel installed successfully!"
    print_message $GREEN "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

    print_message $YELLOW "📌 Access Information:"
    echo -e "   Panel URL:     ${BLUE}http://$(hostname -I | awk '{print $1}'):$FRONTEND_PORT${NC}"
    echo -e "   API URL:       ${BLUE}http://$(hostname -I | awk '{print $1}'):$BACKEND_PORT${NC}"
    echo ""
    print_message $YELLOW "🔐 Admin Credentials:"
    echo -e "   Username:      ${CYAN}$ADMIN_USERNAME${NC}"
    echo -e "   Password:      ${CYAN}$ADMIN_PASSWORD${NC}"
    echo ""
    print_message $YELLOW "📁 Installation Directory:"
    echo -e "   ${CYAN}$APP_DIR${NC}"
    echo ""
    print_message $YELLOW "🔧 Useful Commands:"
    echo -e "   View logs:     ${CYAN}cd $APP_DIR && docker-compose logs -f${NC}"
    echo -e "   Restart:       ${CYAN}cd $APP_DIR && docker-compose restart${NC}"
    echo -e "   Stop:          ${CYAN}cd $APP_DIR && docker-compose down${NC}"
    echo -e "   Start:         ${CYAN}cd $APP_DIR && docker-compose up -d${NC}"

    print_message $GREEN "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

    # Save credentials to file
    cat > "$APP_DIR/credentials.txt" << EOF
Boleyla Panel - Access Information
==================================

Panel URL: http://$(hostname -I | awk '{print $1}'):$FRONTEND_PORT
API URL: http://$(hostname -I | awk '{print $1}'):$BACKEND_PORT

Admin Credentials:
Username: $ADMIN_USERNAME
Password: $ADMIN_PASSWORD
Email: $ADMIN_EMAIL

Database:
Root Password: $MYSQL_ROOT_PASSWORD
User: $DB_USER
Password: $DB_PASSWORD

Generated at: $(date)
EOF

    chmod 600 "$APP_DIR/credentials.txt"
    print_message $CYAN "💾 Credentials saved to: $APP_DIR/credentials.txt"
}

# Main installation process
main() {
    clear
    print_message $CYAN "╔════════════════════════════════════════╗"
    print_message $CYAN "║   Boleyla Panel Installation Script   ║"
    print_message $CYAN "╚════════════════════════════════════════╝"
    echo ""

    check_root
    check_system
    install_dependencies
    install_docker
    clone_repository
    generate_env_file
    setup_containers
    create_admin_user
    show_credentials
}

# Run main function
main
