from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.models import User
from .config import settings

app = FastAPI(
    title=settings.app_name,
    description="Professional VPN Panel Management System",
    version=settings.app_version,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    debug=settings.debug,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {
        "message": f"Welcome to {settings.app_name} API",
        "version": settings.app_version,
        "environment": settings.app_env,
        "status": "running"
    }


@app.get("/ping")
async def ping():
    return {"status": "ok", "message": "pong"}


@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "app_name": settings.app_name,
        "version": settings.app_version,
        "environment": settings.app_env,
        "database": {
            "host": settings.db_host,
            "port": settings.db_port,
            "name": settings.db_name,
        }
    }


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/api/users")
def get_all_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    result = []
    for u in users:
        result.append({
            "id": u.id,
            "username": u.username,
            "email": u.email,
            "full_name": u.full_name,
            "is_active": u.is_active,
            "role": u.role.value
        })
    return {"users": result}

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        reload=settings.is_development()
    )
