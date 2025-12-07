"""
Server model for VPN/Proxy server management
"""

from sqlalchemy import Column, String, Integer, Boolean, Text, Enum as SQLEnum
import enum

from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class ServerType(str, enum.Enum):
    """Server type enumeration"""
    XRAY = "xray"
    V2RAY = "v2ray"
    SHADOWSOCKS = "shadowsocks"
    TROJAN = "trojan"


class ServerStatus(str, enum.Enum):
    """Server status enumeration"""
    ACTIVE = "active"
    INACTIVE = "inactive"
    MAINTENANCE = "maintenance"
    ERROR = "error"


class Server(BaseModel):
    """
    Server model for managing VPN/Proxy servers.

    Fields:
        - name: Server display name
        - host: Server IP or domain
        - port: Server port
        - type: Server type (xray/v2ray/shadowsocks/trojan)
        - status: Server status
        - max_users: Maximum allowed users
        - current_users: Current active users
        - api_url: Server API endpoint
        - api_key: Server API authentication key
        - description: Server description
    """

    __tablename__ = "servers"

    name = Column(String(100), nullable=False, index=True)
    host = Column(String(255), nullable=False)
    port = Column(Integer, nullable=False)
    type = Column(SQLEnum(ServerType), nullable=False)
    status = Column(
        SQLEnum(ServerStatus),
        default=ServerStatus.INACTIVE,
        nullable=False
    )
    max_users = Column(Integer, default=100, nullable=False)
    current_users = Column(Integer, default=0, nullable=False)
    api_url = Column(String(255), nullable=True)
    api_key = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    configs = relationship("Config", back_populates="server", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Server(id={self.id}, name='{self.name}', type='{self.type.value}', status='{self.status.value}')>"
