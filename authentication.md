## CURRENT STATE (what exists right now)

### Backend (FastAPI, base path: /api/v1)

**Auth files to be replaced:**
- `auth.py` — 3 endpoints: POST /auth/login, POST /auth/register, GET /auth/me
- `security.py` — bcrypt password hashing via CryptContext, JWT creation with HS256 using settings.SECRET_KEY
- `deps.py` — `get_current_user()` dependency that extracts JWT from Authorization: Bearer header, decodes with HS256, looks up user by ID from the `sub` claim

**Existing endpoints that use `get_current_user()` from deps.py (these stay, only the auth dependency changes):**
- GET /home — homepage data (lists + unsorted restaurants)
- GET /restaurants/{restaurant_id} — restaurant details
- POST /restaurants/{restaurant_id}/export/google-maps — Google Maps deep link
- POST /lists/ — create a new list
- POST /lists/{list_id}/restaurants — add/move restaurant to list
- POST /save-events/ — create save event from Instagram share (Celery job)
- DELETE /user-restaurants/{id} — delete a saved restaurant

**Database:** PostgreSQL with existing tables: users, restaurants, user_saved_restaurants, notes, lists, etc.

### iOS (SwiftUI)

**Auth files to be replaced:**
- `AuthManager.swift` — handles login/register networking, stores JWT in Keychain and App Group UserDefaults for Share Extension
- `AuthView.swift` — login/register UI (email + password form, toggles between modes)

**Auth flow being replaced:**
1. User enters email/password in AuthView
2. Login sends application/x-www-form-urlencoded to POST /auth/login
3. Register sends JSON to POST /auth/register, then auto-logs in
4. On success, token saved to Keychain + App Group UserDefaults
5. onAuthSuccess() callback dismisses auth view
6. All subsequent API calls attach Authorization: Bearer <token>
7. Share Extension reads token from App Group UserDefaults

---

## WHAT CLERK REPLACES

Clerk takes over:
- User registration (accounts, passwords, email verification)
- User login and session creation
- Token generation, refresh, and rotation (Clerk tokens are ~60 second JWTs, auto-refreshed by the SDK)
- Login/signup UI on iOS (Clerk provides a prebuilt AuthView)

What stays yours:
- Every endpoint listed above (GET /home, POST /save-events/, etc.)
- All database tables for restaurants, lists, save events
- The networking layer structure on iOS (URLSession, async/await)
- The Share Extension

---

## MIGRATION STEPS

### Step 1: Clerk Dashboard Setup

Before touching code:
1. Create a Clerk application at https://dashboard.clerk.com
2. Enable Email/Password authentication
3. Optionally enable Sign in with Apple (recommended for iOS)
4. Go to Native Applications → Enable Native API
5. Add your iOS app (App ID Prefix + Bundle ID)
6. Record these four values:
   - `CLERK_PUBLISHABLE_KEY` — pk_test_... (iOS needs this)
   - `CLERK_SECRET_KEY` — sk_test_... (backend needs this)
   - `CLERK_FRONTEND_API_URL` — https://your-instance.clerk.accounts.dev
   - `CLERK_JWKS_URL` — https://your-instance.clerk.accounts.dev/.well-known/jwks.json
7. Recommended: Go to Sessions → Customize session token → add custom claims:
   ```json
   {
     "email": "{{user.primary_email_address}}",
     "name": "{{user.first_name}}"
   }
   ```
   This embeds the user's email and name directly in the JWT so the backend can read them without calling Clerk's API.

---

### Step 2: Update Backend Environment Variables

**In your .env file, remove or stop using:**
```
SECRET_KEY=...          # was used for HS256 JWT signing
```

**Add:**
```
CLERK_JWKS_URL=https://<your-instance>.clerk.accounts.dev/.well-known/jwks.json
CLERK_JWT_ISSUER=https://<your-instance>.clerk.accounts.dev
CLERK_SECRET_KEY=sk_test_...
```

On AWS, add these to your deployment environment (ECS task definition, EC2 env vars, Parameter Store, etc.). Do not commit real keys to Git. Verify .env is in .gitignore.

You can keep SECRET_KEY in the environment for now if other parts of the app use it (e.g. CORS, general FastAPI config). Just stop using it for JWT operations.

---

### Step 3: Add clerk_user_id to the Users Table

Your existing users table needs a column to store Clerk's user ID. Do NOT drop the table or delete existing data.

**Run this migration:**
```sql
ALTER TABLE users ADD COLUMN clerk_user_id VARCHAR(255) UNIQUE;
CREATE INDEX idx_users_clerk_id ON users(clerk_user_id);
```

Clerk user IDs look like: `user_2Qbkhxfu7VCmvM4Xguez0fmMg1c`

