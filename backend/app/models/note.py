import uuid
from datetime import datetime
from sqlmodel import Field, SQLModel, UniqueConstraint
from sqlalchemy import Column, ForeignKey as SA_ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

class Note(SQLModel, table=True):
    __tablename__ = "notes"
    __table_args__ = (
        UniqueConstraint("user_id", "restaurant_id"),
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)

    # CASCADE: User deletion removes their notes
    user_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("users.id", ondelete="CASCADE"))
    )

    # CASCADE: Restaurant deletion removes associated notes
    restaurant_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("restaurants.id", ondelete="CASCADE"))
    )

    content: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
