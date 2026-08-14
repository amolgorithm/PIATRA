# PIATRA API Specification

Base URL (production): `https://piatra-backend.onrender.com`  
Base URL (local dev): `http://localhost:8000`

All request and response bodies are JSON. All timestamps are ISO 8601 UTC strings.

---

## Authentication

Most `/api/users/` endpoints require a **Firebase ID token** passed as a Bearer token:

```
Authorization: Bearer <firebase_id_token>
```

The `/api/assistant/` and `/api/feedback/` endpoints are currently unauthenticated — they accept an optional `user_id` field in the request body to enable personalised context.

---

## Health

### `GET /health`

Used by Render to confirm the service is alive.

**Response `200`**
```json
{ "status": "ok" }
```

### `GET /`

**Response `200`**
```json
{ "message": "Welcome to PIATRA Backend API" }
```

---

## Users — `/api/users`

### `POST /api/users/register`

Server-side user registration. Creates a user in Firebase Auth and Firestore. Intended for testing only — in production, registration happens client-side via the Firebase Auth SDK.

**Request body**
```json
{
  "email": "user@example.com",
  "display_name": "Jane Smith",
  "password": "securepassword123",
  "first_name": "Jane",       // optional
  "last_name": "Smith",       // optional
  "avatar_url": "https://..."  // optional
}
```

**Response `200` — UserProfile**
```json
{
  "uid": "firebase_uid_abc123",
  "email": "user@example.com",
  "display_name": "Jane Smith",
  "first_name": "Jane",
  "last_name": "Smith",
  "avatar_url": "",
  "created_at": "2025-01-15T10:00:00Z",
  "updated_at": "2025-01-15T10:00:00Z",
  "is_active": true,
  "dietary_preferences": [],
  "allergies": [],
  "favorite_cuisines": []
}
```

**Response `400`** — User with this email already exists  
**Response `500`** — Firebase or Firestore error

---

### `POST /api/users/create-profile`

Creates or updates the Firestore user profile after Firebase Auth registration. Requires a valid Firebase ID token.

**Headers**
```
Authorization: Bearer <firebase_id_token>
```

**Request body**
```json
{
  "email": "user@example.com",
  "display_name": "Jane Smith",
  "first_name": "Jane",       // optional
  "last_name": "Smith",       // optional
  "avatar_url": "https://..."  // optional
}
```

**Response `200`** — UserProfile (same shape as `/register` response)

**Response `401`** — Missing or invalid Firebase ID token  
**Response `500`** — Failed to create profile

---

### `POST /api/users/login`

Exchanges a Firebase ID token for a short-lived JWT access token.

**Request body**
```json
{
  "id_token": "<firebase_id_token>"
}
```

**Response `200`**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

The JWT expires in 30 minutes. It is signed with `SECRET_KEY` using HS256.

**Response `401`** — Invalid Firebase ID token  
**Response `500`** — Login failed

---

### `GET /api/users/profile`

Returns the authenticated user's Firestore profile.

**Headers**
```
Authorization: Bearer <firebase_id_token>
```

**Response `200`** — UserProfile

**Response `401`** — Missing or invalid Firebase ID token

---

### `PUT /api/users/profile`

Updates the authenticated user's profile fields. Only provided fields are updated (partial update).

**Headers**
```
Authorization: Bearer <firebase_id_token>
```

**Request body** (all fields optional)
```json
{
  "display_name": "Jane Smith",
  "first_name": "Jane",
  "last_name": "Smith",
  "avatar_url": "https://..."
}
```

**Response `200`** — Updated UserProfile

**Response `401`** — Missing or invalid Firebase ID token  
**Response `500`** — Failed to update

---

### `DELETE /api/users/profile`

Deletes the authenticated user from both Firestore and Firebase Auth.

**Headers**
```
Authorization: Bearer <firebase_id_token>
```

**Response `200`**
```json
{ "message": "User profile deleted successfully" }
```

**Response `401`** — Missing or invalid Firebase ID token  
**Response `500`** — Failed to delete

---

## Assistant — `/api/assistant`

All assistant endpoints are unauthenticated. Providing `user_id` enables context-aware responses — the backend fetches the user's pantry and profile from Firestore and injects them into the Gemini prompt.

### `POST /api/assistant/chat`

General-purpose chat with PIATRA AI. Also handles **vision scan** requests when the `context` field begins with `VISION_SCAN::`.

**Request body**
```json
{
  "message": "What can I make for dinner tonight?",
  "context": "",       // optional — additional context string, or VISION_SCAN:: prefix
  "user_id": "uid123"  // optional — enables pantry + profile context injection
}
```

**Vision scan format**

To trigger Gemini Vision pantry scanning, set `context` to:
```
VISION_SCAN::<mime_type>::<base64_encoded_image>
```

