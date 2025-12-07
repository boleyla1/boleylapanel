"""
User model for authentication and authorization
"""

from sqlalchemy import Column, String, Boolean, Enum as SQLEnum
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

    Relationships:
        - configs: Node/config objects owned by user
        - audit_logs: Activity logs (dynamic for performance)
    """

    __tablename__ = "users"

    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)

    full_name = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    xray_uuid = Column(String(36), index=True, unique=True, nullable=True)
    role = Column(
        SQLEnum(UserRole),
        default=UserRole.USER,
        nullable=False
    )

    # Relationships
    configs = relationship("Config", back_populates="user")
    audit_logs = relationship("AuditLog", back_populates="user", lazy="dynamic")

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
