#!/bin/bash
set -e

APP_DIR="/opt/boleylapanel"
ENV_FILE="$APP_DIR/.env"

echo "🔧 BoleylPanel Admin User Fix Script"
echo "===================================="

# چک کردن وجود .env
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found at $ENV_FILE"
    echo ""
    echo "📝 Creating default .env file..."

    # تولید رمزهای تصادفی قوی
    MYSQL_ROOT_PASS=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    MYSQL_PASS=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    SECRET_KEY=$(openssl rand -hex 32)
    ADMIN_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

    cat > "$ENV_FILE" << EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}
MYSQL_DATABASE=boleyla
MYSQL_USER=admin
MYSQL_PASSWORD=${MYSQL_PASS}

# Application Configuration
DATABASE_URL=mysql+pymysql://admin:${MYSQL_PASS}@boleylapanel-mysql:3306/boleyla
SECRET_KEY=${SECRET_KEY}

# Admin User
ADMIN_USERNAME=boleyla
ADMIN_PASSWORD=${ADMIN_PASS}
ADMIN_EMAIL=admin@boleyla.com

# Optional
DEBUG=false
ENVIRONMENT=production
EOF

    echo "✅ .env file created at $ENV_FILE"
    echo ""
    echo "⚠️  IMPORTANT: Save these credentials!"
    echo "   Admin Username: boleyla"
    echo "   Admin Password: ${ADMIN_PASS}"
    echo ""
    read -p "Press Enter to continue..."
fi

# بارگذاری متغیرها (به صورت امن)
echo "📥 Loading environment variables..."

# پاک کردن متغیرهای قبلی
unset MYSQL_ROOT_PASSWORD MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD
unset DATABASE_URL SECRET_KEY ADMIN_USERNAME ADMIN_PASSWORD ADMIN_EMAIL

