from typing import Annotated

from fastapi import APIRouter, Depends

from backend.app.api.deps import get_current_user
from backend.app.models.user import User
from backend.app.schemas.auth import UserProfile

router = APIRouter()


@router.get("/me", response_model=UserProfile)
def get_me(current_user: Annotated[User, Depends(get_current_user)]) -> UserProfile:
    return UserProfile(id=current_user.id, email=current_user.email, phone=current_user.phone)
