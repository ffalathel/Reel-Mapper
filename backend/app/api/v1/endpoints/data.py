from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from sqlalchemy.orm import selectinload

from app.api import deps
from app import schemas
from app.models.list import List
from app.models.save_event import UserRestaurant
from app.models.restaurant import Restaurant

router = APIRouter()

@router.get("/home", response_model=schemas.HomeResponse)
async def get_home_data(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    Get homepage data: User's lists and unsorted restaurants.
    """
    # 1. Fetch Lists
    stmt_lists = select(List).where(List.user_id == current_user.id)
    result_lists = await db.execute(stmt_lists)
    lists = result_lists.scalars().all()

    # 2. Fetch Unsorted Restaurants (UserRestaurant where list_id is None)
    # Need to load the related Restaurant object
    stmt_unsorted = (
        select(UserRestaurant)
        .where(UserRestaurant.user_id == current_user.id)
        .where(UserRestaurant.list_id == None)
        .options(selectinload(UserRestaurant.restaurant)) # Assuming relationship needed in model?
    )
    # Wait, I didn't define relationships in SQLModel classes!
    # I need to add Relationship attributes to SQLModel classes for `.restaurant` to work.
    
    # Let's fix the models first or do a join query.
    # Relationships are cleaner.
    
    # For now, I will assume I need to update models.
    # But I can also join:
    # select(UserRestaurant, Restaurant).join(Restaurant, UserRestaurant.restaurant_id == Restaurant.id)
    
    # I will stick to adding Relationships to models as it's better practice.
    # I will modify the models in next step. For now I write the endpoint assuming relationships exist.
    
    result_unsorted = await db.execute(stmt_unsorted)
    unsorted = result_unsorted.scalars().all()

    return {
        "lists": lists,
        "unsorted_restaurants": unsorted
    }

@router.get("/restaurants/{restaurant_id}", response_model=schemas.RestaurantRead)
async def get_restaurant(
    restaurant_id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    stmt = select(Restaurant).where(Restaurant.id == restaurant_id)
    result = await db.execute(stmt)
    restaurant = result.scalar_one_or_none()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant

@router.post("/restaurants/{restaurant_id}/export/google-maps")
async def export_to_google_maps(
    restaurant_id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    Get deep link for Google Maps.
    """
    stmt = select(Restaurant).where(Restaurant.id == restaurant_id)
    result = await db.execute(stmt)
    restaurant = result.scalar_one_or_none()
    
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
        
    if not restaurant.google_place_id:
        return {"url": f"comgooglemaps://?q={restaurant.latitude},{restaurant.longitude}"}
    
    return {"url": f"comgooglemaps://?q=place_id:{restaurant.google_place_id}"}