This comes from the `sub` claim in Clerk's session tokens. Your existing `user.id` (internal UUID/integer) remains the primary key that all other tables reference. The `clerk_user_id` is just the bridge between Clerk and your database.

---

### Step 4: Replace security.py

**Delete the contents of `security.py`.** You no longer need:
- `pwd_context = CryptContext(schemes=["bcrypt"], ...)` — Clerk hashes passwords
- `create_access_token()` — Clerk issues tokens
- `verify_password()` / `get_password_hash()` — Clerk handles passwords

**Replace with a JWKS-based token verifier:**

The new `security.py` must:
1. On app startup, create a `jwt.PyJWKClient` pointed at your CLERK_JWKS_URL
2. Expose a function `verify_clerk_token(token: str)` that:
   - Uses the PyJWKClient to get the signing key for the token
   - Decodes the JWT with algorithm RS256 (NOT HS256 — Clerk uses RSA)
   - Verifies the `iss` claim matches CLERK_JWT_ISSUER
   - Returns the decoded payload if valid
   - Raises an exception if invalid or expired
3. The PyJWKClient handles JWKS caching internally — it fetches keys once and reuses them, and refetches if it encounters an unknown key ID (handles Clerk key rotation automatically)

**Key difference from old code:** You are no longer SIGNING tokens. You are only VERIFYING tokens that Clerk signed. The algorithm changes from HS256 (symmetric, your secret) to RS256 (asymmetric, Clerk's public key).

---

### Step 5: Replace deps.py — get_current_user()

**Rewrite `get_current_user()` in `deps.py`.** The function signature should remain compatible with your existing endpoints so they don't need to change.

The new `get_current_user()` must:

1. Extract the `Authorization: Bearer <token>` header (same as before)
2. Call `verify_clerk_token(token)` from the new security.py
3. If verification fails → raise HTTPException 401 (was 403 before — 401 is more correct for invalid tokens)
4. Extract `clerk_user_id` from the `sub` claim of the decoded payload
5. Look up: `SELECT * FROM users WHERE clerk_user_id = ?`
6. If found → return the user object (same as before)
7. If NOT found → this is a first-time user. Auto-create:
   - Create a new user record with `clerk_user_id` from the token
   - If you added custom claims in Step 1, read `email` and `name` from the token payload and store them
   - Return the new user object
8. Your existing endpoints receive the user object exactly as before — they don't know or care that auth changed

**The "find or create" in step 7 is the key difference.** Previously, users were created via POST /auth/register. Now, users are created in Clerk's system first (via the iOS SDK), and your backend creates the local record the first time it sees their token. This means registration is implicit — the first authenticated API call creates the user row.

---

### Step 6: Delete auth.py Endpoints

Remove the three auth endpoints entirely:

- **DELETE:** `POST /api/v1/auth/login` — Clerk handles login via the iOS SDK
- **DELETE:** `POST /api/v1/auth/register` — Clerk handles registration via the iOS SDK
- **KEEP BUT MODIFY:** `GET /api/v1/auth/me` — this is still useful. Update it to use the new `get_current_user()` dependency. It should return the user object from your database, which now includes `clerk_user_id`.

If you have a router registered for `/auth`, update it to only include the `/me` endpoint. Or move `/me` to a different router if you prefer.

---

### Step 7: Verify All Protected Endpoints Still Work

Go through every endpoint that uses `Depends(get_current_user)`:

- GET /home ✅
- GET /restaurants/{restaurant_id} ✅
- POST /restaurants/{restaurant_id}/export/google-maps ✅
- POST /lists/ ✅
- POST /lists/{list_id}/restaurants ✅
- POST /save-events/ ✅
- DELETE /user-restaurants/{id} ✅
- GET /auth/me ✅

Each one should work identically — the user object they receive is the same shape as before. The only thing that changed is HOW that user was authenticated.

Test each endpoint with a valid Clerk session token. Verify 401 is returned without a token or with an invalid token.

---

### Step 8: Clean Up Backend Dependencies

**Remove from requirements.txt:**
- `passlib` (was used for bcrypt via CryptContext)
- `bcrypt` (no longer hashing passwords)
- `python-multipart` (only if it was solely used for the OAuth2 form login — check if other endpoints need it first)

**Keep:**
- `PyJWT` (still needed for decoding Clerk's tokens)
- `cryptography` (needed by PyJWT for RS256 verification)

**Add if not present:**
- `cryptography` — PyJWT needs this for RSA key handling

Run `pip install PyJWT[crypto]` to ensure RS256 support is installed.

---

### Step 9: iOS — Install Clerk SDK

In Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/clerk/clerk-ios`
3. Add to your main app target

Requirements: iOS 17+, Xcode 16+, Swift 5.10+

---

### Step 10: iOS — Configure Clerk in App Entry Point

In your `@main` App struct:

```swift
import SwiftUI
import Clerk

@main
struct OstaApp: App {
    @State private var clerk = Clerk.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.clerk, clerk)
                .task {
                    clerk.configure(publishableKey: "pk_test_...")
                    try? await clerk.load()
                }
        }
    }
}
```

Also add the Associated Domain capability in Xcode:
- Target → Signing & Capabilities → + Capability → Associated Domains
- Add: `webcredentials:<YOUR_FRONTEND_API_URL>`

---

### Step 11: iOS — Replace AuthView.swift

**Delete your existing `AuthView.swift`** (the custom email/password form).

Replace with Clerk's prebuilt AuthView:

```swift
import SwiftUI
import Clerk

