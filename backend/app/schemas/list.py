from uuid import UUID
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from .restaurant import UserRestaurantRead

class ListBase(BaseModel):
    name: str

class ListCreate(ListBase):
    pass

class ListRead(ListBase):
    id: UUID
    created_at: datetime
    # We might want to include count of restaurants or top 3, but TDD says lists: [...]
    
    class Config:
        from_attributes = True

class HomeResponse(BaseModel):
    lists: List[ListRead]
    unsorted_restaurants: List[UserRestaurantRead]

class ListRestaurantsResponse(BaseModel):
    restaurants: List[UserRestaurantRead]

class AddRestaurantToListRequest(BaseModel):
    restaurant_id: UUID
