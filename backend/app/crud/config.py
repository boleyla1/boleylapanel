from sqlalchemy.orm import Session
from app.models.config import Config
from app.schemas import ConfigCreate, ConfigUpdate


class CRUDConfig:

    def get(self, db: Session, config_id: int):
        return db.query(Config).filter(Config.id == config_id).first()

    def get_multi(self, db: Session, skip: int = 0, limit: int = 100):
        return db.query(Config).offset(skip).limit(limit).all()

    def get_user_configs(self, db: Session, user_id: int):
        return db.query(Config).filter(Config.user_id == user_id).all()

    def create(self, db: Session, data: ConfigCreate):
        db_obj = Config(
            name=data.name,
            user_id=data.user_id,
            server_id=data.server_id,
            protocol=data.protocol,
            config_data=data.config_data,
            traffic_limit_gb=data.traffic_limit_gb,
            traffic_used_gb=data.traffic_used_gb,
            expiry_date=data.expiry_date,
            is_active=data.is_active,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def update(self, db: Session, db_obj: Config, data: ConfigUpdate):
        if data.name is not None:
            db_obj.name = data.name

        if data.server_id is not None:
            db_obj.server_id = data.server_id

        if data.protocol is not None:
            db_obj.protocol = data.protocol

        if data.config_data is not None:
            db_obj.config_data = data.config_data

        if data.traffic_limit_gb is not None:
            db_obj.traffic_limit_gb = data.traffic_limit_gb

        if data.traffic_used_gb is not None:
            db_obj.traffic_used_gb = data.traffic_used_gb

        if data.expiry_date is not None:
            db_obj.expiry_date = data.expiry_date

        if data.is_active is not None:
            db_obj.is_active = data.is_active

        db.commit()
        db.refresh(db_obj)
        return db_obj

    def remove(self, db: Session, config_id: int):
        obj = self.get(db, config_id)
        if obj:
            db.delete(obj)
            db.commit()
        return obj


config = CRUDConfig()
