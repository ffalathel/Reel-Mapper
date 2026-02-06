from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.api import deps
from app import schemas
from app.models.restaurant import Restaurant
from app.models.list import List
from app.models.save_event import UserRestaurant, SaveEvent, SaveEventStatus
from app.models.note import Note

router = APIRouter()

@router.get("/{restaurant_id}", response_model=schemas.RestaurantRead)
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

# --- Shared helper for Favorite/Visited ---
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

@router.post("/{restaurant_id}/favorite", response_model=schemas.FavoriteResponse)
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

@router.post("/{restaurant_id}/visited", response_model=schemas.VisitedResponse)
async def toggle_visited(
    restaurant_id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    vis_list = await _get_or_create_special_list(db, current_user.id, "Visited")
    
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

@router.put("/{restaurant_id}/notes")
async def save_notes(
    restaurant_id: str,
    note_data: schemas.NoteUpdate = Body(...),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    # 1. Check if note exists
    stmt = (
        select(Note)
        .where(Note.user_id == current_user.id)
        .where(Note.restaurant_id == restaurant_id)
    )
    result = await db.execute(stmt)
    existing_note = result.scalar_one_or_none()
    
    if existing_note:
        existing_note.content = note_data.content
        db.add(existing_note)
        await db.commit()
        await db.refresh(existing_note)
        return existing_note
    else:
        new_note = Note(
            user_id=current_user.id,
            restaurant_id=restaurant_id,
            content=note_data.content
        )
        db.add(new_note)
        await db.commit()
        await db.refresh(new_note)
        return new_note
