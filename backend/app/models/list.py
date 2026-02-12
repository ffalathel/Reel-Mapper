import uuid
from datetime import datetime
from sqlmodel import Field, SQLModel
from sqlalchemy import Column, ForeignKey as SA_ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

class List(SQLModel, table=True):
    __tablename__ = "lists"
    # NOTE: Case-insensitive uniqueness enforced by idx_lists_user_id_lower_name_unique index
    # The functional index on LOWER(name) is managed via Alembic migration (cannot be expressed in SQLModel)
    # Application layer also validates via func.lower() for clear error messages

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)

    # CASCADE: User deletion removes their lists
    user_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), SA_ForeignKey("users.id", ondelete="CASCADE"))
    )

    name: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
