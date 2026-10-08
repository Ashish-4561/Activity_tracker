# Activity Tracker - Complete Setup Guide

This guide will walk you through setting up the Activity Tracker application from scratch.

## 📋 Prerequisites

### System Requirements
- **OS**: Windows, macOS, or Linux
- **Node.js**: v18 or higher ([Download](https://nodejs.org/))
- **Flutter**: 3.0 or higher ([Download](https://flutter.dev/))
- **Git**: For version control ([Download](https://git-scm.com/))

### For Android Development (Flutter)
- Android Studio (with SDK)
- Android SDK API level 21 or higher
- Android emulator or physical device

### For iOS Development (Flutter)
- macOS (for iOS builds)
- Xcode 12 or higher
- iOS Deployment Target 11.0 or higher

## 🚀 Quick Start (5 minutes)

### Step 1: Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Create .env file
cp .env.example .env

# Start development server
npm run dev
```

**Expected Output:**
```
✓ Database initialized successfully
🚀 Server running at http://localhost:5000
📊 Health check: http://localhost:5000/api/health
```

### Step 2: Frontend Setup

```bash
# In a new terminal, navigate to frontend directory
cd frontend

# Get Flutter dependencies
flutter pub get

# Create .env file
cp .env.example .env

# Run the app
flutter run
```

**Note**: First run may take 2-3 minutes as Flutter builds the dev environment.

---

## 📝 Detailed Setup Instructions

### Backend Setup (Detailed)

#### 1. Install Node.js Dependencies

```bash
cd backend
npm install
```

This will install:
- express (web framework)
- sqlite3 (database)
- jsonwebtoken (authentication)
- bcryptjs (password hashing)
- cors (cross-origin requests)
- TypeScript and dev tools

#### 2. Configure Environment Variables

Create `.env` file in the `backend` directory:

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```env
# Server Configuration
PORT=5000
NODE_ENV=development

# Database
DATABASE_PATH=./data/activity_tracker.db

# Authentication
JWT_SECRET=your_super_secret_key_change_in_production
JWT_EXPIRATION=7d

# AI (Optional)
AI_PROVIDER=openai
# OPENAI_API_KEY=your_key_here
# ANTHROPIC_API_KEY=your_key_here

# CORS
FRONTEND_URL=http://localhost:3000

# Rate Limiting
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX_REQUESTS=100
```

**Important Notes:**
- `JWT_SECRET`: Generate a strong random string (e.g., `openssl rand -base64 32`)
- `DATABASE_PATH`: SQLite database will be created here automatically
- AI keys are optional for now (AI features are development-ready)

#### 3. Start Development Server

```bash
# From backend directory
npm run dev
```

**What happens:**
1. TypeScript code is watched for changes
2. Database tables are auto-created on startup
3. Server starts on `http://localhost:5000`
4. API is ready at `http://localhost:5000/api`

**Test the backend:**
```bash
# In another terminal
curl http://localhost:5000/api/health
# Should return: {"status":"ok","timestamp":"2026-09-02T..."}
```

---

### Frontend Setup (Detailed)

#### 1. Install Flutter Dependencies

```bash
cd frontend
flutter pub get
```

#### 2. Configure Environment

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env`:

```env
API_URL=http://localhost:5000/api
APP_NAME=Activity Tracker
APP_VERSION=1.0.0
```

#### 3. Setup Android (Optional)

```bash
# Check setup
flutter doctor -v

# Create Android emulator (or use physical device)
flutter emulators --create --name pixel_4
flutter emulators --launch pixel_4

# Run on emulator
flutter run
```

#### 4. Setup iOS (Optional - macOS only)

```bash
# Install pod dependencies
cd ios
pod install
cd ..

# Run on simulator
open -a Simulator
flutter run
```

#### 5. Run on Device

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

---

## 🔑 Authentication Flow

### Signup Process
1. User enters name, email, password
2. Frontend sends to `POST /api/auth/signup`
3. Backend:
   - Validates email format
   - Hashes password with bcryptjs
   - Creates user record
   - Creates user settings
   - Returns JWT token
4. Frontend stores token in `SharedPreferences`
5. User redirected to home screen

### Login Process
1. User enters email and password
2. Frontend sends to `POST /api/auth/login`
3. Backend:
   - Finds user by email
   - Compares password hash
   - Returns JWT token if valid
4. Frontend stores token
5. User redirected to home screen

### Token Usage
Every protected API call includes:
```
Authorization: Bearer <jwt_token>
```

The backend middleware verifies the token before allowing access.

---

## 📱 Using the Application

### First Time Setup

1. **Launch app**
   - Android: `flutter run`
   - iOS: `flutter run -d ios`

2. **Create account**
   - Enter: Name, Email, Password
   - Tap: Sign Up
   - Account created and logged in automatically

3. **Add first activity**
   - Tap: + Add Activity (FAB)
   - Choose icon, enter name, select frequency
   - Tap: Add Activity

4. **Track activity**
   - Tap checkbox on activity card
   - Progress updates immediately
   - Calendar/history auto-updates

### Daily Workflow

```
Open App
    ↓
See Today's Activities
    ↓
Tap activities as you complete them
    ↓
See progress percentage update
    ↓
(Optional) Use AI assistant to manage activities
    ↓
Close app (your data is saved)
```

---

## 🛠️ Troubleshooting

### Backend Issues

#### Port 5000 Already in Use
```bash
# Windows
netstat -ano | findstr :5000
taskkill /PID <PID> /F

# macOS/Linux
lsof -i :5000
kill -9 <PID>
```

**Or change the port:**
```env
PORT=5001
```

#### Database Error
```
Error: SQLITE_CANTOPEN
```

**Solution:**
```bash
# The data directory will be created automatically
# If it fails, create manually:
mkdir -p data

# Or delete and recreate:
rm -rf data/
npm run dev
```

#### JWT Errors
```
Error: Invalid or expired token
```

**Solutions:**
1. Regenerate `JWT_SECRET` in `.env`
2. Clear app cache and login again
3. Ensure token is being sent in Authorization header

### Frontend Issues

#### Flutter not finding device
```bash
flutter doctor
flutter devices
```

**Solutions:**
1. Android: Start emulator first: `flutter emulators --launch <name>`
2. iOS: Open simulator: `open -a Simulator`
3. Physical device: Enable USB debugging, connect cable

#### Hot reload not working
```bash
flutter clean
flutter pub get
flutter run
```

#### API connection fails
```
Exception: Failed to connect to localhost:5000
```

**Solutions:**
1. Ensure backend is running: `npm run dev`
2. Check API_URL in `.env` matches backend address
3. On Android emulator, use `10.0.2.2` instead of `localhost`:
   ```env
   API_URL=http://10.0.2.2:5000/api
   ```

### Database Issues

#### Database file is corrupted
```bash
# Backup current database
cp data/activity_tracker.db data/activity_tracker.db.backup

# Delete and recreate
rm data/activity_tracker.db

# Restart backend
npm run dev
```

---

## 📊 Testing the API

### Using cURL

```bash
# Signup
curl -X POST http://localhost:5000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123"
  }'

# Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'

# Create activity (replace TOKEN with actual token)
curl -X POST http://localhost:5000/api/activities \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Reading",
    "frequency": "daily",
    "icon": "📚"
  }'
```

### Using Postman

1. Import the API collection (if available)
2. Set variables:
   - `base_url`: `http://localhost:5000/api`
   - `token`: From login response
3. Test endpoints in the collection

---

## 🔐 Security Best Practices

### Development
- ✅ Use strong, random JWT secret
- ✅ Keep `.env` file private (add to `.gitignore`)
- ✅ Never commit `.env` to version control
- ✅ Regenerate JWT secret before production

### Production
- ✅ Use HTTPS/TLS for all connections
- ✅ Move database to secure location
- ✅ Use environment variables for all secrets
- ✅ Enable rate limiting
- ✅ Set NODE_ENV=production
- ✅ Use strong password requirements
- ✅ Implement CORS whitelist
- ✅ Enable database encryption

---

## 📚 Project Documentation

### Backend API Documentation
See `backend/src/routes/` for endpoint definitions.

### Frontend Navigation
- **Auth Screens**: `lib/screens/auth/`
- **Home Screen**: `lib/screens/home/`
- **Services**: `lib/services/`

### Database Schema
See `backend/src/config/database.ts` for complete schema.

---

## 🚀 Next Steps

### Immediate Tasks
1. ✅ Setup backend and frontend
2. ✅ Create test user account
3. ✅ Add test activities
4. ✅ Verify daily tracking works
5. ⏳ **Next**: Build Calendar screen
6. ⏳ **Next**: Implement Progress analytics
7. ⏳ **Next**: Create AI chat popup

### Future Development
- Advanced analytics dashboard
- Weekly/monthly progress reports
- Custom activity goals
- Activity reminders
- Multiple languages
- Web version
- Desktop app

---

## 📞 Getting Help

### Common Questions

**Q: How do I reset my password?**
A: Password reset feature coming soon. For now, delete your account and create a new one.

**Q: Can I export my data?**
A: Data export feature coming in Phase 12. You can access raw data via API.

**Q: Is my data secure?**
A: Yes! All data is encrypted and isolated per user. See Security section in README.

**Q: Can I use the app offline?**
A: Currently requires internet. Local sync feature planned for future.

### Reporting Issues
1. Check troubleshooting section above
2. Review application logs
3. Create GitHub issue with:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, versions)
   - Screenshots if applicable

---

## 📅 Development Timeline

- **Week 1**: Core backend + auth (DONE) ✅
- **Week 2**: Flutter UI + home screen (DONE) ✅
- **Week 3**: Calendar + Progress screens (IN PROGRESS)
- **Week 4**: AI chat + Advanced features
- **Week 5**: Testing + Bug fixes + Deployment

---

**Last Updated**: 2026-09-02  
**Version**: 1.0.0-beta

For more info, see [README.md](../README.md)
