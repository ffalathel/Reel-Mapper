import uuid
from datetime import datetime
from sqlmodel import Field, SQLModel, UniqueConstraint

class List(SQLModel, table=True):
    __tablename__ = "lists"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="unique_user_list_name"), # We need to handle lower(name) in app logic or raw sql migration
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="users.id")
    name: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
