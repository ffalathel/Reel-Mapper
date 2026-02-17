# Reel Mapper

> **Status: Work in Progress** — This project is under active development. Features may be incomplete, APIs may change, and bugs are expected.

Reel Mapper lets you save restaurants you discover on Instagram Reels, organize them into folders, and navigate to them via Google Maps. Share a Reel, and the app extracts the restaurant details so you never lose track of a place you wanted to try.

## How It Works

1. **Share or paste** an Instagram Reel link into the app
2. The backend **extracts** the restaurant name and location
3. **Organize** saved restaurants into folders, mark favorites, or flag places you've visited
4. **Navigate** with one tap via Google Maps

## Architecture

| Layer | Stack |
|-------|-------|
| **iOS App** | SwiftUI, MVVM, Clerk Auth |
| **Backend API** | FastAPI, PostgreSQL, SQLModel |
| **Background Jobs** | Celery + Redis |
| **Infrastructure** | AWS EC2, RDS, GitHub Actions CI/CD |

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│   iOS App    │──────▶│  FastAPI      │──────▶│  PostgreSQL  │
│   (SwiftUI)  │       │  (EC2)       │       │  (RDS)       │
└──────────────┘       └──────┬───────┘       └──────────────┘
                              │
                       ┌──────▼───────┐
                       │  Celery      │
                       │  Worker      │
                       │  + Redis     │
                       └──────────────┘
```

## Project Structure

```
Reel Mapper/
├── Reel Mapper/          # iOS app (SwiftUI)
│   ├── Views/            # UI screens
│   ├── ViewModels/       # Business logic
│   ├── Models/           # Data models
│   ├── Managers/         # State managers (Auth, Favorites)
│   └── Networking/       # API client
├── ShareExtension/       # iOS Share Extension for Instagram
├── backend/
│   ├── app/
│   │   ├── api/v1/       # REST endpoints
│   │   └── worker.py     # Celery background tasks
│   ├── alembic/          # Database migrations
│   └── requirements.txt
└── .github/workflows/    # CI/CD pipeline
```

## Current State

### Working
- User authentication (Clerk)
- Save restaurants via Instagram URL
- Folder creation and organization
- Favorite and visited toggles
- Google Maps navigation
- CI/CD auto-deploy on push to `main`

### In Progress
- Restaurant extraction from Instagram Reels (currently using mock/placeholder logic)
- Consensus-based extraction pipeline (multi-source: caption parsing, audio transcription, OCR)

## Development

### Backend

```bash
cd backend
pip install -r requirements.txt
# Set DATABASE_URL, REDIS_URL, CLERK_SECRET_KEY in .env
uvicorn app.main:app --reload
```

### iOS

Open `Reel Mapper.xcodeproj` in Xcode and run on a simulator or device.

## License

This project is not yet licensed for public use.
