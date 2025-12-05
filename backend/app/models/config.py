"""
Config database model
"""
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.db.base import BaseModel, utcnow


class Config(BaseModel):
    """VPN Configuration model"""
    __tablename__ = "configs"

    name = Column(String(100), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    server_id = Column(Integer, ForeignKey("servers.id", ondelete="CASCADE"), nullable=False)

    config_data = Column(Text, nullable=False)
    protocol = Column(String(50), nullable=False, default="vmess")

    traffic_limit_gb = Column(Float, nullable=True)
    traffic_used_gb = Column(Float, default=0.0, nullable=False)

    expiry_date = Column(DateTime, nullable=True)

    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    user = relationship("User", back_populates="configs")
    server = relationship("Server", back_populates="configs")

    def is_expired(self) -> bool:
        """چک کردن انقضای کانفیگ (timezone-safe)"""
        if self.expiry_date is None:
            return False
        return datetime.now(timezone.utc).replace(tzinfo=None) > self.expiry_date

    def days_until_expiry(self) -> int | None:
        """تعداد روز تا انقضا"""
        if self.expiry_date is None:
            return None
        delta = self.expiry_date - datetime.now(timezone.utc).replace(tzinfo=None)
        return max(0, delta.days)

    def __repr__(self):
        return f"<Config(id={self.id}, name='{self.name}', user_id={self.user_id})>"
