"""
Config model for system configuration key-value pairs
"""

from sqlalchemy import Column, String, Text, Boolean

from app.db.base import BaseModel


class Config(BaseModel):
    """
    Configuration model for storing system settings.

    Fields:
        - key: Unique configuration key
        - value: Configuration value (stored as text)
        - description: Configuration description
        - is_public: Whether config is accessible to non-admin users

    Examples:
        - key="max_connections", value="1000"
        - key="maintenance_mode", value="false"
        - key="notification_email", value="admin@example.com"
    """

    __tablename__ = "configs"

    key = Column(String(100), unique=True, index=True, nullable=False)
    value = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
    is_public = Column(Boolean, default=False, nullable=False)

    def __repr__(self):
        return f"<Config(id={self.id}, key='{self.key}')>"
