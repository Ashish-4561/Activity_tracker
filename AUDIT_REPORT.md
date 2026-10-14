# DAYTRACK — COMPREHENSIVE APPLICATION AUDIT REPORT

**Date of Audit**: October 14, 2026  
**Auditor Role**: Senior Full-Stack Software Engineer, Flutter Developer, Backend Architect, Database Engineer, Security Auditor, QA Engineer, DevOps Engineer  
**Target Application**: DayTrack — Personal Daily Activity Tracker  
**Scope**: Flutter Frontend (`frontend/`), Express + TypeScript Backend (`backend/src/`), Database Schema & Migrations (`backend/src/config/database.ts`, `backend/supabase_schema.sql`), Deployment Configuration (`render.yaml`), Authentication & Security Middleware, Automated Tests.

---

## Executive Summary

A comprehensive architectural, security, code quality, database, and integration audit of **DayTrack** was conducted. The application possesses a solid core design featuring Flutter (Mobile/Web), a Node.js/TypeScript REST API backend, and dual database support (Supabase PostgreSQL in production with fallback SQLite in local development). 

However, the audit revealed **critical security vulnerabilities** (unverified account takeover via `/api/auth/google`, plain-text OTP disclosure in HTTP response), **network resilience bugs** (hardcoded local LAN IP in compiled client, missing timeouts on authentication and profile endpoints), **lifecycle and memory leaks** in Flutter widgets, a **completely broken backend test runner (`npm test` failing)**, and **failing Flutter tests due to uncancelled asynchronous timers**.

This report documents verified findings supported by direct code evidence, precise reproduction steps, root cause analyses, and specific recommended fixes.

---

## Summary of Findings by Severity

| Severity | Count | Issue IDs |
|---|---|---|
| **Critical** | 2 | `SEC-01`, `SEC-02` |
| **High** | 4 | `SEC-03`, `BUG-01`, `BUG-02`, `DEV-01` |
| **Medium** | 5 | `SEC-04`, `SEC-05`, `BUG-03`, `BUG-04`, `BUG-05` |
| **Low** | 2 | `BUG-06`, `DEV-02` |

---

## Detailed Audit Findings

### 1. Security Vulnerabilities

---

#### [SEC-01] Critical: Unauthenticated Account Takeover via `/api/auth/google`
- **Severity**: Critical
- **Affected File & Function**: `backend/src/controllers/authController.ts` (`googleAuth`)
- **Route**: `POST /api/auth/google`
- **Steps to Reproduce**:
  1. Send an HTTP POST request to `/api/auth/google` with body:
     ```json
     { "email": "victim@example.com", "name": "Attacker" }
     ```
  2. Observe the server response: Status 200 OK with a signed JWT token for `victim@example.com`.
- **Root Cause**:
  In `authController.ts`:
  ```typescript
  export async function googleAuth(req: AuthRequest, res: Response): Promise<void> {
    const { email, name, profileImage, googleId } = req.body;
    let user = await db.get<User>('SELECT * FROM users WHERE email = ?', [email]);
    ...
    const token = generateToken(user!.id, user!.email || email);
    res.json({ token, user: ... });
  }
  ```
  The endpoint blindly trusts the `email` field supplied in the request body without verifying any Google ID token, cryptographic signature from Google OAuth, or valid Supabase session. Any external caller can forge a request and obtain full administrative access to any user account by knowing only their email address.
- **Recommended Fix**:
  1. Do not accept client-asserted email addresses on public endpoints.
  2. If using Supabase Auth (the primary auth provider), route all OAuth tokens through `Supabase.auth.getUser(token)` in `authMiddleware`.
  3. If supporting direct Google Sign-in on backend, verify the Google `idToken` using `google-auth-library` (`oauth2Client.verifyIdToken({ idToken, audience })`).
- **Regression Tests Required**:
  - Test `POST /api/auth/google` with invalid, expired, or missing tokens; verify rejection with 401 Unauthorized.
  - Verify valid Google / Supabase ID tokens produce authenticated sessions with matching subject identity.

---

