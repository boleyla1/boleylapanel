# """
# Timezone-safe datetime utilities
# """
# from datetime import datetime, timezone, timedelta
# from typing import Optional
#
#
# def utcnow() -> datetime:
#     """دریافت زمان UTC فعلی (بدون tzinfo)"""
#     return datetime.now(timezone.utc).replace(tzinfo=None)
#
#
# def add_days(date: datetime, days: int) -> datetime:
#     """اضافه کردن روز به تاریخ"""
#     return date + timedelta(days=days)
#
#
# def add_months(date: datetime, months: int) -> datetime:
#     """اضافه کردن ماه به تاریخ (تقریبی)"""
#     return date + timedelta(days=30 * months)
#
#
# def parse_user_datetime(date_str: str, user_timezone: str = "UTC") -> datetime:
#     """
#     تبدیل تاریخ کاربر به UTC
#
#     مثال:
#     >>> parse_user_datetime("2025-12-05 14:30:00", "Asia/Tehran")
#     datetime(2025, 12, 05, 11, 0, 0)  # UTC
#     """
#     from zoneinfo import ZoneInfo
#
#     # Parse کردن تاریخ با timezone کاربر
#     dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
#     dt = dt.replace(tzinfo=ZoneInfo(user_timezone))
#
#     # تبدیل به UTC
#     utc_dt = dt.astimezone(timezone.utc)
#
#     # حذف tzinfo برای سازگاری با MySQL
#     return utc_dt.replace(tzinfo=None)
#
#
# def format_for_user(dt: datetime, user_timezone: str = "UTC") -> str:
#     """
#     نمایش تاریخ UTC به timezone کاربر
#
#     مثال:
#     >>> utc_time = datetime(2025, 12, 5, 11, 0, 0)
#     >>> format_for_user(utc_time, "Asia/Tehran")
#     "2025-12-05 14:30:00"
#     """
#     from zoneinfo import ZoneInfo
#
#     # اضافه کردن UTC timezone
#     utc_dt = dt.replace(tzinfo=timezone.utc)
#
#     # تبدیل به timezone کاربر
#     user_dt = utc_dt.astimezone(ZoneInfo(user_timezone))
#
#     return user_dt.strftime("%Y-%m-%d %H:%M:%S")
