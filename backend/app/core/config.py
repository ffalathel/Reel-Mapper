from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    PROJECT_NAME: str = "Reel Mapper"
    DATABASE_URL: str
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REDIS_URL: str = "redis://localhost:6379/0"
    ENVIRONMENT: str = "development"
    
    # Clerk Authentication - Set these in your .env file
    CLERK_JWKS_URL: str = ""  # e.g. https://your-instance.clerk.accounts.dev/.well-known/jwks.json
    CLERK_JWT_ISSUER: str = ""  # e.g. https://your-instance.clerk.accounts.dev

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

