from datetime import datetime
from typing import Optional
import uuid
from sqlmodel import SQLModel

class NoteBase(SQLModel):
    content: str
    
class NoteUpdate(NoteBase):
    pass

class NoteRead(NoteBase):
    id: uuid.UUID
    user_id: uuid.UUID
    restaurant_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
