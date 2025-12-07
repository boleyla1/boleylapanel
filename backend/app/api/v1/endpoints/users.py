from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import (
    get_db_session,
    get_current_admin_user,
)
from app.schemas.user import UserCreate, UserUpdate, UserOut
from app.crud.user import user as crud_user


router = APIRouter()


@router.get("/", response_model=list[UserOut])
def list_users(
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    return crud_user.get_multi(db)


@router.post("/", response_model=UserOut)
def create_user(
    user_in: UserCreate,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    existing = crud_user.get_by_email(db, email=user_in.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email already exists")

    # اصلاح شد: پارامتر 'data' به جای 'obj_in' یا 'user'
    return crud_user.create(db, data=user_in)


@router.put("/{user_id}", response_model=UserOut)
def update_user(
    user_id: int,
    user_in: UserUpdate,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    # اصلاح شد: پارامتر 'user_id' به جای 'id'
    db_user = crud_user.get(db, user_id=user_id)

    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    # پارامترهای update صحیح هستند (db_obj و data)
    return crud_user.update(db, db_user, user_in)


@router.delete("/{user_id}")
def delete_user(
    user_id: int,
    db: Session = Depends(get_db_session),
    _: dict = Depends(get_current_admin_user),
):
    # اصلاح شد: پارامتر 'user_id' به جای 'id'
    db_user = crud_user.get(db, user_id=user_id)
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    # اصلاح شد: پارامتر 'user_id' به جای 'id'
    crud_user.remove(db, user_id=user_id)
    return {"detail": "User deleted"}
