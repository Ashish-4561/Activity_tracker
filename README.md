# Activity Tracker - Personal Daily Activity Tracking App with AI Assistant

A modern, responsive personal activity tracking application built with Flutter (mobile) and Node.js/Express (backend). The app allows users to create, manage, and track their daily activities with optional AI-assisted commands.

## Features

### Core Features
- ✅ User authentication (signup/login)
- ✅ Create, read, update, delete activities
- ✅ Mark activities as complete/incomplete
- ✅ Daily progress tracking
- ✅ Activity frequency management (daily, weekly, custom)
- ✅ Secure user data isolation
- ✅ Responsive mobile UI with Flutter
- ✅ RESTful API with proper error handling

### AI Assistant (Coming Soon)
- 🤖 Smart activity suggestions
- 🤖 Natural language commands
- 🤖 Activity management via chat
- 🤖 Progress queries and reporting
- 🤖 Optional AI features (users can disable)

### Additional Screens (In Progress)
- 📅 Calendar view with activity history
- 📊 Weekly/monthly progress analytics
- 👤 Profile and settings management

---

## Project Structure

```
activity-tracker/
├── backend/                           # Node.js/Express backend
│   ├── src/
│   │   ├── index.ts                  # Main application entry
│   │   ├── config/
│   │   │   └── database.ts           # SQLite database setup
│   │   ├── middleware/
│   │   │   └── auth.ts               # JWT authentication middleware
│   │   ├── models/
│   │   │   └── types.ts              # TypeScript interfaces
│   │   ├── controllers/
│   │   │   ├── authController.ts     # Auth logic
│   │   │   ├── activityController.ts # Activity CRUD
│   │   │   ├── completionController.ts # Completion tracking
│   │   │   ├── progressController.ts # Progress calculations
│   │   │   └── chatController.ts     # AI chat handling
│   │   ├── routes/
│   │   │   ├── auth.ts
│   │   │   ├── activities.ts
│   │   │   ├── completions.ts
│   │   │   ├── progress.ts
│   │   │   └── chat.ts
│   │   ├── ai/
│   │   │   ├── toolsFunctions.ts     # Controlled AI tool functions
│   │   │   └── aiService.ts          # LLM integration
│   │   ├── utils/
│   │   │   └── auth.ts               # Auth utilities
│   │   └── services/                 # Business logic services
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── .gitignore
│
├── frontend/                          # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart                 # App entry point
│   │   ├── services/
│   │   │   ├── api_service.dart      # HTTP API calls
│   │   │   ├── auth_service.dart     # Auth state management
│   │   │   └── activity_service.dart # Activity state management
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── signup_screen.dart
│   │   │   ├── home/
│   │   │   │   ├── home_screen.dart
│   │   │   │   ├── activity_card.dart
│   │   │   │   └── add_activity_sheet.dart
│   │   │   ├── calendar/              # (Coming soon)
│   │   │   ├── progress/              # (Coming soon)
│   │   │   ├── chat/                  # (Coming soon)
│   │   │   └── profile/               # (Coming soon)
│   │   ├── widgets/
│   │   ├── models/
│   │   ├── utils/
│   │   └── constants/
│   ├── pubspec.yaml
│   ├── .env.example
│   ├── android/
│   ├── ios/
│   └── .gitignore
│
├── .gitignore
└── README.md
```

---

## Technology Stack

### Backend
- **Runtime**: Node.js (v18+)
- **Framework**: Express.js
- **Language**: TypeScript
- **Database**: SQLite (development) / PostgreSQL (production)
- **Authentication**: JWT (JSON Web Tokens)
- **Password Hashing**: bcryptjs
- **Validation**: express-validator

### Frontend
- **Framework**: Flutter
- **State Management**: Provider
- **HTTP Client**: http package
- **Local Storage**: shared_preferences
- **Date/Time**: intl
- **UI**: Material Design 3

