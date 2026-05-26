# PIATRA

**Smart Pantry & Recipe Intelligence App for Android**

![PIATRA Mascot](PIATRA.jpg)

PIATRA is a full-stack AI-powered kitchen assistant. It combines a Flutter mobile app with a FastAPI backend to help users manage their pantry, discover recipes tailored to what they have, plan meals for the week, and get real-time cooking guidance — all powered by Gemini AI and the Spoonacular recipe database.

---

## Features

- **AI Assistant** - PIATRA chat assistant powered by Gemini 2.5 Flash. Knows your pantry contents and cooking profile automatically. Supports vision-based scan-to-pantry via Gemini Vision.
- **Smart Pantry Management** - Add items manually or scan them with the camera. Items sync between local SQLite and Firestore in real time.
- **Personalised Recipe Recommendations** - Spoonacular-powered recipe discovery ranked by pantry match, calorie fit, macros, cuisine preference, and cooking mode.
- **Cooking Mode** - Step-by-step guided cooking with per-step timers, an in-session AI sous-chef, and automatic nutrition logging on completion.
- **Meal Planner** - Weekly meal plan with breakfast/lunch/dinner/snack slots. Generates a smart shopping list that cross-references the pantry.
- **Nutrition Analytics** - 30-day history with calorie ring, weekly bar chart, cuisine breakdown, and cooking streaks.
- **User Profiles** - Cooking mode, calorie target, macro breakdown, dietary preferences, favourite cuisines, and allergy/intolerance settings. All persisted to Firestore.
- **Saved Recipes** - Bookmark any recipe. Swipe-to-remove on a dedicated saved recipes screen.
- **Feedback** - In-app feedback form with category tags and star rating, delivered via SMTP email.

---

## Architecture

```
PIATRA
├── backend/          FastAPI + Gemini AI + Firebase
└── mobile_app/       Flutter (iOS & Android)
```

### Backend (`/backend`)

Built with **FastAPI**. Integrates:

- **Google Gemini 2.5 Flash** - conversational AI, vision scanning, recipe/nutrition advice
- **Firebase Admin SDK** - Firestore (user profiles, pantry, recipe history, meal plans, nutrition logs) + Firebase Auth (token verification)
- **SMTP** - feedback email delivery

### Mobile App (`/mobile_app`)

Built with **Flutter**. Key integrations:

- **Spoonacular API** - recipe search, bulk recipe detail fetch, nutrition data
- **Firebase** - Firestore sync + Auth
- **SQLite** (sqflite) - local pantry cache
- **image_picker** - camera and gallery for pantry scanning

---

## Installation

### Quick Install (Android APK)

If you just want to run the app on an Android device without setting up a development environment, a pre-built APK is available in the [Releases](../../releases) tab of this repository.

1. On your Android device, go to **Settings > Apps > Special app access > Install unknown apps** and allow your browser or file manager to install APKs.
2. Open the [Releases](../../releases) page and download the latest `app-release.apk` file.
3. Open the downloaded file on your device and tap **Install**.
4. The backend is already deployed at the production URL, so no further setup is needed.

> **Note:** This APK connects to the hosted backend automatically. iOS does not support sideloading APKs; iOS users must build from source using the developer setup below.

---

### Developer Setup

The following instructions are for running the full project locally or deploying your own instance.

### Backend Prerequisites

