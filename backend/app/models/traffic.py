# app/models/traffic.py

from sqlalchemy import Column, Integer, String, BigInteger, DateTime, ForeignKey, JSON, text, Computed
from sqlalchemy.orm import relationship
from app.db.base import BaseModel


class UserTraffic(BaseModel):
    """Current traffic usage for each user"""
    __tablename__ = "user_traffic"

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True
    )
    upload = Column(
        BigInteger,
        default=0,
        nullable=False,
        server_default="0",
        comment="Upload bytes"
    )
    download = Column(
        BigInteger,
        default=0,
        nullable=False,
        server_default="0",
        comment="Download bytes"
    )
    total = Column(
        BigInteger,
        nullable=False,
        server_default="0",
        comment="Total bytes (upload + download)"
    )
    reset_count = Column(
        Integer,
        default=0,
        nullable=False,
        server_default="0",
        comment="Number of traffic resets"
    )
    last_reset_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="Last traffic reset timestamp"
    )

    # Relationships
    user = relationship("User", back_populates="traffic")

    def __repr__(self):
        return f"<UserTraffic(user_id={self.user_id}, total={self.total})>"


class TrafficHistory(BaseModel):
    """Historical traffic data (for reset strategies)"""
    __tablename__ = "traffic_history"

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    upload = Column(BigInteger, nullable=False)
    download = Column(BigInteger, nullable=False)
    total = Column(BigInteger, nullable=False)
    recorded_at = Column(
        DateTime(timezone=True),
        server_default=text("now()"),
        nullable=False,
        comment="Snapshot timestamp"
    )

    # Relationships
    user = relationship("User", back_populates="traffic_history")

    def __repr__(self):
        return f"<TrafficHistory(user_id={self.user_id}, total={self.total}, recorded_at={self.recorded_at})>"


class UserActivityLog(BaseModel):
    """User activity tracking"""
    __tablename__ = "user_activity_logs"

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    action = Column(
        String(50),
        nullable=False,
        comment="Action type (login, logout, config_change, etc.)"
    )
    description = Column(
        String(500),
        nullable=True,
        comment="Action description"
    )
    ip_address = Column(
        String(45),
        nullable=True,
        comment="IPv4/IPv6"
    )
    user_agent = Column(
        String(255),
        nullable=True
    )

    # Relationships
    user = relationship("User", back_populates="activity_logs")

    def __repr__(self):
        return f"<UserActivityLog(user_id={self.user_id}, action='{self.action}')>"
