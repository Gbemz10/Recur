from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session
import jwt

from backend.app.core.config import Settings
from backend.app.core.config import get_settings
from backend.app.core.security import (
    create_access_token,
    create_refresh_token,
    generate_otp,
    hash_secret,
    utc_now,
    verify_secret,
)
from backend.app.models.otp_code import OtpCode
from backend.app.models.refresh_token import RefreshToken
from backend.app.models.user import User


def contact_from(email: str | None, phone: str | None) -> tuple[str, str]:
    if email:
        return "email", email.strip().lower()
    if phone:
        return "phone", phone.strip()
    raise ValueError("email or phone is required")


def request_otp(db: Session, *, email: str | None, phone: str | None) -> str:
    contact_type, contact_value = contact_from(email, phone)
    code = generate_otp()
    expires_at = utc_now() + timedelta(minutes=get_settings().otp_expire_minutes)
    db.add(
        OtpCode(
            contact_type=contact_type,
            contact_value=contact_value,
            code_hash=hash_secret(code),
            expires_at=expires_at,
        )
    )
    db.commit()
    return code


def verify_otp(db: Session, *, email: str | None, phone: str | None, code: str) -> User | None:
    contact_type, contact_value = contact_from(email, phone)
    statement = (
        select(OtpCode)
        .where(
            OtpCode.contact_type == contact_type,
            OtpCode.contact_value == contact_value,
            OtpCode.consumed_at.is_(None),
            OtpCode.expires_at > utc_now(),
        )
        .order_by(OtpCode.created_at.desc())
    )
    otp = db.scalars(statement).first()
    if otp is None or not verify_secret(code, otp.code_hash):
        return None

    user = _get_or_create_user(db, contact_type=contact_type, contact_value=contact_value)
    otp.consumed_at = utc_now()
    db.commit()
    db.refresh(user)
    return user


def issue_tokens(db: Session, user: User) -> tuple[str, str]:
    access_token = create_access_token(user.id)
    refresh_token, expires_at = create_refresh_token(user.id)
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_secret(refresh_token),
            expires_at=expires_at,
        )
    )
    db.commit()
    return access_token, refresh_token


def refresh_tokens(db: Session, refresh_token: str) -> tuple[str, str] | None:
    settings = get_settings()
    user_id = _decode_refresh_token(refresh_token, settings)
    if user_id is None:
        return None

    stored_token = db.scalars(
        select(RefreshToken).where(
            RefreshToken.token_hash == hash_secret(refresh_token),
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > utc_now(),
        )
    ).first()
    if stored_token is None:
        return None

    user = db.get(User, user_id)
    if user is None or not user.is_active:
        return None

    stored_token.revoked_at = utc_now()
    return issue_tokens(db, user)


def revoke_refresh_token(db: Session, refresh_token: str) -> bool:
    stored_token = db.scalars(
        select(RefreshToken).where(
            RefreshToken.token_hash == hash_secret(refresh_token),
            RefreshToken.revoked_at.is_(None),
        )
    ).first()
    if stored_token is None:
        return False

    stored_token.revoked_at = utc_now()
    db.commit()
    return True


def _get_or_create_user(db: Session, *, contact_type: str, contact_value: str) -> User:
    field = User.email if contact_type == "email" else User.phone
    user = db.scalars(select(User).where(field == contact_value)).first()
    if user is not None:
        return user

    user = User(email=contact_value if contact_type == "email" else None)
    if contact_type == "phone":
        user.phone = contact_value
    db.add(user)
    db.flush()
    return user


def _decode_refresh_token(refresh_token: str, settings: Settings) -> str | None:
    try:
        payload = jwt.decode(
            refresh_token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
    except jwt.PyJWTError:
        return None

    if payload.get("type") != "refresh" or not payload.get("sub"):
        return None
    return str(payload["sub"])
