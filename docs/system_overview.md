# PIATRA — System Overview

## High-Level Architecture

PIATRA is composed of two main components — a Flutter mobile app and a FastAPI backend — plus three external services.

```
┌───────────────────────────────────────────────────────────────────┐
│                       Flutter Mobile App                          │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │   Screens    │  │    State     │  │      Services         │  │
│  │              │  │              │  │                       │  │
│  │ Home         │  │ UserProvider │  │ PantryService (SQLite)│  │
│  │ Pantry       │  │ RecipeProv.  │  │ PantryFirebaseSvc     │  │
│  │ Scan         │  │ SavedRecipes │  │ PantrySyncManager     │  │
│  │ Recipes      │  │ ThemeProv.   │  │ SpoonacularService    │  │
│  │ RecipeDetail │  │              │  │ RecipeRankingEngine   │  │
│  │ CookingMode  │  └──────────────┘  │ MealPlanService       │  │
│  │ MealPlan     │                    │ NutritionHistorySvc   │  │
│  │ Analytics    │                    │ RecipeHistoryService  │  │
│  │ Assistant    │                    │ SavedRecipesService   │  │
│  │ Profile      │                    │ ProfileFirebaseSvc    │  │
│  │ Feedback     │                    │ PantryScanner (Vision)│  │
│  └──────────────┘                    └───────────────────────┘  │
└──────┬──────────────────────┬─────────────────────┬─────────────┘
       │ HTTP REST             │ Firebase SDK          │ HTTP REST
       ▼                      ▼                      ▼
┌─────────────┐   ┌─────────────────────┐   ┌───────────────────┐
│   FastAPI   │   │      Firebase       │   │   Spoonacular     │
│   Backend   │   │                     │   │   Recipe API      │
│             │   │  Auth               │   │                   │
│ /assistant  │   │  Firestore          │   │ findByIngredients │
│ /users      │   │                     │   │ complexSearch     │
│ /feedback   │   │  Collections:       │   │ informationBulk   │
│             │   │  user_profiles      │   │                   │
│  Gemini     │   │  pantry_items       │   └───────────────────┘
│  2.5 Flash  │   │  meal_plans         │
│  (text +    │   │  shopping_lists     │
│   vision)   │   │  nutrition_logs     │
│             │   │  recipe_history     │
│  SMTP       │   │  saved_recipes      │
│  (feedback) │   │                     │
└─────────────┘   └─────────────────────┘
```

---

## Component Responsibilities

### Flutter Mobile App

The app is the primary interface. It owns the user experience end-to-end and handles all real-time data flows.

**Screens** render UI and dispatch actions to providers. They never call services directly — they go through the provider layer.

**Providers** (ChangeNotifier) hold application state and coordinate between screens and services. There are four global providers:
- `UserProvider` — current user profile, auto-saved to Firebase on every change
- `RecipeProvider` — ranked recipe list, filter state, Spoonacular fetch orchestration
- `SavedRecipesProvider` — bookmarked recipe IDs (streamed from Firestore) and the saved list
- `ThemeProvider` — dark/light mode toggle

**Services** handle data access. They are stateless singletons. The pantry services form a three-layer stack:
- `PantryService` — SQLite read/write (fast, offline-capable)
- `PantryFirebaseService` — Firestore read/write
- `PantrySyncManager` — merges the two; cloud changes stream into local DB

### FastAPI Backend

The backend is a thin orchestration layer. It does not store application data (all persistent data lives in Firebase) — it exists to proxy AI calls and protect credentials.

Responsibilities:
- Verify Firebase ID tokens
- Build rich AI context from Firestore (pantry + profile) via `ContextBuilder`
- Send prompts to Gemini and stream back formatted responses
- Decode and validate vision scan payloads before passing to Gemini
- Deliver feedback emails via SMTP

### Firebase

Firebase serves two roles:
- **Firebase Auth** — user identity and token issuance (handled client-side in the app; the backend only verifies tokens)
- **Firestore** — persistent storage for all user data (profiles, pantry, meal plans, nutrition history, recipe history, saved recipes)

Firestore is accessed directly from the Flutter app (via the Firebase SDK) for real-time streams (pantry sync, saved recipe IDs). The backend accesses Firestore via the Firebase Admin SDK for context building.

### Spoonacular

External recipe database. Accessed exclusively from the Flutter app — the backend has no Spoonacular integration. The app uses three endpoints:

- `findByIngredients` — discovers recipes that match pantry contents
- `complexSearch` — filtered search by diet, cuisine, intolerance, nutrition
- `informationBulk` — fetches full recipe data (nutrition, steps, ingredients) in a single call

### Gemini AI

Google's Gemini 2.5 Flash model, accessed from the backend only. Used for:
- General conversational cooking assistant
- Nutrition advice with user context
- Recipe suggestions with pantry context
- Vision-based pantry scanning (multimodal call with base64 image)

---

## Data Flow Diagrams

### Pantry Scan

