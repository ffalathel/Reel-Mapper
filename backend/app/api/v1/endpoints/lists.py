from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.api import deps
from app import schemas
from app.models.list import List
from app.models.save_event import UserRestaurant

router = APIRouter()

@router.post("/", response_model=schemas.ListRead, status_code=201)
async def create_list(
    *,
    db: AsyncSession = Depends(deps.get_db),
    list_in: schemas.ListCreate,
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    Create a new list.
    """
    # Check for duplicate name for user
    stmt = select(List).where(List.user_id == current_user.id).where(List.name == list_in.name)
    existing = await db.execute(stmt)
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="List with this name already exists")

    new_list = List(
        user_id=current_user.id,
        name=list_in.name
    )
    db.add(new_list)
    await db.commit()
    await db.refresh(new_list)
    return new_list

@router.post("/{list_id}/restaurants", response_model=schemas.UserRestaurantRead)
async def add_restaurant_to_list(
    *,
    db: AsyncSession = Depends(deps.get_db),
    list_id: str, # UUID
    restaurant_id: str, # passed in body? TDD says POST /lists/{id}/restaurants. Body?
    # TDD doesn't specify body shape, but presumably {restaurant_id: ...} 
    # Or maybe we are moving an existing UserRestaurant to a list?
    # TDD says: "POST /lists/{id}/restaurants".
    # Logic: "Add restaurant to list".
    # If the user already saved it, we update list_id? Or create new link?
    # Constraints: (user_id, restaurant_id) unique.
    # So a restaurant can only be in ONE list or NO list (unsorted).
    # IF so, we update the existing UserRestaurant record.
    # We need a body schema: `restaurant_id`.
    body: dict, # simplistic
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    # Extract restaurant_id from body
    target_rest_id = body.get("restaurant_id")
    if not target_rest_id:
        raise HTTPException(status_code=400, detail="restaurant_id required")

    # Find the UserRestaurant record
    stmt = select(UserRestaurant).where(UserRestaurant.user_id == current_user.id).where(UserRestaurant.restaurant_id == target_rest_id)
    result = await db.execute(stmt)
    user_rest = result.scalar_one_or_none()
    
    if not user_rest:
        raise HTTPException(status_code=404, detail="Restaurant not saved by user")
    
    # Update list_id
    user_rest.list_id = list_id
    db.add(user_rest)
    await db.commit()
    await db.refresh(user_rest)
    return user_rest

