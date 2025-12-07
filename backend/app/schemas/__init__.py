"""
Pydantic schemas for API request/response validation
"""
from app.schemas.user import (
    UserBase,
    UserCreate,
    UserUpdate,
    UserInDB,
    UserResponse,
    Token,
    TokenData,
)
from app.schemas.server import (
    ServerBase,
    ServerCreate,
    ServerUpdate,
    ServerInDB,
    ServerResponse,
)
from app.schemas.config import (
    ConfigBase,
    ConfigCreate,
    ConfigUpdate,
    ConfigInDB,
    ConfigResponse,
)

__all__ = [
    # User
    "UserBase",
    "UserCreate",
    "UserUpdate",
    "UserInDB",
    "UserResponse",
    "Token",
    "TokenData",
    # Server
    "ServerBase",
    "ServerCreate",
    "ServerUpdate",
    "ServerInDB",
    "ServerResponse",
    # Config
    "ConfigBase",
    "ConfigCreate",
    "ConfigUpdate",
    "ConfigInDB",
    "ConfigResponse",
]