Example:
```
VISION_SCAN::image/jpeg::/9j/4AAQSkZJRgABAQAA...
```

Supported MIME types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`

**Response `200` — normal chat**
```json
{
  "response": "With your chicken breast, rice, and garlic in the pantry, I'd suggest..."
}
```

**Response `200` — vision scan** (JSON array as a string in `response`)
```json
{
  "response": "[{\"name\": \"Granny Smith apple\", \"confidence\": 0.96}, {\"name\": \"baby spinach\", \"confidence\": 0.91}]"
}
```

Each detection object:
```json
{
  "name": "specific food name (never generic category labels)",
  "confidence": 0.0
}
```

Returns `[]` as the response string if no food items are detected.

**Response `500`** — Gemini API error

---

### `POST /api/assistant/nutrition-advice`

Returns personalised nutrition advice. If `user_id` is provided, the response respects the user's dietary preferences and allergies.

**Request body**
```json
{
  "query": "How much protein should I eat to build muscle?",
  "user_id": "uid123"  // optional
}
```

**Response `200`**
```json
{
  "response": "Based on your profile and calorie target of 2000 kcal/day..."
}
```

**Response `500`** — Gemini API error

---

### `POST /api/assistant/recipe-suggestions`

Returns recipe suggestions based on a list of ingredients and (optionally) the user's full pantry and dietary profile.

**Request body**
```json
{
  "ingredients": ["chicken breast", "rice", "garlic"],
  "user_id": "uid123"  // optional
}
```

**Response `200`**
```json
{
  "response": "Here are three recipes using your ingredients:\n\n𝗛𝗲𝗿𝗯..."
}
```

The response text uses Unicode bold characters (e.g. `𝗛`) and `•` bullets — formatted for display in Flutter `Text` widgets without requiring markdown parsing.

**Response `500`** — Gemini API error

---

## Feedback — `/api/feedback`

### `POST /api/feedback/`

> Note the trailing slash — FastAPI redirects `POST /api/feedback` (no slash) with a 307 that drops the POST body. Always use the trailing slash.

Accepts in-app feedback and attempts to deliver it via Gmail SMTP. Email delivery is best-effort — the endpoint always returns `200` even if SMTP is not configured, so the client never sees a server error from missing email credentials. Feedback content is always logged server-side.

**Request body**
```json
{
  "feedback": "[Bug Report] [⭐⭐⭐] The scan screen crashes on Android 12 when...",
  "user_id": "uid123"  // optional
}
```

**Response `200`**
```json
{ "message": "Feedback received. Thank you!" }
```

**Response `400`** — Feedback string is empty

---

## Optimizer — `/api/optimize`

### `POST /api/optimize/meal-plan`

Solves for the cheapest set of recipes that hits the user's nutrient targets under a budget and time limit, instead of the old weighted-score ranking. Candidates are passed in by the client (already pulled from Spoonacular/Firestore) since recipe data isn't stored server-side.

**Request body**
```json
{
  "candidates": [
    {
      "id": "recipe_123",
      "name": "chicken rice bowl",
      "cost": 4.5,
      "prep_minutes": 20,
      "nutrients": { "protein_g": 35, "sodium_mg": 500 },
      "max_servings": 7
    }
  ],
  "nutrient_targets": {
    "minimums": { "protein_g": 300 },
    "maximums": { "sodium_mg": 5000 }
  },
  "budget": 100,
  "time_budget_minutes": 600,
  "mode": "lp"
}
```
`mode` is `"lp"` (hard constraints, can come back infeasible) or `"qp"` (nutrient minimums become a soft penalty instead of a wall, so it always returns something).

**Response `200`**
```json
{
  "status": "optimal",
  "plan": [
    { "id": "recipe_123", "name": "chicken rice bowl", "servings": 3.37, "cost": 15.17 }
  ],
  "total_cost": 36.16,
  "total_time_minutes": 193.4,
  "nutrients_achieved": { "protein_g": 300.0, "sodium_mg": 4835.71 },
  "message": null
}
```
`status` is `"optimal"` (lp solved cleanly), `"penalized"` (qp solved, may miss some targets), or `"infeasible"` (lp only, nothing fits, try qp or loosen a constraint).

**Response `400`** — empty candidates list
**Response `500`** — solver error

---

## Diversity — `/api/diversity`

### `POST /api/diversity/select`

Greedy correlation-minimizing selection over a set of already-scored candidates. Fixes the "five near-identical recipes" problem: ranking by quality alone returns near-duplicates because they score similarly by definition. At each step picks whichever remaining candidate has the best `quality - alpha * avg_similarity_to_already_picked`, same idea as portfolio diversification, just greedy instead of solved exactly.

Each candidate's vector is built from its nutrient profile (same shape Feature 1/3 use), z-scored, compared by cosine similarity.

**Request body**
```json
{
  "candidates": [
    { "id": "recipe_1", "name": "Chicken Stir Fry", "quality": 95, "nutrients": { "calories": 450, "protein_g": 38 } }
  ],
  "k": 5,
  "alpha": 6.0
}
```
`alpha` defaults to 6.0, tuned by testing against a mock "4 near-identical recipes + 3 different ones" case, low alpha (under ~2) barely changes anything against this app's typical 0-100 quality-score gaps, alpha in the 5-8 range is where genuinely different picks start winning over near-duplicates.

**Response `200`**
```json
{
  "selected": [
    { "id": "recipe_1", "name": "Chicken Stir Fry", "quality": 95.0, "avg_similarity_at_pick": 0.0 },
    { "id": "recipe_5", "name": "Lentil Soup", "quality": 88.0, "avg_similarity_at_pick": -0.967 }
  ]
}
```
`avg_similarity_at_pick` is the average cosine similarity to everything already selected at the moment this item was picked, negative means it was a genuine change of pace, close to 1 means it was still fairly similar to what came before.

**Response `400`** — empty candidates list
**Response `500`** — engine error

---

## Energy Model — `/api/energy`

### `POST /api/energy/curve`

Predicted post-meal glucose/energy response, a coupled pair of first-order ODEs solved numerically (scipy RK45), parameterized by an estimated glycemic load derived from the recipe's aggregate macros (carbs, fiber, sugar, protein, fat, same shape Features 1/3/4 use).

**This is a simplified, comparative model, not a clinical or diagnostic tool.** `glucose`/`insulin` values are relative response units, not real blood glucose in mg/dL. Useful for comparing "will this meal or that one keep me steadier through a study session," not for any medical purpose.

**Request body**
```json
{ "nutrients": { "carbs_g": 90, "fiber_g": 2, "sugar_g": 30, "protein_g": 8, "fat_g": 3 }, "duration_minutes": 180 }
```

**Response `200`**
```json
{
  "times_minutes": [0, 5, 10, "..."],
  "glucose": [0.0, 0.31, 0.98, "..."],
  "insulin": [0.0, 0.01, 0.03, "..."],
  "glycemic_load_estimate": 47.2,
  "peak_glucose": 50.08,
  "peak_time_minutes": 60.0,
  "steepest_drop_per_minute": -0.928,
  "possible_energy_dip": true,
  "note": "Simplified comparative model, not a clinical or diagnostic tool. Units are relative, not real blood glucose."
}
```
`possible_energy_dip` is a rough flag (steepest post-peak drop below a tuned threshold), not a diagnosis.

**Response `500`** — model error

---

## Stub Endpoints

The following endpoints exist as router stubs and return placeholder responses. They are reserved for future server-side implementation; the current app manages this data client-side via Firestore and Spoonacular.

| Endpoint | Response |
|----------|----------|
| `GET /api/pantry/` | `{ "message": "Pantry API endpoint" }` |
| `GET /api/nutrition/` | `{ "message": "Nutrition API endpoint" }` |
| `GET /api/recipes/` | `{ "message": "Recipes API endpoint" }` |

---

## Data Schemas

### UserProfile

```json
{
  "uid": "string",
  "email": "string (email)",
  "display_name": "string",
  "first_name": "string | null",
  "last_name": "string | null",
  "avatar_url": "string | null",
  "created_at": "datetime (ISO 8601 UTC)",
  "updated_at": "datetime (ISO 8601 UTC)",
  "is_active": "boolean",
  "dietary_preferences": ["string"],
  "allergies": ["string"],
  "favorite_cuisines": ["string"]
}
```

### Token

```json
{
  "access_token": "string (JWT)",
  "token_type": "bearer"
}
```

---

## Error Responses

All errors follow FastAPI's default error shape:

```json
{
  "detail": "Human-readable error message"
}
```

| Status | Meaning |
|--------|---------|
| `400` | Bad request (e.g. duplicate email, empty feedback) |
| `401` | Missing or invalid Firebase ID token |
| `422` | Pydantic validation error (malformed request body) |
| `500` | Internal server error (Firebase, Gemini, or SMTP failure) |

---

## Response Text Formatting

The AI assistant endpoints return text formatted for Flutter's `Text` widget:

- `**bold**` → Unicode mathematical bold characters (e.g. `𝗕𝗼𝗹𝗱`)
- `- bullet` → `• bullet`
- Multiple blank lines → collapsed to single blank line

This is handled by `app/utils/text_processing.py:format_gemini_response()`. Vision scan responses bypass this formatting and return raw JSON.