#### [SEC-02] Critical: Plaintext OTP Leak in HTTP Response Body & Unrestricted Verification
- **Severity**: Critical
- **Affected File & Function**: `backend/src/controllers/authController.ts` (`sendPhoneOtp`)
- **Route**: `POST /api/auth/phone/send-otp`
- **Steps to Reproduce**:
  1. Send an HTTP POST request to `/api/auth/phone/send-otp` with body:
     ```json
     { "phone": "+19876543210" }
     ```
  2. Examine the response body:
     ```json
     {
       "message": "Verification code sent successfully",
       "phone": "+19876543210",
       "otp": "847291"
     }
     ```
  3. Immediately call `/api/auth/phone/verify-otp` with that OTP to log into or create the target account without physical access to the phone.
- **Root Cause**:
  `authController.ts` lines 346–349 returns `otp: otp` directly in the client response payload and prints it to stdout. Anyone can bypass SMS delivery and authenticate as any phone number.
- **Recommended Fix**:
  1. Never return generated OTPs in API responses in production (`process.env.NODE_ENV === 'production'`).
  2. Gate dev OTP return strictly behind `process.env.NODE_ENV === 'development' && process.env.ENABLE_DEV_OTP === 'true'`.
  3. Integrate an SMS delivery provider (e.g., Twilio, AWS SNS, or Supabase Phone Auth).
  4. Enforce rate limiting on `/phone/send-otp` (e.g. maximum 3 requests per 10 minutes per IP/phone).
- **Regression Tests Required**:
  - Verify `/phone/send-otp` response does not contain `otp` field when `NODE_ENV=production`.
  - Verify rate limiter triggers HTTP 429 upon multiple rapid OTP requests.

---

#### [SEC-03] High: Permissive CORS Configuration with `origin: true` and Credentials Allowed
- **Severity**: High
- **Affected File & Function**: `backend/src/index.ts` (lines 21–24)
- **Steps to Reproduce**:
  1. Send an HTTP GET request with an arbitrary `Origin: https://malicious-site.example` header:
     ```bash
     curl -H "Origin: https://malicious-site.example" -I http://localhost:5000/api/health
     ```
  2. Notice the response headers:
     ```http
     Access-Control-Allow-Origin: https://malicious-site.example
     Access-Control-Allow-Credentials: true
     ```
- **Root Cause**:
  `app.use(cors({ origin: true, credentials: true }));` blindly reflects any origin in `Access-Control-Allow-Origin`. In combination with `credentials: true`, any unauthorized website visited by an authenticated user can perform authenticated requests and read responses.
- **Recommended Fix**:
  Restrict allowed origins to an explicit whitelist from environment variables (`FRONTEND_URL`, `http://localhost:3000`, Flutter web origin), and reject arbitrary web origins in production.
- **Regression Tests Required**:
  - Test CORS request from whitelisted origin (allowed).
  - Test CORS request from untrusted origin in production (rejected or no reflect).

---

#### [SEC-04] Medium: Fallback Default JWT Secret in Production
- **Severity**: Medium
- **Affected File & Function**: `backend/src/utils/auth.ts` (line 5)
- **Root Cause**:
  `const JWT_SECRET = process.env.JWT_SECRET || 'your_super_secret_key';`
  If `JWT_SECRET` is omitted from the deployment environment, the server silently falls back to a widely known hardcoded string. An attacker could forge valid JWTs containing arbitrary `userId` claims.
- **Recommended Fix**:
  Fail fast on application initialization if `NODE_ENV === 'production'` and `JWT_SECRET` is unset, empty, or equals default placeholder values.
- **Regression Tests Required**:
  - Verify server throws startup error when `NODE_ENV=production` and `JWT_SECRET` is missing.

---

#### [SEC-05] Medium: Missing Row-Level Security (RLS) in Schema Definition
- **Severity**: Medium
- **Affected File**: `backend/supabase_schema.sql`, `backend/src/config/database.ts`
- **Root Cause**:
  `supabase_schema.sql` defines tables (`users`, `activities`, `activity_completions`, `chat_messages`, `user_settings`) without `ALTER TABLE <table_name> ENABLE ROW LEVEL SECURITY;`. While direct queries through the Express backend bypass RLS via server-side credentials, the client-side Flutter application embeds `SUPABASE_ANON_KEY`. If an actor uses the anon key directly against Supabase PostgREST, missing RLS policies could expose database records.
