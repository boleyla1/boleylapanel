from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ConfigBase(BaseModel):
    name: str
    user_id: int
    server_id: int
    protocol: str
    config_data: Optional[dict] = None
    traffic_limit_gb: Optional[int] = None
    traffic_used_gb: Optional[int] = None
    expiry_date: Optional[datetime] = None
    is_active: Optional[bool] = True


class ConfigCreate(ConfigBase):
    pass


class ConfigUpdate(BaseModel):
    name: Optional[str] = None
    server_id: Optional[int] = None
    protocol: Optional[str] = None
    config_data: Optional[dict] = None
    traffic_limit_gb: Optional[int] = None
    traffic_used_gb: Optional[int] = None
    expiry_date: Optional[datetime] = None
    is_active: Optional[bool] = None


class ConfigResponse(ConfigBase):
    id: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ConfigOut(ConfigBase):
    id: int

    class Config:
        from_attributes = True


class ConfigInDB(ConfigBase):
    id: int

    class Config:
        from_attributes = True
