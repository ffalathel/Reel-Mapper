from fastapi.testclient import TestClient
from app.main import app

def test_flow():
    with TestClient(app) as client:
        # 1. Register
        reg_payload = {"email": "sync_test@example.com", "password": "password123"}
        response = client.post("/api/v1/auth/register", json=reg_payload)
        if response.status_code == 400:
            assert response.json()["detail"] == "The user with this username already exists in the system"
        else:
            assert response.status_code == 200
            assert response.json()["email"] == "sync_test@example.com"

        # 2. Login
        login_data = {"username": "sync_test@example.com", "password": "password123"}
        login_res = client.post("/api/v1/auth/login", data=login_data)
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 3. Verify Me
        me_res = client.get("/api/v1/auth/me", headers=headers)
        assert me_res.status_code == 200
        assert me_res.json()["email"] == "sync_test@example.com"
        
        # 4. Save Event
        event_payload = {
            "source_url": "https://instagram.com/p/123",
            "raw_caption": "Sushi Time"
        }
        save_res = client.post("/api/v1/save-events/", json=event_payload, headers=headers)
        assert save_res.status_code == 202
        assert save_res.json()["status"] == "pending"

        # 5. Check Home
        home_res = client.get("/api/v1/home", headers=headers)
        assert home_res.status_code == 200
        data = home_res.json()
        assert isinstance(data["lists"], list)
