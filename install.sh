#!/usr/bin/env bash
set -e

# ========================================
#  BolelaPanel Installation Script
# ========================================

INSTALL_DIR="/opt"
APP_NAME="boleylapanel"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

# Colors
colorized_echo() {
    local color=$1
    local text=$2

    case $color in
        "red")    printf "\e[91m${text}\e[0m\n";;
        "green")  printf "\e[92m${text}\e[0m\n";;
        "yellow") printf "\e[93m${text}\e[0m\n";;
        "blue")   printf "\e[94m${text}\e[0m\n";;
        "magenta") printf "\e[95m${text}\e[0m\n";;
        "cyan")   printf "\e[96m${text}\e[0m\n";;
        *)        echo "${text}";;
    esac
}

# Check root
check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This script must be run as root."
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        colorized_echo red "Cannot detect OS"
        exit 1
    fi
}

# Install package based on OS
install_package() {
    local package=$1
    colorized_echo blue "Installing $package..."

    case $OS in
        ubuntu|debian)
            apt-get update -qq && apt-get install -y -qq "$package"
            ;;
        centos|rhel|almalinux)
            yum install -y "$package"
            ;;
        fedora)
            dnf install -y "$package"
            ;;
        arch|manjaro)
            pacman -S --noconfirm "$package"
            ;;
        *)
            colorized_echo red "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Install Docker
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

# Detect docker compose
detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "Docker Compose not found"
        exit 1
    fi
}

# Generate random password
generate_password() {
    openssl rand -base64 32 | tr -d '/+=' | cut -c1-24
}

# Create .env file
generate_env_file() {
    colorized_echo blue "Generating .env file..."

    local db_root_pass=$(generate_password)
    local db_user_pass=$(generate_password)
    local secret_key=$(generate_password)
    local admin_user="admin"
    local admin_pass="admin123"
    local admin_email="admin@boleylapanel.local"

    cat > "$ENV_FILE" << EOF
# App Configuration
APP_NAME=BolelaPanel
APP_VERSION=1.0.0
DEBUG=false

# Database Configuration
DB_HOST=db
DB_PORT=3306
DB_NAME=boleylapanel_db
DB_USER=boleylapanel_user
DB_PASSWORD=$db_user_pass

MYSQL_ROOT_PASSWORD=$db_root_pass
MYSQL_DATABASE=boleylapanel_db
MYSQL_USER=boleylapanel_user
MYSQL_PASSWORD=$db_user_pass

# Database URL
DATABASE_URL=mysql+pymysql://boleylapanel_user:$db_user_pass@db:3306/boleylapanel_db

# Security
SECRET_KEY=$secret_key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Admin Credentials (for initial setup)
ADMIN_USERNAME=$admin_user
ADMIN_PASSWORD=$admin_pass
ADMIN_EMAIL=$admin_email
EOF

    chmod 600 "$ENV_FILE"

    # Save credentials to secure file
    cat > "$APP_DIR/.credentials" << EOF
========================================
   BolelaPanel Installation Info
========================================

Admin Username: $admin_user
Admin Password: $admin_pass
Admin Email:    $admin_email

Database Root Password: $db_root_pass
Database User Password: $db_user_pass

Secret Key: $secret_key

========================================
IMPORTANT: Keep this file secure!
========================================
EOF

    chmod 400 "$APP_DIR/.credentials"

    colorized_echo green ".env file created"
    colorized_echo yellow "Credentials saved to: $APP_DIR/.credentials"
}

# Wait for MySQL
wait_for_mysql() {
    colorized_echo yellow "Waiting for MySQL to be ready..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if $COMPOSE -f "$COMPOSE_FILE" exec -T db mysqladmin ping -h localhost --silent &>/dev/null; then
            colorized_echo green "MySQL is ready!"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    colorized_echo red "MySQL failed to start"
    return 1
}

# Run migrations
run_migrations() {
    colorized_echo blue "Running database migrations..."

    if ! $COMPOSE -f "$COMPOSE_FILE" exec -T backend alembic upgrade head; then
        colorized_echo red "Migration failed!"
        exit 1
    fi

    colorized_echo green "Migrations completed"
}

