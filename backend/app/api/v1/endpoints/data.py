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
from app.errors import ErrorMessages

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


@router.get("/favorites")
async def get_favorites_deprecated():
    """Deprecated: favorites are now returned as flags on /home endpoint."""
    raise HTTPException(status_code=410, detail=ErrorMessages.ENDPOINT_FAVORITES_GONE)


@router.get("/visited")
async def get_visited_deprecated():
    """Deprecated: visited status is now returned as flags on /home endpoint."""
    raise HTTPException(status_code=410, detail=ErrorMessages.ENDPOINT_VISITED_GONE)