- **Recommended Fix**:
  Add `ALTER TABLE <table_name> ENABLE ROW LEVEL SECURITY;` and appropriate ownership policies (`auth.uid() = auth_user_id`) to `supabase_schema.sql`.
- **Regression Tests Required**:
  - Query Supabase PostgREST endpoint using anon key for another user's rows; verify zero records returned.

---

### 2. Bugs & Architectural Issues

---

#### [BUG-01] High: Dynamic Local Wi-Fi IP Breakage on Mobile Clients
- **Severity**: High
- **Affected File & Function**: `frontend/.env`, `frontend/pubspec.yaml`, `frontend/lib/config/api_config.dart`
- **Root Cause**:
  On dynamic DHCP networks (e.g., campus Wi-Fi `gitam.edu`), the host machine's IP address changes frequently (e.g. `172.23.53.157` -> `172.23.131.46` -> `172.22.127.126`). When the APK bundles a static IP inside `.env`, any IP change causes all mobile network requests to time out. Because `fetchActivities()` caught the exception and wiped the memory state, user data appeared completely "lost".
- **Status & Fix Applied**:
  1. Updated `API_URL` to current active network IP.
  2. Implemented `_showServerConfigDialog` in `login_screen.dart` and `profile_screen.dart`, enabling on-device server reconfiguration without rebuilding the APK.
  3. Added timeout resilience so timeouts do not freeze the UI.
- **Regression Tests Required**:
  - Verify app allows changing server URL in-app and persists new URL in SharedPreferences.
  - Verify app falls back gracefully when server is unreachable without erasing local caches.

---

#### [BUG-02] High: Inconsistent API Client Timeouts & Raw Exception Propagation
- **Severity**: High
- **Affected File & Function**: `frontend/lib/services/api_service.dart` (`login`, `signup`, `getProfile`, `googleAuth`, `completeActivity`, `uncompleteActivity`, `getDailyProgress`, `getWeeklyProgress`)
- **Root Cause**:
  In `api_service.dart`, methods such as `createActivity` and `getActivities` properly used `.timeout(requestTimeout)` and `_handleError(e, uri)`. However, `login`, `signup`, `getProfile`, `completeActivity`, `uncompleteActivity`, and `getWeeklyProgress` used un-timed `http.get` / `http.post` calls that rethrow raw `SocketException` or unhandled generic `Exception`. When the server is unreachable or slow, these calls block for up to 2 minutes.
- **Recommended Fix**:
  Standardize all HTTP requests in `ApiService` with a helper method `_sendRequest` that enforces `requestTimeout` (15s) and routes all network exceptions through `_handleError` to produce clean `ApiException`s with user-friendly messages.
- **Regression Tests Required**:
  - Simulate offline/unreachable server; verify calls throw `ApiException(isNetworkError: true)` within 15 seconds.

---

#### [BUG-03] Medium: Unhandled Pending Timer in `SplashScreen` Breaking Flutter Tests & Leaking Memory
- **Severity**: Medium
- **Affected File & Function**: `frontend/lib/screens/splash/splash_screen.dart`, `frontend/test/widget_test.dart`
- **Steps to Reproduce**:
  Run `flutter test` from `frontend/`.
- **Observed Result**:
  ```
  A Timer is still pending even after the widget tree was disposed.
  Failed assertion: line 2543 pos 12: '!timersPending'
  Some tests failed.
  ```
- **Root Cause**:
  `_SplashScreenState._initializeAppAndNavigate` invoked `await Future.delayed(const Duration(milliseconds: 1000))` without tracking or cancelling the timer in `dispose()`. When the widget tree is unmounted before 1000ms elapses (such as in tests or immediate navigation), the pending timer remains in the event queue.
- **Recommended Fix**:
  Store a `Timer? _splashTimer` reference, cancel it in `dispose()`, and verify widget is mounted before navigation. Update `widget_test.dart` to pump for sufficient duration.
- **Regression Tests Required**:
  - Run `flutter test`; verify `widget_test.dart` passes cleanly with 0 failing assertions.

