import os
import sys
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.crud.user import user as crud_user
from app.schemas.user import UserCreate
from app.core.security import get_password_hash


def init_admin():
    """Create initial admin user"""
    db: Session = SessionLocal()

    try:
        # Get admin credentials from environment
        username = os.getenv("ADMIN_USERNAME", "admin")
        email = os.getenv("ADMIN_EMAIL", "admin@boleyla.local")
        password = os.getenv("ADMIN_PASSWORD")

        if not password:
            print("❌ ADMIN_PASSWORD not found in environment variables")
            return False

        # Check if admin already exists
        existing_user = crud_user.get_by_username(db, username=username)
        if existing_user:
            print(f"⚠️  Admin user '{username}' already exists")
            return True

        # Create admin user
        user_in = UserCreate(
            username=username,
            email=email,
            password=password,
            is_admin=True,
            is_active=True
        )

        admin_user = crud_user.create(db, obj_in=user_in)
        print(f"✅ Admin user created successfully")
        print(f"   Username: {admin_user.username}")
        print(f"   Email: {admin_user.email}")
        return True

    except Exception as e:
        print(f"❌ Error creating admin user: {e}")
        return False
    finally:
        db.close()


if __name__ == "__main__":
    print("🔧 Initializing database with admin user...")
    success = init_admin()
    sys.exit(0 if success else 1)
