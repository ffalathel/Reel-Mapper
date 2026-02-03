from typing import Any
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.api import deps
from app import schemas
from app.models.save_event import SaveEvent, SaveEventStatus
from app.worker import extract_info

router = APIRouter()

@router.post("/", response_model=schemas.SaveEventRead, status_code=202)
async def create_save_event(
    *,
    db: AsyncSession = Depends(deps.get_db),
    save_event_in: schemas.SaveEventCreate,
    current_user: Any = Depends(deps.get_current_user),
) -> Any:
    """
    Create new save event and enqueue extraction job.
    """
    # 1. Create DB record
    save_event = SaveEvent(
        user_id=current_user.id,
        source="instagram",
        source_url=str(save_event_in.source_url),
        raw_caption=save_event_in.raw_caption,
        target_list_id=save_event_in.target_list_id,
        status=SaveEventStatus.PENDING,
    )
    db.add(save_event)
    await db.commit()
    await db.refresh(save_event)

    # 2. Enqueue Job
    extract_info.delay(str(save_event.id))
    
    return save_event
