# PIATRA — Documentation

This folder contains technical documentation for the PIATRA project.

---

## Documents

### `README.md` ← you are here
Index of all documentation.

### `api_spec.md`
Full API reference — all endpoints, request/response shapes, authentication requirements, and error codes.

### `system_overview.md`
High-level architecture diagram and data-flow descriptions covering how the Flutter app, FastAPI backend, Firebase, Spoonacular, and Gemini AI interact.

---

## Quick Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                  Flutter Mobile App                  │
│                                                      │
│  Screens: Home, Pantry, Scan, Recipes, Cooking,     │
│           Meal Plan, Analytics, Assistant, Profile   │
│                                                      │
│  State: UserProvider, RecipeProvider,                │
│         SavedRecipesProvider, ThemeProvider          │
│                                                      │
│  Local storage: SQLite (sqflite) — pantry cache      │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
           │ REST (HTTP)           │ Firebase SDK
           ▼                      ▼
┌──────────────────┐   ┌─────────────────────────────┐
│  FastAPI Backend │   │         Firebase             │
│                  │   │                              │
│  /api/assistant  │   │  Firestore collections:      │
│  /api/users      │   │   • user_profiles/{uid}      │
│  /api/feedback   │   │   • pantry_items/{id}        │
│                  │   │   • meal_plans/{uid}/weeks   │
│  Gemini 2.5      │   │   • nutrition_logs/{uid}     │
│  Flash (text +   │   │   • recipe_history/{uid}     │
│  vision)         │   │   • saved_recipes/{uid}      │
└──────────────────┘   └─────────────────────────────┘
           │
           ▼
┌──────────────────┐
│   Spoonacular    │
│   Recipe API     │
│                  │
│  findByIngred.   │
│  complexSearch   │
│  informationBulk │
└──────────────────┘
```

---

## Key Flows

### Pantry Scan
1. User takes a photo in `ScanScreen`
2. `PantryScanner` sends the image (base64) to `/api/assistant/chat` with `context = "VISION_SCAN::<mime>::<base64>"`
3. Backend decodes context, calls Gemini Vision with a strict JSON-array prompt
4. Response is parsed into `DetectionResult` objects
5. User reviews and edits detected items in `_DetectionResultsSheet`
6. Confirmed items are written to SQLite via `PantrySyncManager` and pushed to Firestore

### Recipe Recommendations
1. `RecipeProvider.loadRecommendations()` is called with the current `UserProfileModel`
2. **Pass 1**: `SpoonacularService.findByIngredients()` — pantry-first, returns up to 30 lightweight results
3. **Pass 2**: `SpoonacularService.complexSearch()` — diet/cuisine/intolerance filters applied, up to 20 results
4. **Pass 3** (if cuisine filter active and < 5 matches): cuisine-only search without pantry constraint
5. All results are deduped and bulk-fetched for full nutrition/steps data
6. `RecipeRankingEngine.rankAndFilter()` scores and partitions results
7. UI renders ranked list with pantry-match bar, reason chips, and cuisine grouping

### Cooking Mode
1. User taps "Start Cooking" on a recipe detail screen
2. `CookingModeScreen` renders steps with per-step timer (auto-detected from step text)
3. The AI sous-chef panel has full recipe + current step context
4. On "Finish!", `NutritionHistoryService.logMeal()` and `RecipeHistoryService.recordCook()` are called
5. Completion screen shows macros and offers navigation to Analytics

### Context-Aware AI Chat
1. `AssistantScreen._fetchAIResponse()` builds context from local pantry (SQLite) + profile (`UserProvider`)
2. Sends `{ message, context, user_id }` to `/api/assistant/chat`
3. Backend optionally enriches context further via `ContextBuilder` (Firestore pantry + profile)
4. Gemini response is formatted via `format_gemini_response()` (bold → Unicode bold, `-` → `•`)
5. Response rendered in chat bubble

---

## Data Models

### `UserProfileModel` (Flutter)
| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | Firebase UID |
| `displayName` | String | Display name |
| `cookingMode` | CookingMode | General / QuickMeals / HealthyEating / BulkCooking / BudgetFriendly / Gourmet |
| `calorieTarget` | int | Daily calorie goal |
| `macroTargets` | MacroTargets | Protein / carbs / fat in grams |
| `favoriteCuisines` | List\<String\> | Ranked cuisine preferences |
| `dietaryPreferences` | List\<String\> | Hard exclusion diets (vegan, keto, etc.) |
| `allergies` | List\<String\> | Hard exclusion allergens |

### `PantryItem` (Flutter)
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique ID (timestamp-based for scanned items) |
| `name` | String | Ingredient name |
| `quantity` | String | Free-form quantity string |
| `expiryDate` | DateTime? | Optional expiry date |
| `category` | String | Vegetables / Fruits / Dairy / Meat / Grains & Legumes / Beverages / Bakery / Other |

### `RecipeFilter`
Encapsulates all filter and sort criteria for the recipe ranking engine. Key fields: `cuisines`, `diets`, `intolerances`, `dishTypes`, `maxReadyMinutes`, `minCalories`, `maxCalories`, `minProteinG`, `maxCarbsG`, `pantryOnlyMode`, `sortOrder`.

### Recipe Ranking Score (0–100)
| Component | Max Points | Signal |
|-----------|-----------|--------|
| Pantry match | 35 | Fraction of ingredients in pantry |
| Calorie fit | 20 | Proximity to per-meal target |
| Macro fit | 15 | Protein / carbs / fat vs. targets |
| Cuisine score | 15 | Binary match vs. selected cuisines |
| Cooking-mode fit | 10 | Speed, health, servings, etc. |
| Popularity | 5 | Spoonacular health + popularity scores |

---

## Environment Variables

### Backend (`backend/.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `GEMINI_API_KEY` | ✅ | Google AI Studio key |
| `FIREBASE_PROJECT_ID` | ✅ | Firebase project ID |
| `FIREBASE_PRIVATE_KEY` | ✅ | Firebase service account private key |
| `FIREBASE_CLIENT_EMAIL` | ✅ | Firebase service account email |
| `SECRET_KEY` | ✅ | 64-char random string for JWT signing |
| `DEBUG` | ❌ | `true` enables debug logging (default: false) |
| `FEEDBACK_EMAIL` | ❌ | Gmail address for feedback sending |
| `FEEDBACK_EMAIL_PASSWORD` | ❌ | Gmail App Password |
| `FEEDBACK_RECEIVER_EMAIL` | ❌ | Feedback destination (defaults to FEEDBACK_EMAIL) |

### Mobile (`mobile_app/.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `SPOONACULAR_API_KEY` | ✅ | Spoonacular API key (free tier: 150 pts/day) |

---

## Firestore Collections

| Collection | Document ID | Contents |
|-----------|-------------|----------|
| `user_profiles/{uid}` | Firebase UID | Full `UserProfileModel` |
| `pantry_items/{id}` | Item ID | `PantryItem` fields |
| `meal_plans/{uid}/weeks/{weekKey}` | `YYYY-WW` | `MealPlan` with days and slots |
| `shopping_lists/{uid}/lists/{id}` | Auto | `ShoppingList` with checked items |
| `nutrition_logs/{uid}/entries/{id}` | Auto | `NutritionLogEntry` per cooked meal |
| `recipe_history/{uid}/cooked/{recipeId}` | Spoonacular ID | `CookedRecipe` with cook count |
| `saved_recipes/{uid}/items/{recipeId}` | Spoonacular ID | `SavedRecipe` snapshot |