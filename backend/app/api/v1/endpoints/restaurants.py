from typing import Any
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.api import deps
from app import schemas
from app.models.restaurant import Restaurant
from app.models.save_event import UserRestaurant
from app.models.note import Note

router = APIRouter()

@router.get("/{restaurant_id}", response_model=schemas.RestaurantRead)
async def get_restaurant(
    restaurant_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    stmt = select(Restaurant).where(Restaurant.id == restaurant_id)
    result = await db.execute(stmt)
    restaurant = result.scalar_one_or_none()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant

@router.post("/{restaurant_id}/favorite", response_model=schemas.FavoriteResponse)
async def toggle_favorite(
    restaurant_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    # Check if exists
    stmt = (
        select(UserRestaurant)
        .where(UserRestaurant.restaurant_id == restaurant_id)
        .where(UserRestaurant.user_id == current_user.id)
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        existing.is_favorite = not existing.is_favorite
        db.add(existing)
        await db.commit()
        await db.refresh(existing)
        return {"is_favorite": existing.is_favorite}
    else:
        # Restaurant not saved by user
        raise HTTPException(
            status_code=404,
            detail="Restaurant not saved by user"
        )

@router.post("/{restaurant_id}/visited", response_model=schemas.VisitedResponse)
async def toggle_visited(
    restaurant_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    # Check if exists
    stmt = (
        select(UserRestaurant)
        .where(UserRestaurant.restaurant_id == restaurant_id)
        .where(UserRestaurant.user_id == current_user.id)
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        existing.is_visited = not existing.is_visited
        db.add(existing)
        await db.commit()
        await db.refresh(existing)
        return {"is_visited": existing.is_visited}
    else:
        # Restaurant not saved by user
        raise HTTPException(
            status_code=404,
            detail="Restaurant not saved by user"
        )

@router.put("/{restaurant_id}/notes")
async def save_notes(
    restaurant_id: UUID,
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
