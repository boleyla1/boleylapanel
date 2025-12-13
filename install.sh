#!/bin/bash
set -e

APP_DIR="/opt/boleylapanel"
ENV_FILE="$APP_DIR/.env"

echo "🔧 BoleylPanel Admin User Fix Script"
echo "===================================="

# چک کردن وجود .env
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found at $ENV_FILE"
    exit 1
fi

# بارگذاری متغیرها
echo "📥 Loading environment variables..."
source "$ENV_FILE"

# چک کردن متغیرهای ضروری
if [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ] || [ -z "$DATABASE_URL" ]; then
    echo "❌ Missing required variables in .env file"
    echo "Required: ADMIN_USERNAME, ADMIN_PASSWORD, DATABASE_URL"
    exit 1
fi

echo "✅ Environment variables loaded"
echo "   Username: $ADMIN_USERNAME"
echo "   Database: $(echo $DATABASE_URL | sed 's/:[^:]*@/:***@/')"

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
    echo "⚠️ init_db.py not found, will create admin directly via Python"
    SCRIPT_PATH="direct"
fi

echo ""
echo "🚀 Creating admin user..."

if [ "$SCRIPT_PATH" = "direct" ]; then
    # روش ۱: ساخت مستقیم admin بدون استفاده از init_db.py
    docker exec -i boleylapanel-backend python3 <<PYEOF
import os
import sys

# تنظیم متغیرهای محیطی
os.environ['DATABASE_URL'] = '$DATABASE_URL'
os.environ['ADMIN_USERNAME'] = '$ADMIN_USERNAME'
os.environ['ADMIN_PASSWORD'] = '$ADMIN_PASSWORD'
os.environ['ADMIN_EMAIL'] = '${ADMIN_EMAIL:-admin@boleyla.com}'

# اضافه کردن مسیر app به sys.path
sys.path.insert(0, '/app')

try:
    from app.db.database import engine, SessionLocal
    from app.models.user import User
    from app.core.security import get_password_hash
    from sqlalchemy import inspect

    print('✅ Imports successful')

    # بررسی اتصال به دیتابیس
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    print(f'📊 Available tables: {tables}')

    # ساخت session
    db = SessionLocal()

    try:
        # چک کردن admin موجود
        existing_admin = db.query(User).filter(User.username == os.environ['ADMIN_USERNAME']).first()

        if existing_admin:
            print(f'⚠️  Admin user "{os.environ["ADMIN_USERNAME"]}" already exists')
            print(f'   Role: {existing_admin.role}')
            print(f'   Active: {existing_admin.is_active}')
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
            print(f'✅ Admin user "{admin_user.username}" created successfully!')
            print(f'   ID: {admin_user.id}')
            print(f'   Role: {admin_user.role}')
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
    print('📝 Checking app structure...')
    import os
    for root, dirs, files in os.walk('/app'):
        level = root.replace('/app', '').count(os.sep)
        indent = ' ' * 2 * level
        print(f'{indent}{os.path.basename(root)}/')
        subindent = ' ' * 2 * (level + 1)
        for file in files[:5]:
            print(f'{subindent}{file}')
        if len(files) > 5:
            print(f'{subindent}... and {len(files)-5} more files')
    sys.exit(1)
except Exception as e:
    print(f'❌ Unexpected error: {str(e)}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

else
    # روش ۲: استفاده از init_db.py موجود
    docker exec -i boleylapanel-backend bash -c "
export ADMIN_USERNAME='$ADMIN_USERNAME'
export ADMIN_PASSWORD='$ADMIN_PASSWORD'
export ADMIN_EMAIL='${ADMIN_EMAIL:-admin@boleyla.com}'
export DATABASE_URL='$DATABASE_URL'
python $SCRIPT_PATH
"
fi

RESULT=$?

echo ""
echo "===================================="
if [ $RESULT -eq 0 ]; then
    echo "✅ Script completed successfully!"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Access panel: http://YOUR_SERVER_IP:8000"
    echo "   2. Login with:"
    echo "      Username: $ADMIN_USERNAME"
    echo "      Password: [your password]"
else
    echo "❌ Script failed with exit code: $RESULT"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. Check container logs: docker logs boleylapanel-backend"
    echo "   2. Check MySQL: docker logs boleylapanel-mysql"
    echo "   3. Verify .env file: cat $ENV_FILE"
fi
echo "===================================="
