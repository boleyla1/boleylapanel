from fastapi import APIRouter, Depends
from app.services.xray_service import XrayService
from app.core.database import get_xray_service

router = APIRouter()


@router.post("/sync-xray-config")
def sync_xray_config(xray_service: XrayService = Depends(get_xray_service)):
    return xray_service.sync_config()
