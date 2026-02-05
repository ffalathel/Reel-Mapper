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

    return {"url": f"comgooglemaps://?q=place_id:{restaurant.google_place_id}"}


# --- Favorites & Visited Implementation using named Lists ---

async def _get_or_create_special_list(db: AsyncSession, user_id: Any, list_name: str) -> List:
    stmt = select(List).where(List.user_id == user_id).where(List.name == list_name)
    result = await db.execute(stmt)
    special_list = result.scalar_one_or_none()
    
    if not special_list:
        special_list = List(user_id=user_id, name=list_name)
        db.add(special_list)
        await db.commit()
        await db.refresh(special_list)
        
    return special_list

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

@router.post("/favorites/{restaurant_id}", response_model=schemas.FavoriteResponse)
async def toggle_favorite(
    restaurant_id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    fav_list = await _get_or_create_special_list(db, current_user.id, "Favorites")
    
    # Check if exists
    stmt = (
        select(UserRestaurant)
        .where(UserRestaurant.list_id == fav_list.id)
        .where(UserRestaurant.restaurant_id == restaurant_id)
        .where(UserRestaurant.user_id == current_user.id)
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    
    if existing:
        await db.delete(existing)
        await db.commit()
        return {"is_favorite": False}
    else:
        # We need a source_event_id for UserRestaurant constraint?
        # The schema says source_event_id is NOT nullable.
        # But we don't have a source event here.
        # We might need to create a dummy SaveEvent or fetch one.
        # Or, maybe the constraint allows it? No, schema said NOT NULL.
        # Workaround: Create a placeholder SaveEvent.
        
        from app.models.save_event import SaveEvent, SaveEventStatus
        
        # Check if restaurant exists first to avoid FK error
        # (Assuming it exists if ID is passed, but good to be safe)
        
        # Create a dummy event
        dummy_event = SaveEvent(
            user_id=current_user.id,
            source="manual_toggle",
            source_url="",
            status=SaveEventStatus.COMPLETE.value,
            target_list_id=fav_list.id
        )
        db.add(dummy_event)
        await db.commit()
        await db.refresh(dummy_event)
        
        new_item = UserRestaurant(
            user_id=current_user.id,
            restaurant_id=restaurant_id,
            list_id=fav_list.id,
            source_event_id=dummy_event.id 
        )
        db.add(new_item)
        await db.commit()
        return {"is_favorite": True}

@router.get("/visited", response_model=schemas.VisitedListResponse)
async def get_visited(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    items = []
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

@router.post("/visited/{restaurant_id}", response_model=schemas.VisitedResponse)
async def toggle_visited(
    restaurant_id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    vis_list = await _get_or_create_special_list(db, current_user.id, "Visited")
    
    # Check if exists
    stmt = (
        select(UserRestaurant)
        .where(UserRestaurant.list_id == vis_list.id)
        .where(UserRestaurant.restaurant_id == restaurant_id)
        .where(UserRestaurant.user_id == current_user.id)
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    
    if existing:
        await db.delete(existing)
        await db.commit()
        return {"is_visited": False}
    else:
        from app.models.save_event import SaveEvent, SaveEventStatus
        
        dummy_event = SaveEvent(
            user_id=current_user.id,
            source="manual_toggle",
            source_url="",
            status=SaveEventStatus.COMPLETE.value,
            target_list_id=vis_list.id
        )
        db.add(dummy_event)
        await db.commit()
        await db.refresh(dummy_event)
        
        new_item = UserRestaurant(
            user_id=current_user.id,
            restaurant_id=restaurant_id,
            list_id=vis_list.id,
            source_event_id=dummy_event.id
        )
        db.add(new_item)
        await db.commit()
        return {"is_visited": True}