struct ContentView: View {
    @Environment(\.clerk) private var clerk
    @State private var authIsPresented = false

    var body: some View {
        if clerk.user != nil {
            HomepageView()
        } else {
            Button("Sign in") { authIsPresented = true }
                .sheet(isPresented: $authIsPresented) {
                    AuthView()  // Clerk handles everything
                }
        }
    }
}
```

Clerk's AuthView handles: sign-in, sign-up, email verification, password reset, and error states. You do not build any of this.

---

### Step 12: iOS — Replace AuthManager.swift

**Gut `AuthManager.swift`.** Remove:
- The `login(email:, password:)` method that called POST /auth/login
- The `register(email:, name:, password:)` method that called POST /auth/register
- Any manual JWT storage in Keychain (Clerk manages its own session)
- The token refresh logic (if any)

**What AuthManager becomes:**

AuthManager is now a thin wrapper whose only jobs are:
1. Check if user is signed in: `Clerk.shared.user != nil`
2. Get a valid session token for API calls: `Clerk.shared.session?.getToken()`
3. Sign out: `Clerk.shared.signOut()`
4. Bridge the token to the Share Extension (see Step 14)

The Clerk iOS SDK handles session state, token refresh (~every 50 seconds), and persistence internally. You do not store tokens in the Keychain yourself — Clerk does that.

---

### Step 13: iOS — Update Networking Layer

Every API call currently attaches the token from Keychain. Change it to get the token from Clerk instead.

**Before (old):**
```swift
let token = KeychainService.getToken()
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```

**After (Clerk):**
```swift
guard let token = try await Clerk.shared.session?.getToken()?.jwt else {
    // Not signed in — show auth screen
    throw AuthError.notAuthenticated
}
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```

`getToken()` is cached and fast — it only makes a network call when the cached token is about to expire. In normal use it returns instantly.

**Add retry logic for 401s:**

Since Clerk tokens have a ~60 second lifetime, there's a small window where a token could expire between `getToken()` and the request arriving at your server. Handle this:

```swift
let (data, response) = try await URLSession.shared.data(for: request)
if (response as? HTTPURLResponse)?.statusCode == 401 {
    // Token expired in transit — force refresh and retry once
    guard let freshToken = try await Clerk.shared.session?.getToken(
        options: .init(skipCache: true)
    )?.jwt else {
        throw AuthError.sessionExpired
    }
    request.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
    let (retryData, _) = try await URLSession.shared.data(for: request)
    return retryData
}
```

Apply this pattern in your existing APIClient/networking wrapper so all endpoints get it automatically.

---

### Step 14: iOS — Update Share Extension

Your Share Extension currently reads the token from App Group UserDefaults. This still works, but the source of the token changes.

**In the main app**, whenever the app becomes active, store the current Clerk token for the extension:

```swift
func storeTokenForExtension() async {
    guard let tokenResponse = try? await Clerk.shared.session?.getToken() else { return }
    let sharedDefaults = UserDefaults(suiteName: "group.com.yourapp.osta")
    sharedDefaults?.set(tokenResponse.jwt, forKey: "clerk_session_token")
    sharedDefaults?.set(Date().addingTimeInterval(50), forKey: "clerk_token_expiry")
}
```

Call this:
- In your scene phase handler when the app becomes active
- After a successful sign-in
- Any time before the user might switch to Instagram to share

**In the Share Extension**, read the token:

```swift
func getTokenForAPICall() -> String? {
    let sharedDefaults = UserDefaults(suiteName: "group.com.yourapp.osta")
    guard let expiry = sharedDefaults?.object(forKey: "clerk_token_expiry") as? Date,
          expiry > Date(),
          let token = sharedDefaults?.string(forKey: "clerk_session_token") else {
        return nil  // Token expired — user needs to open the main app first
    }
    return token
}
```

The token has a ~60 second lifetime, so this works when the user was recently in your app (which they typically are — they open your app, then switch to Instagram). If the token is expired, the extension should fail gracefully with a message like "Open Osta first to refresh your session."

**Important:** Update the UserDefaults key names if your old code used different keys (e.g. if it was `"auth_token"` before, change to `"clerk_session_token"` or keep the same key — just be consistent).

---

### Step 15: iOS — Handle Sign Out

Replace your old sign-out logic:

**Before:**
```swift
KeychainService.deleteToken()
UserDefaults(suiteName: "group.com.yourapp.osta")?.removeObject(forKey: "auth_token")
```

**After:**
```swift
try await Clerk.shared.signOut()
// Also clear the Share Extension token
UserDefaults(suiteName: "group.com.yourapp.osta")?.removeObject(forKey: "clerk_session_token")
UserDefaults(suiteName: "group.com.yourapp.osta")?.removeObject(forKey: "clerk_token_expiry")
```

---

## FILES CHANGED — SUMMARY

### Backend (modified):
| File | Action |
|------|--------|
| `security.py` | **Rewrite** — remove bcrypt/HS256, add JWKS verifier with RS256 |
| `deps.py` | **Rewrite** — new get_current_user() with Clerk JWT verification + find-or-create user |
| `auth.py` | **Gut** — delete login + register endpoints, keep /auth/me |
| `.env` | **Update** — remove old secrets, add CLERK_JWKS_URL + CLERK_JWT_ISSUER + CLERK_SECRET_KEY |
| `requirements.txt` | **Update** — remove passlib/bcrypt, add cryptography if missing |
| Migration SQL | **Add** clerk_user_id column to users table |

### Backend (NOT changed):
| File | Status |
|------|--------|
| All restaurant endpoints | Unchanged |
| All list endpoints | Unchanged |
| All save-event endpoints | Unchanged |
| All user-restaurant endpoints | Unchanged |
| Database tables (restaurants, lists, etc.) | Unchanged |
| Celery tasks | Unchanged |

### iOS (modified):
| File | Action |
|------|--------|
| App entry point | **Modify** — add Clerk initialization |
| `AuthView.swift` | **Replace** — delete custom form, use Clerk's AuthView |
| `AuthManager.swift` | **Gut** — remove login/register networking, token storage; becomes thin wrapper |
| Networking layer / APIClient | **Modify** — get token from Clerk instead of Keychain |
| Share Extension | **Modify** — read token from updated App Group key |
| Xcode project | **Add** Clerk iOS SDK package + Associated Domain capability |

### iOS (NOT changed):
| File | Status |
|------|--------|
| HomepageView | Unchanged |
| RestaurantDetailView | Unchanged |
| All other views | Unchanged |
| Data models | Unchanged |

---

## VERIFICATION CHECKLIST

**Backend:**
- [ ] CLERK_JWKS_URL, CLERK_JWT_ISSUER, CLERK_SECRET_KEY are in .env (not in code)
- [ ] security.py uses PyJWKClient + RS256 (not HS256, not your own SECRET_KEY)
- [ ] deps.py get_current_user() extracts clerk_user_id from sub claim
- [ ] deps.py auto-creates user record on first request from a new Clerk user
- [ ] POST /auth/login is deleted
- [ ] POST /auth/register is deleted
- [ ] GET /auth/me works with Clerk token
- [ ] GET /home works with Clerk token
- [ ] POST /save-events/ works with Clerk token
- [ ] All other protected endpoints return 401 without a token
- [ ] All other protected endpoints return 401 with an expired/invalid token
- [ ] No bcrypt, passlib, or CryptContext references remain in active code
- [ ] No HS256 JWT signing remains in active code
- [ ] users table has clerk_user_id column with unique index

**iOS:**
- [ ] Clerk SDK installed via SPM
- [ ] Associated Domain configured in Xcode
- [ ] Clerk.shared.configure() called in App struct with publishable key
- [ ] Old AuthView.swift replaced with Clerk's AuthView
- [ ] Old login/register networking code removed from AuthManager
- [ ] All API calls use Clerk.shared.session?.getToken() for the Bearer token
- [ ] 401 retry logic works (force refresh token, retry once)
- [ ] Share Extension reads Clerk token from App Group UserDefaults
- [ ] Share Extension handles expired token gracefully
- [ ] Sign out calls Clerk.shared.signOut() and clears App Group token
- [ ] Old Keychain token storage code removed

---

## BEGIN

Start with Step 1 (Clerk Dashboard Setup). Then move to Step 2 (environment variables) and Step 3 (database migration). Show me the complete file for each file you modify. After each step, confirm what was changed and what is next. Do not skip steps or combine them.