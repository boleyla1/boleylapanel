from typing import List
from sqlalchemy.orm import Session
from app.crud.base import CRUDBase
from app.models.server import Server, ServerStatus
from app.schemas.server import ServerCreate, ServerUpdate


class CRUDServer(CRUDBase[Server, ServerCreate, ServerUpdate]):

    def get_active_servers(
            self, db: Session, *, skip: int = 0, limit: int = 100
    ) -> List[Server]:
        """دریافت سرورهای فعال"""
        return (
            db.query(Server)
            .filter(Server.is_active.is_(True))
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_servers_by_status(
            self, db: Session, *, status: str, skip: int = 0, limit: int = 100
    ) -> List[Server]:
        """دریافت سرورها بر اساس وضعیت"""
        try:
            status_enum = ServerStatus(status)
        except ValueError:
            return []

        return (
            db.query(Server)
            .filter(Server.status == status_enum)
            .offset(skip)
            .limit(limit)
            .all()
        )


server = CRUDServer(Server)