# بارگذاری فایل .env
while IFS='=' read -r key value; do
    # حذف فضای خالی و کامنت‌ها
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    # رد کردن خطوط خالی و کامنت
    if [[ -z "$key" || "$key" =~ ^# ]]; then
        continue
    fi

    # Export کردن متغیر
    export "$key=$value"
done < "$ENV_FILE"

# چک کردن متغیرهای ضروری
MISSING_VARS=()
[[ -z "$ADMIN_USERNAME" ]] && MISSING_VARS+=("ADMIN_USERNAME")
[[ -z "$ADMIN_PASSWORD" ]] && MISSING_VARS+=("ADMIN_PASSWORD")
[[ -z "$DATABASE_URL" ]] && MISSING_VARS+=("DATABASE_URL")

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Missing required variables in .env file:"
    printf '   - %s\n' "${MISSING_VARS[@]}"
    exit 1
fi

echo "✅ Environment variables loaded"
echo "   Username: $ADMIN_USERNAME"
echo "   Email: ${ADMIN_EMAIL:-admin@boleyla.com}"
echo "   Database: $(echo $DATABASE_URL | sed 's/:[^:]*@/:***@/')"

# چک کردن وضعیت کانتینر
echo ""
echo "🔍 Checking container status..."
if ! docker ps | grep -q boleylapanel-backend; then
    echo "❌ Backend container is not running!"
    echo "   Run: docker-compose up -d"
    exit 1
fi
echo "✅ Backend container is running"

# تشخیص مسیر اسکریپت init_db
echo ""
echo "🔍 Detecting init_db.py location..."

if docker exec boleylapanel-backend test -f /app/scripts/init_db.py 2>/dev/null; then
    SCRIPT_PATH="/app/scripts/init_db.py"
    echo "✅ Found at: $SCRIPT_PATH"
elif docker exec boleylapanel-backend test -f /app/app/scripts/init_db.py 2>/dev/null; then
    SCRIPT_PATH="/app/app/scripts/init_db.py"
    echo "✅ Found at: $SCRIPT_PATH"
else
    echo "⚠️  init_db.py not found, will create admin directly via Python"
    SCRIPT_PATH="direct"
fi

echo ""
echo "🚀 Creating admin user..."

if [ "$SCRIPT_PATH" = "direct" ]; then
    # روش ۱: ساخت مستقیم admin بدون استفاده از init_db.py
    docker exec -i boleylapanel-backend python3 <<PYEOF
import os
import sys

# تنظیم متغیرهای محیطی (از متغیرهای bash)
os.environ['DATABASE_URL'] = '''${DATABASE_URL}'''
os.environ['ADMIN_USERNAME'] = '''${ADMIN_USERNAME}'''
os.environ['ADMIN_PASSWORD'] = '''${ADMIN_PASSWORD}'''
os.environ['ADMIN_EMAIL'] = '''${ADMIN_EMAIL:-admin@boleyla.com}'''

# اضافه کردن مسیر app به sys.path
sys.path.insert(0, '/app')

try:
    from app.db.database import engine, SessionLocal
    from app.models.user import User
    from app.core.security import get_password_hash
    from sqlalchemy import inspect, text

    print('✅ Imports successful')

    # بررسی اتصال به دیتابیس
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            print('✅ Database connection successful')
    except Exception as e:
        print(f'❌ Database connection failed: {e}')
        sys.exit(1)

    # بررسی جداول موجود
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    print(f'📊 Available tables: {tables}')

    if 'users' not in tables:
        print('⚠️  Table "users" not found. Running migrations...')
        from app.db.base import Base
        Base.metadata.create_all(bind=engine)
        print('✅ Tables created')

    # ساخت session
    db = SessionLocal()

    try:
        # چک کردن admin موجود
        existing_admin = db.query(User).filter(
            User.username == os.environ['ADMIN_USERNAME']
        ).first()

        if existing_admin:
            print(f'⚠️  Admin user "{os.environ["ADMIN_USERNAME"]}" already exists')
            print(f'   ID: {existing_admin.id}')
            print(f'   Role: {existing_admin.role}')
            print(f'   Active: {existing_admin.is_active}')
            print(f'   Email: {existing_admin.email}')

            # آپدیت رمز عبور اگر تغییر کرده
            choice = input('\\n🔄 Update password? (yes/no): ').lower()
            if choice == 'yes':
                existing_admin.hashed_password = get_password_hash(os.environ['ADMIN_PASSWORD'])
                db.commit()
                print('✅ Password updated successfully!')
        else:
            # ساخت admin جدید
            admin_user = User(
                username=os.environ['ADMIN_USERNAME'],
                hashed_password=get_password_hash(os.environ['ADMIN_PASSWORD']),
                email=os.environ.get('ADMIN_EMAIL', 'admin@boleyla.com'),
                role='admin',
                is_active=True
            )
            db.add(admin_user)
            db.commit()
            db.refresh(admin_user)

            print(f'\\n✅ Admin user created successfully!')
            print(f'   ID: {admin_user.id}')
            print(f'   Username: {admin_user.username}')
            print(f'   Email: {admin_user.email}')
            print(f'   Role: {admin_user.role}')
            print(f'   Active: {admin_user.is_active}')

    except Exception as e:
        db.rollback()
        print(f'❌ Database operation error: {str(e)}')
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        db.close()

except ImportError as e:
    print(f'❌ Import error: {str(e)}')
    print('\\n📝 Checking app structure...')
    import os
    for root, dirs, files in os.walk('/app'):
        level = root.replace('/app', '').count(os.sep)
        if level > 3:  # محدود کردن عمق
            continue
        indent = ' ' * 2 * level
        print(f'{indent}{os.path.basename(root)}/')
        subindent = ' ' * 2 * (level + 1)
        for file in files[:5]:
            if file.endswith('.py'):
                print(f'{subindent}{file}')
    sys.exit(1)

except Exception as e:
    print(f'❌ Unexpected error: {str(e)}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

else
    # روش ۲: استفاده از init_db.py موجود
    docker exec -i boleylapanel-backend bash <<BASHEOF
export ADMIN_USERNAME='${ADMIN_USERNAME}'
export ADMIN_PASSWORD='${ADMIN_PASSWORD}'
export ADMIN_EMAIL='${ADMIN_EMAIL:-admin@boleyla.com}'
export DATABASE_URL='${DATABASE_URL}'
python ${SCRIPT_PATH}
BASHEOF
fi

RESULT=$?

echo ""
echo "===================================="
if [ $RESULT -eq 0 ]; then
    echo "✅ Script completed successfully!"
    echo ""
    echo "🎯 Access Information:"
    echo "   🌐 URL: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP'):8000"
    echo "   👤 Username: $ADMIN_USERNAME"
    echo "   🔑 Password: [check .env file or your notes]"
    echo ""
    echo "📝 To view password:"
    echo "   grep ADMIN_PASSWORD $ENV_FILE"
else
    echo "❌ Script failed with exit code: $RESULT"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. Check backend logs:"
    echo "      docker logs boleylapanel-backend --tail 50"
    echo ""
    echo "   2. Check MySQL logs:"
    echo "      docker logs boleylapanel-mysql --tail 50"
    echo ""
    echo "   3. Check containers:"
    echo "      docker-compose ps"
    echo ""
    echo "   4. Verify .env file:"
    echo "      cat $ENV_FILE"
    echo ""
    echo "   5. Test database connection:"
    echo "      docker exec boleylapanel-backend python -c 'from app.db.database import engine; engine.connect()'"
fi
echo "===================================="
