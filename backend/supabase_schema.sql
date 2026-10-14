-- ==========================================================
-- Activity Tracker: Supabase PostgreSQL Schema
-- Run this script in the Supabase SQL Editor (SQL Editor -> New Query)
-- ==========================================================

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone VARCHAR(30) UNIQUE,
    password_hash TEXT,
    profile_image TEXT,
    auth_provider VARCHAR(20) DEFAULT 'email',
    theme TEXT DEFAULT 'light',
    ai_enabled BOOLEAN DEFAULT TRUE,
    ai_suggestions_enabled BOOLEAN DEFAULT TRUE,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.1 Phone Verifications Table (for SMS OTP)
CREATE TABLE IF NOT EXISTS phone_verifications (
    id TEXT PRIMARY KEY,
    phone VARCHAR(30) NOT NULL,
    otp VARCHAR(10) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Activities Table
CREATE TABLE IF NOT EXISTS activities (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    group_name TEXT NOT NULL DEFAULT 'General',
    icon TEXT,
    frequency VARCHAR(50) NOT NULL DEFAULT 'daily',
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    frequency_value INTEGER NOT NULL DEFAULT 1,
    frequency_unit VARCHAR(20) NOT NULL DEFAULT 'days',
    duration_value INTEGER NOT NULL DEFAULT 12,
    duration_unit VARCHAR(20) NOT NULL DEFAULT 'months',
    is_active BOOLEAN DEFAULT TRUE,
    color VARCHAR(50),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Activity Completions Table
CREATE TABLE IF NOT EXISTS activity_completions (
    id TEXT PRIMARY KEY,
    activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_name TEXT NOT NULL DEFAULT 'General',
    date DATE NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_activity_completion UNIQUE (activity_id, user_id, date)
);

-- 4. Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    message TEXT NOT NULL,
    action_type TEXT,
    action_data TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. User Settings Table
CREATE TABLE IF NOT EXISTS user_settings (
    id TEXT PRIMARY KEY,
    user_id TEXT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    theme VARCHAR(50) DEFAULT 'light',
    ai_enabled BOOLEAN DEFAULT TRUE,
    ai_suggestions_enabled BOOLEAN DEFAULT TRUE,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    timezone VARCHAR(100) DEFAULT 'UTC',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================================
-- Performance Indices
-- ==========================================================
CREATE INDEX IF NOT EXISTS idx_activities_user_id ON activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_user_active ON activities(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_activity_completions_user_id ON activity_completions(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_completions_activity_id ON activity_completions(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_completions_date ON activity_completions(date);
CREATE INDEX IF NOT EXISTS idx_activity_completions_user_date ON activity_completions(user_id, date);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON chat_messages(user_id, created_at DESC);

-- ==========================================================
-- Row Level Security (RLS) Policies
-- ==========================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can view own activities" ON activities;
DROP POLICY IF EXISTS "Users can insert own activities" ON activities;
DROP POLICY IF EXISTS "Users can update own activities" ON activities;
DROP POLICY IF EXISTS "Users can delete own activities" ON activities;
DROP POLICY IF EXISTS "Users can view own completions" ON activity_completions;
DROP POLICY IF EXISTS "Users can insert own completions" ON activity_completions;
DROP POLICY IF EXISTS "Users can update own completions" ON activity_completions;
DROP POLICY IF EXISTS "Users can delete own completions" ON activity_completions;
DROP POLICY IF EXISTS "Users can view own chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can insert own chat messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can view own settings" ON user_settings;
DROP POLICY IF EXISTS "Users can update own settings" ON user_settings;

-- Users: users can view and update their own record
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = auth_user_id OR auth.uid()::text = id);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = auth_user_id OR auth.uid()::text = id);

-- Activities: users can only manage their own activities
CREATE POLICY "Users can view own activities" ON activities
    FOR SELECT USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activities.user_id));

CREATE POLICY "Users can insert own activities" ON activities
    FOR INSERT WITH CHECK (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activities.user_id));

CREATE POLICY "Users can update own activities" ON activities
    FOR UPDATE USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activities.user_id));

CREATE POLICY "Users can delete own activities" ON activities
    FOR DELETE USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activities.user_id));

-- Activity Completions: users can only manage their own completions
CREATE POLICY "Users can view own completions" ON activity_completions
    FOR SELECT USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activity_completions.user_id));

CREATE POLICY "Users can insert own completions" ON activity_completions
    FOR INSERT WITH CHECK (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activity_completions.user_id));

CREATE POLICY "Users can update own completions" ON activity_completions
    FOR UPDATE USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activity_completions.user_id));

CREATE POLICY "Users can delete own completions" ON activity_completions
    FOR DELETE USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = activity_completions.user_id));

-- Chat Messages: users can only manage their own messages
CREATE POLICY "Users can view own chat messages" ON chat_messages
    FOR SELECT USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = chat_messages.user_id));

CREATE POLICY "Users can insert own chat messages" ON chat_messages
    FOR INSERT WITH CHECK (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = chat_messages.user_id));

-- User Settings: users can manage their own settings
CREATE POLICY "Users can view own settings" ON user_settings
    FOR SELECT USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = user_settings.user_id));

CREATE POLICY "Users can update own settings" ON user_settings
    FOR UPDATE USING (auth.uid()::text = user_id OR auth.uid() IN (SELECT auth_user_id FROM users WHERE id = user_settings.user_id));

