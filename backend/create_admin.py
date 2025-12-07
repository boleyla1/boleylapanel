# backend/create_admin.py
import os
import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy.orm import Session
from app.db.database import SessionLocal, engine
from app.db import Base
from app.schemas import UserCreate
from app.crud.user import user as crud_user
from app.models.user import UserRole
import asyncio


def create_initial_admin_user():
    db: Session = SessionLocal()
    try:

        Base.metadata.create_all(bind=engine)

        existing_admin_by_email = crud_user.get_by_email(db, email="admin@example.com")
        existing_admin_by_username = crud_user.get_by_username(db, username="admin")

        if existing_admin_by_email or existing_admin_by_username:
            print("Admin user 'admin@example.com' or 'admin' already exists. Skipping creation.")
            if existing_admin_by_email:
                print(f"Existing admin user (email): {existing_admin_by_email.email}, ID: {existing_admin_by_email.id}")
            if existing_admin_by_username and not existing_admin_by_email:  # Only print if different user found by username
                print(
                    f"Existing admin user (username): {existing_admin_by_username.username}, ID: {existing_admin_by_username.id}")
            return

        print("Creating initial admin user...")
        user_in = UserCreate(
            username="admin",
            email="admin@example.com",
            full_name="Admin User",
            password="admin123",
            is_active=True,
            role=UserRole.ADMIN
        )
        admin_user = crud_user.create(db, data=user_in)
        print(f"Admin user '{admin_user.email}' created successfully with ID: {admin_user.id}")
    except Exception as e:
        print(f"An error occurred during admin user creation: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    create_initial_admin_user()
