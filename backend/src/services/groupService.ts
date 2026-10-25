import { getDatabase } from '../config/database';
import { generateId } from '../utils/auth';
import { ActivityGroup } from '../models/types';

/**
 * Ensures an activity group exists for a user in the `activity_groups` table.
 * If not present, creates it.
 */
export async function ensureGroupExists(userId: string, rawGroupName: string): Promise<ActivityGroup> {
  const db = await getDatabase();
  const groupName = (rawGroupName || 'General').trim() || 'General';

  let group = await db.get<ActivityGroup>(
    `SELECT * FROM activity_groups WHERE user_id = ? AND name = ?`,
    [userId, groupName]
  );

  if (!group) {
    const groupId = generateId();
    await db.run(
      `INSERT INTO activity_groups (id, user_id, name) VALUES (?, ?, ?)`,
      [groupId, userId, groupName]
    );

    group = await db.get<ActivityGroup>(
      `SELECT * FROM activity_groups WHERE id = ?`,
      [groupId]
    );
  }

  return group!;
}

/**
 * Handles group renaming: updates `activity_groups`, `activities`, and `activity_completions`.
 */
export async function renameActivityGroup(
  userId: string,
  groupId: string,
  newName: string
): Promise<ActivityGroup | null> {
  const db = await getDatabase();
  const trimmed = newName.trim();
  if (!trimmed) return null;

  const group = await db.get<ActivityGroup>(
    `SELECT * FROM activity_groups WHERE id = ? AND user_id = ?`,
    [groupId, userId]
  );

  if (!group) return null;

  const oldName = group.name;

  // 1. Update activity_groups name
  await db.run(
    `UPDATE activity_groups SET name = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?`,
    [trimmed, groupId, userId]
  );

  // 2. Update activities table
  await db.run(
    `UPDATE activities SET group_name = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND group_name = ? AND is_active = 1`,
    [trimmed, userId, oldName]
  );

  // 3. Update activity_completions table
  await db.run(
    `UPDATE activity_completions SET group_name = ? WHERE user_id = ? AND group_name = ?`,
    [trimmed, userId, oldName]
  );

  return {
    ...group,
    name: trimmed,
    updated_at: new Date().toISOString(),
  };
}

/**
 * Handles group deletion: soft-deletes activities in the group and removes the group record.
 */
export async function deleteActivityGroup(
  userId: string,
  groupId: string
): Promise<{ deleted: boolean; groupName?: string }> {
  const db = await getDatabase();
  const group = await db.get<ActivityGroup>(
    `SELECT * FROM activity_groups WHERE id = ? AND user_id = ?`,
    [groupId, userId]
  );

  if (!group) return { deleted: false };

  // 1. Soft-delete activities in this group
  await db.run(
    `UPDATE activities SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND group_name = ?`,
    [userId, group.name]
  );

  // 2. Delete group
  await db.run(
    `DELETE FROM activity_groups WHERE id = ? AND user_id = ?`,
    [groupId, userId]
  );

  return { deleted: true, groupName: group.name };
}
