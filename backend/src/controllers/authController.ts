import { Response } from 'express';
import { getDatabase } from '../config/database';
import { getSupabaseClient } from '../config/supabase';
import {
  generateToken,
  hashPassword,
  comparePassword,
  generateId,
  validateEmail,
} from '../utils/auth';
import { AuthRequest } from '../middleware/auth';
import { User } from '../models/types';

export async function signup(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { name, email, password } = req.body;

    // Validation
    if (!name || !email || !password) {
      res.status(400).json({ error: 'Name, email, and password are required' });
      return;
    }

    if (!validateEmail(email)) {
      res.status(400).json({ error: 'Invalid email format' });
      return;
    }

    if (password.length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters' });
      return;
    }

    const db = await getDatabase();

    // Check if email already exists
    const existingUser = await db.get('SELECT id FROM users WHERE email = ?', [email]);
    if (existingUser) {
      res.status(409).json({
        error: 'Account already exists. Please log in instead.',
        code: 'ACCOUNT_EXISTS',
      });
      return;
    }

    const userId = generateId();
    const passwordHash = await hashPassword(password);

    // Create user
    await db.run(
      `INSERT INTO users (id, name, email, password_hash, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, name, email, passwordHash, 'light', 1, 1, 1]
    );

    // Create user settings
    const settingsId = generateId();
    await db.run(
      `INSERT INTO user_settings (id, user_id, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled, timezone)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [settingsId, userId, 'light', 1, 1, 1, 'UTC']
    );

    const token = generateToken(userId, email);

    res.status(201).json({
      message: 'User created successfully',
      token,
      user: {
        id: userId,
        name,
        email,
      },
    });
  } catch (error: any) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'Signup failed' });
  }
}

export async function login(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'Email and password are required' });
      return;
    }

    const db = await getDatabase();

    const user = await db.get<User>('SELECT * FROM users WHERE email = ?', [email]);
    if (!user || !user.password_hash) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const isPasswordValid = await comparePassword(password, user.password_hash);
    if (!isPasswordValid) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const token = generateToken(user.id, user.email || email);

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        theme: user.theme,
        ai_enabled: user.ai_enabled,
      },
    });
  } catch (error: any) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
}

export async function getProfile(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const db = await getDatabase();
    const user = await db.get<User>(
      'SELECT id, name, email, profile_image, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled FROM users WHERE id = ?',
      [req.userId]
    );

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ user });
  } catch (error: any) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Failed to get profile' });
  }
}

