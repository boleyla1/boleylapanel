from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.crud.server import server
from app.models.server import ServerStatus
from app.schemas.server import ServerCreate, ServerUpdate
from typing import List, Optional
from sqlalchemy.exc import (
    IntegrityError,
    OperationalError,
    DatabaseError,
    DataError
)
crud_server = server



class ServerService:
    def __init__(self, db: Session):
        self.db = db

    def create_server(self, server_data: ServerCreate):
        """ایجاد سرور جدید با بررسی تکراری"""

        # ✅ بررسی نام تکراری
        existing_name = self.get_server_by_name(server_data.name)
        if existing_name:
            raise HTTPException(
                status_code=400,
                detail=f"Server with name '{server_data.name}' already exists"
            )

        # ✅ بررسی آدرس تکراری
        existing_address = self.get_server_by_address(server_data.address)
        if existing_address:
            raise HTTPException(
                status_code=400,
                detail=f"Server with address '{server_data.address}' already exists"
            )

        # ✅ Handle کردن خطاهای دیتابیس
        try:
            return crud_server.create(self.db, obj_in=server_data)
        except IntegrityError as e:
            self.db.rollback()
            error_msg = str(e)

            if "Duplicate entry" in error_msg:
                if "'name'" in error_msg:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Server with name '{server_data.name}' already exists"
                    )
                elif "'address'" in error_msg:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Server with address '{server_data.address}' already exists"
                    )

            raise HTTPException(status_code=400, detail="Database integrity error")

    def get_server_by_id(self, server_id: int):
        server = crud_server.get(self.db, obj_id=server_id)
        if not server:
            raise HTTPException(
                status_code=404,
                detail=f"Server with id {server_id} not found"
            )
        return server

    def get_all_servers(self, skip: int = 0, limit: int = 100) -> List:
        return crud_server.get_multi(self.db, skip=skip, limit=limit)

    def get_active_servers(self, skip: int = 0, limit: int = 100) -> List:
        return crud_server.get_active_servers(self.db, skip=skip, limit=limit)

    def get_servers_by_status(self, status: str, skip: int = 0, limit: int = 100) -> List:
        return crud_server.get_servers_by_status(self.db, status=status, skip=skip, limit=limit)

    def update_server(self, server_id: int, server_data: ServerUpdate):
        db_server = crud_server.get(self.db, obj_id=server_id)
        if not db_server:
            raise HTTPException(status_code=404, detail="Server not found")

        # ✅ بررسی تکراری بودن نام
        if server_data.name and server_data.name != db_server.name:
            existing = self.get_server_by_name(server_data.name)
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail=f"Server with name '{server_data.name}' already exists"
                )

        # ✅ بررسی تکراری بودن آدرس
        if server_data.address and server_data.address != db_server.address:
            existing = self.get_server_by_address(server_data.address)
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail=f"Server with address '{server_data.address}' already exists"
                )

        return crud_server.update(self.db, db_obj=db_server, obj_in=server_data)

    def update_server_status(self, server_id: int, new_status: str):
        server = crud_server.get(self.db, obj_id=server_id)
        if not server:
            raise HTTPException(status_code=404, detail="Server not found")

        try:
            status_enum = ServerStatus(new_status)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid status. Must be one of: {', '.join([s.value for s in ServerStatus])}"
            )

        server.status = status_enum
        self.db.commit()
        self.db.refresh(server)
        return server

    def delete_server(self, server_id: int):
        db_server = crud_server.get(self.db, obj_id=server_id)
        if not db_server:
            raise HTTPException(status_code=404, detail="Server not found")
        return crud_server.remove(self.db, obj_id=server_id)

    def get_server_by_name(self, name: str):
        """پیدا کردن سرور با نام"""
        from app.models.server import Server
        return self.db.query(Server).filter(Server.name == name).first()

    def get_server_by_address(self, address: str):
        """پیدا کردن سرور با آدرس"""
        from app.models.server import Server
        return self.db.query(Server).filter(Server.address == address).first()

    def get_server_stats(self, server_id: int):
        server = crud_server.get(self.db, obj_id=server_id)

        if server is None:
            raise HTTPException(
                status_code=404,
                detail=f"Server with id {server_id} not found"
            )

        total_traffic = server.total_traffic or 0
        max_traffic = server.max_traffic or 0
        total_users = server.total_users or 0
        max_users = server.max_users or 0

        traffic_percentage = round((total_traffic / max_traffic * 100), 2) if max_traffic > 0 else 0.0
        users_percentage = round((total_users / max_users * 100), 2) if max_users > 0 else 0.0

        return {
            "server_id": server.id,
            "server_name": server.name,
            "status": server.status.value if hasattr(server.status, "value") else server.status,
            "total_users": total_users,
            "active_users": server.active_users or 0,
            "total_traffic": total_traffic,
            "max_traffic": max_traffic,
            "cpu_usage": server.cpu_usage or 0.0,
            "memory_usage": server.memory_usage or 0.0,
            "disk_usage": server.disk_usage or 0.0,
            "uptime": server.uptime or 0,
            "traffic_percentage": traffic_percentage,
            "users_percentage": users_percentage
        }

