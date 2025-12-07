# app/schemas/__init__.py

from app.schemas.user import (
    UserBase,
    UserCreate,
    UserUpdate,
    UserResponse,
    UserExtended,
    UserOut,
    UserInDB,
    Token,
    TokenData,
    UserResetTraffic,
    UserExtendExpiry,
    UserAddTraffic,
    TrafficInfo,
)
from app.schemas.traffic import (
    TrafficHistoryResponse,
    UserActivityLogResponse,
    TrafficStatsResponse,
)
from app.schemas.server import (
    ServerBase,
    ServerCreate,
    ServerUpdate,
    ServerResponse,
)
from app.schemas.config import (
    ConfigBase,
    ConfigCreate,
    ConfigUpdate,
    ConfigResponse,
)

__all__ = [
    # User schemas
    "UserBase",
    "UserCreate",
    "UserUpdate",
    "UserResponse",
    "UserExtended",
    "UserOut",
    "UserInDB",
    "Token",
    "TokenData",
    "UserResetTraffic",
    "UserExtendExpiry",
    "UserAddTraffic",
    "TrafficInfo",

    # Traffic schemas
    "TrafficHistoryResponse",
    "UserActivityLogResponse",
    "TrafficStatsResponse",

    # Server schemas
    "ServerBase",
    "ServerCreate",
    "ServerUpdate",
    "ServerResponse",

    # Config schemas
    "ConfigBase",
    "ConfigCreate",
    "ConfigUpdate",
    "ConfigResponse",
]
