"""add cascade delete behavior

Revision ID: f8c3d2e1a4b7
Revises: e4f7a8b9c2d1
Create Date: 2026-02-12 14:30:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'f8c3d2e1a4b7'
down_revision: Union[str, None] = 'e4f7a8b9c2d1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    Add proper cascade delete behavior to all foreign keys.

    Strategy:
    1. Drop existing FK constraints
    2. Recreate with explicit ondelete behavior
    """

    # ============================================
    # UserRestaurant Table (4 FKs)
    # ============================================

    # user_id: CASCADE (user deletion removes saved restaurants)
    op.drop_constraint('user_restaurants_user_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key(
        'user_restaurants_user_id_fkey',
        'user_restaurants', 'users',
        ['user_id'], ['id'],
        ondelete='CASCADE'
    )

    # restaurant_id: RESTRICT (prevent deletion if saved by any user)
    op.drop_constraint('user_restaurants_restaurant_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key(
        'user_restaurants_restaurant_id_fkey',
        'user_restaurants', 'restaurants',
        ['restaurant_id'], ['id'],
        ondelete='RESTRICT'
    )

    # list_id: SET NULL (list deletion moves to "Unsorted")
    op.drop_constraint('user_restaurants_list_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key(
        'user_restaurants_list_id_fkey',
        'user_restaurants', 'lists',
        ['list_id'], ['id'],
        ondelete='SET NULL'
    )

    # source_event_id: RESTRICT (preserve audit trail)
    op.drop_constraint('user_restaurants_source_event_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key(
        'user_restaurants_source_event_id_fkey',
        'user_restaurants', 'save_events',
        ['source_event_id'], ['id'],
        ondelete='RESTRICT'
    )

    # ============================================
    # SaveEvent Table (2 FKs)
    # ============================================

    # user_id: CASCADE (user deletion removes history)
    op.drop_constraint('save_events_user_id_fkey', 'save_events', type_='foreignkey')
    op.create_foreign_key(
        'save_events_user_id_fkey',
        'save_events', 'users',
        ['user_id'], ['id'],
        ondelete='CASCADE'
    )

    # target_list_id: SET NULL (preserve event when list deleted)
    op.drop_constraint('save_events_target_list_id_fkey', 'save_events', type_='foreignkey')
    op.create_foreign_key(
        'save_events_target_list_id_fkey',
        'save_events', 'lists',
        ['target_list_id'], ['id'],
        ondelete='SET NULL'
    )

    # ============================================
    # Note Table (2 FKs)
    # ============================================

    # user_id: CASCADE (user deletion removes notes)
    op.drop_constraint('notes_user_id_fkey', 'notes', type_='foreignkey')
    op.create_foreign_key(
        'notes_user_id_fkey',
        'notes', 'users',
        ['user_id'], ['id'],
        ondelete='CASCADE'
    )

    # restaurant_id: CASCADE (restaurant deletion removes notes)
    op.drop_constraint('notes_restaurant_id_fkey', 'notes', type_='foreignkey')
    op.create_foreign_key(
        'notes_restaurant_id_fkey',
        'notes', 'restaurants',
        ['restaurant_id'], ['id'],
        ondelete='CASCADE'
    )

    # ============================================
    # List Table (1 FK)
    # ============================================

    # user_id: CASCADE (user deletion removes lists)
    op.drop_constraint('lists_user_id_fkey', 'lists', type_='foreignkey')
    op.create_foreign_key(
        'lists_user_id_fkey',
        'lists', 'users',
        ['user_id'], ['id'],
        ondelete='CASCADE'
    )


def downgrade() -> None:
    """
    Revert to default RESTRICT behavior on all FKs.
    """

    # UserRestaurant Table
    op.drop_constraint('user_restaurants_user_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key('user_restaurants_user_id_fkey', 'user_restaurants', 'users', ['user_id'], ['id'])

    op.drop_constraint('user_restaurants_restaurant_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key('user_restaurants_restaurant_id_fkey', 'user_restaurants', 'restaurants', ['restaurant_id'], ['id'])

    op.drop_constraint('user_restaurants_list_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key('user_restaurants_list_id_fkey', 'user_restaurants', 'lists', ['list_id'], ['id'])

    op.drop_constraint('user_restaurants_source_event_id_fkey', 'user_restaurants', type_='foreignkey')
    op.create_foreign_key('user_restaurants_source_event_id_fkey', 'user_restaurants', 'save_events', ['source_event_id'], ['id'])

    # SaveEvent Table
    op.drop_constraint('save_events_user_id_fkey', 'save_events', type_='foreignkey')
    op.create_foreign_key('save_events_user_id_fkey', 'save_events', 'users', ['user_id'], ['id'])

    op.drop_constraint('save_events_target_list_id_fkey', 'save_events', type_='foreignkey')
    op.create_foreign_key('save_events_target_list_id_fkey', 'save_events', 'lists', ['target_list_id'], ['id'])

    # Note Table
    op.drop_constraint('notes_user_id_fkey', 'notes', type_='foreignkey')
    op.create_foreign_key('notes_user_id_fkey', 'notes', 'users', ['user_id'], ['id'])

    op.drop_constraint('notes_restaurant_id_fkey', 'notes', type_='foreignkey')
    op.create_foreign_key('notes_restaurant_id_fkey', 'notes', 'restaurants', ['restaurant_id'], ['id'])

    # List Table
    op.drop_constraint('lists_user_id_fkey', 'lists', type_='foreignkey')
    op.create_foreign_key('lists_user_id_fkey', 'lists', 'users', ['user_id'], ['id'])
