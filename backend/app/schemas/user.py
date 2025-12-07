# app/schemas/user.py

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    full_name: Optional[str] = Field(None, max_length=100)
    is_active: bool = True


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)
    role: str = Field(default="user", pattern="^(admin|user|viewer)$")
    data_limit: Optional[int] = Field(None, ge=0, description="Traffic limit in bytes")
    expire_date: Optional[datetime] = None
    max_concurrent_ips: Optional[int] = Field(None, ge=0)
    max_devices: Optional[int] = Field(None, ge=0)
    note: Optional[str] = None


class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    full_name: Optional[str] = Field(None, max_length=100)
    password: Optional[str] = Field(None, min_length=8)
    is_active: Optional[bool] = None
    role: Optional[str] = Field(None, pattern="^(admin|user|viewer)$")
    data_limit: Optional[int] = Field(None, ge=0)
    expire_date: Optional[datetime] = None
    max_concurrent_ips: Optional[int] = Field(None, ge=0)
    max_devices: Optional[int] = Field(None, ge=0)
    note: Optional[str] = None


class UserResponse(UserBase):
    id: int
    role: str
    xray_uuid: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class TrafficInfo(BaseModel):
    upload: int = 0
    download: int = 0
    total: int = 0
    reset_count: int = 0
    last_reset_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserExtended(UserResponse):
    data_limit: Optional[int] = None
    expire_date: Optional[datetime] = None
    max_concurrent_ips: Optional[int] = None
    max_devices: Optional[int] = None
    note: Optional[str] = None
    last_activity_at: Optional[datetime] = None
    traffic: Optional[TrafficInfo] = None

    class Config:
        from_attributes = True


class UserResetTraffic(BaseModel):
    user_id: int = Field(..., gt=0)
    save_to_history: bool = Field(default=True, description="Save current traffic to history")


class UserExtendExpiry(BaseModel):
    user_id: int = Field(..., gt=0)
    days: int = Field(..., gt=0, description="Number of days to extend")


class UserAddTraffic(BaseModel):
    user_id: int = Field(..., gt=0)
    gigabytes: float = Field(..., gt=0, description="Traffic to add in GB")


class TrafficStats(BaseModel):
    user_id: int
    username: str
    current_upload: int
    current_download: int
    current_total: int
    data_limit: Optional[int]
    usage_percent: float
    reset_count: int
    last_reset_at: Optional[datetime]
    expire_date: Optional[datetime]
    is_expired: bool
    is_quota_exceeded: bool

    class Config:
        from_attributes = True


class UserOut(UserResponse):
    pass


class UserInDB(UserBase):
    id: int
    hashed_password: str
    role: str

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: int | None = None
