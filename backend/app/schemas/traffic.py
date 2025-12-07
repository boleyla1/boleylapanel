# app/schemas/traffic.py

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class TrafficHistoryResponse(BaseModel):
    """Traffic history snapshot"""
    id: int
    user_id: int
    upload: int
    download: int
    total: int
    recorded_at: datetime

    class Config:
        from_attributes = True


class UserActivityLogResponse(BaseModel):
    """User activity log entry"""
    id: int
    user_id: int
    action: str
    description: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class TrafficStatsResponse(BaseModel):
    """Traffic statistics for a user"""
    user_id: int
    username: str
    current_upload: int
    current_download: int
    current_total: int
    data_limit: Optional[int] = None
    usage_percent: Optional[float] = None
    reset_count: int
    last_reset_at: Optional[datetime] = None
    expire_date: Optional[datetime] = None
    is_expired: bool
    is_quota_exceeded: bool