- Python 3.8+
- Firebase project with Firestore and Authentication enabled
- Gemini API key from [Google AI Studio](https://aistudio.google.com)

### Backend Packages

```bash
cd backend
pip install -r requirements.txt
```

Required packages and their purposes:

- `fastapi>=0.110.0` - Web framework for the API server
- `uvicorn[standard]>=0.24.0` - ASGI server to run FastAPI
- `google-generativeai>=0.3.2` - Google Gemini AI integration for chat and vision
- `python-dotenv>=1.0.0` - Loads environment variables from `.env` file
- `pydantic>=2.7.0` - Data validation and serialization for API models
- `email-validator>=2.1.0` - Validates email addresses in user models
- `firebase-admin>=6.2.0` - Firebase Admin SDK for Firestore and Auth
- `python-jose[cryptography]>=3.3.0` - JWT token creation and verification
- `passlib[bcrypt]>=1.7.4` - Password hashing utilities

### Mobile App Prerequisites

- Flutter SDK 3.x
- A Firebase project with Android/iOS apps configured
- Spoonacular API key (free tier: 150 points/day)

### Mobile App Packages

Key Flutter packages and their purposes:

- `provider` - State management across the app
- `sqflite` - Local SQLite database for offline pantry storage
- `cloud_firestore` - Firestore database sync
- `firebase_auth` - User authentication
- `firebase_core` - Firebase initialization
- `http` - HTTP requests to the backend and Spoonacular API
- `image_picker` - Camera and gallery access for pantry scanning
- `shared_preferences` - Persistent local storage for small values
- `google_fonts` - Sora and DM Sans typefaces
- `flutter_dotenv` - Loads `.env` file for API keys
- `path_provider` - Locates the app documents directory for SQLite
- `path` - File path utilities

```bash
cd mobile_app
flutter pub get
```

### Environment Variables

Copy `.env.example` to `.env` in the backend folder and fill in:

```env
GEMINI_API_KEY=your_gemini_api_key_here
DEBUG=false

FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxx@your-project.iam.gserviceaccount.com

SECRET_KEY=generate_a_random_64_char_string_here

# Optional - for feedback email delivery
FEEDBACK_EMAIL=youremail@gmail.com
FEEDBACK_EMAIL_PASSWORD=your_gmail_app_password
FEEDBACK_RECEIVER_EMAIL=recipient@example.com
```

For feedback email, use a Gmail **App Password** (Google Account > Security > 2-Step Verification > App passwords), not your login password.

Create `mobile_app/.env`:

```env
SPOONACULAR_API_KEY=your_spoonacular_key
```

### Firebase Setup

Replace `mobile_app/lib/firebase_options.dart` with the output of:

```bash
flutterfire configure
```

### Backend URL

Edit `mobile_app/lib/core/config/app_config.dart` to point `_productionUrl` at your deployed backend, and toggle `_useProduction` as needed for local development.

### Run Backend

```bash
cd backend
python main.py
```

API available at `http://localhost:8000`. Swagger docs at `http://localhost:8000/docs`.

### Run Mobile App

```bash
cd mobile_app
flutter pub get
flutter run
```

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
    │   ├── pantry.py              (stub - pantry managed client-side)
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
├── models/                        Data models (PantryItem, Recipe, UserProfileModel, ...)
├── services/
│   ├── pantry_service.dart        SQLite local pantry
│   ├── pantry_firebase_service.dart  Firestore pantry sync
│   ├── pantry_sync_manager.dart   Two-way local/cloud sync
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

**Context-aware AI** - Every chat request to the backend includes the user's full pantry inventory and cooking profile. The `ContextBuilder` service assembles this from Firestore before passing it to Gemini, so the assistant always knows what you have and can respect allergies and dietary preferences.

**Two-pass pantry sync** - Pantry items live in SQLite for offline speed and are mirrored to Firestore. `PantrySyncManager` keeps both in sync; Firestore changes stream back to the local DB.

**Three-pass recipe fetch** - `RecipeProvider` runs up to three Spoonacular queries per load: (1) pantry-first ingredient search, (2) profile-tailored complex search, and (3) a cuisine-only fallback if fewer than 5 cuisine-matching recipes are found. Results are merged, deduped, and ranked.

**Recipe ranking** - `RecipeRankingEngine` scores each recipe 0-100 across six dimensions: pantry match (35 pts), calorie fit (20 pts), macro fit (15 pts), cuisine match (15 pts), cooking-mode fit (10 pts), and popularity (5 pts). Cuisine-matching recipes are always partitioned above non-matching ones regardless of sort order.

**Cooking mode logging** - When the user taps "Finish!" in cooking mode, `NutritionHistoryService` and `RecipeHistoryService` are both updated atomically so analytics and "cook again" history stay current.

---

## Testing

```bash
cd backend
pytest tests/
```

The test suite currently covers Pydantic user models (`tests/test_users.py`). Firebase-dependent endpoints require a live Firebase project or mocked credentials.

---

## Known Bugs

- **Render cold start delay** - The backend is hosted on Render's free tier, which spins down after inactivity. The first request after a period of inactivity may take 20-40 seconds. The app displays a "Server waking up" banner during this time.
- **Spoonacular free tier limit** - The free Spoonacular API key allows 150 points per day. Heavy use of the recipe screen (especially with large pantries triggering multiple batch fetches) can exhaust this quota. When exhausted, the recipe list will be empty until the quota resets at midnight UTC.
- **Vision scan on low-light images** - Gemini Vision performs poorly on dark or blurry photos. Items may be missed or misidentified. The app filters out generic labels ("fruit", "vegetable") but specific items in poor lighting may still be wrong.
- **Firebase offline mode** - If the device has no internet connection on first launch, Firebase cannot initialise and the app falls back to SQLite-only mode. Cloud sync will not work until connectivity is restored and the app is restarted.
- **Pantry sync conflict resolution** - The current sync strategy is "cloud wins." If the same item is edited on two devices simultaneously while offline, the last cloud write will overwrite the other. There is no merge/conflict UI.
- **iOS camera permissions** - On some iOS versions, the first camera scan attempt may silently fail if camera permissions have not been granted. The user must go to Settings to grant permission manually.
- **Recipe detail missing steps** - Some Spoonacular recipes do not include `analyzedInstructions`. For these recipes, the "Start Cooking" button shows a warning and cooking mode cannot be entered.

---

## Support

For help or questions, contact the development team. Please include your device model, OS version, and a description of what you were doing when the issue occurred.

---

## Sources

[1] Dart, "Loops," Dart Documentation, 2023. https://dart.dev/language/loops
- Used to implement iteration over pantry items, recipe ingredients, and nutrition log entries throughout the Flutter codebase (e.g. `for` loops in `recipe_ranking_engine.dart` to score ingredients, loops in `pantry_sync_manager.dart` to merge cloud items into local DB).

[2] YouTube, "Dart Loops Tutorial," YouTube, 2020. https://www.youtube.com/watch?v=6JUPI8zM1zo
- Supplementary reference for Dart loop syntax, particularly `for-in` loops used when iterating over `List<PantryItem>` and `List<SpoonacularRecipe>` collections.

[3] YouTube, "Flutter Text Input & Widgets Tutorial," YouTube, 2020. https://www.youtube.com/watch?v=p5dkB3Mrxdo
- Referenced when building the `TextField` widgets used in the pantry add/edit dialog (`pantry_screen.dart`), the assistant chat input (`assistant_screen.dart`), and the feedback form (`feedback_form_screen.dart`).

[4] YouTube, "Flutter Widgets Tutorial," YouTube, 2020. https://www.youtube.com/watch?v=ABmqtI7ec7E
- Referenced for foundational Flutter widget composition patterns. Informed the structure of custom widgets including `IngredientCard`, `StepCard`, `NutritionBar`, and the various FAB widgets.

[5] YouTube, "Sending Email with Python Tutorial," YouTube, 2021. https://www.youtube.com/watch?v=ZXfgwe2H01g
- Used directly when implementing `feedback_email.py`. The `smtplib.SMTP_SSL` connection pattern, Gmail App Password approach, and `MIMEMultipart`/`MIMEText` message construction follow this tutorial.

[6] Flutter, "Persist data with SQLite," Flutter Documentation, 2023. https://docs.flutter.dev/cookbook/persistence/sqlite
- Used to implement `pantry_service.dart`. The database initialisation pattern (`openDatabase`, `onCreate`, table creation SQL), and CRUD methods (`insert`, `query`, `update`, `delete`) follow the official Flutter SQLite cookbook.

[7] Sheraz Ahmad, "Custom Button Widget in Flutter," Medium, 2021. https://medium.com/@sherazthedev/custom-button-widget-in-flutter-7c212138abb2
- Referenced when building reusable button-style widgets such as `_GlassBtn`, `_GradientBtn`, and `_TimerBtn`, particularly the `GestureDetector` wrapping `AnimatedContainer` pattern for press feedback.

[8] ChatGPT, "Generated project file and folder framework," OpenAI, 2026.
- Used to generate the initial project scaffold including folder structure, boilerplate `main.py`, `pubspec.yaml` dependencies, and base class skeletons. All application logic, UI design, ranking algorithms, and feature implementation were written independently.

---

## Roadmap

- [ ] Push notifications for expiring pantry items
- [ ] Cooking history context fed into AI for better suggestions
- [ ] Barcode scanning for packaged goods
- [ ] Nutritional goal tracking with weekly summaries
