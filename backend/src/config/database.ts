import { Pool, PoolConfig, types } from 'pg';
import sqlite3 from 'sqlite3';
import { open, Database as SqliteDatabase } from 'sqlite';
import path from 'path';
import fs from 'fs';
import dotenv from 'dotenv';

// Ensure PostgreSQL DATE columns (type 1082) are parsed as exact YYYY-MM-DD strings
types.setTypeParser(1082, (val: string) => val);

dotenv.config();

export interface RunResult {
  changes?: number;
  lastID?: any;
  rowCount?: number;
}

export interface AppDatabase {
  get<T = any>(sql: string, params?: any[]): Promise<T | undefined>;
  all<T = any>(sql: string, params?: any[]): Promise<T>;
  run(sql: string, params?: any[]): Promise<RunResult>;
  exec(sql: string): Promise<void>;
  close(): Promise<void>;
  isPostgres: boolean;
}

let dbInstance: AppDatabase | null = null;
let pgPool: Pool | null = null;
let sqliteDb: SqliteDatabase | null = null;

/**
 * Transforms SQLite SQL syntax to PostgreSQL SQL syntax:
 * 1. Converts ? parameter placeholders to $1, $2, $3...
 * 2. Converts SQLite boolean integer literals (is_active = 1, completed = 0) to PostgreSQL booleans
 */
export function formatSqlForPostgres(sql: string): string {
  let paramIndex = 1;
  let formatted = sql.replace(/\?/g, () => `$${paramIndex++}`);

  // Normalize SQLite boolean expressions for PostgreSQL
  formatted = formatted
    .replace(/\bis_active\s*=\s*1\b/gi, 'is_active = TRUE')
    .replace(/\bis_active\s*=\s*0\b/gi, 'is_active = FALSE')
    .replace(/\bcompleted\s*=\s*1\b/gi, 'completed = TRUE')
    .replace(/\bcompleted\s*=\s*0\b/gi, 'completed = FALSE')
    .replace(/\bSET\s+is_active\s*=\s*1\b/gi, 'SET is_active = TRUE')
    .replace(/\bSET\s+is_active\s*=\s*0\b/gi, 'SET is_active = FALSE')
    .replace(/\bSET\s+completed\s*=\s*1\b/gi, 'SET completed = TRUE')
    .replace(/\bSET\s+completed\s*=\s*0\b/gi, 'SET completed = FALSE');

  return formatted;
}

/**
 * Normalize params array for PostgreSQL (e.g. converting 1/0 to true/false where appropriate)
 */
function normalizeParamsForPostgres(params?: any[]): any[] {
  if (!params || !Array.isArray(params)) return [];
  return params.map(val => {
    if (val === undefined) return null;
    return val;
  });
}

class PostgresAppDatabase implements AppDatabase {
  private pool: Pool;
  public isPostgres = true;

  constructor(pool: Pool) {
    this.pool = pool;
  }

  async get<T = any>(sql: string, params?: any[]): Promise<T | undefined> {
    const formattedSql = formatSqlForPostgres(sql);
    const normalizedParams = normalizeParamsForPostgres(params);
    const result = await this.pool.query(formattedSql, normalizedParams);
    return (result.rows[0] as T) || undefined;
  }

  async all<T = any>(sql: string, params?: any[]): Promise<T> {
    const formattedSql = formatSqlForPostgres(sql);
    const normalizedParams = normalizeParamsForPostgres(params);
    const result = await this.pool.query(formattedSql, normalizedParams);
    return (result.rows as unknown) as T;
  }

  async run(sql: string, params?: any[]): Promise<RunResult> {
    const formattedSql = formatSqlForPostgres(sql);
    const normalizedParams = normalizeParamsForPostgres(params);
    const result = await this.pool.query(formattedSql, normalizedParams);
    return {
      changes: result.rowCount ?? 0,
      rowCount: result.rowCount ?? 0,
    };
  }

  async exec(sql: string): Promise<void> {
    await this.pool.query(sql);
  }

  async close(): Promise<void> {
    await this.pool.end();
    pgPool = null;
    dbInstance = null;
  }
}

class SqliteAppDatabase implements AppDatabase {
  private db: SqliteDatabase;
  public isPostgres = false;