```
User taps camera
       │
       ▼
ImagePicker → XFile (local path)
       │
       ▼
PantryScanner.detectObjects()
  • Read file bytes
  • base64 encode
  • Build payload: "VISION_SCAN::image/jpeg::<base64>"
       │
       ▼ POST /api/assistant/chat
       │  { message: "<prompt>", context: "VISION_SCAN::...", user_id: "" }
       │
FastAPI backend
  • Detects VISION_SCAN:: prefix
  • Decodes base64 → raw bytes
  • Calls Gemini 2.5 Flash with image + strict JSON prompt
  • Strips markdown fences, extracts JSON array
  • Filters generic labels (fruit, vegetable, food…)
  • Returns: { response: "[{name, confidence}, ...]" }
       │
       ▼
Flutter parses JSON array → List<DetectionResult>
PantryScanner.filterFoodItems() (confidence ≥ 0.35)
       │
       ▼
_DetectionResultsSheet — user reviews, edits, deletes
       │
User taps "Add N to Pantry"
       │
       ▼
PantrySyncManager.addItem() for each confirmed item
  • PantryService.insertItem() → SQLite
  • PantryFirebaseService.uploadItem() → Firestore
```

### Recipe Recommendation Pipeline

```
RecipeProvider.loadRecommendations(profile)
       │
       ├─ PantryService.getAllItems() → local SQLite pantry names
       │
       ├─ PASS 1: SpoonacularService.findByIngredients(pantryNames, n=30)
       │    └─ getRecipesBulk(ids) → List<SpoonacularRecipe> with full data
       │
       ├─ PASS 2: SpoonacularService.complexSearch(cuisine, diet, intolerances, ...)
       │    └─ Returns recipes with nutrition embedded (addRecipeNutrition=true)
       │
       ├─ PASS 3 (if cuisine filter active and < 5 cuisine matches):
       │    SpoonacularService.complexSearch(cuisine only, no ingredient constraint)
       │
       ├─ Deduplicate by recipe ID
       │
       └─ RecipeRankingEngine.rankAndFilter(recipes, profile, pantry, filter)
            │
            ├─ Stage 0: Hard restriction gate
            │    • Diet compliance (vegetarian, vegan, gluten free, dairy free, keto)
            │    • Intolerance/allergy exclusions
            │    • Numeric hard filters (time, calories, macros, dish type, pantry-only mode)
            │
            ├─ Stage 1: Score each recipe (0–100)
            │    • Pantry match:    fraction of ingredients in pantry × 35
            │    • Calorie fit:     proximity to per-meal target × 20
            │    • Macro fit:       protein/carbs/fat vs. targets × 15
            │    • Cuisine score:   binary match vs. selected cuisines × 15
            │    • Cooking-mode:    mode-specific heuristics × 10
            │    • Popularity:      Spoonacular health + score × 5
            │
            ├─ Stage 2: Partition + sort
            │    Group A: cuisine-matching → sorted by score DESC
            │    Group B: non-cuisine     → sorted by score DESC
            │    Final list: [Group A] + [Group B]
            │
            └─ Stage 3: Pantry-miss warning flag
                 If all top results have > 80% missing ingredients
                 → pantryMatchWarning = true (UI shows banner)
```

### Context-Aware AI Chat

```
User sends message in AssistantScreen
       │
       ▼
_buildPantryContext()
  • PantryService.getAllItems() → local SQLite
  • Format: "Pantry items (N total):\n- Apple (3)\n- ..."

_buildProfileContext()
  • context.read<UserProvider>().profile
  • Format: "Cooking profile:\n- Name: Jane\n- Mode: ⚡ Quick Meals\n..."

Recent conversation history (last 10 messages)
       │
       ▼ POST /api/assistant/chat
  { message, context: "<profile>\n\n<pantry>\n\nConversation:\n...", user_id: "" }
       │
FastAPI — ai_assistant.py
  • context does NOT start with VISION_SCAN:: → normal chat path
  • user_id is empty → skip ContextBuilder (context already built client-side)
  • Build Gemini prompt with PIATRA system instructions + context
  • Call Gemini 2.5 Flash
  • format_gemini_response(): ** → Unicode bold, - → •
  • Return { response: "..." }
       │
       ▼
Flutter renders in chat bubble
```

### Cooking Mode Completion

```
User taps "Finish!" on final step
       │
       ▼
_logCompletion()
  │
  ├─ NutritionHistoryService.logMeal()
  │    • Firestore: nutrition_logs/{uid}/entries/{auto_id}
  │    • Fields: recipeId, title, image, calories, protein, carbs, fat,
  │              fiber, sodium, servings, cookedAt, cuisines, tags
  │
  └─ RecipeHistoryService.recordCook()
       • Firestore: recipe_history/{uid}/cooked/{recipeId}
       • If exists: increment cookCount, update lastCookedAt
       • If new: create CookedRecipe document
       │
       ▼
_CompletionScreen renders
  • Shows macro summary from recipe.nutrition
  • "Logged to Nutrition History ✓"
  • Navigation to Home or Analytics
```

### Meal Plan → Shopping List

