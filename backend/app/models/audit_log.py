"""
Audit log model for tracking user actions
"""

from sqlalchemy import Column, String, Text, Integer, ForeignKey
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class AuditLog(BaseModel):
    """
    Audit log model for tracking user activities.

    Fields:
        - user_id: Foreign key to users table
        - action: Action performed (login/logout/create/update/delete)
        - resource: Resource affected (user/server/config)
        - resource_id: ID of affected resource
        - details: Additional details (JSON string)
        - ip_address: User's IP address

    Relationships:
        - user: Related user object
    """

    __tablename__ = "audit_logs"

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    action = Column(String(50), nullable=False, index=True)
    resource = Column(String(50), nullable=False, index=True)
    resource_id = Column(Integer, nullable=True)
    details = Column(Text, nullable=True)
    ip_address = Column(String(45), nullable=True)  # IPv6 support

    # Relationships
    user = relationship("User", back_populates="audit_logs")

    def __repr__(self):
        return f"<AuditLog(id={self.id}, user_id={self.user_id}, action='{self.action}', resource='{self.resource}')>"
