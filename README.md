# PIATRA

**Smart Pantry & Recipe Intelligence App**

![PIATRA Mascot](PIATRA.jpg)

PIATRA is a full-stack AI-powered kitchen assistant. It combines a Flutter mobile app with a FastAPI backend to help users manage their pantry, discover recipes tailored to what they have, plan meals for the week, and get real-time cooking guidance — all powered by Gemini AI and the Spoonacular recipe database.

---

## Features

- **AI Assistant** — PIATRA chat assistant powered by Gemini 2.5 Flash. Knows your pantry contents and cooking profile automatically. Supports voice-style scan-to-pantry via Gemini Vision.
- **Smart Pantry Management** — Add items manually or scan them with the camera. Items sync between local SQLite and Firestore in real time.
- **Personalised Recipe Recommendations** — Spoonacular-powered recipe discovery ranked by pantry match, calorie fit, macros, cuisine preference, and cooking mode.
- **Cooking Mode** — Step-by-step guided cooking with per-step timers, an in-session AI sous-chef, and automatic nutrition logging on completion.
- **Meal Planner** — Weekly meal plan with breakfast/lunch/dinner/snack slots. Generates a smart shopping list that cross-references the pantry.
- **Nutrition Analytics** — 30-day history with calorie ring, weekly bar chart, cuisine breakdown, and cooking streaks.
- **User Profiles** — Cooking mode, calorie target, macro breakdown, dietary preferences, favourite cuisines, and allergy/intolerance settings. All persisted to Firestore.
- **Saved Recipes** — Bookmark any recipe. Swipe-to-remove on a dedicated saved recipes screen.
- **Feedback** — In-app feedback form with category tags and star rating, delivered via SMTP email.

---

## Architecture

```
PIATRA
├── backend/          FastAPI + Gemini AI + Firebase
└── mobile_app/       Flutter (iOS & Android)
```

### Backend (`/backend`)

Built with **FastAPI**. Integrates:

- **Google Gemini 2.5 Flash** — conversational AI, vision scanning, recipe/nutrition advice
- **Firebase Admin SDK** — Firestore (user profiles, pantry, recipe history, meal plans, nutrition logs) + Firebase Auth (token verification)
- **SMTP** — feedback email delivery

### Mobile App (`/mobile_app`)

Built with **Flutter**. Key integrations:

- **Spoonacular API** — recipe search, bulk recipe detail fetch, nutrition data
- **Firebase** — Firestore sync + Auth
- **SQLite** (sqflite) — local pantry cache
- **image_picker** — camera and gallery for pantry scanning

---

## Backend Setup

### Prerequisites

