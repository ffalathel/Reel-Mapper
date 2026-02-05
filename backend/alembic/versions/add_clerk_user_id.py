"""Add clerk_user_id to users table

Revision ID: add_clerk_user_id
Revises: 
Create Date: 2026-02-05

This migration adds the clerk_user_id column to the users table to support
Clerk authentication. Existing users will have NULL clerk_user_id until they
log in with Clerk, at which point the column will be populated via email matching.
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_clerk_user_id'
down_revision = '202401270001'  # Links to existing migration
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add clerk_user_id column
    op.add_column('users', sa.Column('clerk_user_id', sa.String(255), nullable=True))
    
    # Add unique constraint and index
    op.create_unique_constraint('uq_users_clerk_user_id', 'users', ['clerk_user_id'])
    op.create_index('idx_users_clerk_id', 'users', ['clerk_user_id'])
    
    # Add name column
    op.add_column('users', sa.Column('name', sa.String(100), nullable=True))
    
    # Make hashed_password nullable for Clerk users
    op.alter_column('users', 'hashed_password',
                    existing_type=sa.String(255),
                    nullable=True)


def downgrade() -> None:
    # Remove name column
    op.drop_column('users', 'name')
    
    # Remove clerk_user_id column and its constraints
    op.drop_index('idx_users_clerk_id', table_name='users')
    op.drop_constraint('uq_users_clerk_user_id', 'users', type_='unique')
    op.drop_column('users', 'clerk_user_id')
    
    # Make hashed_password required again
    op.alter_column('users', 'hashed_password',
                    existing_type=sa.String(255),
                    nullable=False)