### AI Integration
- **Flexible Architecture**: Support for multiple LLM providers
- **Default**: OpenAI API (easily switchable)
- **Alternative**: Anthropic Claude API
- **Tool Calling**: Controlled backend functions only

---

## Getting Started

### Prerequisites
- **Backend**: Node.js (v18+), npm or yarn
- **Frontend**: Flutter SDK (3.0+), Android/iOS development environment
- **Database**: SQLite3 (included with Node.js packages)

### Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Update .env with:**
   ```
   PORT=5000
   NODE_ENV=development
   DATABASE_PATH=./data/activity_tracker.db
   JWT_SECRET=your_secret_key_here
   OPENAI_API_KEY=your_openai_key (optional)
   API_URL=http://localhost:5000/api
   ```

5. **Start development server:**
   ```bash
   npm run dev
   ```

   The backend will:
   - Initialize SQLite database at `./data/activity_tracker.db`
   - Create all required tables
   - Start listening on `http://localhost:5000`

### Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your backend API URL
   ```

4. **Update .env:**
   ```
   API_URL=http://localhost:5000/api
   ```

5. **Run on development device/emulator:**
   ```bash
   # Android
   flutter run

   # iOS
   flutter run -d <device_id>
   ```

---

## API Endpoints

### Authentication
- `POST /api/auth/signup` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/profile` - Get current user profile (auth required)
- `PUT /api/auth/profile` - Update user profile (auth required)

### Activities
- `POST /api/activities` - Create activity (auth required)
- `GET /api/activities` - List all user activities (auth required)
- `GET /api/activities/:id` - Get single activity (auth required)
- `PUT /api/activities/:id` - Update activity (auth required)
- `DELETE /api/activities/:id` - Soft delete activity (auth required)

### Completions
- `POST /api/completions/complete` - Mark activity as complete (auth required)
- `POST /api/completions/uncomplete` - Mark activity as incomplete (auth required)
- `GET /api/completions/by-date` - Get completions for specific date (auth required)
- `GET /api/completions/history` - Get completion history (auth required)

### Progress
- `GET /api/progress/daily` - Get daily progress (auth required)
- `GET /api/progress/weekly` - Get weekly progress (auth required)
- `GET /api/progress/monthly` - Get monthly progress (auth required)
- `GET /api/progress/streak` - Get streak data (auth required)

### Chat/AI
- `POST /api/chat/message` - Send message to AI assistant (auth required)
- `GET /api/chat/history` - Get chat message history (auth required)

---

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  theme TEXT DEFAULT 'light',
  ai_enabled INTEGER DEFAULT 1,
  ai_suggestions_enabled INTEGER DEFAULT 1,
  notifications_enabled INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Activities Table
