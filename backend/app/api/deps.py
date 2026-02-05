"""
FastAPI Dependencies

Provides get_current_user() dependency that:
1. Extracts JWT from Authorization: Bearer header
2. Verifies the token using Clerk's JWKS
3. Finds or creates the user in our database
"""

from typing import Generator
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.core.security import verify_clerk_token
from app.db.base import get_session
from app.models.user import User

import jwt
import logging

logger = logging.getLogger(__name__)

# Use HTTPBearer instead of OAuth2PasswordBearer since we're not using password flow anymore
security = HTTPBearer()


async def get_db() -> AsyncSession:
    """Get database session."""
    async for session in get_session():
        yield session


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """
    Get the current authenticated user from a Clerk session token.
    
    This dependency:
    1. Extracts the JWT from the Authorization: Bearer header
    2. Verifies the token using Clerk's JWKS (RS256)
    3. Looks up the user by clerk_user_id
    4. If not found, auto-creates the user (first-time login)
    5. Returns the user object
    
    Raises:
        HTTPException 401: If token is missing, invalid, or expired
    """
    token = credentials.credentials
    logger.info(f"DEBUG deps: Received token: {token[:50]}...")
    
    try:
        # Verify the Clerk token
        logger.info("DEBUG deps: Calling verify_clerk_token...")
        payload = verify_clerk_token(token)
        logger.info(f"DEBUG deps: Token verified successfully. Payload: {payload}")
    except jwt.ExpiredSignatureError:
        logger.error("DEBUG deps: Token expired")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        logger.error(f"DEBUG deps: Invalid token: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except ValueError as e:
        # Clerk not configured
        logger.error(f"DEBUG deps: ValueError (Clerk config issue): {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f"DEBUG deps: Unexpected exception: {type(e).__name__}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {type(e).__name__}: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Extract clerk_user_id from the sub claim
    clerk_user_id = payload.get("sub")
    if not clerk_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Look up user by clerk_user_id
    stmt = select(User).where(User.clerk_user_id == clerk_user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    
    if user:
        return user
    
    # User not found - this is a first-time user
    # Auto-create the user record (find-or-create pattern per spec Step 5)
    
    # Extract email and name from custom claims (if configured in Clerk dashboard)
    email = payload.get("email")
    name = payload.get("name")
    
    if not email:
        # If email not in custom claims, we need it to create the user
        # This shouldn't happen if Clerk is configured correctly
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not found in token. Please configure custom claims in Clerk dashboard.",
        )
    
    # Check if a user with this email already exists (legacy user migration case)
    stmt_email = select(User).where(User.email == email)
    result_email = await db.execute(stmt_email)
    existing_user = result_email.scalar_one_or_none()
    
    if existing_user:
        # Link existing user to Clerk by setting clerk_user_id
        existing_user.clerk_user_id = clerk_user_id
        if name and not existing_user.name:
            existing_user.name = name
        db.add(existing_user)
        await db.commit()
        await db.refresh(existing_user)
        return existing_user
    
    # Create new user
    new_user = User(
        clerk_user_id=clerk_user_id,
        email=email,
        name=name,
        hashed_password=None,  # Clerk handles passwords
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    return new_user
