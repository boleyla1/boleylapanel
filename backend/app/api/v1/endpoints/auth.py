# app/api/v1/endpoints/auth.py

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

from app.api.deps import get_db_session
from app.core.security import create_access_token
from app.config.settings import settings
from app.crud.user import user as crud_user
from app.schemas.token import Token

router = APIRouter()


@router.post("/login", response_model=Token)
def login(
        form_data: OAuth2PasswordRequestForm = Depends(),
        db: Session = Depends(get_db_session)
):
    print("DEBUG: Calling authenticate function...")
    db_user = crud_user.authenticate(
        db,
        identifier=form_data.username,
        password=form_data.password
    )
    print(f"DEBUG: Result of authenticate: db_user is None: {db_user is None}")

    if not db_user:
        print("DEBUG: Authentication failed. Raising HTTPException.")
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    print(f"DEBUG: User authenticated successfully. Email: {db_user.email}")
    print(f"DEBUG: SECRET_KEY first 5 chars: {settings.SECRET_KEY[:5]}")
    print(f"DEBUG: ALGORITHM: {settings.ALGORITHM}")
    print(f"DEBUG: ACCESS_TOKEN_EXPIRE_MINUTES: {settings.ACCESS_TOKEN_EXPIRE_MINUTES}")

    expire = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    print(f"DEBUG: Token expiration calculated: {expire}")

    token = create_access_token(
        user_id=db_user.id,
        expires_delta=expire
    )
    print("DEBUG: Access token created successfully.")
    return Token(access_token=token)
