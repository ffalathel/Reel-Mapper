"""add_case_insensitive_list_name_constraint

Revision ID: e4f7a8b9c2d1
Revises: cf65632ea191
Create Date: 2026-02-12 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e4f7a8b9c2d1'
down_revision: Union[str, None] = 'cf65632ea191'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop old case-sensitive constraint
    op.drop_constraint('unique_user_list_name', 'lists', type_='unique')

    # Create case-insensitive unique index on LOWER(name)
    op.create_index(
        'idx_lists_user_id_lower_name_unique',
        'lists',
        [sa.text('user_id'), sa.text('LOWER(name)')],
        unique=True,
        postgresql_using='btree'
    )


def downgrade() -> None:
    # Restore original case-sensitive constraint
    op.drop_index('idx_lists_user_id_lower_name_unique', table_name='lists')

    op.create_unique_constraint(
        'unique_user_list_name',
        'lists',
        ['user_id', 'name']
    )
