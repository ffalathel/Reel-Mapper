import uuid
from datetime import datetime
from sqlmodel import Field, SQLModel

class List(SQLModel, table=True):
    __tablename__ = "lists"
    # NOTE: Case-insensitive uniqueness enforced by idx_lists_user_id_lower_name_unique index
    # The functional index on LOWER(name) is managed via Alembic migration (cannot be expressed in SQLModel)
    # Application layer also validates via func.lower() for clear error messages

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="users.id")
    name: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
