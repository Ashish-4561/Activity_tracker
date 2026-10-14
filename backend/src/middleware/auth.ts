import { Request, Response, NextFunction } from 'express';
import { getSupabaseClient } from '../config/supabase';
import { getDatabase } from '../config/database';
import { generateId, verifyToken } from '../utils/auth';

export interface AuthRequest extends Request {
  userId?: string;
  authUserId?: string;
  email?: string;
}

export async function authMiddleware(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing or invalid authorization header' });
      return;
    }

    const token = authHeader.substring(7);
    const db = await getDatabase();
    const supabase = getSupabaseClient();

    let authUserId: string | null = null;
    let verifiedEmail: string | null = null;
    let isEmailVerified = false;
    let userName: string | null = null;
    let providerName = 'email';

    // 1. Primary: Verify token with Supabase Auth
    if (supabase) {
      try {
        const { data: { user: authUser }, error: supabaseError } = await supabase.auth.getUser(token);
        if (authUser && !supabaseError) {
          authUserId = authUser.id;
          verifiedEmail = authUser.email || null;
          isEmailVerified = Boolean(
            authUser.email_confirmed_at ||
            authUser.confirmed_at ||
            authUser.app_metadata?.provider === 'google' ||
            authUser.app_metadata?.provider === 'oauth'
          );
          userName = authUser.user_metadata?.name ||
            authUser.user_metadata?.full_name ||
            (authUser.email ? authUser.email.split('@')[0] : 'User');
          providerName = authUser.app_metadata?.provider || 'supabase';
        }
      } catch (_) {
        // Fallback to custom token verification below
      }
    }

    // 2. Fallback: Verify legacy JWT if Supabase verification did not match
    if (!authUserId) {
      try {
        const decoded = verifyToken(token);
        req.userId = decoded.userId;
        req.email = decoded.email;
        next();
        return;
      } catch (_) {
        res.status(401).json({ error: 'Invalid or expired authentication token' });
        return;
      }
    }

    // 3. Resolve public.users record by auth_user_id
    let userRecord = await db.get('SELECT * FROM users WHERE auth_user_id = ?', [authUserId]);

    // 4. Safe verified email linking (Only if email is verified by Supabase Auth)
    if (!userRecord && verifiedEmail) {
      const existingUserByEmail = await db.get('SELECT * FROM users WHERE email = ?', [verifiedEmail]);
      if (existingUserByEmail && isEmailVerified) {
        // Link existing user record to Supabase Auth User ID if not conflicting
        if (!existingUserByEmail.auth_user_id || existingUserByEmail.auth_user_id === authUserId) {
          await db.run('UPDATE users SET auth_user_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
            authUserId,
            existingUserByEmail.id,
          ]);
          userRecord = await db.get('SELECT * FROM users WHERE id = ?', [existingUserByEmail.id]);
        }
      }
    }

    // 5. Create new public.users & user_settings record if user does not exist
    if (!userRecord) {
      const newUserId = generateId();
      const settingsId = generateId();

      await db.run(
        `INSERT INTO users (id, auth_user_id, name, email, auth_provider, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled)
         VALUES (?, ?, ?, ?, ?, 'light', true, true, true)`,
        [newUserId, authUserId, userName || 'User', verifiedEmail, providerName]
      );

      await db.run(
        `INSERT INTO user_settings (id, user_id, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled, timezone)
         VALUES (?, ?, 'light', true, true, true, 'UTC')`,
        [settingsId, newUserId]
      );

      userRecord = await db.get('SELECT * FROM users WHERE id = ?', [newUserId]);
    }

    if (!userRecord) {
      res.status(401).json({ error: 'Failed to resolve user account' });
      return;
    }

    req.userId = userRecord.id;
    req.authUserId = authUserId;
    req.email = userRecord.email || verifiedEmail || undefined;

    next();
  } catch (error: any) {
    console.error('Auth middleware error:', error);
    res.status(401).json({ error: error.message || 'Unauthorized' });
  }
}
