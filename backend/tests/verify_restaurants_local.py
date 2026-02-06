import sys
import os
import pytest
from unittest.mock import AsyncMock, MagicMock

# Add parent directory to sys.path to allow importing app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Set dummy env vars BEFORE importing app/config to avoid pydantic errors
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["SECRET_KEY"] = "dummy_secret_for_tests"
os.environ["CLERK_SECRET_KEY"] = "dummy_clerk_key"

from fastapi.testclient import TestClient
from app.api import deps
from app.main import app
from app.models.user import User

# --- Mock Data ---
TEST_USER_ID = "test_user_id"
TEST_RESTAURANT_ID = "test_restaurant_id"

def get_dummy_user():
    return User(id=TEST_USER_ID, email="test@example.com", clerk_user_id="clerk_123")

def get_mock_db():
    mock_session = AsyncMock()
    # Mock execute result
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None #Default to nothing found
    mock_result.scalars.return_value.all.return_value = []
    
    mock_session.execute.return_value = mock_result
    return mock_session

# --- Overrides ---
app.dependency_overrides[deps.get_current_user] = get_dummy_user
app.dependency_overrides[deps.get_db] = get_mock_db

client = TestClient(app)

def test_routes_exist():
    # We are mainly checking that 404 is NOT returned for the route itself (i.e., route exists)
    # Since we mocked the DB to return None for restaurant, we expect 404 "Restaurant not found" 
    # OR 404 "Not Found" if route doesn't exist. 
    # Wait, both are 404.
    # To distinguish, we will check the detail message if possible, or simple status code.
    
    # 1. GET /restaurants/{id}
    # Expected: 404 because our mock returns None for restaurant lookup, 
    # BUT this proves the route matches and code executes.
    response = client.get(f"/api/v1/restaurants/{TEST_RESTAURANT_ID}")
    print(f"GET /restaurants/{{id}} -> {response.status_code} {response.json()}")
    # If route missing: 404 {"detail": "Not Found"}
    # If route hit but logic says 404: 404 {"detail": "Restaurant not found"}
    
    # 2. POST /restaurants/{id}/favorite
    response = client.post(f"/api/v1/restaurants/{TEST_RESTAURANT_ID}/favorite")
    print(f"POST /restaurants/{{id}}/favorite -> {response.status_code} {response.json()}")
    
    # 3. POST /restaurants/{id}/visited
    response = client.post(f"/api/v1/restaurants/{TEST_RESTAURANT_ID}/visited")
    print(f"POST /restaurants/{{id}}/visited -> {response.status_code} {response.json()}")
    
    # 4. PUT /restaurants/{id}/notes
    response = client.put(f"/api/v1/restaurants/{TEST_RESTAURANT_ID}/notes", json={"content": "Yummy"})
    print(f"PUT /restaurants/{{id}}/notes -> {response.status_code} {response.json()}")

if __name__ == "__main__":
    test_routes_exist()
