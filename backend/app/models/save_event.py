import uuid
from datetime import datetime
from enum import Enum
from typing import Optional, TYPE_CHECKING
from sqlmodel import Field, SQLModel, UniqueConstraint, Relationship

if TYPE_CHECKING:
    from .restaurant import Restaurant

class UserRestaurant(SQLModel, table=True):
    __tablename__ = "user_restaurants"
    __table_args__ = (
        UniqueConstraint("user_id", "restaurant_id"),
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="users.id")
    restaurant_id: uuid.UUID = Field(foreign_key="restaurants.id")
    list_id: Optional[uuid.UUID] = Field(default=None, foreign_key="lists.id")
    source_event_id: uuid.UUID = Field(foreign_key="save_events.id")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    restaurant: "Restaurant" = Relationship(sa_relationship_kwargs={"lazy": "selectin"})

class SaveEventStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETE = "complete"
    FAILED = "failed"

class SaveEvent(SQLModel, table=True):
    __tablename__ = "save_events"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="users.id")
    source: str = Field(default="instagram") # Enum in code, string in DB usually fine
    source_url: str
    raw_caption: Optional[str] = None
    target_list_id: Optional[uuid.UUID] = Field(default=None, foreign_key="lists.id")
    status: str = Field(default=SaveEventStatus.PENDING.value)
    error_message: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