# Create admin user
create_admin_user() {
    colorized_echo blue "Creating admin user..."

    $COMPOSE -f "$COMPOSE_FILE" exec -T backend python << 'PYTHON_SCRIPT'
import sys
import os
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.user import User, UserRole
from app.core.security import get_password_hash

try:
    db = SessionLocal()

    # Check if admin exists
    existing_admin = db.query(User).filter(
        User.username == os.getenv('ADMIN_USERNAME')
    ).first()

    if existing_admin:
        print("Admin user already exists")
        sys.exit(0)

    # Create admin
    admin = User(
        username=os.getenv('ADMIN_USERNAME'),
        email=os.getenv('ADMIN_EMAIL'),
        hashed_password=get_password_hash(os.getenv('ADMIN_PASSWORD')),
        role=UserRole.ADMIN,
        is_active=True,
        full_name="System Administrator"
    )

    db.add(admin)
    db.commit()
    print(f"Admin user '{admin.username}' created successfully")
    sys.exit(0)

except Exception as e:
    print(f"Error creating admin: {e}")
    sys.exit(1)
finally:
    db.close()
PYTHON_SCRIPT

    if [ $? -eq 0 ]; then
        colorized_echo green "Admin user ready"
    else
        colorized_echo red "Failed to create admin user"
        exit 1
    fi
}

# Install boleylapanel script
install_boleylapanel_script() {
    colorized_echo blue "Installing boleylapanel command..."

    cat > /usr/local/bin/boleylapanel << 'EOF'
#!/usr/bin/env bash
set -e

COMPOSE_FILE="/opt/boleylapanel/docker-compose.yml"
COMPOSE="docker compose"

case "$1" in
    up)
        $COMPOSE -f $COMPOSE_FILE up -d
        ;;
    down)
        $COMPOSE -f $COMPOSE_FILE down
        ;;
    restart)
        $COMPOSE -f $COMPOSE_FILE restart
        ;;
    logs)
        $COMPOSE -f $COMPOSE_FILE logs -f "${@:2}"
        ;;
    status)
        $COMPOSE -f $COMPOSE_FILE ps
        ;;
    makemigration)
        $COMPOSE -f $COMPOSE_FILE exec backend alembic revision --autogenerate -m "${2:-auto}"
        ;;
    migrate)
        $COMPOSE -f $COMPOSE_FILE exec backend alembic upgrade head
        ;;
    migration-status)
        $COMPOSE -f $COMPOSE_FILE exec backend alembic current
        ;;
    migration-downgrade)
        $COMPOSE -f $COMPOSE_FILE exec backend alembic downgrade -1
        ;;
    *)
        echo "Usage: boleylapanel {up|down|restart|logs|status|makemigration|migrate|migration-status|migration-downgrade}"
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/boleylapanel
    colorized_echo green "boleylapanel command installed"
}

# Show success message
show_success_message() {
    local ip=$(hostname -I | awk '{print $1}')
    [ -z "$ip" ] && ip=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

    cat << EOF

========================================
  BolelaPanel Installed Successfully!
========================================

Access Panel:
  http://$ip:8000

Credentials file:
  $APP_DIR/.credentials

Useful commands:
  boleylapanel up              - Start services
  boleylapanel down            - Stop services
  boleylapanel restart         - Restart services
  boleylapanel logs            - View logs
  boleylapanel status          - Check status
  boleylapanel migrate         - Run migrations
  boleylapanel makemigration   - Create new migration

========================================
EOF
}

# Main installation
install_command() {
    colorized_echo cyan "========================================="
    colorized_echo cyan "   BolelaPanel Installation Started"
    colorized_echo cyan "========================================="

    check_running_as_root
    detect_os

    # Install dependencies
    colorized_echo blue "Installing dependencies..."
    install_package "curl"
    install_package "git"

    # Install Docker
    install_docker
    detect_compose

    # Create directories
    colorized_echo blue "Creating directories..."
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"

    # Download project files
    colorized_echo blue "Downloading project files..."
    cd "$APP_DIR"

    if [ ! -f "docker-compose.yml" ]; then
        colorized_echo red "Please place docker-compose.yml in $APP_DIR"
        exit 1
    fi

    # Generate .env
    if [ ! -f "$ENV_FILE" ]; then
        generate_env_file
    else
        colorized_echo yellow ".env file already exists, skipping generation"
    fi

    # Start services
    colorized_echo blue "Starting containers..."
    $COMPOSE -f "$COMPOSE_FILE" up -d

    # Wait for MySQL
    wait_for_mysql || exit 1

    # Run migrations
    run_migrations

    # Create admin
    create_admin_user

    # Install CLI
    install_boleylapanel_script

    # Success message
    show_success_message
}

# Run installation
install_command
