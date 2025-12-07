# app/services/user_service.py

from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from datetime import datetime, timedelta
from typing import List, Optional
import uuid

from app.models.user import User
from app.models.traffic import UserTraffic, TrafficHistory, UserActivityLog
from app.schemas.user import (
    UserCreate,
    UserUpdate,
    UserResetTraffic,
    UserExtendExpiry,
    UserAddTraffic,
    TrafficStats
)
from app.core.security import get_password_hash


class UserService:
    @staticmethod
    def get_user_by_email(db: Session, email: str) -> Optional[User]:
        return db.query(User).filter(User.email == email).first()

    @staticmethod
    def get_user_by_username(db: Session, username: str) -> Optional[User]:
        return db.query(User).filter(User.username == username).first()

    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
        return db.query(User).filter(User.id == user_id).first()

    @staticmethod
    def get_users(
            db: Session,
            skip: int = 0,
            limit: int = 100,
            is_active: Optional[bool] = None,
            role: Optional[str] = None
    ) -> List[User]:
        query = db.query(User)

        if is_active is not None:
            query = query.filter(User.is_active == is_active)

        if role:
            query = query.filter(User.role == role)

        return query.offset(skip).limit(limit).all()

    @staticmethod
    def create_user(db: Session, user_create: UserCreate) -> User:
        # Check if email already exists
        if UserService.get_user_by_email(db, user_create.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        # Check if username already exists
        if UserService.get_user_by_username(db, user_create.username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken"
            )

        # Create user
        db_user = User(
            email=user_create.email,
            username=user_create.username,
            full_name=user_create.full_name,
            hashed_password=get_password_hash(user_create.password),
            role=user_create.role,
            is_active=user_create.is_active,
            xray_uuid=str(uuid.uuid4()),
            data_limit=user_create.data_limit,
            expire_date=user_create.expire_date,
            max_concurrent_ips=user_create.max_concurrent_ips,
            max_devices=user_create.max_devices,
            note=user_create.note
        )

        db.add(db_user)
        db.commit()
        db.refresh(db_user)

        # Create initial traffic record
        traffic = UserTraffic(
            user_id=db_user.id,
            upload=0,
            download=0,
            total=0,
            reset_count=0
        )
        db.add(traffic)
        db.commit()

        return db_user

    @staticmethod
    def update_user(db: Session, user_id: int, user_update: UserUpdate) -> User:
        user = UserService.get_user_by_id(db, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        update_data = user_update.model_dump(exclude_unset=True)

        # Check email uniqueness if being updated
        if "email" in update_data and update_data["email"] != user.email:
            if UserService.get_user_by_email(db, update_data["email"]):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already registered"
                )

        # Check username uniqueness if being updated
        if "username" in update_data and update_data["username"] != user.username:
            if UserService.get_user_by_username(db, update_data["username"]):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username already taken"
                )

        # Hash password if being updated
        if "password" in update_data:
            update_data["hashed_password"] = get_password_hash(update_data["password"])
            del update_data["password"]

        # Update user fields
        for field, value in update_data.items():
            setattr(user, field, value)

        user.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(user)

        return user

    @staticmethod
    def delete_user(db: Session, user_id: int) -> bool:
        user = UserService.get_user_by_id(db, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        db.delete(user)
        db.commit()
        return True

    @staticmethod
    def reset_user_traffic(db: Session, request: UserResetTraffic) -> User:
        user = db.query(User).filter(User.id == request.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        traffic = db.query(UserTraffic).filter(UserTraffic.user_id == request.user_id).first()

        # Handle NULL values from DB
        upload = traffic.upload if traffic and traffic.upload is not None else 0
        download = traffic.download if traffic and traffic.download is not None else 0

        if request.save_to_history and (upload > 0 or download > 0):
            history = TrafficHistory(
                user_id=request.user_id,
                upload=upload,
                download=download,
                total=upload + download,
                reset_at=datetime.utcnow()
            )
            db.add(history)

        if traffic:
            traffic.upload = 0
            traffic.download = 0
            traffic.total = 0
            traffic.reset_count += 1
            traffic.last_reset_at = datetime.utcnow()

        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def extend_user_expiry(db: Session, request: UserExtendExpiry) -> User:
        user = db.query(User).filter(User.id == request.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        if user.expire_date:
            # If already has expiry date, extend from that date
            if user.expire_date > datetime.utcnow():
                user.expire_date = user.expire_date + timedelta(days=request.days)
            else:
                # If expired, extend from now
                user.expire_date = datetime.utcnow() + timedelta(days=request.days)
        else:
            # If no expiry date, set from now
            user.expire_date = datetime.utcnow() + timedelta(days=request.days)

        user.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def add_user_traffic(db: Session, request: UserAddTraffic) -> User:
        user = db.query(User).filter(User.id == request.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Convert GB to bytes (1 GB = 1024^3 bytes)
        bytes_to_add = int(request.gigabytes * (1024 ** 3))

        if user.data_limit:
            user.data_limit += bytes_to_add
        else:
            user.data_limit = bytes_to_add

        user.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def get_user_traffic_stats(db: Session, user_id: int) -> TrafficStats:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        traffic = db.query(UserTraffic).filter(UserTraffic.user_id == user_id).first()

        # Handle NULL values
        upload = traffic.upload if traffic and traffic.upload is not None else 0
        download = traffic.download if traffic and traffic.download is not None else 0
        total = upload + download

        # Calculate usage percentage
        usage_percent = 0.0
        if user.data_limit and user.data_limit > 0:
            usage_percent = (total / user.data_limit) * 100

        # Check if expired
        is_expired = False
        if user.expire_date:
            is_expired = user.expire_date < datetime.utcnow()

        # Check if quota exceeded
        is_quota_exceeded = False
        if user.data_limit and user.data_limit > 0:
            is_quota_exceeded = total >= user.data_limit

        return TrafficStats(
            user_id=user.id,
            username=user.username,
            current_upload=upload,
            current_download=download,
            current_total=total,
            data_limit=user.data_limit,
            usage_percent=round(usage_percent, 2),
            reset_count=traffic.reset_count if traffic else 0,
            last_reset_at=traffic.last_reset_at if traffic else None,
            expire_date=user.expire_date,
            is_expired=is_expired,
            is_quota_exceeded=is_quota_exceeded
        )

    @staticmethod
    def get_all_traffic_stats(db: Session, skip: int = 0, limit: int = 100) -> List[TrafficStats]:
        users = db.query(User).offset(skip).limit(limit).all()
        stats = []

        for user in users:
            try:
                stat = UserService.get_user_traffic_stats(db, user.id)
                stats.append(stat)
            except:
                continue

        return stats

    @staticmethod
    def get_user_activity_logs(db: Session, user_id: int, limit: int = 50) -> List[UserActivityLog]:
        """
        Get activity logs for a specific user

        Args:
            db: Database session
            user_id: User ID
            limit: Maximum number of logs to return

        Returns:
            List of activity logs
        """
        # Check if user exists
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Get activity logs ordered by creation date (newest first)
        logs = db.query(UserActivityLog).filter(
            UserActivityLog.user_id == user_id
        ).order_by(
            UserActivityLog.created_at.desc()
        ).limit(limit).all()

        return logs
