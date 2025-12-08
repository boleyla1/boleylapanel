# app/schemas/server.py

from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from app.models.server import ServerType, ServerStatus


class ServerBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="نام سرور")
    address: str = Field(..., min_length=1, max_length=255, description="آدرس IP یا دامنه سرور")
    port: int = Field(..., ge=1, le=65535, description="پورت سرور")
    server_type: ServerType = Field(default=ServerType.XRAY, description="نوع سرور")
    is_active: bool = Field(default=True, description="وضعیت فعال/غیرفعال")

    api_port: Optional[int] = Field(None, description="پورت API")
    api_path: Optional[str] = Field(None, max_length=255, description="مسیر API")

    username: Optional[str] = Field(None, max_length=100, description="نام کاربری SSH")
    password: Optional[str] = Field(None, max_length=255, description="رمز عبور SSH")
    ssh_port: int = Field(default=22, ge=1, le=65535, description="پورت SSH")

    max_users: int = Field(default=0, ge=0, description="حداکثر تعداد کاربران")
    max_traffic: int = Field(default=0, ge=0, description="حداکثر ترافیک")

    description: Optional[str] = Field(None, description="توضیحات سرور")
    tags: Optional[str] = Field(None, max_length=500, description="تگ‌ها")

    @field_validator('api_port')
    @classmethod
    def validate_api_port(cls, v):
        if v is not None and v < 1:
            raise ValueError('api_port باید بیشتر از 0 باشد')
        return v


class ServerCreate(ServerBase):
    pass


class ServerUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    address: Optional[str] = Field(None, min_length=1, max_length=255)
    port: Optional[int] = Field(None, ge=1, le=65535)
    server_type: Optional[ServerType] = None
    is_active: Optional[bool] = None
    status: Optional[ServerStatus] = None

    api_port: Optional[int] = None
    api_path: Optional[str] = Field(None, max_length=255)

    username: Optional[str] = Field(None, max_length=100)
    password: Optional[str] = Field(None, max_length=255)
    ssh_port: Optional[int] = Field(None, ge=1, le=65535)

    max_users: Optional[int] = Field(None, ge=0)
    max_traffic: Optional[int] = Field(None, ge=0)

    description: Optional[str] = None
    tags: Optional[str] = Field(None, max_length=500)

    @field_validator('api_port')
    @classmethod
    def validate_api_port(cls, v):
        if v is not None and v < 1:
            raise ValueError('api_port باید بیشتر از 0 باشد')
        return v


class ServerResponse(ServerBase):
    id: int
    status: ServerStatus
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ServerOut(BaseModel):
    id: int
    name: str
    address: str
    port: int
    server_type: ServerType
    status: ServerStatus
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ServerStats(BaseModel):
    server_id: int
    server_name: str
    total_users: int = 0
    active_users: int = 0
    total_traffic: int = 0
    status: ServerStatus

    class Config:
        from_attributes = True
