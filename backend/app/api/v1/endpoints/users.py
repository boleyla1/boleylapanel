# app/api/v1/endpoints/users.py

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from app.api.deps import get_db, get_current_user, get_current_admin_user
from app.models.user import User, UserRole
from app.schemas.user import (
    UserCreate,
    UserUpdate,
    UserResponse,
    UserExtended,
    UserResetTraffic,
    UserExtendExpiry,
    UserAddTraffic
)
from app.schemas.traffic import TrafficStatsResponse
from app.services.user_service import UserService

router = APIRouter()


@router.get("/me", response_model=UserExtended)
def get_current_user_info(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user's detailed information"""
    return UserService.get_user(db, current_user.id)


@router.get("/", response_model=List[UserExtended])
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    role: Optional[str] = Query(None, regex="^(admin|user|viewer)$"),
    is_active: Optional[bool] = None,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """List all users (Admin only)"""
    role_enum = UserRole(role) if role else None
    users = UserService.get_users(
        db,
        skip=skip,
        limit=limit,
        role=role_enum,
        is_active=is_active
    )
    return users


@router.get("/{user_id}", response_model=UserExtended)
def get_user(
    user_id: int,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Get user by ID (Admin only)"""
    user = UserService.get_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return user


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    user_in: UserCreate,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Create new user (Admin only)"""
    # Check username uniqueness
    if UserService.get_user_by_username(db, user_in.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )

    # Check email uniqueness
    if UserService.get_user_by_email(db, user_in.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    user = UserService.create_user(db, user_in)
    return user


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: int,
    user_in: UserUpdate,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Update user (Admin only)"""
    user = UserService.get_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    # Check username uniqueness if changing
    if user_in.username and user_in.username != user.username:
        if UserService.get_user_by_username(db, user_in.username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken"
            )

    # Check email uniqueness if changing
    if user_in.email and user_in.email != user.email:
        if UserService.get_user_by_email(db, user_in.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already taken"
            )

    updated_user = UserService.update_user(db, user, user_in)
    return updated_user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Deactivate user (Admin only)"""
    user = UserService.get_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    UserService.delete_user(db, user)
    return None


# ===== Traffic Management Endpoints =====

@router.post("/traffic/reset", response_model=UserResponse)
def reset_user_traffic(
    request: UserResetTraffic,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Reset user's traffic usage (Admin only)"""
    try:
        user = UserService.reset_user_traffic(db, request)
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )


@router.post("/expiry/extend", response_model=UserResponse)
def extend_user_expiry(
    request: UserExtendExpiry,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Extend user's expiration date (Admin only)"""
    try:
        user = UserService.extend_user_expiry(db, request)
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )


@router.post("/traffic/add", response_model=UserResponse)
def add_user_traffic(
    request: UserAddTraffic,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Add traffic quota to user (Admin only)"""
    try:
        user = UserService.add_user_traffic(db, request)
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )


@router.get("/{user_id}/traffic/stats", response_model=TrafficStatsResponse)
def get_user_traffic_stats(
    user_id: int,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Get detailed traffic statistics for a user (Admin only)"""
    try:
        stats = UserService.get_user_traffic_stats(db, user_id)
        return stats
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
