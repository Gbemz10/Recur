from fastapi import APIRouter

from backend.app.api.v1 import auth, health, users

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(users.router, tags=["users"])
