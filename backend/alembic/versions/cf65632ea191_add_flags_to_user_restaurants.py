"""add_flags_to_user_restaurants

Revision ID: cf65632ea191
Revises: create_notes_table
Create Date: 2026-02-05 22:16:49.928071

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = 'cf65632ea191'
down_revision: Union[str, None] = 'create_notes_table'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('user_restaurants', sa.Column('is_favorite', sa.Boolean(), server_default=sa.text('false'), nullable=False))
    op.add_column('user_restaurants', sa.Column('is_visited', sa.Boolean(), server_default=sa.text('false'), nullable=False))


def downgrade() -> None:
    op.drop_column('user_restaurants', 'is_visited')
    op.drop_column('user_restaurants', 'is_favorite')
