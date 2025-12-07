

from fastapi import HTTPException
from sqlalchemy.orm import Session
from typing import Type, List

from app.crud.base import CRUDBase
from app.models.config import Config
from app.schemas import ConfigCreate, ConfigUpdate


class CRUDConfig(CRUDBase[Config, ConfigCreate, ConfigUpdate]):
    def __init__(self, model: Type[Config]):
        super().__init__(model)

    def get_user_configs(self, db: Session, user_id: int) -> List[Config]:
        return db.query(self.model).filter(self.model.user_id == user_id).all()


config = CRUDConfig(Config)
