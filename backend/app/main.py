from pathlib import Path
import os
import sys

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
# Fix Windows Console Encoding
# ===============================

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass


# ===============================
# Smart Path Configuration (Windows + Linux)
# ===============================

def get_base_dir():
    """
    Automatically detect base directory for both Windows and Linux
    """
    current_file = Path(__file__).resolve()

    # Try to find frontend directory by going up the tree
    for parent_level in range(5):
        potential_base = current_file.parents[parent_level]
        frontend_dir = potential_base / "frontend"

        if frontend_dir.exists() and (frontend_dir / "index.html").exists():
            print(f"[OK] Found frontend at: {frontend_dir}")
            return potential_base

    # Fallback: check common locations
    common_paths = [
        Path("/opt/boleylapanel"),  # Linux VPS
        Path.cwd().parent,  # Current working directory's parent
        Path.cwd(),  # Current working directory
    ]

    for path in common_paths:
        frontend_dir = path / "frontend"
        if frontend_dir.exists() and (frontend_dir / "index.html").exists():
            print(f"[OK] Found frontend at: {frontend_dir}")
            return path

    # Last resort: use current file's parent
    print("[WARN] Frontend not found, using default path")
    return current_file.parents[2]


BASE_DIR = get_base_dir()
FRONTEND_DIR = BASE_DIR / "frontend"
STATIC_DIR = FRONTEND_DIR / "static"

print(f"[INFO] BASE_DIR: {BASE_DIR}")
print(f"[INFO] FRONTEND_DIR: {FRONTEND_DIR}")
print(f"[INFO] index.html exists: {(FRONTEND_DIR / 'index.html').exists()}")

# ===============================
# FastAPI App
# ===============================

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
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
# Database Dependency
# ===============================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ===============================
# API Routes
# ===============================

app.include_router(api_router, prefix="/api/v1")


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
# Static Files
# ===============================

if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
else:
    print(f"[WARN] Static directory not found: {STATIC_DIR}")


# ===============================
# HTML Pages
# ===============================

@app.get("/{page}.html")
async def serve_html(page: str):
    file_path = FRONTEND_DIR / f"{page}.html"
    if not file_path.is_file():
        raise HTTPException(status_code=404, detail=f"Page '{page}.html' not found")
    return FileResponse(file_path)


# ===============================
# Root Route
# ===============================

@app.get("/")
async def root():
    index_path = FRONTEND_DIR / "index.html"

    if not index_path.exists():
        return JSONResponse(
            status_code=500,
            content={
                "app": settings.app_name,
                "version": settings.app_version,
                "status": "running",
                "error": "index.html not found",
                "searched_path": str(index_path),
                "base_dir": str(BASE_DIR),
            }
        )

    return FileResponse(index_path)
