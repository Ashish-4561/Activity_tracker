import { getDatabase } from '../config/database';
import { generateId, getCurrentDate } from '../utils/auth';
import { Activity, ActivityCompletion } from '../models/types';

/**
 * AI Tool Functions - These are the controlled functions that the AI can call.
 * The AI should ONLY interact with these functions, never directly with the database.
 * Every function receives the authenticated userId and verifies ownership.
 */

export async function aiCreateActivity(
  userId: string,
  name: string,
  frequency: 'daily' | 'weekly' | 'custom' = 'daily',
  icon?: string,
  color?: string,
  description?: string,
  frequencyValue = 1,
  frequencyUnit = 'days',
  durationValue = 12,
  durationUnit = 'months',
  startDate?: string,
  groupName?: string,
): Promise<{ success: boolean; activity?: Activity; error?: string }> {
  try {
    if (!name) {
      return { success: false, error: 'Activity name is required' };
    }

    if (!['daily', 'weekly', 'custom'].includes(frequency)) {
      return { success: false, error: 'Invalid frequency' };
    }

    const db = await getDatabase();
    const activityId = generateId();

    await db.run(
      `INSERT INTO activities (id, user_id, name, group_name, icon, frequency, start_date, frequency_value, frequency_unit, duration_value, duration_unit, color, description, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [activityId, userId, name.trim(), groupName?.trim() || 'General', icon || null, frequency, startDate || getCurrentDate(), frequencyValue, frequencyUnit, durationValue, durationUnit, color || null, description || null, 1]
    );

    const activity = await db.get<Activity>(
      'SELECT * FROM activities WHERE id = ?',
      [activityId]
    );

    return { success: true, activity };
  } catch (error: any) {
    console.error('AI create activity error:', error);
    return { success: false, error: 'Failed to create activity' };
  }
}

export async function aiUpdateActivity(
  userId: string,
  activityId: string,
  updates: Partial<{
    name: string;
    group_name: string;
    icon: string;
    frequency: string;
    color: string;
    description: string;
  }>
): Promise<{ success: boolean; error?: string }> {
  try {
    const db = await getDatabase();

    // Verify ownership
    const activity = await db.get<Activity>(
      'SELECT * FROM activities WHERE id = ? AND user_id = ?',
      [activityId, userId]
    );

    if (!activity) {
      return { success: false, error: 'Activity not found' };
    }

    const updateFields: string[] = [];
    const values: any[] = [];

    if (updates.name !== undefined) {
      updateFields.push('name = ?');
      values.push(updates.name);
    }
    if (updates.group_name !== undefined) {
      updateFields.push('group_name = ?');
      values.push(updates.group_name.trim() || 'General');
    }
    if (updates.icon !== undefined) {
      updateFields.push('icon = ?');
      values.push(updates.icon);
    }
    if (updates.frequency !== undefined) {
      if (!['daily', 'weekly', 'custom'].includes(updates.frequency)) {
        return { success: false, error: 'Invalid frequency' };
      }
      updateFields.push('frequency = ?');
      values.push(updates.frequency);
    }
    if (updates.color !== undefined) {
      updateFields.push('color = ?');
      values.push(updates.color);
    }
    if (updates.description !== undefined) {
      updateFields.push('description = ?');
      values.push(updates.description);
    }

    if (updateFields.length === 0) {
      return { success: false, error: 'No updates provided' };
    }

    updateFields.push('updated_at = CURRENT_TIMESTAMP');
    values.push(activityId);

    await db.run(
      `UPDATE activities SET ${updateFields.join(', ')} WHERE id = ?`,
      values
    );

    return { success: true };
  } catch (error: any) {
    console.error('AI update activity error:', error);
    return { success: false, error: 'Failed to update activity' };
  }
}

export async function aiDeleteActivity(
  userId: string,
  activityId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const db = await getDatabase();

    // Verify ownership
    const activity = await db.get<Activity>(
      'SELECT * FROM activities WHERE id = ? AND user_id = ?',
      [activityId, userId]
    );

    if (!activity) {
      return { success: false, error: 'Activity not found' };
    }

    // Soft delete
    await db.run(
      'UPDATE activities SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [activityId]
    );

    return { success: true };
  } catch (error: any) {
    console.error('AI delete activity error:', error);
    return { success: false, error: 'Failed to delete activity' };
  }
}

export async function aiDeleteGroup(
  userId: string,
  groupName: string
): Promise<{ success: boolean; count?: number; error?: string }> {
  try {
    const db = await getDatabase();
    const activities = await db.all<Activity[]>(
      'SELECT * FROM activities WHERE user_id = ? AND group_name = ? AND is_active = 1',
      [userId, groupName]
    );

    if (!activities || activities.length === 0) {
      return { success: false, error: 'Group not found' };
    }

    await db.run(
      'UPDATE activities SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND group_name = ?',
      [userId, groupName]
    );

    return { success: true, count: activities.length };
  } catch (error: any) {
    console.error('AI delete group error:', error);
    return { success: false, error: 'Failed to delete group' };
  }
}

export async function aiGetActivities(userId: string): Promise<{ activities: Activity[] | null }> {
  try {
    const db = await getDatabase();
    const activities = await db.all<Activity[]>(
      'SELECT * FROM activities WHERE user_id = ? AND is_active = 1 ORDER BY created_at DESC',
      [userId]
    );
    return { activities: activities || [] };
  } catch (error: any) {
    console.error('AI get activities error:', error);
    return { activities: null };
  }
}

export async function aiCompleteActivity(
  userId: string,
  activityId: string,
  date?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const db = await getDatabase();
    const targetDate = date || getCurrentDate();

    // Verify ownership
    const activity = await db.get<Activity>(
      'SELECT * FROM activities WHERE id = ? AND user_id = ?',
      [activityId, userId]
    );

    if (!activity) {
      return { success: false, error: 'Activity not found' };
    }

    const existingCompletion = await db.get<ActivityCompletion>(
      'SELECT * FROM activity_completions WHERE activity_id = ? AND user_id = ? AND date = ?',
      [activityId, userId, targetDate]
    );

    if (existingCompletion) {
      await db.run(
        'UPDATE activity_completions SET completed = 1, group_name = ?, completed_at = CURRENT_TIMESTAMP WHERE activity_id = ? AND user_id = ? AND date = ?',
        [activity.group_name || 'General', activityId, userId, targetDate]
      );
    } else {
      const completionId = generateId();
      await db.run(
        'INSERT INTO activity_completions (id, activity_id, user_id, group_name, date, completed, completed_at) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
        [completionId, activityId, userId, activity.group_name || 'General', targetDate, 1]
      );
    }

    return { success: true };
  } catch (error: any) {
    console.error('AI complete activity error:', error);
    return { success: false, error: 'Failed to complete activity' };
  }
}

export async function aiUncompleteActivity(
  userId: string,
  activityId: string,
  date?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const db = await getDatabase();
    const targetDate = date || getCurrentDate();

    // Verify ownership
    const activity = await db.get<Activity>(
      'SELECT * FROM activities WHERE id = ? AND user_id = ?',
      [activityId, userId]
    );

    if (!activity) {
      return { success: false, error: 'Activity not found' };
    }

    const existingCompletion = await db.get<ActivityCompletion>(
      'SELECT * FROM activity_completions WHERE activity_id = ? AND user_id = ? AND date = ?',
      [activityId, userId, targetDate]
    );

    if (existingCompletion) {
      await db.run(
        'UPDATE activity_completions SET completed = 0, group_name = ?, completed_at = NULL WHERE activity_id = ? AND user_id = ? AND date = ?',
        [activity.group_name || 'General', activityId, userId, targetDate]
      );
    } else {
      const completionId = generateId();
      await db.run(
        'INSERT INTO activity_completions (id, activity_id, user_id, group_name, date, completed) VALUES (?, ?, ?, ?, ?, ?)',
        [completionId, activityId, userId, activity.group_name || 'General', targetDate, 0]
      );
    }

    return { success: true };
  } catch (error: any) {
    console.error('AI uncomplete activity error:', error);
    return { success: false, error: 'Failed to uncomplete activity' };
  }
}

export async function aiGetDailyProgress(
  userId: string,
  date?: string
): Promise<{
  daily_progress?: {
    date: string;
    completed: number;
    total: number;
    percentage: number;
  };
  error?: string;
}> {
  try {
    const db = await getDatabase();
    const targetDate = date || getCurrentDate();

    const activities = await db.all<Activity[]>(
      'SELECT * FROM activities WHERE user_id = ? AND is_active = 1',
      [userId]
    );

    if (!activities || activities.length === 0) {
      return {
        daily_progress: {
          date: targetDate,
          completed: 0,
          total: 0,
          percentage: 0,
        },
      };
    }

    const completions = await db.all<ActivityCompletion[]>(
      'SELECT * FROM activity_completions WHERE user_id = ? AND date = ?',
      [userId, targetDate]
    );

    const completedCount = completions?.filter(c => Boolean(c.completed)).length || 0;
    const percentage = Math.round((completedCount / activities.length) * 100);

    return {
      daily_progress: {
        date: targetDate,
        completed: completedCount,
        total: activities.length,
        percentage,
      },
    };
  } catch (error: any) {
    console.error('AI get daily progress error:', error);
    return { error: 'Failed to get progress data' };
  }
}

export async function aiGetRangeProgress(userId: string, from: string, to: string): Promise<{
  completed: number;
  total: number;
  percentage: number;
  daily_progress: Array<{ date: string; completed: number; total: number; percentage: number }>;
  error?: string;
}> {
  try {
    const db = await getDatabase();
    const activities = await db.all<Activity[]>(
      'SELECT * FROM activities WHERE user_id = ? AND is_active = 1',
      [userId],
    );
    const completions = await db.all<ActivityCompletion[]>(
      'SELECT * FROM activity_completions WHERE user_id = ? AND date BETWEEN ? AND ?',
      [userId, from, to],
    );
    const map = new Map<string, boolean>();
    completions.forEach(completion => map.set(`${completion.activity_id}:${completion.date}`, Boolean(completion.completed)));
    const daily_progress = [];
    for (let date = new Date(`${from}T00:00:00Z`); date <= new Date(`${to}T00:00:00Z`); date.setUTCDate(date.getUTCDate() + 1)) {
      const dateString = date.toISOString().split('T')[0];
      const completed = activities.filter(activity => map.get(`${activity.id}:${dateString}`)).length;
      const total = activities.length;
      daily_progress.push({ date: dateString, completed, total, percentage: total ? Math.round((completed / total) * 100) : 0 });
    }
    const completed = daily_progress.reduce((sum, day) => sum + day.completed, 0);
    const total = daily_progress.reduce((sum, day) => sum + day.total, 0);
    return { completed, total, percentage: total ? Math.round((completed / total) * 100) : 0, daily_progress };
  } catch (error) {
    console.error('AI get range progress error:', error);
    return { completed: 0, total: 0, percentage: 0, daily_progress: [], error: 'Failed to get historical progress' };
  }
}

export async function aiSaveChatMessage(
  userId: string,
  role: 'user' | 'assistant',
  message: string,
  actionType?: string,
  actionData?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const db = await getDatabase();
    const messageId = generateId();

    await db.run(
      `INSERT INTO chat_messages (id, user_id, role, message, action_type, action_data)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [messageId, userId, role, message, actionType || null, actionData || null]
    );

    return { success: true };
  } catch (error: any) {
    console.error('AI save chat message error:', error);
    return { success: false, error: 'Failed to save message' };
  }
}

export async function aiGetChatHistory(userId: string, limit: number = 50): Promise<{
  messages?: Array<{
    role: string;
    message: string;
    created_at: string;
  }>;
  error?: string;
}> {
  try {
    const db = await getDatabase();
    const messages = await db.all(
      `SELECT role, message, created_at FROM chat_messages 
       WHERE user_id = ? 
       ORDER BY created_at DESC 
       LIMIT ?`,
      [userId, limit]
    );

    return { messages: messages ? messages.reverse() : [] };
  } catch (error: any) {
    console.error('AI get chat history error:', error);
    return { error: 'Failed to get chat history' };
  }
}
