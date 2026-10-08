import dotenv from 'dotenv';
import path from 'path';
import { Pool } from 'pg';

dotenv.config({ path: path.join(__dirname, '../../.env') });

async function runMigration() {
  const databaseUrl = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL not found in backend/.env');
  }

  const pool = new Pool({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false }
  });

  const client = await pool.connect();

  try {
    console.log('🔄 Executing Supabase auth_user_id bridge migration...');

    await client.query(`
      DO $$
      BEGIN
          IF NOT EXISTS (
              SELECT 1 FROM information_schema.columns 
              WHERE table_schema = 'public' 
                AND table_name = 'users' 
                AND column_name = 'auth_user_id'
          ) THEN
              ALTER TABLE public.users 
                ADD COLUMN auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE;
              RAISE NOTICE 'Added auth_user_id column to public.users';
          ELSE
              RAISE NOTICE 'auth_user_id column already exists';
          END IF;
      END $$;

      CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users(auth_user_id);
    `);

    console.log('✓ Migration completed successfully: auth_user_id bridge and index created.');
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