  constructor(db: SqliteDatabase) {
    this.db = db;
  }

  async get<T = any>(sql: string, params?: any[]): Promise<T | undefined> {
    return this.db.get<T>(sql, params || []);
  }

  async all<T = any>(sql: string, params?: any[]): Promise<T> {
    return this.db.all<T>(sql, params || []);
  }

  async run(sql: string, params?: any[]): Promise<RunResult> {
    const result = await this.db.run(sql, params || []);
    return {
      changes: result.changes,
      lastID: result.lastID,
    };
  }

  async exec(sql: string): Promise<void> {
    await this.db.exec(sql);
  }

  async close(): Promise<void> {
    await this.db.close();
    sqliteDb = null;
    dbInstance = null;
  }
}

async function createPostgresTables(pool: Pool): Promise<void> {
  await pool.query(`
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      auth_user_id TEXT UNIQUE,
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

    CREATE TABLE IF NOT EXISTS phone_verifications (
      id TEXT PRIMARY KEY,
      phone VARCHAR(30) NOT NULL,
      otp VARCHAR(10) NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

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
      activity_type VARCHAR(20) DEFAULT 'flexible',
      start_time VARCHAR(10),
      end_time VARCHAR(10),
      repeat_days TEXT,
      target_duration_minutes INTEGER,
      reminders_enabled BOOLEAN DEFAULT FALSE,
      reminder_minutes_before INTEGER DEFAULT 10,
      reminder_at_end BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS activity_completions (
      id TEXT PRIMARY KEY,
      activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      group_name TEXT NOT NULL DEFAULT 'General',
      date DATE NOT NULL,
      completed BOOLEAN DEFAULT FALSE,
      completed_at TIMESTAMPTZ,
      duration_seconds INTEGER DEFAULT 0,
      sessions TEXT DEFAULT '[]',
      notes TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      CONSTRAINT uq_activity_completion UNIQUE (activity_id, user_id, date)
    );

    CREATE TABLE IF NOT EXISTS chat_messages (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
      message TEXT NOT NULL,
      action_type TEXT,
      action_data TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_settings (
      id TEXT PRIMARY KEY,
      user_id TEXT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      theme VARCHAR(50) DEFAULT 'light',
      ai_enabled BOOLEAN DEFAULT TRUE,
      ai_suggestions_enabled BOOLEAN DEFAULT TRUE,
      notifications_enabled BOOLEAN DEFAULT TRUE,
      timezone VARCHAR(100) DEFAULT 'UTC',
      quiet_hours_enabled BOOLEAN DEFAULT FALSE,
      quiet_hours_start VARCHAR(10) DEFAULT '22:00',
      quiet_hours_end VARCHAR(10) DEFAULT '07:00',
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS activity_groups (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      CONSTRAINT uq_user_group_name UNIQUE (user_id, name)
    );

    CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
    CREATE INDEX IF NOT EXISTS idx_activities_user_id ON activities(user_id);
    CREATE INDEX IF NOT EXISTS idx_activities_user_active ON activities(user_id, is_active);
    CREATE INDEX IF NOT EXISTS idx_activity_groups_user_id ON activity_groups(user_id);
    CREATE INDEX IF NOT EXISTS idx_activity_completions_user_id ON activity_completions(user_id);
    CREATE INDEX IF NOT EXISTS idx_activity_completions_activity_id ON activity_completions(activity_id);
    CREATE INDEX IF NOT EXISTS idx_activity_completions_date ON activity_completions(date);
    CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
    CREATE INDEX IF NOT EXISTS idx_phone_verifications_phone ON phone_verifications(phone);
  `);

  // Run dynamic schema migrations on users, activities, completions, user_settings if needed
  const alterQueries = [
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_user_id TEXT;`,
    `CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);`,
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(30) UNIQUE;`,
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(20) DEFAULT 'email';`,
    `ALTER TABLE users ALTER COLUMN email DROP NOT NULL;`,
    `ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;`,

    // Scheduling, Duration, and Reminder columns on activities
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS activity_type VARCHAR(20) DEFAULT 'flexible';`,
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS start_time VARCHAR(10);`,
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS end_time VARCHAR(10);`,
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS repeat_days TEXT;`,
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS target_duration_minutes INTEGER;`,
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS reminders_enabled BOOLEAN DEFAULT FALSE;`,
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS reminder_minutes_before INTEGER DEFAULT 10;`,
    `ALTER TABLE activities ADD COLUMN IF NOT EXISTS reminder_at_end BOOLEAN DEFAULT FALSE;`,

    // Duration progress & session tracking on activity_completions
    `ALTER TABLE activity_completions ADD COLUMN IF NOT EXISTS duration_seconds INTEGER DEFAULT 0;`,
    `ALTER TABLE activity_completions ADD COLUMN IF NOT EXISTS sessions TEXT DEFAULT '[]';`,

    // Quiet hours on user_settings
    `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN DEFAULT FALSE;`,
    `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS quiet_hours_start VARCHAR(10) DEFAULT '22:00';`,
    `ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS quiet_hours_end VARCHAR(10) DEFAULT '07:00';`,
  ];
  for (const query of alterQueries) {
    try {
      await pool.query(query);
    } catch (_) {
      // Ignore migration errors if already applied or constrained
    }
  }
}

