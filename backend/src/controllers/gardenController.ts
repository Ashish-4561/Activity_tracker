import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import {
  getAllGardensForUser,
  getGardenByGroupId,
  ensureGroupExists,
  renameActivityGroup,
  deleteActivityGroup,
} from '../services/gardenService';
import { getDatabase } from '../config/database';
import { ActivityGroup } from '../models/types';

/**
 * GET /api/gardens
 * Returns all group gardens for the authenticated user.
 */
export async function getGardens(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const gardens = await getAllGardensForUser(req.userId);
    res.json({
      gardens,
      total_gardens: gardens.length,
    });
  } catch (error: any) {
    console.error('Get gardens error:', error);
    res.status(500).json({ error: 'Failed to retrieve gardens' });
  }
}

/**
 * GET /api/gardens/:groupId
 * Returns the garden for a specific activity group.
 */
export async function getGardenById(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { groupId } = req.params;
    if (!groupId) {
      res.status(400).json({ error: 'Group ID is required' });
      return;
    }

    let garden = await getGardenByGroupId(req.userId, groupId);

    // If not found by ID directly, check if parameter was passed as group name (URL-encoded)
    if (!garden) {
      const decodedName = decodeURIComponent(groupId).trim();
      const db = await getDatabase();
      const groupByName = await db.get<ActivityGroup>(
        `SELECT * FROM activity_groups WHERE user_id = ? AND name = ?`,
        [req.userId, decodedName]
      );
      if (groupByName) {
        garden = await getGardenByGroupId(req.userId, groupByName.id);
      }
    }

    if (!garden) {
      res.status(404).json({ error: 'Garden not found for this group' });
      return;
    }

    res.json({ garden });
  } catch (error: any) {
    console.error('Get garden by ID error:', error);
    res.status(500).json({ error: 'Failed to retrieve group garden' });
  }
}

/**
 * POST /api/groups
 * Ensures or creates a group and returns its ID and garden.
 */
export async function createOrGetGroup(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { name } = req.body;
    if (!name || !name.trim()) {
      res.status(400).json({ error: 'Group name is required' });
      return;
    }

    const group = await ensureGroupExists(req.userId, name.trim());
    const garden = await getGardenByGroupId(req.userId, group.id);

    res.json({
      group,
      garden,
    });
  } catch (error: any) {
    console.error('Create group error:', error);
    res.status(500).json({ error: 'Failed to create group' });
  }
}

/**
 * PUT /api/groups/:groupId/rename
 * Renames a group while preserving its group ID and attached garden.
 */
export async function renameGroupById(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { groupId } = req.params;
    const { newGroupName } = req.body;

    if (!groupId || !newGroupName || !newGroupName.trim()) {
      res.status(400).json({ error: 'Group ID and new group name are required' });
      return;
    }

    let targetGroupId = groupId;
    const db = await getDatabase();
    let group = await db.get<ActivityGroup>(
      `SELECT * FROM activity_groups WHERE id = ? AND user_id = ?`,
      [targetGroupId, req.userId]
    );

    // Support rename by groupName if passed as param
    if (!group) {
      const decodedName = decodeURIComponent(groupId).trim();
      group = await db.get<ActivityGroup>(
        `SELECT * FROM activity_groups WHERE user_id = ? AND name = ?`,
        [req.userId, decodedName]
      );
      if (group) {
        targetGroupId = group.id;
      }
    }

    if (!group) {
      // Group was never seeded in activity_groups, create it first
      const ensured = await ensureGroupExists(req.userId, decodeURIComponent(groupId).trim());
      targetGroupId = ensured.id;
    }

    const updatedGarden = await renameActivityGroup(req.userId, targetGroupId, newGroupName.trim());

    if (!updatedGarden) {
      res.status(500).json({ error: 'Failed to rename group' });
      return;
    }

    res.json({
      message: `Group renamed to "${newGroupName.trim()}"`,
      garden: updatedGarden,
    });
  } catch (error: any) {
    console.error('Rename group by ID error:', error);
    res.status(500).json({ error: 'Failed to rename group' });
  }
}

/**
 * DELETE /api/groups/:groupId
 * Deletes a group and handles its garden data safely according to existing group-deletion rules.
 */
export async function deleteGroupById(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { groupId } = req.params;
    if (!groupId) {
      res.status(400).json({ error: 'Group ID is required' });
      return;
    }

    let targetGroupId = groupId;
    const db = await getDatabase();
    let group = await db.get<ActivityGroup>(
      `SELECT * FROM activity_groups WHERE id = ? AND user_id = ?`,
      [targetGroupId, req.userId]
    );

    if (!group) {
      const decodedName = decodeURIComponent(groupId).trim();
      group = await db.get<ActivityGroup>(
        `SELECT * FROM activity_groups WHERE user_id = ? AND name = ?`,
        [req.userId, decodedName]
      );
      if (group) {
        targetGroupId = group.id;
      }
    }

    if (!group) {
      res.json({ message: 'Group deleted or not found', deleted: false });
      return;
    }

    const result = await deleteActivityGroup(req.userId, targetGroupId);
    res.json({
      message: `Group "${result.groupName || group.name}" and garden deleted successfully`,
      deleted: result.deleted,
    });
  } catch (error: any) {
    console.error('Delete group by ID error:', error);
    res.status(500).json({ error: 'Failed to delete group' });
  }
}
