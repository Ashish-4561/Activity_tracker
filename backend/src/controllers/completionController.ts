import { Response } from 'express';
import { getDatabase } from '../config/database';
import { generateId, getCurrentDate } from '../utils/auth';
import { AuthRequest } from '../middleware/auth';
import { ActivityCompletion, Activity } from '../models/types';

export async function completeActivity(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { activity_id, date } = req.body;

    if (!activity_id) {
      res.status(400).json({ error: 'Activity ID is required' });
      return;
    }

    const targetDate = date || getCurrentDate();
    const currentDate = getCurrentDate();

    if (targetDate < currentDate) {
      res.status(400).json({ error: 'Cannot modify activity completions for previous days' });
      return;
    }

    const db = await getDatabase();

    // Verify activity ownership
    const activity = await db.get<Activity>(
      `SELECT * FROM activities WHERE id = ? AND user_id = ?`,
      [activity_id, req.userId]
    );

    if (!activity) {
      res.status(404).json({ error: 'Activity not found' });
      return;
    }

    // Check if completion record exists
    const existingCompletion = await db.get<ActivityCompletion>(
      `SELECT * FROM activity_completions WHERE activity_id = ? AND user_id = ? AND date = ?`,
      [activity_id, req.userId, targetDate]
    );

    if (existingCompletion) {
      // Update existing record
      await db.run(
        `UPDATE activity_completions SET completed = 1, group_name = ?, completed_at = CURRENT_TIMESTAMP WHERE activity_id = ? AND user_id = ? AND date = ?`,
        [activity.group_name || 'General', activity_id, req.userId, targetDate]
      );
    } else {
      // Create new completion record
      const completionId = generateId();
      await db.run(
        `INSERT INTO activity_completions (id, activity_id, user_id, group_name, date, completed, completed_at)
         VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
        [completionId, activity_id, req.userId, activity.group_name || 'General', targetDate, true]
      );
    }

    res.json({
      message: 'Activity marked as completed',
      completion: {
        activity_id,
        date: targetDate,
        completed: true,
      },
    });
  } catch (error: any) {
    console.error('Complete activity error:', error);
    res.status(500).json({ error: 'Failed to complete activity' });
  }
}

export async function uncompleteActivity(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { activity_id, date } = req.body;

    if (!activity_id) {
      res.status(400).json({ error: 'Activity ID is required' });
      return;
    }

    const targetDate = date || getCurrentDate();
    const currentDate = getCurrentDate();

    if (targetDate < currentDate) {
      res.status(400).json({ error: 'Cannot modify activity completions for previous days' });
      return;
    }

    const db = await getDatabase();

    // Verify activity ownership
    const activity = await db.get<Activity>(
      `SELECT * FROM activities WHERE id = ? AND user_id = ?`,
      [activity_id, req.userId]
    );

    if (!activity) {
      res.status(404).json({ error: 'Activity not found' });
      return;
    }

    // Check if completion record exists
    const existingCompletion = await db.get<ActivityCompletion>(
      `SELECT * FROM activity_completions WHERE activity_id = ? AND user_id = ? AND date = ?`,
      [activity_id, req.userId, targetDate]
    );

    if (existingCompletion) {
      // Update existing record
      await db.run(
        `UPDATE activity_completions SET completed = 0, group_name = ?, completed_at = NULL WHERE activity_id = ? AND user_id = ? AND date = ?`,
        [activity.group_name || 'General', activity_id, req.userId, targetDate]
      );
    } else {
      // Create new uncompleted record
      const completionId = generateId();
      await db.run(
        `INSERT INTO activity_completions (id, activity_id, user_id, group_name, date, completed)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [completionId, activity_id, req.userId, activity.group_name || 'General', targetDate, false]
      );
    }

    res.json({
      message: 'Activity marked as incomplete',
      completion: {
        activity_id,
        date: targetDate,
        completed: false,
      },
    });
  } catch (error: any) {
    console.error('Uncomplete activity error:', error);
    res.status(500).json({ error: 'Failed to uncomplete activity' });
  }
}

export async function getCompletionsByDate(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { date } = req.query;
    const targetDate = (date as string) || getCurrentDate();

    const db = await getDatabase();

    const completions = await db.all<ActivityCompletion[]>(
      `SELECT ac.*, a.name, a.icon FROM activity_completions ac
       JOIN activities a ON ac.activity_id = a.id
       WHERE ac.user_id = ? AND ac.date = ?
       ORDER BY ac.created_at DESC`,
      [req.userId, targetDate]
    );

    res.json({ completions: completions || [], date: targetDate });
  } catch (error: any) {
    console.error('Get completions error:', error);
    res.status(500).json({ error: 'Failed to get completions' });
  }
}

