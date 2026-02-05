from uuid import UUID
from typing import Optional
from pydantic import BaseModel
from datetime import datetime

class RestaurantBase(BaseModel):
    name: str
    latitude: float
    longitude: float
    city: str
    price_range: Optional[str] = None
    google_place_id: Optional[str] = None

class RestaurantRead(RestaurantBase):
    id: UUID
    
    class Config:
        from_attributes = True

class UserRestaurantRead(BaseModel):
    id: UUID
    restaurant: RestaurantRead
    created_at: datetime
    
    class Config:
        from_attributes = True

class FavoriteResponse(BaseModel):
    is_favorite: bool

class VisitedResponse(BaseModel):
    is_visited: bool

class FavoritesListResponse(BaseModel):
    restaurant_ids: list[UUID]

class VisitedListResponse(BaseModel):
    restaurant_ids: list[UUID]
