from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.api.deps import (
    get_db_session,
    get_current_active_user
)
from app.models.user import User
from app.schemas.config import ConfigCreate, ConfigUpdate, ConfigOut
from app.crud.config import config as crud_config
from app.core.database import get_xray_service
from app.services.xray_service import XrayService
from app.crud.config import config

router = APIRouter()
from app.api import deps


# -------------------------------
# List configs
# -------------------------------
@router.get("/", response_model=List[ConfigOut])
def list_configs(
        db: Session = Depends(get_db_session),
        current_user: User = Depends(get_current_active_user),
):
    if current_user.is_admin:
        return crud_config.get_multi(db)

    return crud_config.get_by_user(db, user_id=current_user.id)


# -------------------------------
# Create config (Admin only)
# -------------------------------
@router.post("/", response_model=ConfigOut)
def create_config(
        config_in: ConfigCreate,
        db: Session = Depends(get_db_session),
        current_user: User = Depends(get_current_active_user),
):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return crud_config.create(db, obj_in=config_in)


# -------------------------------
# Update config (Admin only)
# -------------------------------
@router.put("/{config_id}", response_model=ConfigOut)
def update_config(
        config_id: int,
        config_in: ConfigUpdate,
        db: Session = Depends(get_db_session),
        current_user: User = Depends(get_current_active_user),
):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")

    db_item = crud_config.get(db, id=config_id)
    if not db_item:
        raise HTTPException(status_code=404, detail="Config not found")

    return crud_config.update(db, db_item, config_in)


# -------------------------------
# Delete config (Admin only)
# -------------------------------
@router.delete("/{config_id}")
def delete_config(
        config_id: int,
        db: Session = Depends(get_db_session),
        current_user: User = Depends(get_current_active_user),
):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")

    db_item = crud_config.get(db, obj_id=config_id)
    if not db_item:
        raise HTTPException(status_code=404, detail="Config not found")

    crud_config.remove(db, obj_id=config_id)
    return {"detail": "Config deleted"}


# -------------------------------
# Sync Xray config (Admin only)
# -------------------------------
@router.post("/sync-xray-config")
def sync_xray_config(
        xray_service: XrayService = Depends(deps.get_xray_service),
        current_user: User = Depends(deps.get_current_active_user)
):
    if not current_user.is_admin:
        raise HTTPException(
            status_code=403,
            detail="Admin access required to sync Xray config."
        )

    return xray_service.sync_database_to_xray()
