import uuid
from datetime import datetime
from sqlmodel import Field, SQLModel, UniqueConstraint

class Note(SQLModel, table=True):
    __tablename__ = "notes"
    __table_args__ = (
        UniqueConstraint("user_id", "restaurant_id"),
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="users.id")
    restaurant_id: uuid.UUID = Field(foreign_key="restaurants.id")
    content: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