async function createSqliteTables(db: SqliteDatabase): Promise<void> {
  await db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      auth_user_id TEXT UNIQUE,
      name TEXT NOT NULL,
      email TEXT UNIQUE,
      phone VARCHAR(30) UNIQUE,
      password_hash TEXT,
      profile_image TEXT,
      auth_provider TEXT DEFAULT 'email',
      theme TEXT DEFAULT 'light',
      ai_enabled INTEGER DEFAULT 1,
      ai_suggestions_enabled INTEGER DEFAULT 1,
      notifications_enabled INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS activities (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      group_name TEXT NOT NULL DEFAULT 'General',
      icon TEXT,
      frequency TEXT NOT NULL DEFAULT 'daily',
      start_date TEXT NOT NULL DEFAULT (date('now')),
      frequency_value INTEGER NOT NULL DEFAULT 1,
      frequency_unit TEXT NOT NULL DEFAULT 'days',
      duration_value INTEGER NOT NULL DEFAULT 12,
      duration_unit TEXT NOT NULL DEFAULT 'months',
      is_active INTEGER DEFAULT 1,
      color TEXT,
      description TEXT,
      activity_type TEXT DEFAULT 'flexible',
      start_time TEXT,
      end_time TEXT,
      repeat_days TEXT,
      target_duration_minutes INTEGER,
      reminders_enabled INTEGER DEFAULT 0,
      reminder_minutes_before INTEGER DEFAULT 10,
      reminder_at_end INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS activity_completions (
      id TEXT PRIMARY KEY,
      activity_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      group_name TEXT NOT NULL DEFAULT 'General',
      date TEXT NOT NULL,
      completed INTEGER DEFAULT 0,
      completed_at DATETIME,
      duration_seconds INTEGER DEFAULT 0,
      sessions TEXT DEFAULT '[]',
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(activity_id, user_id, date)
    );

    CREATE TABLE IF NOT EXISTS chat_messages (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      role TEXT NOT NULL,
      message TEXT NOT NULL,
      action_type TEXT,
      action_data TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS user_settings (
      id TEXT PRIMARY KEY,
      user_id TEXT UNIQUE NOT NULL,
      theme TEXT DEFAULT 'light',
      ai_enabled INTEGER DEFAULT 1,
      ai_suggestions_enabled INTEGER DEFAULT 1,
      notifications_enabled INTEGER DEFAULT 1,
      timezone TEXT DEFAULT 'UTC',
      quiet_hours_enabled INTEGER DEFAULT 0,
      quiet_hours_start TEXT DEFAULT '22:00',
      quiet_hours_end TEXT DEFAULT '07:00',
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS activity_groups (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(user_id, name)
    );

    CREATE INDEX IF NOT EXISTS idx_activities_user_id ON activities(user_id);
    CREATE INDEX IF NOT EXISTS idx_activity_groups_user_id ON activity_groups(user_id);
    CREATE INDEX IF NOT EXISTS idx_activity_completions_user_id ON activity_completions(user_id);
    CREATE INDEX IF NOT EXISTS idx_activity_completions_activity_id ON activity_completions(activity_id);
    CREATE INDEX IF NOT EXISTS idx_activity_completions_date ON activity_completions(date);
    CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
  `);

  const sqliteAlterQueries = [
    `ALTER TABLE activities ADD COLUMN activity_type TEXT DEFAULT 'flexible';`,
    `ALTER TABLE activities ADD COLUMN start_time TEXT;`,
    `ALTER TABLE activities ADD COLUMN end_time TEXT;`,
    `ALTER TABLE activities ADD COLUMN repeat_days TEXT;`,
    `ALTER TABLE activities ADD COLUMN target_duration_minutes INTEGER;`,
    `ALTER TABLE activities ADD COLUMN reminders_enabled INTEGER DEFAULT 0;`,
    `ALTER TABLE activities ADD COLUMN reminder_minutes_before INTEGER DEFAULT 10;`,
    `ALTER TABLE activities ADD COLUMN reminder_at_end INTEGER DEFAULT 0;`,
    `ALTER TABLE activity_completions ADD COLUMN duration_seconds INTEGER DEFAULT 0;`,
    `ALTER TABLE activity_completions ADD COLUMN sessions TEXT DEFAULT '[]';`,
    `ALTER TABLE user_settings ADD COLUMN quiet_hours_enabled INTEGER DEFAULT 0;`,
    `ALTER TABLE user_settings ADD COLUMN quiet_hours_start TEXT DEFAULT '22:00';`,
    `ALTER TABLE user_settings ADD COLUMN quiet_hours_end TEXT DEFAULT '07:00';`,
  ];
  for (const q of sqliteAlterQueries) {
    try {
      await db.exec(q);
    } catch (_) {}
  }
}

export function parseDatabaseUrl(databaseUrl: string): PoolConfig {
  return {
    connectionString: databaseUrl,
    ssl: {
      rejectUnauthorized: false,
    },
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 25000,
    keepAlive: true,
  };
}

export async function initializeDatabase(): Promise<AppDatabase> {
  if (dbInstance) {
    return dbInstance;
  }

  const databaseUrl = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;

  if (databaseUrl) {
    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        console.log(`🔗 Connecting to Supabase PostgreSQL (attempt ${attempt}/2)...`);
        const config = parseDatabaseUrl(databaseUrl);

        pgPool = new Pool(config);

        // Prevent uncaught ECONNRESET on idle clients from crashing Node process
        pgPool.on('error', (err: any) => {
          console.warn('ℹ Supabase pool idle client reset (auto-reconnecting):', err.message || err);
        });

        // Test connection
        const client = await pgPool.connect();
        try {
          console.log('✓ Connected to Supabase PostgreSQL successfully');
          await createPostgresTables(pgPool);
          console.log('✓ PostgreSQL schema and tables verified');
        } finally {
          client.release();
        }

        dbInstance = new PostgresAppDatabase(pgPool);
        return dbInstance;
      } catch (pgError: any) {
        if (pgPool) {
          try { await pgPool.end(); } catch (_) {}
          pgPool = null;
        }
        if (attempt < 2) {
          console.warn(`⚠ Supabase connection attempt 1 failed (${pgError.message || pgError}). Retrying in 2 seconds...`);
          await new Promise(res => setTimeout(res, 2000));
        } else {
          console.warn(`⚠ Supabase connection failed (${pgError.message || pgError}).`);
          console.log('ℹ Falling back to local SQLite database (./data/activity_tracker.db)...');
        }
      }
    }
  }

  // Fallback to SQLite if DATABASE_URL is not set
  console.log('ℹ DATABASE_URL not found, using local SQLite fallback (./data/activity_tracker.db)');
  const dbPath = process.env.DATABASE_PATH || './data/activity_tracker.db';
  const dbDir = path.dirname(dbPath);

  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  sqliteDb = await open({
    filename: dbPath,
    driver: sqlite3.Database,
  });

  await sqliteDb.exec('PRAGMA foreign_keys = ON');
  await createSqliteTables(sqliteDb);

  dbInstance = new SqliteAppDatabase(sqliteDb);
  return dbInstance;
}

export async function getDatabase(): Promise<AppDatabase> {
  if (!dbInstance) {
    return initializeDatabase();
  }
  return dbInstance;
}

export async function closeDatabase(): Promise<void> {
  if (dbInstance) {
    await dbInstance.close();
    dbInstance = null;
  }
}
