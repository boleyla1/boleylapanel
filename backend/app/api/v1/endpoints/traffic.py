# app/api/v1/endpoints/traffic.py

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List

from app.api.deps import get_db, get_current_admin_user
from app.models.user import User
from app.schemas.traffic import TrafficHistoryResponse, UserActivityLogResponse
from app.services.traffic_service import TrafficService
from app.services.user_service import UserService

router = APIRouter()


@router.get("/history/{user_id}", response_model=List[TrafficHistoryResponse])
def get_user_traffic_history(
    user_id: int,
    days: int = Query(30, ge=1, le=365),
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Get traffic history for a user (Admin only)"""
    history = TrafficService.get_traffic_history(db, user_id, days)
    return history


@router.post("/snapshot/{user_id}", response_model=TrafficHistoryResponse)
def create_traffic_snapshot(
    user_id: int,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Create a traffic snapshot for a user (Admin only)"""
    try:
        snapshot = TrafficService.record_traffic_snapshot(db, user_id)
        return snapshot
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )


@router.get("/top-users", response_model=List[dict])
def get_top_users_by_traffic(
    limit: int = Query(10, ge=1, le=100),
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Get top users by traffic usage (Admin only)"""
    return TrafficService.get_top_users_by_traffic(db, limit)


@router.get("/stats/system", response_model=dict)
def get_system_traffic_stats(
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Get system-wide traffic statistics (Admin only)"""
    return TrafficService.get_total_traffic_stats(db)


@router.get("/activity/{user_id}", response_model=List[UserActivityLogResponse])
def get_user_activity_logs(
    user_id: int,
    limit: int = Query(50, ge=1, le=500),
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Get activity logs for a user (Admin only)"""
    logs = UserService.get_user_activity_logs(db, user_id, limit)
    return logs
