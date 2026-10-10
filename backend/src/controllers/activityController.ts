import { Response } from 'express';
import { getDatabase } from '../config/database';
import { generateId, getCurrentDate } from '../utils/auth';
import { AuthRequest } from '../middleware/auth';
import { Activity } from '../models/types';

export async function createActivity(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const {
      name, group_name, icon, frequency, frequency_value, frequency_unit,
      duration_value, duration_unit, start_date, color, description,
    } = req.body;

    if (!name) {
      res.status(400).json({ error: 'Activity name is required' });
      return;
    }

    const normalizedFrequency = frequency || 'custom';
    const normalizedUnit = frequency_unit || (normalizedFrequency === 'weekly' ? 'weeks' : 'days');
    const frequencyValue = Number(frequency_value ?? 1);
    const durationValue = Number(duration_value ?? 12);
    const normalizedDurationUnit = duration_unit || 'months';
    if (!['days', 'weeks', 'months'].includes(normalizedUnit) || !Number.isInteger(frequencyValue) || frequencyValue < 1) {
      res.status(400).json({ error: 'Frequency must include a positive whole number and a valid unit' });
      return;
    }
    if (!['days', 'weeks', 'months'].includes(normalizedDurationUnit) || !Number.isInteger(durationValue) || durationValue < 1) {
      res.status(400).json({ error: 'Duration must include a positive whole number and a valid unit' });
      return;
    }
    const startDate = typeof start_date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(start_date)
      ? start_date
      : new Date().toISOString().split('T')[0];

    const db = await getDatabase();
    const activityId = generateId();

    await db.run(
      `INSERT INTO activities (id, user_id, name, group_name, icon, frequency, start_date, frequency_value, frequency_unit, duration_value, duration_unit, color, description, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [activityId, req.userId, name.trim(), group_name || 'General', icon || null, normalizedFrequency, startDate, frequencyValue, normalizedUnit, durationValue, normalizedDurationUnit, color || null, description || null, true]
    );

    res.status(201).json({
      message: 'Activity created successfully',
      activity: {
        id: activityId,
        user_id: req.userId,
        name: name.trim(),
        group_name: group_name || 'General',
        icon,
        frequency: normalizedFrequency,
        start_date: startDate,
        frequency_value: frequencyValue,
        frequency_unit: normalizedUnit,
        duration_value: durationValue,
        duration_unit: normalizedDurationUnit,
        is_active: true,
      },
    });
  } catch (error: any) {
    console.error('Create activity error:', error);
    res.status(500).json({ error: 'Failed to create activity' });
  }
}

export async function getActivities(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { date } = req.query;
    const targetDate = (date as string) || getCurrentDate();
    const db = await getDatabase();

    const activities = await db.all<Activity[]>(
      `SELECT a.*, 
              CASE WHEN ac.completed = true OR ac.completed = 1 THEN 1 ELSE 0 END as completed,
              ac.completed_at
       FROM activities a
       LEFT JOIN activity_completions ac 
         ON ac.activity_id = a.id 
         AND ac.user_id = a.user_id 
         AND ac.date = ?
       WHERE a.user_id = ? AND a.is_active = 1 
       ORDER BY a.created_at DESC`,
      [targetDate, req.userId]
    );

    res.json({ activities: activities || [] });
  } catch (error: any) {
    console.error('Get activities error:', error);
    res.status(500).json({ error: 'Failed to get activities' });
  }
}

export async function getActivityById(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const db = await getDatabase();

    const activity = await db.get<Activity>(
      `SELECT * FROM activities WHERE id = ? AND user_id = ?`,
      [id, req.userId]
    );

    if (!activity) {
      res.status(404).json({ error: 'Activity not found' });
      return;
    }

    res.json({ activity });
  } catch (error: any) {
    console.error('Get activity error:', error);
    res.status(500).json({ error: 'Failed to get activity' });
  }
}

export async function updateActivity(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const { name, group_name, icon, frequency, frequency_value, frequency_unit, duration_value, duration_unit, start_date, color, description } = req.body;

    // Verify ownership
    const db = await getDatabase();
    const activity = await db.get<Activity>(
      `SELECT * FROM activities WHERE id = ? AND user_id = ?`,
      [id, req.userId]
    );

    if (!activity) {
      res.status(404).json({ error: 'Activity not found' });
      return;
    }

    const updates: string[] = [];
    const values: any[] = [];

    if (name !== undefined) {
      updates.push('name = ?');
      values.push(name);
    }
    if (icon !== undefined) {
      updates.push('icon = ?');
      values.push(icon);
    }
    if (group_name !== undefined) {
      updates.push('group_name = ?');
      values.push(group_name || 'General');
    }
    if (frequency !== undefined) {
      if (!['daily', 'weekly', 'custom'].includes(frequency)) {
        res.status(400).json({ error: 'Invalid frequency' });
        return;
      }
      updates.push('frequency = ?');
      values.push(frequency);
    }
    if (frequency_value !== undefined) {
      if (!Number.isInteger(Number(frequency_value)) || Number(frequency_value) < 1) {
        res.status(400).json({ error: 'Frequency value must be a positive whole number' });
        return;
      }
      updates.push('frequency_value = ?');
      values.push(Number(frequency_value));
    }
    if (frequency_unit !== undefined) {
      if (!['days', 'weeks', 'months'].includes(frequency_unit)) {
        res.status(400).json({ error: 'Invalid frequency unit' });
        return;
      }
      updates.push('frequency_unit = ?');
      values.push(frequency_unit);
    }
    if (duration_value !== undefined) {
      if (!Number.isInteger(Number(duration_value)) || Number(duration_value) < 1) {
        res.status(400).json({ error: 'Duration value must be a positive whole number' });
        return;
      }
      updates.push('duration_value = ?');
      values.push(Number(duration_value));
    }
    if (duration_unit !== undefined) {
      if (!['days', 'weeks', 'months'].includes(duration_unit)) {
        res.status(400).json({ error: 'Invalid duration unit' });
        return;
      }
      updates.push('duration_unit = ?');
      values.push(duration_unit);
    }
    if (start_date !== undefined) {
      if (typeof start_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(start_date)) {
        res.status(400).json({ error: 'Start date must use YYYY-MM-DD format' });
        return;
      }
      updates.push('start_date = ?');
      values.push(start_date);
    }
    if (color !== undefined) {
      updates.push('color = ?');
      values.push(color);
    }
    if (description !== undefined) {
      updates.push('description = ?');
      values.push(description);
    }

    if (updates.length === 0) {
      res.status(400).json({ error: 'No updates provided' });
      return;
    }

    updates.push('updated_at = CURRENT_TIMESTAMP');
    values.push(id);

    await db.run(
      `UPDATE activities SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    res.json({ message: 'Activity updated successfully' });
  } catch (error: any) {
    console.error('Update activity error:', error);
    res.status(500).json({ error: 'Failed to update activity' });
  }
}

