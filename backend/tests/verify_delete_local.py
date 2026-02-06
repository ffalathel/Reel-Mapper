import sys
import os
import pytest
from unittest.mock import AsyncMock, MagicMock

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Set dummy env vars BEFORE importing app
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["SECRET_KEY"] = "dummy_secret_for_tests"
os.environ["CLERK_SECRET_KEY"] = "dummy_clerk_key"

from fastapi.testclient import TestClient
from app.api import deps
from app.main import app
from app.models.user import User

# --- Mock Data ---
TEST_USER_ID = "test_user_id"
TEST_LIST_ID = "test_list_id"
TEST_RESTAURANT_ID = "test_restaurant_id"

def get_dummy_user():
    return User(id=TEST_USER_ID, email="test@example.com", clerk_user_id="clerk_123")

def get_mock_db():
    mock_session = AsyncMock()
    mock_result = MagicMock()
    # Return a dummy object so 404 check passes
    mock_item = MagicMock()
    mock_item.id = "found_id"
    
    mock_result.scalar_one_or_none.return_value = mock_item
    mock_result.scalars.return_value.all.return_value = [] # For associated items
    
    mock_session.execute.return_value = mock_result
    return mock_session

app.dependency_overrides[deps.get_current_user] = get_dummy_user
app.dependency_overrides[deps.get_db] = get_mock_db

client = TestClient(app)

def test_delete_endpoints():
    print("\n--- Testing DELETE endpoints ---")
    
    # 1. DELETE /lists/{id}
    print("Testing DELETE /lists/{id}...")
    response_list = client.delete(f"/api/v1/lists/{TEST_LIST_ID}")
    print(f"Response: {response_list.status_code}")
    assert response_list.status_code == 204 or response_list.status_code == 200
    
    # 3. Test DELETE /user-restaurants/restaurant/{restaurant_id}
    print(f"Testing DELETE /user-restaurants/restaurant/{TEST_RESTAURANT_ID}...")
    response_del_rest = client.delete(f"/api/v1/user-restaurants/restaurant/{TEST_RESTAURANT_ID}")
    
    if response_del_rest.status_code == 200 or response_del_rest.status_code == 204:
        print(f"Response: {response_del_rest.status_code}")
    else:
        print(f"Failed: {response_del_rest.status_code}")
        print(response_del_rest.json())
        sys.exit(1)
    
    # 2. DELETE /user-restaurants/{id}
    # Note: the endpoint is defined in user_restaurants.py as DELETE /{id}
    # And router.py includes it with prefix="/user-restaurants"
    print("Testing DELETE /user-restaurants/{id}...")
    response_rest = client.delete(f"/api/v1/user-restaurants/{TEST_RESTAURANT_ID}")
    print(f"Response: {response_rest.status_code}")
    assert response_rest.status_code == 200 or response_rest.status_code == 204

if __name__ == "__main__":
    test_delete_endpoints()
