from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import (
    get_db_session,
    get_current_active_user,
    get_current_admin_user,
)
from app.schemas.config import ConfigCreate, ConfigUpdate, ConfigOut
from app.crud.config import config as crud_config


router = APIRouter()


@router.get("/", response_model=list[ConfigOut])
def list_configs(
    db: Session = Depends(get_db_session),
    current_user=Depends(get_current_active_user),
):
    if current_user.is_admin:
        return crud_config.get_multi(db)

    return crud_config.get_by_user(db, user_id=current_user.id)


@router.post("/", response_model=ConfigOut)
def create_config(
    config_in: ConfigCreate,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    return crud_config.create(db, obj_in=config_in)


@router.put("/{config_id}", response_model=ConfigOut)
def update_config(
    config_id: int,
    config_in: ConfigUpdate,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    db_item = crud_config.get(db, id=config_id)
    if not db_item:
        raise HTTPException(status_code=404, detail="Config not found")

    return crud_config.update(db, db_item, config_in)


@router.delete("/{config_id}")
def delete_config(
    config_id: int,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    db_item = crud_config.get(db, id=config_id)
    if not db_item:
        raise HTTPException(status_code=404, detail="Config not found")

    crud_config.remove(db, id=config_id)
    return {"detail": "Config deleted"}
