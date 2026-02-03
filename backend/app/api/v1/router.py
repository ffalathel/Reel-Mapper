from fastapi import APIRouter
from app.api.v1.endpoints import auth, save_events, data, lists, user_restaurants

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(save_events.router, prefix="/save-events", tags=["save-events"])
api_router.include_router(data.router, tags=["data"])
api_router.include_router(lists.router, prefix="/lists", tags=["lists"])
api_router.include_router(user_restaurants.router, prefix="/user-restaurants", tags=["user-restaurants"])
