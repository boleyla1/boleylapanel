# app/api/v1/api.py

from fastapi import APIRouter
from app.api.v1.endpoints import auth, users, servers, configs, traffic

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(servers.router, prefix="/servers", tags=["Servers"])
api_router.include_router(configs.router, prefix="/configs", tags=["Configs"])
api_router.include_router(traffic.router, prefix="/traffic", tags=["Traffic"])
