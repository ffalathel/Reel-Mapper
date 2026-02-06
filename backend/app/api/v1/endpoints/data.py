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
    
    result_unsorted = await db.execute(stmt_unsorted)
    unsorted = result_unsorted.scalars().all()

    return {
        "lists": lists,
        "unsorted_restaurants": unsorted
    }


# --- DEPRECATED: Favorites & Visited Endpoints ---
# These endpoints are kept for backward compatibility but are no longer needed.
# The /home endpoint now includes is_favorite and is_visited flags on each restaurant,
# eliminating the need for separate calls.

@router.get("/favorites", response_model=schemas.FavoritesListResponse, deprecated=True)
async def get_favorites(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    DEPRECATED: Use /home endpoint instead, which returns restaurants with is_favorite flags.

    Get list of favorite restaurant IDs.
    This endpoint is maintained for backward compatibility only.
    """
    stmt = (
        select(UserRestaurant.restaurant_id)
        .where(UserRestaurant.user_id == current_user.id)
        .where(UserRestaurant.is_favorite == True)
    )
    result = await db.execute(stmt)
    restaurant_ids = result.scalars().all()

    return {"restaurant_ids": restaurant_ids}

@router.get("/visited", response_model=schemas.VisitedListResponse, deprecated=True)
async def get_visited(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    DEPRECATED: Use /home endpoint instead, which returns restaurants with is_visited flags.

    Get list of visited restaurant IDs.
    This endpoint is maintained for backward compatibility only.
    """
    stmt = (
        select(UserRestaurant.restaurant_id)
        .where(UserRestaurant.user_id == current_user.id)
        .where(UserRestaurant.is_visited == True)
    )
    result = await db.execute(stmt)
    restaurant_ids = result.scalars().all()

    return {"restaurant_ids": restaurant_ids}

