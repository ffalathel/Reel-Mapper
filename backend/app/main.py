from fastapi import FastAPI
from app.api.v1.router import api_router

app = FastAPI(title="Reel Mapper API")

app.include_router(api_router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {"message": "Welcome to Reel Mapper API"}
