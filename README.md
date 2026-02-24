## PIATRA

Smart Pantry &amp; Recipe Intelligence App

![PIATRA Mascot](PIATRA.jpg)
## Backend Setup

The backend is built with FastAPI and integrates Google's Gemini AI for the assistant chatbot, plus Firebase for user authentication and data storage.

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
- `POST /api/users/register` - Register a new user (server-side, for testing)
- `POST /api/users/create-profile` - Create/update user profile after Firebase Auth
- `POST /api/users/login` - Login with Firebase ID token and get JWT token
- `GET /api/users/profile` - Get user profile (requires Firebase ID token)
- `PUT /api/users/profile` - Update user profile (requires Firebase ID token)
- `POST /api/assistant/chat` - Chat with AI assistant
- `POST /api/assistant/nutrition-advice` - Get nutrition advice
- `POST /api/assistant/recipe-suggestions` - Recipe suggestions

### Authentication Flow

1. **Client-side**: User registers/authenticates with Firebase Auth SDK
2. **Create Profile**: Call `/api/users/create-profile` with Firebase ID token
3. **Login**: Call `/api/users/login` with Firebase ID token to get JWT
4. **API Access**: Use Firebase ID token for user-specific operations