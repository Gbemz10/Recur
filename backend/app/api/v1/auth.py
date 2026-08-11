from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.app.core.config import get_settings
from backend.app.db.session import get_db
from backend.app.schemas.auth import (
    OtpRequest,
    OtpRequestResponse,
    OtpVerifyRequest,
    RefreshTokenRequest,
    TokenPair,
)
from backend.app.services.auth import (
    issue_tokens,
    refresh_tokens,
    request_otp,
    revoke_refresh_token,
    verify_otp,
)

router = APIRouter()


@router.post("/otp/request", response_model=OtpRequestResponse)
def request_login_otp(
    payload: OtpRequest,
    db: Annotated[Session, Depends(get_db)],
) -> OtpRequestResponse:
    code = request_otp(db, email=payload.email, phone=payload.phone)
    dev_otp = code if get_settings().environment == "local" else None
    return OtpRequestResponse(message="OTP sent.", dev_otp=dev_otp)


@router.post("/otp/verify", response_model=TokenPair)
def verify_login_otp(
    payload: OtpVerifyRequest,
    db: Annotated[Session, Depends(get_db)],
) -> TokenPair:
    user = verify_otp(db, email=payload.email, phone=payload.phone, code=payload.code)
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")

    access_token, refresh_token = issue_tokens(db, user)
    return TokenPair(access_token=access_token, refresh_token=refresh_token)


@router.post("/token/refresh", response_model=TokenPair)
def refresh_login_token(
    payload: RefreshTokenRequest,
    db: Annotated[Session, Depends(get_db)],
) -> TokenPair:
    tokens = refresh_tokens(db, payload.refresh_token)
    if tokens is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    access_token, refresh_token = tokens
    return TokenPair(access_token=access_token, refresh_token=refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(payload: RefreshTokenRequest, db: Annotated[Session, Depends(get_db)]) -> None:
    revoke_refresh_token(db, payload.refresh_token)
