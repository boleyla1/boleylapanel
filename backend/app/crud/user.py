from sqlalchemy.orm import Session
from app.models.user import User, UserRole
from app.schemas import UserCreate, UserUpdate
from app.core.security import get_password_hash, verify_password


class CRUDUser:

    def get(self, db: Session, user_id: int):
        return db.query(User).filter(User.id == user_id).first()

    def get_by_email(self, db: Session, email: str):
        return db.query(User).filter(User.email == email).first()

    def get_by_username(self, db: Session, username: str):
        return db.query(User).filter(User.username == username).first()

    def get_multi(self, db: Session, skip: int = 0, limit: int = 100):
        return db.query(User).offset(skip).limit(limit).all()

    def create(self, db: Session, data: UserCreate):
        hashed_password = get_password_hash(data.password)

        user_role = UserRole.USER
        if hasattr(data, 'is_admin') and data.is_admin is True:
            user_role = UserRole.ADMIN

        db_obj = User(
            username=data.username,  # <--- این خط اضافه شد!
            email=data.email,
            full_name=data.full_name,
            hashed_password=hashed_password,
            is_active=data.is_active,
            role=user_role,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def update(self, db: Session, db_obj: User, data: UserUpdate):
        if data.email is not None:
            db_obj.email = data.email

        if data.full_name is not None:
            db_obj.full_name = data.full_name

        if data.username is not None:  # <--- و این خط هم برای به‌روزرسانی اضافه شد
            db_obj.username = data.username

        if data.password:
            db_obj.hashed_password = get_password_hash(data.password)

        if data.is_active is not None:
            db_obj.is_active = data.is_active

        if hasattr(data, 'is_admin') and data.is_admin is not None:
            db_obj.role = UserRole.ADMIN if data.is_admin else UserRole.USER

        db.commit()
        db.refresh(db_obj)
        return db_obj

    def remove(self, db: Session, user_id: int):
        obj = self.get(db, user_id)
        if obj:
            db.delete(obj)
            db.commit()
        return obj

    def authenticate(self, db: Session, identifier: str, password: str):
        print(f"DEBUG(crud_user.authenticate): Attempting to authenticate user with identifier: {identifier}")

        user = self.get_by_email(db, identifier)

        if user:
            print(f"DEBUG(crud_user.authenticate): User found by email: {user.email}")
        else:
            print(f"DEBUG(crud_user.authenticate): User with email {identifier} not found. Trying to find by username.")
            user = self.get_by_username(db, identifier)
            if user:
                print(f"DEBUG(crud_user.authenticate): User found by username: {user.username}")

        if not user:
            print(
                f"DEBUG(crud_user.authenticate): User with identifier {identifier} not found after checking email/username.")
            return None

        if not verify_password(password, user.hashed_password):
            print("DEBUG(crud_user.authenticate): Password verification FAILED (Incorrect password).")
            return None

        print("DEBUG(crud_user.authenticate): Authentication SUCCESSFUL.")
        return user


user = CRUDUser()
