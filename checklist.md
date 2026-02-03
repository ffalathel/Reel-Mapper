OSTA
Complete Build Checklist
Backend + Frontend + Integrations
iOS Share Extension → Backend → Google Places → SwiftUI
February 2026
I. DATA MODEL
These are the database tables your backend must create and manage. This is your source of truth.
1. User
☐ Create users table
☐ Support account creation
☐ Support authentication (sign in / sign out)
☐ Associate saved restaurants with a user
Field Notes
user_id PK
name Display name
email Unique, used for auth
created_at Timestamp
2. Restaurant
☐ Create restaurants table
☐ Populate primarily from Google Places API
☐ Deduplicate by google_place_id before inserting
Field Notes
restaurant_id PK
google_place_id Unique — used for deduplication
name Restaurant name
address Full street address
city City
state State abbreviation
latitude Float
longitude Float
price_range $$, $$$, etc.
rating Float (e.g. 4.2)
review_count Integer
primary_photo_url Cover image URL
created_at Timestamp
3. UserSavedRestaurant
Links users to restaurants. Includes status for Favorites/Visited.
☐ Create user_saved_restaurants table
☐ Default status = 'saved' on every new save
☐ Support status transitions: saved → favorite → visited (and back)
Field Notes
user_id FK → User
restaurant_id FK → Restaurant
saved_from Instagram URL (source link)
saved_at Timestamp
status ENUM: 'saved' | 'favorite' | 'visited' — default 'saved'
folder_id Nullable FK → Folder
4. Folders (Optional)
For organizing into groups like "Best Italian", "LA Spots", etc.
☐ Create folders table
☐ Create folder_restaurants join table
Field Notes
folder_id PK
user_id FK → User
name Folder name
cover_image_url Nullable
created_at Timestamp
Field Notes
folder_id FK → Folder
restaurant_id FK → Restaurant
5. Notes
☐ Create notes table
☐ Support upsert (create or update)
Field Notes
note_id PK
user_id FK → User
restaurant_id FK → Restaurant
content Free text
updated_at Timestamp
6. TopDish (Later Phase)
☐ Create top_dishes table (Phase 6)
Field Notes
restaurant_id FK → Restaurant
dish_name Extracted dish name
mentions_count Frequency in reviews
II. BACKEND APIs
REST endpoints your server must expose. Every endpoint requires the authenticated user_id from
JWT/session.
A. Authentication
☐ Implement signup endpoint
☐ Implement login endpoint
☐ Implement logout endpoint
☐ JWT or session-based auth on all protected routes
POST /auth/signup
Create new user account
POST /auth/login
Authenticate and return token
POST /auth/logout
Invalidate session/token
B. Save from Instagram (Core Flow)
This is the most important endpoint. It powers the entire save pipeline.
☐ Implement endpoint
☐ Extract restaurant name from Instagram post/caption
☐ Search Google Places for matching restaurant
☐ Fetch name, address, rating, price range, photos, coordinates
☐ Create Restaurant record in DB (if not already exists — deduplicate by google_place_id)
☐ Insert into UserSavedRestaurant with status = 'saved'
☐ (Optional) Pre-fetch and cache photos to S3 / Supabase Storage
☐ (Optional) Send push notification / set new-item flag
POST /restaurants/save-from-instagram
Body: { instagram_url }
Backend Pipeline (step by step):
☐ Step 1 — Receive Instagram URL
☐ Step 2 — Parse/scrape caption, extract restaurant name
☐ Step 3 — Search Google Places (name + city if available)
☐ Step 4 — Check DB: SELECT * FROM restaurants WHERE google_place_id = ?
☐ Step 5 — If not found, create new Restaurant record
☐ Step 6 — Insert into UserSavedRestaurant
☐ Step 7 — (Optional) Pre-fetch photos, notify app
C. Homepage Data
☐ Implement homepage endpoint
☐ Return three sections: favorites, visited, saved
☐ Sort each section by saved_at DESC (newest first)
☐ Include folders list (optional)
GET /users/{user_id}/homepage
Returns grouped restaurant lists + folders
Response shape:
{
"favorites": [ ...restaurants... ],
"visited": [ ...restaurants... ],
"saved": [ ...restaurants... ],
"folders": [ ...folders... ]
}
Each restaurant object must include: restaurant_id, name, city, state, price_range, rating,
primary_photo_url, status.
D. Update Restaurant Status
Move restaurants between Saved, Favorite, and Visited.
☐ Implement mark-as-favorite endpoint
☐ Implement mark-as-visited endpoint
☐ Implement unsort (back to saved) endpoint
POST /restaurants/{restaurant_id}/favorite
SET status = 'favorite'
POST /restaurants/{restaurant_id}/visited
SET status = 'visited'
POST /restaurants/{restaurant_id}/unsort
SET status = 'saved'
E. Restaurant Detail
☐ Implement restaurant detail endpoint
☐ Return full details including user notes and status
GET /restaurants/{restaurant_id}
Full restaurant details + photos + top dishes + notes + status
Response shape:
{
"restaurant_id": "...",
"name": "Catch LA",
"rating": 4.2,
"review_count": 4217,
"price_range": "$$$",
"city": "Los Angeles",
"state": "CA",
"latitude": 34.05,
"longitude": -118.24,
"photos": [ ... ],
"top_dishes": [ ... ],
"user_notes": "Best for birthdays",
"status": "saved" | "favorite" | "visited"
}
F. Notes
☐ Implement notes upsert endpoint
POST /restaurants/{restaurant_id}/notes
Body: { content } — create or update
G. Folders (Optional)
☐ Implement create folder
☐ Implement add restaurant to folder
☐ Implement remove restaurant from folder
POST /folders
Create new folder
POST /folders/{folder_id}/add-restaurant
Link restaurant to folder
POST /folders/{folder_id}/remove-restaurant
Unlink restaurant from folder
III. EXTERNAL SERVICES & INTEGRATIONS
1. Google Places API (Required)
☐ Obtain API key
☐ Integrate Places Search (text search by restaurant name)
☐ Integrate Place Details (full info by place_id)
☐ Integrate Place Photos (fetch photo URLs / blobs)
Used for: restaurant matching, ratings, review count, photos, coordinates, price range.
2. Yelp API (Optional, Later Phase)
☐ Integrate for richer photo coverage
☐ Integrate for "top dishes" review text extraction
3. Apple Maps / Google Maps (Frontend)
☐ Open Apple Maps or Google Maps from lat/long on button tap
☐ Use MapKit in SwiftUI (already wired)
4. Image Storage
☐ Set up S3 or Supabase Storage bucket
☐ Cache Google Places photos to avoid repeated API calls
☐ Return optimized image URLs to frontend
5. Push Notifications (APNs)
☐ Configure APNs certificates/keys
☐ Backend triggers notification after successful save
☐ Example: "Catch LA was added to your list."
IV. iOS SHARE EXTENSION
This is what lets users share directly from Instagram into your app.
A. Create the Extension Target
☐ In Xcode: File → New → Target → Share Extension
☐ Name it (e.g. OstaShareExtension)
☐ Configure App Groups for shared data between extension and main app
B. Accept Instagram Content
☐ Configure Info.plist: NSExtension → NSExtensionAttributes
☐ Set NSExtensionActivationRule to accept URLs
C. Extract the Instagram URL
☐ In ShareViewController, extract URL from extensionContext inputItems
☐ Filter for attachments conforming to "public.url"
☐ Load the URL via loadItem(forTypeIdentifier:)
D. Send to Backend
☐ POST extracted URL to /restaurants/save-from-instagram via URLSession
☐ Include auth token (from shared Keychain / App Group)
E. Close the Extension
☐ On success: call extensionContext?.completeRequest(returningItems: nil)
☐ User returns to Instagram seamlessly
V. FRONTEND (SwiftUI)
A. Homepage
Data Loading
☐ Call GET /users/{user_id}/homepage on launch
☐ Show loading spinner while fetching
☐ If empty → show "Nothing saved yet" state
☐ If not empty → render Favorites, Visited, Saved sections + folders
Refresh Behavior
☐ Refresh on .onAppear (minimum viable)
☐ Refresh on didBecomeActiveNotification (better UX)
☐ Handle push notification to trigger refresh (best UX)
☐ Handle empty → non-empty transition gracefully
Add Button ("+") Flow
☐ Tap "+" → open sheet
☐ Allow paste of Instagram link
☐ Send to backend
☐ Show loading state during save
☐ On success → refresh homepage automatically
Grid Interaction
☐ Tap restaurant card → navigate to RestaurantDetailView
☐ Cards display: name, city/state, price, rating, cover image, status
B. Restaurant Detail View
Data
☐ Fetch details via GET /restaurants/{restaurant_id} on load
Display
☐ Name, rating, price range, location
☐ Scrollable photo gallery
☐ Top dishes list
☐ Notes text box
☐ Current status indicator (saved / favorite / visited)
Actions
☐ ⭐ Favorite button → POST /restaurants/{id}/favorite
☐ ✅ Mark as Visited button → POST /restaurants/{id}/visited
☐ Notes autosave after 1–2 seconds of inactivity → POST /restaurants/{id}/notes
☐ Open Maps button → use lat/long to open Apple Maps or Google Maps
VI. BACKEND BUSINESS LOGIC
1. Instagram → Restaurant Matching
This is the hardest part of the backend. Two strategies:
☐ Option A (start here): Google Places search
☐ Scrape/parse Instagram caption
☐ Extract likely restaurant name
☐ Search Google Places by name + city
☐ Fetch place_id, name, address, rating, price, photos, coordinates
☐ Option B (later, smarter): LLM-assisted parsing
☐ Use LLM to infer restaurant name from caption + comments
☐ Then search Google Places
2. Deduplication
☐ Before creating any restaurant: SELECT * FROM restaurants WHERE google_place_id = ?
☐ If exists → reuse the existing record
☐ If not → create new
3. Homepage Sorting
☐ All sections sorted by saved_at DESC (newest first)
4. Top Dishes Extraction (Later Phase)
☐ Pull recent Google/Yelp reviews for a restaurant
☐ Use NLP or LLM to extract dish names
☐ Count frequency of mentions
☐ Store top 3–5 dishes in TopDish table
☐ Return in Restaurant Detail API
5. Photos Caching
☐ Fetch Google Places photos on save
☐ Upload to S3 / Supabase Storage
☐ Return optimized URLs to frontend
VII. RECOMMENDED TECH STACK
Backend
☐ FastAPI (Python) or Node + Express
☐ PostgreSQL database
☐ Google Places API integration
☐ S3 or Supabase Storage for images
☐ JWT-based authentication
Frontend
☐ SwiftUI
☐ URLSession or async/await networking
☐ MapKit
☐ iOS Share Extension
Minimum Tables to Create
☐ users
☐ restaurants
☐ user_saved_restaurants (with status column)
☐ notes
☐ folders (optional)
☐ folder_restaurants (optional)
☐ top_dishes (later phase)
VIII. BUILD ORDER
Work through these phases in order. Each phase builds on the previous one.
PHASE 1: CORE SAVE FLOW
☐ Set up PostgreSQL with users, restaurants, user_saved_restaurants tables
☐ Build POST /auth/signup and POST /auth/login
☐ Build POST /restaurants/save-from-instagram
☐ Integrate Google Places API for restaurant lookup
☐ Default status = 'saved' on every insert
☐ Build iOS Share Extension (accept URL, send to backend)
PHASE 2: HOMEPAGE
☐ Build GET /users/{user_id}/homepage
☐ Return favorites, visited, saved sections
☐ SwiftUI: load homepage on launch, show loading/empty states
☐ SwiftUI: render grid with restaurant cards
☐ SwiftUI: refresh on .onAppear and didBecomeActive
PHASE 3: RESTAURANT DETAIL
☐ Build GET /restaurants/{restaurant_id}
☐ Include photos, notes, status in response
☐ SwiftUI: RestaurantDetailView with all fields
☐ SwiftUI: scrollable photo gallery
☐ SwiftUI: Open Maps button (lat/long)
PHASE 4: FAVORITES & VISITED
☐ Build POST /restaurants/{id}/favorite
☐ Build POST /restaurants/{id}/visited
☐ Build POST /restaurants/{id}/unsort
☐ SwiftUI: Favorite and Visited buttons on detail view
☐ SwiftUI: homepage sections reflect status changes
PHASE 5: NOTES
☐ Build POST /restaurants/{id}/notes (upsert)
☐ SwiftUI: notes text box with autosave (1–2s debounce)
PHASE 6: POLISH & ENHANCEMENTS
☐ Push notification on successful save (APNs)
☐ Better Instagram → restaurant matching (LLM option)
☐ Top dishes extraction from reviews
☐ Folder management endpoints + UI
☐ Photo caching to S3
☐ Add button ("+") manual paste flow in-app