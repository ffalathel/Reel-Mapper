from typing import Any
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from sqlalchemy.orm import selectinload

from app.api import deps
from app import schemas
from app.models.list import List
from app.models.save_event import UserRestaurant, SaveEvent

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

@router.get("/{list_id}/restaurants", response_model=schemas.ListRestaurantsResponse)
async def get_list_restaurants(
    list_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    Get all restaurants in a specific list.
    """
    # First verify the list belongs to the user
    stmt_list = select(List).where(List.id == list_id).where(List.user_id == current_user.id)
    result_list = await db.execute(stmt_list)
    list_item = result_list.scalar_one_or_none()

    if not list_item:
        raise HTTPException(status_code=404, detail="List not found")

    # Fetch all UserRestaurant records for this list
    stmt = (
        select(UserRestaurant)
        .where(UserRestaurant.user_id == current_user.id)
        .where(UserRestaurant.list_id == list_id)
        .options(selectinload(UserRestaurant.restaurant))
    )

    result = await db.execute(stmt)
    restaurants = result.scalars().all()

    return {"restaurants": restaurants}

@router.post("/{list_id}/restaurants", response_model=schemas.UserRestaurantRead)
async def add_restaurant_to_list(
    list_id: UUID,
    request: schemas.AddRestaurantToListRequest,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    Add a restaurant to a list by updating the UserRestaurant's list_id.
    """
    # Find the UserRestaurant record
    stmt = select(UserRestaurant).where(UserRestaurant.user_id == current_user.id).where(UserRestaurant.restaurant_id == request.restaurant_id)
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


@router.delete("/{list_id}", status_code=200)
async def delete_list(
    list_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    Delete a list.
    """
    stmt = select(List).where(List.id == list_id).where(List.user_id == current_user.id)
    result = await db.execute(stmt)
    list_item = result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(status_code=404, detail="List not found")
        
    # Optional: Delete associated UserRestaurants inside this list?
    # Or just set their list_id to NULL (unsorted)?
    # For now, let's just delete the list.
    # If we have CASCADE delete in DB, items might be deleted. 
    # If not, we should probably set them to unsorted or delete them.
    # Let's set them to NULL (Unsorted) so the user doesn't lose the restaurant.
    
    stmt_items = select(UserRestaurant).where(UserRestaurant.list_id == list_id)
    result_items = await db.execute(stmt_items)
    items = result_items.scalars().all()
    
    for item in items:
        item.list_id = None
        db.add(item)
        
    # Also clean up any SaveEvents referencing this list
    stmt_events = select(SaveEvent).where(SaveEvent.target_list_id == list_id)
    result_events = await db.execute(stmt_events)
    events = result_events.scalars().all()
    
    for event in events:
        event.target_list_id = None
        db.add(event)
        
    await db.delete(list_item)
    await db.commit()
    return None
