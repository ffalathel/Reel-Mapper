import os
import time
import logging
from celery import Celery
from sqlmodel import Session, create_engine, select
from app.core.config import settings
from app.models.save_event import SaveEvent, SaveEventStatus, UserRestaurant
from app.models.restaurant import Restaurant
from app.models.list import List

logger = logging.getLogger(__name__)

# Setup Sync DB
# DATABASE_URL is "postgresql+asyncpg://..."
# We need "postgresql://..." for sync psycopg2
SYNC_DATABASE_URL = settings.DATABASE_URL.replace("+asyncpg", "")
engine = create_engine(SYNC_DATABASE_URL, echo=True)

celery_app = Celery("worker", broker=os.environ.get("REDIS_URL", "redis://localhost:6379/0"))

# celery_app.conf.task_routes = {
#     "app.worker.extract_info": "main-queue",
# }

def get_sync_session():
    with Session(engine) as session:
        yield session

@celery_app.task(acks_late=True)
def extract_info(save_event_id: str):
    with Session(engine) as session:
        # 1. Fetch Save Event
        save_event = session.get(SaveEvent, save_event_id)
        if not save_event:
            logger.error(f"SaveEvent {save_event_id} not found")
            return

        save_event.status = SaveEventStatus.PROCESSING.value
        session.add(save_event)
        session.commit()

        # 2. Extract Logic (Mock/Regex)
        raw = save_event.raw_caption or ""
        # Super basic rule: "Name in City" or just first 2 words
        # Mocking extraction for now
        candidate_name = "Joe's Pizza"
        candidate_city = "New York"
        
        if "Sushi" in raw:
            candidate_name = "Sushi Nakazawa"
            candidate_city = "Tokyo"
        
        # 3. Resolve Restaurant (Job 2 inline or chained)
        # We chain logically here for simplicity in this agent task
        restaurant = resolve_restaurant(session, candidate_name, candidate_city)
        
        # 4. Finalize (Job 3)
        finalize_save(session, save_event, restaurant)

def resolve_restaurant(session: Session, name: str, city: str) -> Restaurant:
    # 1. Check DB for exact match (fuzzy ignored for now)
    stmt = select(Restaurant).where(Restaurant.name == name).where(Restaurant.city == city)
    existing = session.exec(stmt).first()
    if existing:
        return existing
        
    # 2. Not found, mock Google Places API creation
    # In real app, call Google API here
    new_rest = Restaurant(
        name=name,
        city=city,
        latitude=40.7128, # Mock NY
        longitude=-74.0060,
        price_range="$$"
    )
    session.add(new_rest)
    session.commit()
    session.refresh(new_rest)
    return new_rest

def finalize_save(session: Session, save_event: SaveEvent, restaurant: Restaurant):
    # 1. Create UserRestaurant
    # Check duplicate
    stmt = select(UserRestaurant).where(
        UserRestaurant.user_id == save_event.user_id
    ).where(
        UserRestaurant.restaurant_id == restaurant.id
    )

    existing = session.exec(stmt).first()

    if existing:
        # Duplicate detected - mark SaveEvent as complete with note
        logger.info(f"Duplicate detected: user {save_event.user_id}, restaurant {restaurant.id}")
        save_event.status = SaveEventStatus.COMPLETE.value
        save_event.error_message = "Restaurant already saved"
        session.add(save_event)
        session.commit()
        logger.info(f"Marked SaveEvent {save_event.id} as complete (duplicate)")
        return

    # Not a duplicate - create new UserRestaurant
    user_rest = UserRestaurant(
        user_id=save_event.user_id,
        restaurant_id=restaurant.id,
        list_id=save_event.target_list_id,
        source_event_id=save_event.id
    )
    session.add(user_rest)

    # 2. Update status
    save_event.status = SaveEventStatus.COMPLETE.value
    session.add(save_event)
    session.commit()
    logger.debug(f"Finished processing save_event {save_event.id}")
