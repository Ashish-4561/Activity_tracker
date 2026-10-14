# DAYTRACK — PRIORITIZED REPAIR PLAN

**Version**: 1.0.0  
**Status**: Ready for Execution  
**Strategy**: Non-destructive, evidence-driven, backward-compatible, preserving existing working functionality and UI.

---

## 1. Safety Principles & Invariants

1. **Zero Data Loss Guarantee**: Never run `DROP TABLE`, `TRUNCATE`, or destructive migrations on PostgreSQL or SQLite.
2. **Preserve Working UI**: Do not change visual layouts, styling, themes, or colors unless directly addressing a bug.
3. **Preserve API Contracts**: Keep all existing request/response JSON schemas backward-compatible so older client versions or cached data do not break.
4. **Targeted Diffs**: Make minimal, verified edits. Add regression tests for each repair.

---

## 2. Phased Repair Roadmap

### Phase 1: Critical Security Hardening (Backend)
- [x] **SEC-01**: Secure `/api/auth/google` endpoint against unauthenticated spoofing.
  - Required Supabase Bearer token or Google ID token verification before issuing user tokens.
  - Tested and verified in `backend/tests/security.test.ts`.
- [x] **SEC-02**: Remove plaintext OTP disclosure in `/api/auth/phone/send-otp`.
  - Conditioned OTP inclusion strictly on non-production flag (`ENABLE_DEV_OTP === 'true'`).
  - Redacted OTP from production logs.
- [x] **SEC-03**: Restrict CORS origins.
  - Configured CORS origin callback checking `FRONTEND_URL` and `CORS_ALLOWED_ORIGINS` in production while allowing mobile apps and local dev.
- [x] **SEC-04**: Production check for fallback `JWT_SECRET`.
  - Enforced fatal startup error if `JWT_SECRET` is unset or default in production.
- [x] **SEC-05**: Supabase Row Level Security policies.
  - Added RLS tables and user-isolated policies in `backend/supabase_schema.sql`.

---

### Phase 2: API Client & Network Resilience (Frontend)
- [x] **BUG-02**: Standardize `ApiService` with timeout and exception translation.
  - Wrapped all HTTP calls (`signup`, `login`, `googleAuth`, `sendPhoneOtp`, `verifyPhoneOtp`, `getProfile`, `updateProfile`, `changePassword`, `deleteAccount`, `completeActivity`, `uncompleteActivity`, `getCompletionsByDate`, `getDailyProgress`, `getWeeklyProgress`, `getMonthlyProgress`, `getRangeProgress`, `sendChatMessage`, `getChatHistory`) with `requestTimeout` (15s) and `_handleError`.
  - Clean `ApiException` thrown with actionable error messages.
- [x] **BUG-04**: Fix `getWeeklyProgress` in backend to accept date parameter and avoid in-place date mutation.
  - Added support for `?date=YYYY-MM-DD` query parameter.
  - Implemented immutable UTC date boundary calculations without mutating `Date` objects in-place.

---

### Phase 3: AI Tool Consistency & Dead Code Cleanup
- [x] **BUG-05**: Include `group_name` in `aiCreateActivity` and `aiUpdateActivity`.
  - Added `group_name` parameter and column insertion/update in `backend/src/ai/toolsFunctions.ts`.
- [x] **BUG-06**: Clean up dead code `home_screen.dart`.
  - Marked `HomeScreen` with `@Deprecated` annotation pointing to active `ProgressHomeScreen`.

---

### Phase 4: Automated Testing & Test Suite Fixes
- [x] **BUG-03**: Fix `SplashScreen` timer lifecycle and `widget_test.dart`.
  - Replaced unmanaged `Future.delayed` with managed `_splashTimer` cancelled in `dispose()`.
  - Verified `flutter test` passes with zero pending timers.
- [x] **DEV-01**: Fix backend testing framework.
  - Configured Jest with `ts-jest` and added integration test suites (`utils.test.ts`, `security.test.ts`). All 11 tests passed.
- [x] **DEV-02**: Add frontend unit tests.
  - Added unit test suite in `frontend/test/activity_service_test.dart` testing `Activity`, `DailyProgress`, and `User` models. All 5 tests passed.

---

## 3. Rollback & Contingency Plan

| Component | Risk | Rollback Procedure |
|---|---|---|
| **Auth Controller** | Legitimate users unable to login | Git revert on `authController.ts` commit; backend restarts automatically via `ts-node-dev`. |
| **CORS Policy** | Mobile APK or Web client blocked | Environment variable override: set `CORS_ORIGINS=*` temporarily until frontend domain is added. |
| **Api Service** | Premature timeouts on slow cellular | `requestTimeout` configured to 15 seconds; can be adjusted via `ApiService.requestTimeout`. |
| **Database Migrations** | Schema mismatch | All schema modifications are non-destructive `ADD COLUMN IF NOT EXISTS` or `CREATE INDEX IF NOT EXISTS`. |
