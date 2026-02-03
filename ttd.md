Technical Design Document (TDD)
Project: Instagram Reels → Restaurant Saver (iOS + Backend)
1. Purpose
This document translates the PRD into a fully actionable technical design. It is written for coding agents
and engineers to implement independently with minimal ambiguity.
Goals: - Define system architecture - Specify data models and schemas - Define API contracts - Define async
job workflows - Specify iOS integration points - Establish non-functional requirements and guardrails
2. System Architecture Overview
Components
1.
2.
3.
iOS App
Main app (Swift / SwiftUI)
Share Extension (Instagram ingestion)
4.
Backend API
5.
6.
REST API (FastAPI or similar)
Auth middleware
7.
Async Processing System
8.
9.
Background workers
Job queue (e.g., Redis + worker)
10.
Database
11.
PostgreSQL
12.
External Services
13.
14.
15.
Instagram (share URL only; no API dependency)
Google Places API
Google Maps deep linking
1
3. Data Model & Database Schema
3.1 Users
users
- id (uuid, pk)
- email
- created_at
3.2 Restaurants (Global Canonical Entity)
restaurants
- id (uuid, pk)
- name (text)
- latitude (float)
- longitude (float)
- city (text)
- price_range (text, nullable)
- google_place_id (text, nullable, unique)
- created_at
Indexes: - (google_place_id) - (lower(name), city)
3.3 User Lists
lists
- id (uuid, pk)
- user_id (fk → users.id)
- name (text)
- created_at
Constraints: - (user_id, lower(name)) unique
3.4 User Saved Restaurants
user_restaurants
- id (uuid, pk)
- user_id (fk)
2
- restaurant_id (fk)
- list_id (fk, nullable)
- source_event_id (fk)
- created_at
Constraints: - (user_id, restaurant_id) unique
3.5 Save Events (Ingestion Layer)
save_events
- id (uuid, pk)
- user_id (fk)
- source (enum: instagram)
- source_url (text)
- raw_caption (text, nullable)
- target_list_id (fk, nullable)
- status (enum: pending | processing | complete | failed)
- error_message (text, nullable)
- created_at
4. API Design
4.1 Auth
•
•
JWT-based auth
All endpoints require auth except health checks
4.2 Save Event Creation (iOS Share Extension)
POST /save-events
Request:
{
"source_url": "https://instagram.com/reel/...",
"raw_caption": "Amazing sushi spot in NYC",
"target_list_id": "uuid | null"
}
Response:
3
{ "status": "accepted" }
Behavior: - Create save_event - Enqueue extraction job - Return immediately
4.3 Fetch Homepage Data
GET /home
Response:
{
"lists": [...],
"unsorted_restaurants": [...]
}
4.4 Restaurant Detail
GET /restaurants/{id}
4.5 Mutations
•
•
•
•
POST /lists
POST /lists/{id}/restaurants
DELETE /user-restaurants/{id}
POST /restaurants/{id}/export/google-maps
5. Async Job Design
5.1 Job: Extract Restaurant Info
Input: - save_event_id
Steps: 1. Fetch save_event 2. Parse caption + URL metadata 3. Run NLP extraction 4. Output candidate name
+ location
Output:
4
extraction_result
- candidate_name
- candidate_city
- confidence_score
5.2 Job: Resolve Restaurant
Logic: - Check existing restaurants by google_place_id - Fuzzy match name + city - Create new restaurant if
needed
5.3 Job: Finalize Save
Steps: 1. Create user_restaurant 2. Assign list if present 3. Update save_event status → complete
Idempotency: - Jobs must be retry-safe - Use unique constraints to prevent duplicates
6. iOS App Technical Design
6.1 Share Extension
Responsibilities: - Receive shared content - Extract URL + caption - Call POST /save-events
Constraints: - Must complete within extension time limits
6.2 Main App
Screens: - Home - List Detail - Restaurant Detail
State Management: - Poll backend for save completion - Optimistically show "Processing" placeholder
7. Google Maps Integration
Approach: - Backend resolves google_place_id - iOS app deep links using: comgooglemaps://?
q=place_id:{id}
No bi-directional sync.
5
8. Non-Functional Requirements
•
•
•
•
Async jobs must be idempotent
API p95 latency < 300ms
Save flow must never block UI
Graceful failure with retry
9. Agent Execution Guidelines
•
•
•
•
•
•
•
•
Do not add features outside this document
Backend agents own:
API
DB
Jobs
iOS agents own:
Share Extension
UI state handling
All assumptions must be documented before implementation.
10. Out of Scope (Explicit)
•
•
•
•
Social features
Restaurant reviews
Auto-sync with Google Maps
Android app
End of Document
6