- Python 3.8+
- Firebase project with Firestore and Authentication enabled
- Gemini API key from [Google AI Studio](https://aistudio.google.com)

### Installation

```bash
cd backend
pip install -r requirements.txt
```

### Environment Variables

Copy `.env.example` to `.env` and fill in:

```env
GEMINI_API_KEY=your_gemini_api_key_here
DEBUG=false

FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxx@your-project.iam.gserviceaccount.com

SECRET_KEY=generate_a_random_64_char_string_here

# Optional — for feedback email delivery
FEEDBACK_EMAIL=youremail@gmail.com
FEEDBACK_EMAIL_PASSWORD=your_gmail_app_password
FEEDBACK_RECEIVER_EMAIL=recipient@example.com
```

> For feedback email, use a Gmail **App Password** (Google Account → Security → 2-Step Verification → App passwords), not your login password.

### Run

```bash
python main.py
```

API available at `http://localhost:8000`. Swagger docs at `http://localhost:8000/docs`.

### Deployment

The backend is deployed to [Render](https://render.com). The production URL is configured in `mobile_app/lib/core/config/app_config.dart`.

---

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check (used by Render) |
| `POST` | `/api/users/register` | Register a user (server-side / testing only) |
| `POST` | `/api/users/create-profile` | Create/update Firestore profile after Firebase Auth |
| `POST` | `/api/users/login` | Exchange Firebase ID token for JWT |
| `GET` | `/api/users/profile` | Get user profile (requires Firebase ID token) |
| `PUT` | `/api/users/profile` | Update user profile |
| `DELETE` | `/api/users/profile` | Delete user profile |
| `POST` | `/api/assistant/chat` | Chat with PIATRA AI (supports vision scan context) |
| `POST` | `/api/assistant/nutrition-advice` | Personalised nutrition advice |
| `POST` | `/api/assistant/recipe-suggestions` | Recipe suggestions from ingredients |
| `POST` | `/api/feedback/` | Submit in-app feedback |

### Authentication

All `/api/users/` endpoints (except `/register`) require a Firebase ID token in the `Authorization` header:

```
Authorization: Bearer <firebase_id_token>
```

### Vision Scanning

The `/api/assistant/chat` endpoint handles image-based pantry scanning. The mobile app embeds a base64-encoded image in the `context` field using the format:

```
VISION_SCAN::<mime_type>::<base64_data>
```

The backend decodes this, sends it to Gemini Vision, and returns a JSON array of detected food items.

---

## Mobile App Setup

### Prerequisites

- Flutter SDK 3.x
- A Firebase project with Android/iOS apps configured
- Spoonacular API key (free tier: 150 points/day)

### Environment

Create `mobile_app/.env`:

```env
SPOONACULAR_API_KEY=your_spoonacular_key
```

### Firebase

Replace `mobile_app/lib/firebase_options.dart` with the output of:

```bash
flutterfire configure
```

### Backend URL

Edit `mobile_app/lib/core/config/app_config.dart` to point `_productionUrl` at your deployed backend, and toggle `_useProduction` as needed for local development.

### Run

```bash
cd mobile_app
flutter pub get
flutter run
```

---

## Project Structure

```
backend/
├── main.py                        FastAPI app entry point
├── requirements.txt
├── .env.example
└── app/
    ├── api/
    │   ├── assistant.py           Chat, nutrition advice, recipe suggestions
    │   ├── users.py               User registration, login, profile CRUD
    │   ├── feedback.py            Feedback submission
    │   ├── pantry.py              (stub — pantry managed client-side)
    │   ├── nutrition.py           (stub)
    │   └── recipes.py             (stub)
    ├── core/
    │   ├── config.py              Environment variable loading
    │   └── security.py            JWT creation and verification
    ├── db/
    │   ├── firebase_client.py     Firebase Admin SDK initialisation
    │   ├── user_repository.py     User CRUD against Firestore
    │   └── pantry_repository.py   Pantry item CRUD against Firestore
    ├── models/
    │   └── user.py                Pydantic models (UserCreate, UserProfile, etc.)
    └── services/
        ├── ai_assistant.py        Gemini integration (text + vision)
        ├── context_builder.py     Builds rich AI context from user data
        ├── feedback_email.py      SMTP email delivery for feedback
        ├── nutrition_engine.py    (stub)
        └── recipe_engine.py       (stub)

mobile_app/lib/
├── main.dart                      App entry point
├── app.dart                       Root widget + providers
├── core/
│   ├── config/
│   │   ├── app_config.dart        Backend URL configuration
│   │   └── env_config.dart        .env loading (Spoonacular key)
│   └── constants/
│       └── theme/app_theme.dart   Design system (colours, typography, gradients)
├── models/                        Data models (PantryItem, Recipe, UserProfileModel, …)
├── services/
│   ├── pantry_service.dart        SQLite local pantry
│   ├── pantry_firebase_service.dart  Firestore pantry sync
│   ├── pantry_sync_manager.dart   Two-way local ↔ cloud sync
│   ├── spoonacular_service.dart   Spoonacular API client
│   ├── recipe_ranking_engine.dart Multi-factor recipe ranking
│   ├── meal_plan_service.dart     Meal planning + shopping lists
│   ├── nutrition_history_service.dart  Nutrition log (Firestore)
│   ├── recipe_history_service.dart     Cook history (Firestore)
│   ├── saved_recipes_service.dart      Saved/bookmarked recipes
│   └── profile_firebase_service.dart   User profile persistence
├── state/
│   ├── user_provider.dart         UserProfileModel state + auto-save
│   ├── recipe_provider.dart       Recipe fetch, rank, filter state
│   ├── saved_recipes_provider.dart Bookmarks state
│   └── theme_provider.dart        Dark/light mode toggle
├── ui/screens/                    All app screens
└── ml/
    ├── pantry_scanner.dart        Gemini Vision pantry scan client
    └── detection_result.dart      Scan result model
```

---

## Key Design Decisions

**Context-aware AI** — Every chat request to the backend includes the user's full pantry inventory and cooking profile. The `ContextBuilder` service assembles this from Firestore before passing it to Gemini, so the assistant always knows what you have and can respect allergies and dietary preferences.

**Two-pass pantry sync** — Pantry items live in SQLite for offline speed and are mirrored to Firestore. `PantrySyncManager` keeps both in sync; Firestore changes stream back to the local DB.

**Three-pass recipe fetch** — `RecipeProvider` runs up to three Spoonacular queries per load: (1) pantry-first ingredient search, (2) profile-tailored complex search, and (3) a cuisine-only fallback if fewer than 5 cuisine-matching recipes are found. Results are merged, deduped, and ranked.

**Recipe ranking** — `RecipeRankingEngine` scores each recipe 0–100 across six dimensions: pantry match (35 pts), calorie fit (20 pts), macro fit (15 pts), cuisine match (15 pts), cooking-mode fit (10 pts), and popularity (5 pts). Cuisine-matching recipes are always partitioned above non-matching ones regardless of sort order.

**Cooking mode logging** — When the user taps "Finish!" in cooking mode, `NutritionHistoryService` and `RecipeHistoryService` are both updated atomically so analytics and "cook again" history stay current.

---

## Testing

```bash
cd backend
pytest tests/
```

The test suite currently covers Pydantic user models (`tests/test_users.py`). Firebase-dependent endpoints require a live Firebase project or mocked credentials.

---

## Roadmap

- [ ] Push notifications for expiring pantry items
- [ ] Cooking history context fed into AI for better suggestions
- [ ] Barcode scanning for packaged goods
- [ ] Nutritional goal tracking with weekly summaries