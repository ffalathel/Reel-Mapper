import uuid
from datetime import datetime
from typing import Optional
from sqlmodel import Field, SQLModel, Index, UniqueConstraint

class Restaurant(SQLModel, table=True):
    __tablename__ = "restaurants"
    __table_args__ = (
        Index("ix_restaurants_lower_name_city", "name", "city"), # Approximate lower index logic needed in raw SQL or handled via collation but simple index for now
        UniqueConstraint("google_place_id"),
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    name: str
    latitude: float
    longitude: float
    city: str
    price_range: Optional[str] = None
    google_place_id: Optional[str] = Field(default=None, unique=True, index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    # user_restaurants: List["UserRestaurant"] = Relationship(back_populates="restaurant") 
    # Commented out to avoid circular import complexity for now if not strictly needed for access pattern
    # Actually, for UserRestaurant -> Restaurant loading we need it on UserRestaurant side mostly.