export async function updateProfile(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { name, profile_image, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled } = req.body;

    const db = await getDatabase();

    const updates: string[] = [];
    const values: any[] = [];

    if (name !== undefined) {
      updates.push('name = ?');
      values.push(name);
    }
    if (profile_image !== undefined) {
      updates.push('profile_image = ?');
      values.push(profile_image);
    }
    if (theme !== undefined) {
      updates.push('theme = ?');
      values.push(theme);
    }
    if (ai_enabled !== undefined) {
      updates.push('ai_enabled = ?');
      values.push(ai_enabled ? 1 : 0);
    }
    if (ai_suggestions_enabled !== undefined) {
      updates.push('ai_suggestions_enabled = ?');
      values.push(ai_suggestions_enabled ? 1 : 0);
    }
    if (notifications_enabled !== undefined) {
      updates.push('notifications_enabled = ?');
      values.push(notifications_enabled ? 1 : 0);
    }

    if (updates.length === 0) {
      res.status(400).json({ error: 'No updates provided' });
      return;
    }

    updates.push('updated_at = CURRENT_TIMESTAMP');
    values.push(req.userId);

    await db.run(
      `UPDATE users SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    res.json({ message: 'Profile updated successfully' });
  } catch (error: any) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
}

export async function changePassword(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      res.status(400).json({ error: 'Current password and new password are required' });
      return;
    }

    if (newPassword.length < 6) {
      res.status(400).json({ error: 'New password must be at least 6 characters' });
      return;
    }

    const db = await getDatabase();
    const user = await db.get<User>('SELECT password_hash FROM users WHERE id = ?', [req.userId]);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    if (!user.password_hash) {
      res.status(400).json({ error: 'This account was created with Google or Phone sign-in. Password cannot be changed.' });
      return;
    }

    const isCurrentValid = await comparePassword(currentPassword, user.password_hash);
    if (!isCurrentValid) {
      res.status(401).json({ error: 'Current password is incorrect' });
      return;
    }

    const newHash = await hashPassword(newPassword);
    await db.run(
      'UPDATE users SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [newHash, req.userId]
    );

    res.json({ message: 'Password changed successfully' });
  } catch (error: any) {
    console.error('Change password error:', error);
    res.status(500).json({ error: 'Failed to change password' });
  }
}

export async function deleteAccount(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const db = await getDatabase();
    await db.run('DELETE FROM users WHERE id = ?', [req.userId]);

    res.json({ message: 'Account and all associated data permanently deleted' });
  } catch (error: any) {
    console.error('Delete account error:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
}

export async function googleAuth(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { email, name, profileImage, googleId, idToken, supabaseToken } = req.body;
    const authHeader = req.headers.authorization;
    const bearerToken = authHeader?.startsWith('Bearer ') ? authHeader.substring(7) : null;
    const tokenToVerify = supabaseToken || bearerToken;

    let verifiedEmail = email;
    let verifiedName = name;
    let verifiedPicture = profileImage;
    let authUserId: string | null = null;

    const isProduction = process.env.NODE_ENV === 'production';
    const supabase = getSupabaseClient();

    // 1. Verify Supabase token if provided
    if (tokenToVerify && supabase) {
      try {
        const { data: { user: authUser }, error } = await supabase.auth.getUser(tokenToVerify);
        if (authUser && !error) {
          verifiedEmail = authUser.email || verifiedEmail;
          verifiedName = authUser.user_metadata?.full_name || authUser.user_metadata?.name || verifiedName;
          verifiedPicture = authUser.user_metadata?.avatar_url || authUser.user_metadata?.picture || verifiedPicture;
          authUserId = authUser.id;
        } else if (isProduction && !idToken) {
          res.status(401).json({ error: 'Invalid or expired Supabase authentication token' });
          return;
        }
      } catch (err) {
        if (isProduction && !idToken) {
          res.status(401).json({ error: 'Supabase token verification failed' });
          return;
        }
      }
    } else if (idToken) {
      // 2. Verify Google id_token via Google tokeninfo
      try {
        const verifyRes = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
        if (verifyRes.ok) {
          const payload = await verifyRes.json() as any;
          if (payload.email) {
            verifiedEmail = payload.email;
            verifiedName = payload.name || verifiedName;
            verifiedPicture = payload.picture || verifiedPicture;
          }
        } else if (isProduction) {
          res.status(401).json({ error: 'Invalid Google ID token' });
          return;
        }
      } catch (err) {
        if (isProduction) {
          res.status(401).json({ error: 'Failed to verify Google ID token' });
          return;
        }
      }
    } else if (isProduction && process.env.ALLOW_INSECURE_AUTH !== 'true') {
      res.status(401).json({ error: 'Authentication token or Google ID token is required for Google sign-in' });
      return;
    }

    if (!verifiedEmail) {
      res.status(400).json({ error: 'Email is required for Google authentication' });
      return;
    }

    const db = await getDatabase();
    let user = await db.get<User>('SELECT * FROM users WHERE email = ?', [verifiedEmail]);

    if (!user) {
      const userId = generateId();
      const userName = verifiedName || verifiedEmail.split('@')[0] || 'User';
      await db.run(
        `INSERT INTO users (id, auth_user_id, name, email, profile_image, auth_provider, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [userId, authUserId || null, userName, verifiedEmail, verifiedPicture || null, 'google', 'light', true, true, true]
      );

      const settingsId = generateId();
      await db.run(
        `INSERT INTO user_settings (id, user_id, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled, timezone)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [settingsId, userId, 'light', true, true, true, 'UTC']
      );

      user = await db.get<User>('SELECT * FROM users WHERE id = ?', [userId]);
    } else if (authUserId && !user.auth_user_id) {
      await db.run('UPDATE users SET auth_user_id = ? WHERE id = ?', [authUserId, user.id]);
    }

    const token = generateToken(user!.id, user!.email || verifiedEmail);

    res.json({
      message: 'Google authentication successful',
      token,
      user: {
        id: user!.id,
        name: user!.name,
        email: user!.email,
        profile_image: user!.profile_image,
        theme: user!.theme,
        ai_enabled: user!.ai_enabled,
      },
    });
  } catch (error: any) {
    console.error('Google auth error:', error);
    res.status(500).json({ error: 'Google authentication failed' });
  }
}

export async function sendPhoneOtp(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { phone } = req.body;

    if (!phone || typeof phone !== 'string' || phone.trim().length < 8) {
      res.status(400).json({ error: 'Valid phone number is required (e.g. +1234567890)' });
      return;
    }

    const cleanedPhone = phone.trim().replace(/\s+/g, '');
    const db = await getDatabase();

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const verificationId = generateId();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    await db.run(
      `INSERT INTO phone_verifications (id, phone, otp, expires_at) VALUES (?, ?, ?, ?)`,
      [verificationId, cleanedPhone, otp, expiresAt]
    );

    const isDev = process.env.NODE_ENV !== 'production';
    const enableDevOtp = process.env.ENABLE_DEV_OTP === 'true';

    if (isDev && enableDevOtp) {
      console.log(`📱 [DEV ONLY] SMS OTP for ${cleanedPhone}: [ ${otp} ] (Valid for 5 mins)`);
    }

    res.json({
      message: 'Verification code sent successfully',
      phone: cleanedPhone,
      ...(isDev && enableDevOtp ? { otp } : {}),
    });
  } catch (error: any) {
    console.error('Send phone OTP error:', error);
    res.status(500).json({ error: 'Failed to send verification code' });
  }
}

export async function verifyPhoneOtp(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { phone, otp, name } = req.body;

    if (!phone || !otp) {
      res.status(400).json({ error: 'Phone number and OTP code are required' });
      return;
    }

    const cleanedPhone = phone.trim().replace(/\s+/g, '');
    const cleanedOtp = otp.toString().trim();
    const db = await getDatabase();

    const verification = await db.get<{ id: string; otp: string; expires_at: string }>(
      `SELECT * FROM phone_verifications WHERE phone = ? ORDER BY created_at DESC LIMIT 1`,
      [cleanedPhone]
    );

    if (!verification) {
      res.status(400).json({ error: 'No verification code found. Please request a new code.' });
      return;
    }

    if (new Date() > new Date(verification.expires_at)) {
      res.status(400).json({ error: 'Verification code has expired. Please request a new one.' });
      return;
    }

    if (verification.otp !== cleanedOtp) {
      res.status(401).json({ error: 'Invalid verification code' });
      return;
    }

    let user = await db.get<User>('SELECT * FROM users WHERE phone = ?', [cleanedPhone]);

    if (!user) {
      const userId = generateId();
      const userName = name || `User ${cleanedPhone.slice(-4)}`;
      await db.run(
        `INSERT INTO users (id, name, phone, auth_provider, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [userId, userName, cleanedPhone, 'phone', 'light', true, true, true]
      );

      const settingsId = generateId();
      await db.run(
        `INSERT INTO user_settings (id, user_id, theme, ai_enabled, ai_suggestions_enabled, notifications_enabled, timezone)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [settingsId, userId, 'light', true, true, true, 'UTC']
      );

      user = await db.get<User>('SELECT * FROM users WHERE id = ?', [userId]);
    }

    await db.run('DELETE FROM phone_verifications WHERE phone = ?', [cleanedPhone]);

    const token = generateToken(user!.id, user!.phone || user!.email || cleanedPhone);

    res.json({
      message: 'Phone authentication successful',
      token,
      user: {
        id: user!.id,
        name: user!.name,
        phone: user!.phone,
        email: user!.email,
        theme: user!.theme,
        ai_enabled: user!.ai_enabled,
      },
    });
  } catch (error: any) {
    console.error('Verify phone OTP error:', error);
    res.status(500).json({ error: 'Phone verification failed' });
  }
}

