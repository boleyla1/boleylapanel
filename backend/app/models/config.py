from sqlalchemy import Column, Integer, String, Boolean, DateTime, JSON, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base import Base

class Config(Base):
    __tablename__ = "configs"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    server_id = Column(Integer, ForeignKey("servers.id"), nullable=False)
    protocol = Column(String(50), nullable=False)
    config_data = Column(JSON)
    traffic_limit_gb = Column(Integer, default=0)
    traffic_used_gb = Column(Integer, default=0)
    expiry_date = Column(DateTime)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime)
    updated_at = Column(DateTime)
    user = relationship("User", back_populates="configs")
    server = relationship("Server", back_populates="configs")
