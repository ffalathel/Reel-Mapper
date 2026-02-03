"""initial schema

Revision ID: 202401270001
Revises: 
Create Date: 2024-01-27 20:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '202401270001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Users
    op.create_table('users',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('email', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('hashed_password', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    # Restaurants
    op.create_table('restaurants',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('name', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('city', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('price_range', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('google_place_id', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_restaurants_google_place_id'), 'restaurants', ['google_place_id'], unique=True)
    op.create_index('ix_restaurants_lower_name_city', 'restaurants', ['name', 'city'], unique=False) # Note: Functional index typically requires raw sql or func, keeping simple for now as per model

    # Lists
    op.create_table('lists',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('name', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'name', name='unique_user_list_name')
    )

    # SaveEvents
    op.create_table('save_events',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('source', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('source_url', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('raw_caption', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('target_list_id', sa.UUID(), nullable=True),
        sa.Column('status', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('error_message', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['target_list_id'], ['lists.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )

    # UserRestaurants
    op.create_table('user_restaurants',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('restaurant_id', sa.UUID(), nullable=False),
        sa.Column('list_id', sa.UUID(), nullable=True),
        sa.Column('source_event_id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['list_id'], ['lists.id'], ),
        sa.ForeignKeyConstraint(['restaurant_id'], ['restaurants.id'], ),
        sa.ForeignKeyConstraint(['source_event_id'], ['save_events.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'restaurant_id', name='unique_user_restaurant')
    )


def downgrade() -> None:
    op.drop_table('user_restaurants')
    op.drop_table('save_events')
    op.drop_table('lists')
    op.drop_index('ix_restaurants_lower_name_city', table_name='restaurants')
    op.drop_index(op.f('ix_restaurants_google_place_id'), table_name='restaurants')
    op.drop_table('restaurants')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')
