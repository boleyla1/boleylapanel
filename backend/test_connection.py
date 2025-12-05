"""تست اتصال به MySQL"""
from sqlalchemy import create_engine, text
from app.config.settings import settings

print(f"🔍 تست اتصال به: {settings.database_url}")
print(f"📊 Database: {settings.db_name}")
print(f"👤 User: {settings.db_user}")
print(f"🖥️ Host: {settings.db_host}:{settings.db_port}")
print("-" * 50)

try:
    engine = create_engine(
        settings.database_url,
        connect_args={
            "charset": "utf8mb4",
            "init_command": "SET time_zone='+00:00'"
        }
    )

    with engine.connect() as conn:
        # تست timezone
        result = conn.execute(text("SELECT @@session.time_zone, @@global.time_zone, NOW()"))
        for row in result:
            print(f"✅ Session Timezone: {row[0]}")
            print(f"✅ Global Timezone: {row[1]}")
            print(f"✅ Current Time: {row[2]}")

        # تست دیتابیس
        result = conn.execute(text("SELECT DATABASE()"))
        for row in result:
            print(f"✅ Connected to database: {row[0]}")

    print("\n🎉 اتصال موفقیت‌آمیز بود!")

except Exception as e:
    print(f"\n❌ خطا در اتصال:")
    print(f"   {str(e)}")
