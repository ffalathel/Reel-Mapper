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
from app.errors import ErrorMessages

router = APIRouter()

async def _toggle_user_restaurant_flag(
    restaurant_id: UUID,
    field_name: str,
    db: AsyncSession,
    current_user: Any
) -> dict:
    """
    Generic helper to toggle boolean flags on UserRestaurant.

    Args:
        restaurant_id: UUID of the restaurant
        field_name: Name of the boolean field to toggle ("is_favorite" or "is_visited")
        db: Database session
        current_user: Current authenticated user

    Returns:
        Dict with the field name and new boolean value

    Raises:
        HTTPException: 404 if restaurant not saved by user
    """
    # Query for existing UserRestaurant
    stmt = (
        select(UserRestaurant)
        .where(UserRestaurant.restaurant_id == restaurant_id)
        .where(UserRestaurant.user_id == current_user.id)
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if not existing:
        # Restaurant not saved by user - cannot toggle flags
        raise HTTPException(
            status_code=404,
            detail="Restaurant not saved by user"
        )

    # Toggle the field using getattr/setattr for dynamic field access
    current_value = getattr(existing, field_name)
    new_value = not current_value
    setattr(existing, field_name, new_value)

    db.add(existing)
    await db.commit()
    await db.refresh(existing)

    # Return response with field name and new value
    return {field_name: new_value}

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
        raise HTTPException(status_code=404, detail=ErrorMessages.RESOURCE_RESTAURANT_NOT_FOUND)
    return restaurant

@router.post("/{restaurant_id}/favorite", response_model=schemas.FavoriteResponse)
async def toggle_favorite(
    restaurant_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """Toggle favorite status for a restaurant."""
    return await _toggle_user_restaurant_flag(
        restaurant_id=restaurant_id,
        field_name="is_favorite",
        db=db,
        current_user=current_user
    )

@router.post("/{restaurant_id}/visited", response_model=schemas.VisitedResponse)
async def toggle_visited(
    restaurant_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """Toggle visited status for a restaurant."""
    return await _toggle_user_restaurant_flag(
        restaurant_id=restaurant_id,
        field_name="is_visited",
        db=db,
        current_user=current_user
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
