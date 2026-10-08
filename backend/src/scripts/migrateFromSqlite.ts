import { Pool } from 'pg';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

import { parseDatabaseUrl } from '../config/database';

dotenv.config();

async function migrate() {
  const databaseUrl = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;
  if (!databaseUrl) {
    console.error('❌ Error: DATABASE_URL is not defined in your environment / .env');
    console.log('Please provide your Supabase PostgreSQL connection string in .env:');
    console.log('DATABASE_URL=postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres');
    process.exit(1);
  }

  const sqlitePath = process.env.DATABASE_PATH || './data/activity_tracker.db';
  if (!fs.existsSync(sqlitePath)) {
    console.log(`ℹ No existing SQLite database found at ${sqlitePath}. Nothing to migrate.`);
    process.exit(0);
  }

  console.log(`📂 Reading data from SQLite database: ${sqlitePath}`);
  const sqlite = await open({
    filename: sqlitePath,
    driver: sqlite3.Database,
  });

  console.log('🔗 Connecting to Supabase PostgreSQL...');
  const pool = new Pool(parseDatabaseUrl(databaseUrl));

  const client = await pool.connect();

  try {
    console.log('🚀 Starting data migration...');

    // 1. Migrate Users
    const users = await sqlite.all('SELECT * FROM users');
    console.log(`  👤 Migrating ${users.length} users...`);
    for (const u of users) {
      await client.query(
        `INSERT INTO users (id, name, email, password_hash, profile_image, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (id) DO NOTHING`,
        [
          u.id,
          u.name,
          u.email,
          u.password_hash,
          u.profile_image || null,
          u.theme || 'light',
          Boolean(u.ai_enabled),
          Boolean(u.ai_suggestions_enabled),
          Boolean(u.notifications_enabled),
          u.created_at || new Date().toISOString(),
          u.updated_at || new Date().toISOString(),
        ]
      );
    }

    // 2. Migrate User Settings
    const settings = await sqlite.all('SELECT * FROM user_settings');
    console.log(`  ⚙ Migrating ${settings.length} user settings...`);
    for (const s of settings) {
      await client.query(
        `INSERT INTO user_settings (id, user_id, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled, timezone, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (id) DO NOTHING`,
        [
          s.id,
          s.user_id,
          s.theme || 'light',
          Boolean(s.ai_enabled),
          Boolean(s.ai_suggestions_enabled),
          Boolean(s.notifications_enabled),
          s.timezone || 'UTC',
          s.updated_at || new Date().toISOString(),
        ]
      );
    }

    // 3. Migrate Activities
    const activities = await sqlite.all('SELECT * FROM activities');
    console.log(`  📋 Migrating ${activities.length} activities...`);
    for (const a of activities) {
      await client.query(
        `INSERT INTO activities (id, user_id, name, group_name, icon, frequency, start_date, frequency_value, frequency_unit, duration_value, duration_unit, is_active, color, description, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
         ON CONFLICT (id) DO NOTHING`,
        [
          a.id,
          a.user_id,
          a.name,
          a.group_name || 'General',
          a.icon || null,
          a.frequency || 'daily',
          a.start_date || (a.created_at ? a.created_at.split(' ')[0] : '1970-01-01'),
          a.frequency_value || 1,
          a.frequency_unit || 'days',
          a.duration_value || 12,
          a.duration_unit || 'months',
          Boolean(a.is_active !== 0),
          a.color || null,
          a.description || null,
          a.created_at || new Date().toISOString(),
          a.updated_at || new Date().toISOString(),
        ]
      );
    }

    // 4. Migrate Activity Completions
    const completions = await sqlite.all('SELECT * FROM activity_completions');
    console.log(`  ✅ Migrating ${completions.length} completions...`);
    for (const c of completions) {
      await client.query(
        `INSERT INTO activity_completions (id, activity_id, user_id, group_name, date, completed, completed_at, notes, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (activity_id, user_id, date) DO NOTHING`,
        [
          c.id,
          c.activity_id,
          c.user_id,
          c.group_name || 'General',
          c.date,
          Boolean(c.completed),
          c.completed_at || null,
          c.notes || null,
          c.created_at || new Date().toISOString(),
        ]
      );
    }

    // 5. Migrate Chat Messages
    const chatMessages = await sqlite.all('SELECT * FROM chat_messages');
    console.log(`  💬 Migrating ${chatMessages.length} chat messages...`);
    for (const m of chatMessages) {
      await client.query(
        `INSERT INTO chat_messages (id, user_id, role, message, action_type, action_data, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (id) DO NOTHING`,
        [
          m.id,
          m.user_id,
          m.role,
          m.message,
          m.action_type || null,
          m.action_data || null,
          m.created_at || new Date().toISOString(),
        ]
      );
    }

    console.log('🎉 Migration from SQLite to Supabase PostgreSQL completed successfully!');
  } catch (error) {
    console.error('❌ Migration failed with error:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
    await sqlite.close();
  }
}

migrate();
