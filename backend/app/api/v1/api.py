"""
API v1 router aggregator
"""
from fastapi import APIRouter

from app.api.v1.endpoints import auth, users, servers, configs

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(servers.router, prefix="/servers", tags=["servers"])
api_router.include_router(configs.router, prefix="/configs", tags=["configs"])
api_router.include_router(configs.router, prefix="/xray", tags=["Xray"])