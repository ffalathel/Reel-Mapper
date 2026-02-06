from typing import Any, List as PyList
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select, col
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


# --- Favorites & Visited Implementation using named Lists ---

@router.get("/favorites", response_model=schemas.FavoritesListResponse)
async def get_favorites(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    # Find "Favorites" list
    stmt = select(List).where(List.user_id == current_user.id).where(List.name == "Favorites")
    result = await db.execute(stmt)
    fav_list = result.scalar_one_or_none()
    
    restaurant_ids = []
    if fav_list:
        stmt_items = select(UserRestaurant).where(UserRestaurant.list_id == fav_list.id)
        result_items = await db.execute(stmt_items)
        items = result_items.scalars().all()
        restaurant_ids = [item.restaurant_id for item in items]
        
    return {"restaurant_ids": restaurant_ids}

@router.get("/visited", response_model=schemas.VisitedListResponse)
async def get_visited(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    # Find "Visited" list
    stmt = select(List).where(List.user_id == current_user.id).where(List.name == "Visited")
    result = await db.execute(stmt)
    vis_list = result.scalar_one_or_none()
    
    restaurant_ids = []
    if vis_list:
        stmt_items = select(UserRestaurant).where(UserRestaurant.list_id == vis_list.id)
        result_items = await db.execute(stmt_items)
        items = result_items.scalars().all()
        restaurant_ids = [item.restaurant_id for item in items]
        
    return {"restaurant_ids": restaurant_ids}