```
User taps "Generate Shopping List"
       │
       ▼
PantryService.getAllItems() → pantryNames (List<String>)
       │
       ▼
MealPlanService.generateShoppingList(plan, pantryNames)
  │
  ├─ Aggregate all PlannedIngredient across all MealPlanDay × MealSlot
  │    Group by name.toLowerCase(), sum amounts, track which recipes need each
  │
  ├─ Cross-reference vs. pantry names (fuzzy: contains match)
  │    → alreadyInPantry: items the user already has
  │    → toShop: items that need to be purchased
  │
  └─ Persist to Firestore: shopping_lists/{uid}/lists/{auto_id}
       │
       ▼
ShoppingListScreen renders
  • "To Buy" section with checkboxes
  • "In Cart" section for checked items
  • "Already Have" collapsible section
  • Progress bar (checked / total)
  • Copy-to-clipboard exports unchecked items as plain text
```

---

## State Management

The app uses the **Provider** package with `ChangeNotifier`. State flows unidirectionally:

```
User action
    │
    ▼
Screen dispatches to Provider
    │
    ▼
Provider calls Service(s)
    │
    ▼
Service reads/writes data source (SQLite / Firestore / HTTP)
    │
    ▼
Provider updates state + notifyListeners()
    │
    ▼
Widgets rebuild via Consumer<T> or context.watch<T>()
```

**Provider scope** — All four providers are registered at the root `MultiProvider` in `RootApp`, so they persist for the entire app lifetime. This means recipe results, pantry state, and the user profile are not re-fetched on navigation.

**Auto-save pattern** — `UserProvider` saves to Firebase on every setter call (`updateCookingMode`, `updateAllergies`, etc.). The Profile screen uses `WillPopScope` to trigger a final save on back-navigation, and displays a "Save" button in the app bar when unsaved changes exist.

---

## Offline Behaviour

| Feature | Offline behaviour |
|---------|------------------|
| Pantry read | ✅ Served from SQLite |
| Pantry write | ✅ Written to SQLite; queued push to Firestore on reconnect (via `PantrySyncManager`) |
| Recipe recommendations | ❌ Requires Spoonacular API |
| AI chat | ❌ Requires backend + Gemini |
| Pantry scan | ❌ Requires backend + Gemini Vision |
| User profile read | ✅ Last value cached in `UserProvider` memory |
| Meal plan | ❌ Requires Firestore |
| Analytics | ❌ Requires Firestore |

---

## Security

**Firebase ID token verification** — The backend calls `firebase_admin.auth.verify_id_token()` on every protected endpoint. Tokens are short-lived (1 hour) and are not stored server-side.

**JWT** — A secondary JWT (HS256, 30-minute expiry) is issued by `/api/users/login` for use cases that need a non-Firebase token. Signed with `SECRET_KEY` from the environment.

**API keys** — The Gemini API key and Spoonacular API key are never exposed to the client. Gemini is accessed only from the backend. Spoonacular is accessed from the mobile app but the key is loaded from a `.env` file excluded from version control.

**CORS** — The backend currently allows all origins (`allow_origins=["*"]`). This should be tightened to the production domain after launch.

**Feedback endpoint** — The `/api/feedback/` endpoint is unauthenticated to minimise friction. It rate-limits exposure by requiring a non-empty body and logging all submissions server-side regardless of email delivery success.

---

## Deployment

### Backend

Deployed to [Render](https://render.com) as a web service. The `/health` endpoint is used as the health check URL. Environment variables are set in the Render dashboard.

**Start command:** `python main.py`  
**Build command:** `pip install -r requirements.txt`  
**Python version:** 3.8+

### Mobile App

Distributed via the App Store (iOS) and Google Play (Android). The production backend URL is hardcoded in `app_config.dart`. Toggle `_useProduction = false` for local development.

**Local dev URLs:**
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://127.0.0.1:8000`
- Physical device (LAN): `http://192.168.x.x:8000`

---

## Third-Party Dependencies

### Backend (`requirements.txt`)

| Package | Purpose |
|---------|---------|
| `fastapi` | Web framework |
| `uvicorn[standard]` | ASGI server |
| `google-generativeai` | Gemini AI SDK |
| `firebase-admin` | Firestore + Auth admin |
| `python-jose[cryptography]` | JWT creation and verification |
| `passlib[bcrypt]` | Password hashing (for server-side registration) |
| `pydantic` | Request/response validation |
| `email-validator` | Email field validation in Pydantic models |
| `python-dotenv` | `.env` file loading |

### Mobile App (key `pubspec.yaml` dependencies)

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `firebase_core` | Firebase initialisation |
| `cloud_firestore` | Firestore SDK |
| `firebase_auth` | Firebase Auth SDK |
| `sqflite` | Local SQLite database |
| `http` | HTTP client for backend + Spoonacular |
| `image_picker` | Camera and gallery access |
| `google_fonts` | Sora + DM Sans typefaces |
| `flutter_dotenv` | `.env` file loading |
| `shared_preferences` | Local UID persistence for guest users |
| `path_provider` | SQLite database file path |