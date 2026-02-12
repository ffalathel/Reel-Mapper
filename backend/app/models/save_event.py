import uuid
from datetime import datetime
from enum import Enum
from typing import Optional, TYPE_CHECKING
from sqlmodel import Field, SQLModel, UniqueConstraint, Relationship
from sqlalchemy import Column, ForeignKey as SA_ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

if TYPE_CHECKING:
    from .restaurant import Restaurant

class UserRestaurant(SQLModel, table=True):
    __tablename__ = "user_restaurants"
    __table_args__ = (
        UniqueConstraint("user_id", "restaurant_id"),
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)

    # CASCADE: User deletion removes all their saved restaurants
    user_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("users.id", ondelete="CASCADE"))
    )

    # RESTRICT: Prevent restaurant deletion if saved by any user
    restaurant_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("restaurants.id", ondelete="RESTRICT"))
    )

    # SET NULL: List deletion moves to "Unsorted"
    list_id: Optional[uuid.UUID] = Field(
        default=None,
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("lists.id", ondelete="SET NULL"), nullable=True)
    )

    # RESTRICT: Preserve audit trail
    source_event_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("save_events.id", ondelete="RESTRICT"))
    )

    is_favorite: bool = Field(default=False)
    is_visited: bool = Field(default=False)
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

    # CASCADE: User deletion removes their history
    user_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("users.id", ondelete="CASCADE"))
    )

    source: str = Field(default="instagram") # Enum in code, string in DB usually fine
    source_url: str
    raw_caption: Optional[str] = None

    # SET NULL: Preserve event when list deleted
    target_list_id: Optional[uuid.UUID] = Field(
        default=None,
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("lists.id", ondelete="SET NULL"), nullable=True)
    )

    status: str = Field(default=SaveEventStatus.PENDING.value)
    error_message: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
