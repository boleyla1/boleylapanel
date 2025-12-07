# app/services/traffic_service.py

from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, timedelta

from app.models.user import User
from app.models.traffic import UserTraffic, TrafficHistory


class TrafficService:
    """Service for traffic monitoring and history"""

    @staticmethod
    def record_traffic_snapshot(db: Session, user_id: int) -> TrafficHistory:
        """Record current traffic as historical snapshot"""
        traffic = db.query(UserTraffic).filter(
            UserTraffic.user_id == user_id
        ).first()

        if not traffic:
            raise ValueError(f"No traffic data for user {user_id}")

        snapshot = TrafficHistory(
            user_id=user_id,
            upload=traffic.upload,
            download=traffic.download,
            total=traffic.total,
            recorded_at=datetime.utcnow()
        )
        db.add(snapshot)
        db.commit()
        db.refresh(snapshot)
        return snapshot

    @staticmethod
    def get_traffic_history(
            db: Session,
            user_id: int,
            days: int = 30
    ) -> List[TrafficHistory]:
        """Get traffic history for specified days"""
        cutoff_date = datetime.utcnow() - timedelta(days=days)

        return db.query(TrafficHistory).filter(
            TrafficHistory.user_id == user_id,
            TrafficHistory.recorded_at >= cutoff_date
        ).order_by(TrafficHistory.recorded_at.desc()).all()

    @staticmethod
    def get_top_users_by_traffic(
            db: Session,
            limit: int = 10
    ) -> List[dict]:
        """Get top users by total traffic usage"""
        results = db.query(
            User.id,
            User.username,
            UserTraffic.total
        ).join(UserTraffic).order_by(
            UserTraffic.total.desc()
        ).limit(limit).all()

        return [
            {
                "user_id": r.id,
                "username": r.username,
                "total_traffic": r.total
            }
            for r in results
        ]

    @staticmethod
    def get_total_traffic_stats(db: Session) -> dict:
        """Get system-wide traffic statistics"""
        stats = db.query(
            func.sum(UserTraffic.upload).label("total_upload"),
            func.sum(UserTraffic.download).label("total_download"),
            func.sum(UserTraffic.total).label("total_traffic"),
            func.count(UserTraffic.id).label("user_count")
        ).first()

        return {
            "total_upload": stats.total_upload or 0,
            "total_download": stats.total_download or 0,
            "total_traffic": stats.total_traffic or 0,
            "active_users": stats.user_count or 0
        }