export async function getCompletionHistory(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { activity_id, start_date, end_date } = req.query;

    const db = await getDatabase();

    let query = `SELECT * FROM activity_completions WHERE user_id = ?`;
    const params: any[] = [req.userId];

    if (activity_id) {
      query += ` AND activity_id = ?`;
      params.push(activity_id);
    }

    if (start_date) {
      query += ` AND date >= ?`;
      params.push(start_date);
    }

    if (end_date) {
      query += ` AND date <= ?`;
      params.push(end_date);
    }

    query += ` ORDER BY date DESC`;

    const completions = await db.all<ActivityCompletion[]>(query, params);

    res.json({ completions: completions || [] });
  } catch (error: any) {
    console.error('Get completion history error:', error);
    res.status(500).json({ error: 'Failed to get completion history' });
  }
}

export async function trackActivityDuration(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { activity_id, session_duration_seconds, date, start_timestamp, end_timestamp } = req.body;

    if (!activity_id || session_duration_seconds == null) {
      res.status(400).json({ error: 'Activity ID and session_duration_seconds are required' });
      return;
    }

    const durationSec = Math.max(0, parseInt(session_duration_seconds, 10) || 0);
    const targetDate = date || getCurrentDate();
    const db = await getDatabase();

    // Verify activity ownership
    const activity = await db.get<Activity>(
      `SELECT * FROM activities WHERE id = ? AND user_id = ?`,
      [activity_id, req.userId]
    );

    if (!activity) {
      res.status(404).json({ error: 'Activity not found' });
      return;
    }

    // Check if completion record exists
    const existingCompletion = await db.get<ActivityCompletion>(
      `SELECT * FROM activity_completions WHERE activity_id = ? AND user_id = ? AND date = ?`,
      [activity_id, req.userId, targetDate]
    );

    let currentSessions: any[] = [];
    if (existingCompletion && existingCompletion.sessions) {
      try {
        currentSessions = typeof existingCompletion.sessions === 'string'
          ? JSON.parse(existingCompletion.sessions)
          : existingCompletion.sessions;
        if (!Array.isArray(currentSessions)) currentSessions = [];
      } catch (_) {
        currentSessions = [];
      }
    }

    const nowIso = new Date().toISOString();
    currentSessions.push({
      start: start_timestamp || nowIso,
      end: end_timestamp || nowIso,
      duration_seconds: durationSec,
    });

    const existingDuration = existingCompletion ? (Number(existingCompletion.duration_seconds) || 0) : 0;
    const newTotalSeconds = existingDuration + durationSec;

    // Determine completion: if goal reached or already marked complete
    let shouldComplete = existingCompletion ? (existingCompletion.completed === true || (existingCompletion as any).completed === 1) : false;
    if (activity.activity_type === 'duration' && activity.target_duration_minutes) {
      const targetSeconds = activity.target_duration_minutes * 60;
      if (newTotalSeconds >= targetSeconds) {
        shouldComplete = true;
      }
    }

    const sessionsJson = JSON.stringify(currentSessions);

    if (existingCompletion) {
      await db.run(
        `UPDATE activity_completions 
         SET duration_seconds = ?, sessions = ?, completed = ?, 
             completed_at = CASE WHEN ? = 1 AND completed_at IS NULL THEN CURRENT_TIMESTAMP ELSE completed_at END
         WHERE activity_id = ? AND user_id = ? AND date = ?`,
        [newTotalSeconds, sessionsJson, shouldComplete ? 1 : 0, shouldComplete ? 1 : 0, activity_id, req.userId, targetDate]
      );
    } else {
      const completionId = generateId();
      await db.run(
        `INSERT INTO activity_completions (
          id, activity_id, user_id, group_name, date, completed, completed_at, duration_seconds, sessions
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          completionId, activity_id, req.userId, activity.group_name || 'General', targetDate,
          shouldComplete ? 1 : 0, shouldComplete ? nowIso : null, newTotalSeconds, sessionsJson
        ]
      );
    }

    res.json({
      message: 'Activity duration tracked successfully',
      activity_id,
      date: targetDate,
      total_duration_seconds: newTotalSeconds,
      completed: shouldComplete,
      sessions: currentSessions,
    });
  } catch (error: any) {
    console.error('Track duration error:', error);
    res.status(500).json({ error: 'Failed to track duration' });
  }
}