```sql
CREATE TABLE activities (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  icon TEXT,
  frequency TEXT NOT NULL DEFAULT 'daily',
  is_active INTEGER DEFAULT 1,
  color TEXT,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Activity Completions Table
```sql
CREATE TABLE activity_completions (
  id TEXT PRIMARY KEY,
  activity_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  completed INTEGER DEFAULT 0,
  completed_at DATETIME,
  notes TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(activity_id, user_id, date)
);
```

---

## Security Features

### Authentication
- ✅ JWT token-based authentication
- ✅ Secure password hashing (bcryptjs)
- ✅ Token expiration (7 days default)
- ✅ Protected API endpoints

### Data Isolation
- ✅ Every query verified against authenticated user ID
- ✅ No cross-user data access possible
- ✅ Soft deletes for data preservation
- ✅ Proper foreign key constraints

### AI Tool Functions
- ✅ Controlled backend functions only
- ✅ AI cannot access database directly
- ✅ All operations verified for user ownership
- ✅ Input validation on all endpoints

### Best Practices
- ✅ Environment variables for sensitive data
- ✅ HTTPS/TLS ready (production)
- ✅ CORS configured for frontend
- ✅ Input validation and sanitization

---

## AI Assistant Architecture

### Intent Detection (Current Phase)
The AI uses pattern matching to detect user intent:
- **Add Activity**: "Add reading as daily", "Create coding activity"
- **Delete Activity**: "Remove meditation", "Delete gym"
- **Update Activity**: "Rename gym to workout", "Make reading weekly"
- **Mark Complete**: "I completed coding", "Mark gym as done"
- **Mark Incomplete**: "Undo reading", "Not done with coding"
- **Progress Query**: "How did I do today?", "Show my progress"

### Future LLM Integration
The architecture supports upgrading to full LLM function calling:
1. Replace `processIntentWithTools()` with actual LLM calls
2. Use OpenAI function calling or Claude tools
3. Keep the same backend tool functions (`aiCreateActivity`, etc.)
4. Maintains user data security and isolation

---

## Development Phases (Implemented)

### ✅ Phase 1-8: Core Foundation (COMPLETE)
- Core UI and navigation
- Authentication and database
- Activity CRUD operations
- Daily completion tracking
- Flutter UI structure
- Login/Signup screens
- Home screen with daily progress
- Activity card component

### 🔄 Phase 9-10: Advanced Features (IN PROGRESS)
- [ ] Calendar screen with monthly view
- [ ] Weekly/monthly progress analytics
- [ ] AI chat popup component
- [ ] AI tool/function calling backend

### ⏳ Phase 11-12: Polish & Testing
- [ ] Progress screen with detailed analytics
- [ ] Profile/settings management
- [ ] AI activity management commands
- [ ] Error handling and edge cases
- [ ] UI polish and animations
- [ ] Comprehensive testing

---

## Building for Production

### Backend Production Build
```bash
cd backend
npm run build
npm start
```

### Frontend Production Build
```bash
cd frontend

# iOS
flutter build ios --release

# Android
flutter build apk --release
flutter build appbundle --release
```

---

## Environment Configuration

### Backend .env (Production)
```
PORT=5000
NODE_ENV=production
DATABASE_PATH=/var/lib/activity_tracker/data.db
JWT_SECRET=<generate_strong_secret>
OPENAI_API_KEY=<your_api_key>
FRONTEND_URL=https://yourdomain.com
```

### Frontend .env (Production)
```
API_URL=https://api.yourdomain.com/api
APP_NAME=Activity Tracker
```

---

## Troubleshooting

### Backend Issues
- **Database error**: Ensure `./data/` directory exists
- **Port already in use**: Change PORT in .env
- **JWT errors**: Verify JWT_SECRET is set
- **CORS errors**: Check FRONTEND_URL matches your app

### Frontend Issues
- **API connection failed**: Verify API_URL in .env
- **Hot reload issues**: Run `flutter clean` then `flutter pub get`
- **Package not found**: Run `flutter pub get`

---

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit changes: `git commit -am 'Add new feature'`
3. Push to branch: `git push origin feature/your-feature`
4. Submit a pull request

---

## License

This project is open source and available under the MIT License.

---

## Support

For issues, questions, or suggestions:
1. Check existing issues on GitHub
2. Create a new issue with detailed description
3. Include steps to reproduce and environment details

---

## Roadmap

### Short Term
- [ ] Calendar screen implementation
- [ ] Monthly progress analytics
- [ ] AI chat popup (fully functional)
- [ ] Profile/Settings page

### Medium Term
- [ ] Advanced filtering and sorting
- [ ] Activity history and insights
- [ ] Custom reminders
- [ ] Data export (CSV/PDF)
- [ ] Multi-language support

### Long Term
- [ ] Habit goal tracking
- [ ] Social features (share progress)
- [ ] Integration with calendar apps
- [ ] Gamification (badges, levels)
- [ ] Advanced AI coaching
- [ ] Web version
- [ ] Desktop app (Windows/Mac)

---

**Version**: 1.0.0  
**Last Updated**: 2026-09-02
