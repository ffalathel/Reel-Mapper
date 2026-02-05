import uuid
from datetime import datetime
from typing import Optional
from sqlmodel import Field, SQLModel

class User(SQLModel, table=True):
    __tablename__ = "users"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    clerk_user_id: Optional[str] = Field(default=None, unique=True, index=True)  # Clerk's user ID from sub claim
    email: str = Field(index=True, unique=True)
    name: Optional[str] = Field(default=None)  # From Clerk custom claims
    hashed_password: Optional[str] = Field(default=None)  # Optional - Clerk handles passwords for new users
    created_at: datetime = Field(default_factory=datetime.utcnow)

