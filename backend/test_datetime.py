"""تست datetime و timezone"""
from app.db.base import utcnow
from datetime import datetime, timezone

print("🔍 تست توابع datetime:")
print("-" * 50)

# تست تابع utcnow
now = utcnow()
print(f"✅ utcnow(): {now}")
print(f"✅ Type: {type(now)}")
print(f"✅ Timezone info: {now.tzinfo}")  # باید None باشه

# تست datetime معمولی
normal = datetime.now()
print(f"\n📅 datetime.now(): {normal}")
print(f"📅 Timezone info: {normal.tzinfo}")

# تست UTC
utc = datetime.now(timezone.utc).replace(tzinfo=None)
print(f"\n🌍 UTC (naive): {utc}")
print(f"🌍 Timezone info: {utc.tzinfo}")

print("\n" + "="*50)
if now.tzinfo is None:
    print("✅ همه چیز درسته - timezone ها None هستند")
else:
    print("❌ مشکل - timezone وجود داره!")
