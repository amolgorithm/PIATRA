## PIATRA

Smart Pantry & Recipe Intelligence App

![PIATRA Mascot](PIATRA.jpg)

## Features

- **AI-Powered Assistant**: Chat with Gemini AI for nutrition advice and recipe suggestions
- **User Profile Management**: Complete user registration, authentication, and profile management
- **Firebase Integration**: Secure authentication and data storage with Firebase
- **Nutrition Tracking**: Monitor dietary preferences, allergies, and nutritional goals
- **Pantry Management**: Track ingredients and get smart recipe recommendations

## Backend Setup

The backend is built with FastAPI and integrates Google's Gemini AI for the assistant chatbot, plus Firebase for user management.

### Prerequisites
- Python 3.8+
- Firebase project with Firestore and Authentication enabled
- Gemini API key from Google AI Studio

### Installation
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set up environment variables:
   - Copy `.env.example` to `.env`
   - Add your Gemini API key
   - Add your Firebase service account credentials
   - Add a JWT secret key

4. Run the server:
   ```bash
   python main.py
   ```

The API will be available at `http://localhost:8000`

### API Endpoints
- `POST /api/users/register` - User registration
- `POST /api/users/login` - User authentication
- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update user profile
- `POST /api/assistant/chat` - Chat with AI assistant
- `POST /api/assistant/nutrition-advice` - Get nutrition advice
- `POST /api/assistant/recipe-suggestions` - Recipe suggestions