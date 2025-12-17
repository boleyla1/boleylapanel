from pathlib import Path

from fastapi import FastAPI, Depends, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from sqlalchemy.orm import Session

from app.api.v1.api import api_router
from app.db.database import SessionLocal
from app.models import User
from app.config import settings

# ===============================
# Path Configuration
# ===============================

# /app/app/main.py → parents[1] = /app
BASE_DIR = Path(__file__).resolve().parents[1]

FRONTEND_DIR = BASE_DIR / "frontend"
STATIC_DIR = FRONTEND_DIR / "static"
INDEX_FILE = FRONTEND_DIR / "index.html"

# ===============================
# FastAPI App
# ===============================

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ===============================
# CORS
# ===============================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===============================
# API Router
# ===============================

app.include_router(api_router, prefix="/api/v1")

# ===============================
# Static Files & SPA
# ===============================

# Mount static files if exists
if STATIC_DIR.exists():
    app.mount(
        "/static",
        StaticFiles(directory=STATIC_DIR),
        name="static",
    )

# ===============================
# Root & Health
# ===============================

@app.get("/")
async def root():
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "environment": settings.app_env,
        "status": "running",
    }

@app.get("/ping")
async def ping():
    return {"status": "ok"}

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "database": settings.db_host,
        "environment": settings.app_env,
    }

# ===============================
# Database Dependency
# ===============================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ===============================
# Example DB Route (Test)
# ===============================

@app.get("/api/users")
def get_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return [
        {
            "id": u.id,
            "username": u.username,
            "email": u.email,
            "is_active": u.is_active,
            "role": u.role.value if u.role else None,
        }
        for u in users
    ]

# ===============================
# SPA Fallback (End of routes)
# ===============================

@app.get("/{path:path}")
async def spa_fallback(path: str):
    """
    Serve index.html for SPA routes
    """
    # Skip API/docs paths
    if path.startswith(("api", "docs", "redoc", "static")):
        raise HTTPException(status_code=404, detail="Not Found")

    # Serve index.html if exists
    if INDEX_FILE.exists():
        return FileResponse(INDEX_FILE)

    raise HTTPException(
        status_code=500,
        detail="Frontend not built or index.html missing"
    )

# ===============================
# Entrypoint
# ===============================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
    )
