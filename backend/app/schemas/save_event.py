from uuid import UUID
from typing import Optional
from pydantic import BaseModel, HttpUrl

class SaveEventBase(BaseModel):
    source_url: HttpUrl
    raw_caption: Optional[str] = None
    target_list_id: Optional[UUID] = None

class SaveEventCreate(SaveEventBase):
    pass

class SaveEventRead(SaveEventBase):
    id: UUID
    status: str
    
    class Config:
        from_attributes = True