export async function deleteActivity(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const db = await getDatabase();

    // Verify ownership
    const activity = await db.get<Activity>(
      `SELECT * FROM activities WHERE id = ? AND user_id = ?`,
      [id, req.userId]
    );

    if (!activity) {
      res.status(404).json({ error: 'Activity not found' });
      return;
    }

    // Soft delete - mark as inactive
    await db.run(
      `UPDATE activities SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      [id]
    );

    res.json({ message: 'Activity deleted successfully' });
  } catch (error: any) {
    console.error('Delete activity error:', error);
    res.status(500).json({ error: 'Failed to delete activity' });
  }
}

export async function deleteGroup(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { groupName } = req.params;
    if (!groupName) {
      res.status(400).json({ error: 'Group name is required' });
      return;
    }

    const db = await getDatabase();

    // Check if user has active activities in this group
    const activities = await db.all<Activity[]>(
      `SELECT * FROM activities WHERE user_id = ? AND group_name = ? AND is_active = 1`,
      [req.userId, groupName]
    );

    if (!activities || activities.length === 0) {
      res.status(404).json({ error: 'No active activities found in this group' });
      return;
    }

    // Soft delete all activities in this group for the user
    await db.run(
      `UPDATE activities SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND group_name = ?`,
      [req.userId, groupName]
    );

    res.json({
      message: `Group "${groupName}" deleted successfully`,
      deleted_count: activities.length,
    });
  } catch (error: any) {
    console.error('Delete group error:', error);
    res.status(500).json({ error: 'Failed to delete group' });
  }
}

export async function renameGroup(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { groupName } = req.params;
    const { newGroupName } = req.body;

    if (!groupName || !newGroupName || !newGroupName.trim()) {
      res.status(400).json({ error: 'Current group name and new group name are required' });
      return;
    }

    const trimmedNew = newGroupName.trim();
    const db = await getDatabase();

    // Update all active activities in this group
    const result = await db.run(
      `UPDATE activities SET group_name = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND group_name = ? AND is_active = 1`,
      [trimmedNew, req.userId, groupName]
    );

    // Also update activity_completions table for consistency
    await db.run(
      `UPDATE activity_completions SET group_name = ? WHERE user_id = ? AND group_name = ?`,
      [trimmedNew, req.userId, groupName]
    );

    res.json({
      message: `Group "${groupName}" renamed to "${trimmedNew}"`,
      updated_count: result.changes,
    });
  } catch (error: any) {
    console.error('Rename group error:', error);
    res.status(500).json({ error: 'Failed to rename group' });
  }
}


