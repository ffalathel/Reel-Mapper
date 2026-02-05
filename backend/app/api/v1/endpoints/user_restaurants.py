from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.api import deps
from app.models.save_event import UserRestaurant

router = APIRouter()

@router.delete("/{id}", status_code=204)
async def delete_user_restaurant(
    id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
):
    """
    Delete a saved restaurant.
    """
    stmt = select(UserRestaurant).where(UserRestaurant.id == id).where(UserRestaurant.user_id == current_user.id)
    result = await db.execute(stmt)
    user_rest = result.scalar_one_or_none()
    
    if not user_rest:
        raise HTTPException(status_code=404, detail="Saved restaurant not found")
        
    await db.delete(user_rest)
    await db.commit()
    return None


@router.delete("/restaurant/{restaurant_id}", status_code=204)
async def delete_user_restaurant_by_rid(
    restaurant_id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
):
    """
    Delete a saved restaurant by restaurant_id.
    """
    stmt = select(UserRestaurant).where(UserRestaurant.restaurant_id == restaurant_id).where(UserRestaurant.user_id == current_user.id)
    result = await db.execute(stmt)
    user_rest = result.scalar_one_or_none()
    
    if not user_rest:
        raise HTTPException(status_code=404, detail="Saved restaurant not found")
        
    await db.delete(user_rest)
    await db.commit()
    return None
