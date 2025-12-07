from sqlalchemy.orm import Session
from app.models.server import Server
from app.schemas import ServerCreate, ServerUpdate


class CRUDServer:

    def get(self, db: Session, server_id: int):
        return db.query(Server).filter(Server.id == server_id).first()

    def get_multi(self, db: Session, skip: int = 0, limit: int = 100):
        return db.query(Server).offset(skip).limit(limit).all()

    def create(self, db: Session, data: ServerCreate):
        db_obj = Server(
            name=data.name,
            address=data.address,
            port=data.port,
            is_active=data.is_active,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def update(self, db: Session, db_obj: Server, data: ServerUpdate):
        if data.name is not None:
            db_obj.name = data.name

        if data.address is not None:
            db_obj.address = data.address

        if data.port is not None:
            db_obj.port = data.port

        if data.is_active is not None:
            db_obj.is_active = data.is_active

        db.commit()
        db.refresh(db_obj)
        return db_obj

    def remove(self, db: Session, server_id: int):
        obj = self.get(db, server_id)
        if obj:
            db.delete(obj)
            db.commit()
        return obj


server = CRUDServer()
