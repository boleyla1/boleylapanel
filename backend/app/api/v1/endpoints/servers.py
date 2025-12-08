# app/api/v1/endpoints/servers.py

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List

from app.api.deps import get_db, get_current_admin_user
from app.schemas.server import ServerCreate, ServerUpdate, ServerResponse, ServerOut, ServerStats
from app.services.server_service import ServerService
from app.models.server import ServerStatus


router = APIRouter()


def get_server_service(db: Session = Depends(get_db)) -> ServerService:
    return ServerService(db)


@router.get("/", response_model=List[ServerOut])
def list_servers(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    return server_service.get_all_servers(skip=skip, limit=limit)


@router.get("/active", response_model=List[ServerOut])
def list_active_servers(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    return server_service.get_active_servers(skip=skip, limit=limit)


@router.get("/status/{status}", response_model=List[ServerOut])
def list_servers_by_status(
    status: ServerStatus,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    return server_service.get_servers_by_status(status=status, skip=skip, limit=limit)


@router.get("/{server_id}", response_model=ServerResponse)
def get_server(
    server_id: int,
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    server = server_service.get_server_by_id(server_id)
    if not server:
        raise HTTPException(status_code=404, detail="سرور یافت نشد")
    return server


@router.get("/{server_id}/stats", response_model=ServerStats)
def get_server_stats(
    server_id: int,
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    stats = server_service.get_server_stats(server_id)
    if not stats:
        raise HTTPException(status_code=404, detail="سرور یافت نشد")
    return stats


@router.post("/", response_model=ServerResponse, status_code=201)
def create_server(
    server_in: ServerCreate,
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    try:
        return server_service.create_server(server_in)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/{server_id}", response_model=ServerResponse)
def update_server(
    server_id: int,
    server_in: ServerUpdate,
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    try:
        return server_service.update_server(server_id, server_in)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/{server_id}/status", response_model=ServerResponse)
def update_server_status(
    server_id: int,
    status: ServerStatus,
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    server = server_service.update_server_status(server_id, status)
    if not server:
        raise HTTPException(status_code=404, detail="سرور یافت نشد")
    return server


@router.delete("/{server_id}", status_code=204)
def delete_server(
    server_id: int,
    server_service: ServerService = Depends(get_server_service),
    _: dict = Depends(get_current_admin_user),
):
    try:
        server_service.delete_server(server_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