---

#### [BUG-04] Medium: `getWeeklyProgress` Ignores Date Parameters and Mutates Date Object In-Place
- **Severity**: Medium
- **Affected File & Function**: `backend/src/controllers/progressController.ts` (`getWeeklyProgress`)
- **Root Cause**:
  `getWeeklyProgress` ignores any date query parameter and calculates:
  ```typescript
  const today = new Date();
  const dayOfWeek = today.getDay();
  const diff = today.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1);
  const mondayDate = new Date(today.setDate(diff));
  ```
  `today.setDate(diff)` mutates the `today` instance in-place. If users navigate backward in history, `getWeeklyProgress` always returns data for the current calendar week. Furthermore, mixing local `getDate()` with UTC `toISOString().split('T')[0]` causes date boundary offsets near midnight.
- **Recommended Fix**:
  Accept optional `date` query parameter. Calculate week boundaries using UTC methods without mutating base date objects.
- **Regression Tests Required**:
  - Query `/api/progress/weekly?date=2026-09-15`; verify it returns progress for the week of September 15, not current week.

---

#### [BUG-05] Medium: Missing `group_name` in `aiCreateActivity` and `aiUpdateActivity`
- **Severity**: Medium
- **Affected File & Function**: `backend/src/ai/toolsFunctions.ts` (`aiCreateActivity`, `aiUpdateActivity`)
- **Root Cause**:
  `aiCreateActivity` does not include `group_name` in the SQL `INSERT` statement into `activities`, causing activities created by the AI assistant to receive NULL or omit group association, resulting in broken groupings in `ProgressHomeScreen`.
- **Recommended Fix**:
  Add `group_name` parameter to `aiCreateActivity` defaulting to `'General'`. Allow updating `group_name` in `aiUpdateActivity`.
- **Regression Tests Required**:
  - Call `aiCreateActivity` and verify resulting record contains valid `group_name`.

---

#### [BUG-06] Low: Obsolete Unused Duplicate File `home_screen.dart`
- **Severity**: Low
- **Affected File**: `frontend/lib/screens/home/home_screen.dart`
- **Root Cause**:
  `home_screen.dart` contains 313 lines of code from an earlier iteration of the home screen. It was replaced by `ProgressHomeScreen` (`progress_home_screen.dart`) and is never instantiated anywhere in the project.
- **Recommended Fix**:
  Deprecate or delete `home_screen.dart` to prevent developer confusion.

---

### 3. Testing & DevOps Findings

---

#### [DEV-01] High: Missing Backend Testing Framework (`npm test` broken)
- **Severity**: High
- **Affected File**: `backend/package.json`
- **Steps to Reproduce**:
  Run `npm test` in `backend/`.
- **Observed Result**:
  ```
  'jest' is not recognized as an internal or external command
  ```
- **Root Cause**:
  `package.json` lists `"test": "jest"`, but `jest` and `@types/jest` are not installed in `devDependencies`, and no test files exist in `backend/`.
- **Recommended Fix**:
  Install `jest`, `ts-jest`, `@types/jest`, and `supertest`, and write automated integration tests covering health check, auth endpoints, activity CRUD, and completion toggle.
- **Regression Tests Required**:
  - Run `npm test` in `backend/`; verify it executes and passes.

---

#### [DEV-02] Low: Inadequate Frontend Test Coverage
- **Severity**: Low
- **Affected File**: `frontend/test/`
- **Root Cause**:
  The frontend repository only contained a single placeholder test (`widget_test.dart`), which was failing. No unit tests existed for core business logic: streak calculation, date navigation, activity serialization, or guest trial logic.
- **Recommended Fix**:
  Add unit tests for `ActivityService` (streak calculation, guest completion tracking, serialization).
- **Regression Tests Required**:
  - Execute `flutter test` and verify all tests pass.

---

## Conclusion & Verification Status

The core functional pillars of DayTrack (Activity tracking, day rollover, completion toggling, progress summaries, and local guest fallback) are architecturally sound. The critical issues identified above are concrete, verified defects that can be resolved systematically through targeted, non-destructive modifications.
