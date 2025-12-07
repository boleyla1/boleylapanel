import os

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.services.xray_service import XrayService
from app.db.database import get_db
from app.core.security import decode_access_token
from app.crud.user import user as crud_user
from app.config import settings

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_db_session():
    db = next(get_db())
    try:
        yield db
    finally:
        db.close()


def get_current_user(
        token: str = Depends(oauth2_scheme),
        db: Session = Depends(get_db_session)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid authentication credentials",
    )

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception

    user_id: int = payload.get("user_id")
    if user_id is None:
        raise credentials_exception

    user_obj = crud_user.get(db, user_id=user_id)
    if user_obj is None:
        raise credentials_exception

    return user_obj


def get_current_active_user(current_user=Depends(get_current_user)):
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )
    return current_user


def get_current_admin_user(current_user=Depends(get_current_active_user)):
    # مدل User جدید: نقش‌ها در فیلد role.value ذخیره شده
    if hasattr(current_user, "role"):
        if current_user.role.value.lower() != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin privileges required",
            )
    else:
        # اگر مدل قدیمی is_admin داشته
        if not current_user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin privileges required",
            )

    return current_user


def get_xray_service(db: Session = Depends(get_db)) -> XrayService:
    return XrayService(
        db=db,
        template_path=settings.XRAY_CONFIG_TEMPLATE_PATH,
        output_path=settings.XRAY_CONFIG_OUTPUT_PATH,
        enable_service=settings.ENABLE_XRAY_SERVICE,
        service_name=settings.XRAY_SERVICE_NAME,
        base_port=settings.XRAY_BASE_PORT
    )
