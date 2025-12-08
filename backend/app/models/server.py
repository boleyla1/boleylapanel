# app/models/server.py

from sqlalchemy import Column, Integer, String, Boolean, Enum as SQLEnum, Text, DateTime, func, BigInteger, Float
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum


class ServerType(str, enum.Enum):
    XRAY = "xray"
    V2RAY = "v2ray"
    SINGBOX = "singbox"


class ServerStatus(str, enum.Enum):
    ONLINE = "online"
    OFFLINE = "offline"
    MAINTENANCE = "maintenance"
    ERROR = "error"


class Server(Base):
    __tablename__ = "servers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False, index=True)
    address = Column(String(255), unique=True, nullable=False)
    port = Column(Integer, nullable=False)
    server_type = Column(SQLEnum(ServerType), nullable=False, default=ServerType.XRAY)
    status = Column(SQLEnum(ServerStatus), nullable=False, default=ServerStatus.OFFLINE)
    is_active = Column(Boolean, default=True, nullable=False)
    memory_usage = Column(Float, default=0.0)
    disk_usage = Column(Float, default=0.0)
    uptime = Column(BigInteger, default=0)
    api_port = Column(Integer, nullable=True)
    api_path = Column(String(255), nullable=True)

    username = Column(String(100), nullable=True)
    password = Column(String(255), nullable=True)
    ssh_port = Column(Integer, default=22)
    cpu_usage = Column(Float, default=0.0)
    max_users = Column(BigInteger, default=0)  # 0 = unlimited
    max_traffic = Column(BigInteger, default=0)  # 0 = unlimited (in GB)
    total_users = Column(Integer, default=0)
    active_users = Column(Integer, default=0)
    total_traffic = Column(BigInteger, default=0)
    description = Column(Text, nullable=True)
    tags = Column(String(500), nullable=True)  # comma-separated tags

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    configs = relationship("Config", back_populates="server", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Server(id={self.id}, name='{self.name}', status='{self.status}')>"
