"""
User model for authentication and authorization
"""

from sqlalchemy import Column, String, Boolean, Enum as SQLEnum, Integer, BigInteger, DateTime, Text
from sqlalchemy.orm import relationship
import enum

from app.db.base import BaseModel


class UserRole(str, enum.Enum):
    """User role enumeration"""
    ADMIN = "admin"
    USER = "user"
    VIEWER = "viewer"


class User(BaseModel):
    """
    User model for system authentication.

    Fields:
        - username: Unique username
        - email: Unique email
        - hashed_password: Bcrypt hashed password
        - full_name: Optional full name
        - is_active: Account status
        - role: User role (admin/user/viewer)
        - xray_uuid: UUID for Xray integration

        # Traffic Management Fields (Option B)
        - data_limit: Maximum traffic in bytes (NULL = unlimited)
        - expire_date: Account expiration date
        - max_concurrent_ips: Max simultaneous IPs
        - max_devices: Max device count
        - note: Admin notes
        - last_activity_at: Last connection timestamp

    Relationships:
        - configs: Node/config objects owned by user
        - audit_logs: Activity logs (dynamic for performance)
        - traffic: Current traffic usage (1-to-1)
        - traffic_history: Historical traffic snapshots (1-to-many)
        - activity_logs: User activity logs (1-to-many)
    """

    __tablename__ = "users"

    # Authentication fields
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)

    # Xray integration
    xray_uuid = Column(String(36), index=True, unique=True, nullable=True)

    # Role
    role = Column(
        SQLEnum(UserRole),
        default=UserRole.USER,
        nullable=False
    )

    # ===== Traffic Management Fields (Option B) =====
    data_limit = Column(
        BigInteger,
        nullable=True,
        comment="Max traffic in bytes (NULL = unlimited)"
    )
    expire_date = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="Account expiration date"
    )
    max_concurrent_ips = Column(
        Integer,
        default=0,
        nullable=True,
        comment="Max simultaneous IPs (0 = unlimited)"
    )
    max_devices = Column(
        Integer,
        default=1,
        nullable=True,
        comment="Max device count"
    )
    note = Column(
        Text,
        nullable=True,
        comment="Admin notes"
    )
    last_activity_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="Last connection timestamp"
    )

    # ===== Relationships =====
    configs = relationship("Config", back_populates="user")
    audit_logs = relationship("AuditLog", back_populates="user", lazy="dynamic")

    # Traffic relationships
    traffic = relationship(
        "UserTraffic",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan"
    )
    traffic_history = relationship(
        "TrafficHistory",
        back_populates="user",
        cascade="all, delete-orphan"
    )
    activity_logs = relationship(
        "UserActivityLog",
        back_populates="user",
        cascade="all, delete-orphan"
    )

    # ---- Role helper properties ----
    @property
    def is_admin(self) -> bool:
        """Check if user has admin role."""
        return self.role == UserRole.ADMIN

    @property
    def is_user(self) -> bool:
        """Check if user has normal user role."""
        return self.role == UserRole.USER

    @property
    def is_viewer(self) -> bool:
        """Check if user has viewer role."""
        return self.role == UserRole.VIEWER

    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', role='{self.role.value}')>"
