# app/core/database.py
from fastapi import Depends
from sqlalchemy.orm import Session
from app.db.database import SessionLocal, engine
from app.db.base import Base
from app.config.settings import settings
from app.services.xray_service import XrayService


# Dependency دیتابیس
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Dependency سرویس Xray
def get_xray_service(db: Session = Depends(get_db)):
    return XrayService(
        db=db,
        template_path=settings.XRAY_CONFIG_TEMPLATE_PATH,
        output_path=settings.XRAY_OUTPUT_CONFIG_PATH,
        service_name=settings.XRAY_SERVICE_NAME,
        base_port=settings.XRAY_BASE_PORT,
        enable_service=settings.ENABLE_XRAY_SERVICE
    )
