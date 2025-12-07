from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import (
    get_db_session,
    get_current_admin_user,
)
from app.schemas.server import ServerCreate, ServerUpdate, ServerOut
from app.crud.server import server as crud_server


router = APIRouter()


@router.get("/", response_model=list[ServerOut])
def list_servers(
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    return crud_server.get_multi(db)


@router.post("/", response_model=ServerOut)
def create_server(
    server_in: ServerCreate,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    return crud_server.create(db, obj_in=server_in)


@router.put("/{server_id}", response_model=ServerOut)
def update_server(
    server_id: int,
    server_in: ServerUpdate,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    db_server = crud_server.get(db, id=server_id)
    if not db_server:
        raise HTTPException(status_code=404, detail="Server not found")

    return crud_server.update(db, db_server, server_in)


@router.delete("/{server_id}")
def delete_server(
    server_id: int,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    db_server = crud_server.get(db, id=server_id)
    if not db_server:
        raise HTTPException(status_code=404, detail="Server not found")

    crud_server.remove(db, id=server_id)
    return {"detail": "Server deleted"}
