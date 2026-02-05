"""
Auth Endpoints

POST /auth/login - REMOVED (Clerk handles login via iOS SDK)
POST /auth/register - REMOVED (Clerk handles registration via iOS SDK)
GET /auth/me - KEPT (returns current user from our database)
"""

from typing import Any
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app import schemas
from app.models.user import User

router = APIRouter()


@router.get("/me", response_model=schemas.UserRead)
async def read_users_me(
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get current user.
    
    Returns the user object from our database, which includes:
    - id: Our internal UUID
    - email: User's email
    - clerk_user_id: The Clerk user ID (for debugging/linking)
    """
    return current_user
