import { getDatabase } from '../config/database';
import { generateId } from '../utils/auth';
import { ActivityGroup, GroupGarden, GardenPlant, GardenMilestone } from '../models/types';

// Catalog of potential plants that can be unlocked in each group's garden
export const BASE_PLANT_CATALOG: Omit<GardenPlant, 'unlocked' | 'unlockedAt'>[] = [
  {
    id: 'plant_golden_sprout',
    name: 'Golden Sprout',
    emoji: '🌱',
    stage: 'sprout',
    rarity: 'common',
    levelRequired: 1,
    description: 'The dawn of a new habit journey. Fragile yet full of infinite potential.',
  },
  {
    id: 'plant_jade_herb',
    name: 'Jade Herb',
    emoji: '🌿',
    stage: 'seedling',
    rarity: 'common',
    levelRequired: 1,
    description: 'Fresh, aromatic leaves that thrive with steady daily consistency.',
  },
  {
    id: 'plant_cherry_blossom',
    name: 'Cherry Blossom',
    emoji: '🌸',
    stage: 'budding',
    rarity: 'common',
    levelRequired: 2,
    description: 'Delicate petals celebrating the first fruits of disciplined focus.',
  },
  {
    id: 'plant_zen_bonsai',
    name: 'Zen Bonsai',
    emoji: '🪴',
    stage: 'sprout',
    rarity: 'rare',
    levelRequired: 2,
    description: 'Cultivated with patience and mindful daily repetition.',
  },
  {
    id: 'plant_sunburst_bloom',
    name: 'Sunburst Bloom',
    emoji: '🌻',
    stage: 'blooming',
    rarity: 'rare',
    levelRequired: 3,
    description: 'Radiates warm golden light, fueled by sustained daily momentum.',
  },
  {
    id: 'plant_whispering_bamboo',
    name: 'Whispering Bamboo',
    emoji: '🌾',
    stage: 'sprout',
    rarity: 'rare',
    levelRequired: 3,
    description: 'Flexible yet unbreakable strength rooted in recurring habits.',
  },
  {
    id: 'plant_lotus_serenity',
    name: 'Lotus of Serenity',
    emoji: '🌺',
    stage: 'blooming',
    rarity: 'rare',
    levelRequired: 4,
    description: 'Emerges pure and calm from persevering through challenges.',
  },
  {
    id: 'plant_desert_resilience',
    name: 'Resilience Cactus',
    emoji: '🌵',
    stage: 'budding',
    rarity: 'epic',
    levelRequired: 4,
    description: 'Thrives in any circumstance through enduring, quiet discipline.',
  },
  {
    id: 'plant_royal_orchid',
    name: 'Royal Orchid',
    emoji: '🌷',
    stage: 'blooming',
    rarity: 'epic',
    levelRequired: 5,
    description: 'Exquisite and vibrant, awarded to dedicated habit cultivators.',
  },
  {
    id: 'plant_bodhi_tree',
    name: 'Ancient Bodhi Tree',
    emoji: '🌳',
    stage: 'mastery',
    rarity: 'epic',
    levelRequired: 5,
    description: 'Deeply rooted wisdom gained from sustained daily practice.',
  },
  {
    id: 'plant_evergreen_pine',
    name: 'Evergreen Pine',
    emoji: '🌲',
    stage: 'mastery',
    rarity: 'epic',
    levelRequired: 6,
    description: 'Stands tall and unwavering throughout every season of life.',
  },
  {
    id: 'plant_dew_fountain',
    name: 'Crystal Dew Fountain',
    emoji: '⛲',
    stage: 'mastery',
    rarity: 'epic',
    levelRequired: 6,
    description: 'A serene crystal sanctuary celebrating sustained focus.',
  },
  {
    id: 'plant_stone_lantern',
    name: 'Luminous Stone Lantern',
    emoji: '🏮',
    stage: 'mastery',
    rarity: 'epic',
    levelRequired: 7,
    description: 'Illuminates your growth path with peaceful, ambient radiance.',
  },
  {
    id: 'plant_sunlit_palm',
    name: 'Sunlit Oasis Palm',
    emoji: '🌴',
    stage: 'blooming',
    rarity: 'legendary',
    levelRequired: 7,
    description: 'A tropical beacon of enduring personal achievement.',
  },
  {
    id: 'plant_autumn_maple',
    name: 'Scarlet Autumn Maple',
    emoji: '🍁',
    stage: 'blooming',
    rarity: 'legendary',
    levelRequired: 8,
    description: 'Rich scarlet and gold leaves marking exceptional mastery.',
  },
  {
    id: 'plant_butterfly_haven',
    name: 'Butterfly Sanctuary',
    emoji: '🦋',
    stage: 'mastery',
    rarity: 'legendary',
    levelRequired: 8,
    description: 'Fluttering companions drawn to a thriving, balanced ecosystem.',
  },
  {
    id: 'plant_celestial_tree',
    name: 'Prismatic Celestial Tree',
    emoji: '🌈',
    stage: 'mastery',
    rarity: 'legendary',
    levelRequired: 9,
    description: 'A mythical beacon woven from unbreakable daily devotion.',
  },
  {
    id: 'plant_star_blossom',
    name: 'Star of Mastery',
    emoji: '🌟',
    stage: 'mastery',
    rarity: 'legendary',
    levelRequired: 10,
    description: 'The crowning testament to lifelong self-transformation.',
  },
];

export const LEVEL_DEFINITIONS = [
  { level: 1, name: 'Sprout Haven', minPoints: 0, maxPoints: 49 },
  { level: 2, name: 'Seedling Sanctuary', minPoints: 50, maxPoints: 119 },
  { level: 3, name: 'Blooming Meadow', minPoints: 120, maxPoints: 219 },
  { level: 4, name: 'Verdant Oasis', minPoints: 220, maxPoints: 349 },
  { level: 5, name: 'Emerald Grove', minPoints: 350, maxPoints: 499 },
  { level: 6, name: 'Flourishing Arboretum', minPoints: 500, maxPoints: 699 },
  { level: 7, name: 'Enchanted Botanical', minPoints: 700, maxPoints: 949 },
  { level: 8, name: 'Celestial Canopy', minPoints: 950, maxPoints: 1249 },
  { level: 9, name: 'Evergreen Arcadia', minPoints: 1250, maxPoints: 1599 },
  { level: 10, name: 'Mythic Garden of Mastery', minPoints: 1600, maxPoints: 999999 },
];

export function calculateGardenLevel(points: number): {
  level: number;
  levelName: string;
  progressPercentage: number;
  nextLevelPoints: number;
  currentLevelBasePoints: number;
} {
  let matched = LEVEL_DEFINITIONS[0];
  for (const def of LEVEL_DEFINITIONS) {
    if (points >= def.minPoints) {
      matched = def;
    } else {
      break;
    }
  }

  const nextLevel = LEVEL_DEFINITIONS.find((d) => d.level === matched.level + 1);
  const nextLevelPoints = nextLevel ? nextLevel.minPoints : matched.maxPoints;
  const range = nextLevelPoints - matched.minPoints;
  const currentInLevel = Math.max(0, points - matched.minPoints);
  const progressPercentage = range > 0 ? Math.min(100, Math.round((currentInLevel / range) * 100)) : 100;

  return {
    level: matched.level,
    levelName: matched.name,
    progressPercentage,
    nextLevelPoints,
    currentLevelBasePoints: matched.minPoints,
  };
}

export function buildGroupMilestones(
  completedCount: number,
  currentStreak: number,
  bestStreak: number,
  gardenLevel: number
): GardenMilestone[] {
  return [
    {
      id: 'ms_first_sprout',
      title: 'First Sprout',
      description: 'Completed the first activity in this group',
      badge: '🌱',
      achieved: completedCount >= 1,
    },
    {
      id: 'ms_active_cultivator',
      title: 'Active Cultivator',
      description: 'Completed 5 activities in this group',
      badge: '🌿',
      achieved: completedCount >= 5,
    },
    {
      id: 'ms_streak_3',
      title: 'Streak of Life',
      description: 'Maintained a 3-day activity streak in this group',
      badge: '🔥',
      achieved: currentStreak >= 3 || bestStreak >= 3,
    },
    {
      id: 'ms_garden_bloom',
      title: 'Blooming Meadow',
      description: 'Reached Garden Level 3 in this group',
      badge: '🌸',
      achieved: gardenLevel >= 3,
    },
    {
      id: 'ms_streak_7',
      title: 'Unstoppable Flow',
      description: 'Maintained a 7-day activity streak in this group',
      badge: '⚡',
      achieved: currentStreak >= 7 || bestStreak >= 7,
    },
    {
      id: 'ms_emerald_grove',
      title: 'Grove Guardian',
      description: 'Reached Garden Level 5 in this group',
      badge: '🌳',
      achieved: gardenLevel >= 5,
    },
    {
      id: 'ms_quarter_century',
      title: 'Master Botanist',
      description: 'Completed 25 activities in this group',
      badge: '🏆',
      achieved: completedCount >= 25,
    },
    {
      id: 'ms_mythic_mastery',
      title: 'Mythic Garden',
      description: 'Achieved Garden Level 10 in this group',
      badge: '👑',
      achieved: gardenLevel >= 10,
    },
  ];
}

/**
 * Ensures an activity group exists in `activity_groups` for this user.
 * Returns the stable `ActivityGroup` record.
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

    // Also initialize the group garden
    const gardenId = generateId();
    await db.run(
      `INSERT INTO group_gardens (id, group_id, user_id, growth_points, level, unlocked_plants, milestones)
       VALUES (?, ?, ?, 0, 1, '[]', '[]')`,
      [gardenId, groupId, userId]
    );

    group = await db.get<ActivityGroup>(
      `SELECT * FROM activity_groups WHERE id = ?`,
      [groupId]
    );
  }

  return group!;
}

/**
 * Computes streaks for a specific group based on distinct completed activity dates.
 */
export async function computeGroupStreaks(
  userId: string,
  groupName: string
): Promise<{ currentStreak: number; bestStreak: number }> {
  const db = await getDatabase();

  // Find distinct completion dates for activities belonging to this group
  const rows = await db.all<{ date: string }[]>(
    `SELECT DISTINCT date FROM activity_completions
     WHERE user_id = ? AND group_name = ? AND (completed = 1 OR completed = TRUE)
     ORDER BY date DESC`,
    [userId, groupName]
  );

  if (!rows || rows.length === 0) {
    return { currentStreak: 0, bestStreak: 0 };
  }

  const sortedDates = rows.map((r) => r.date).sort().reverse();
  const today = new Date().toISOString().split('T')[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

  let currentStreak = 0;
  let bestStreak = 0;
  let tempStreak = 0;

  // Calculate current streak
  let checkDate = new Date();
  if (!sortedDates.includes(today) && !sortedDates.includes(yesterday)) {
    currentStreak = 0;
  } else {
    let currentCheck = sortedDates.includes(today) ? new Date(today) : new Date(yesterday);
    while (true) {
      const dateStr = currentCheck.toISOString().split('T')[0];
      if (sortedDates.includes(dateStr)) {
        currentStreak++;
        currentCheck.setDate(currentCheck.getDate() - 1);
      } else {
        break;
      }
    }
  }

  // Calculate best streak
  if (sortedDates.length > 0) {
    tempStreak = 1;
    bestStreak = 1;
    for (let i = 0; i < sortedDates.length - 1; i++) {
      const d1 = new Date(sortedDates[i]);
      const d2 = new Date(sortedDates[i + 1]);
      const diffDays = Math.round((d1.getTime() - d2.getTime()) / 86400000);
      if (diffDays === 1) {
        tempStreak++;
        if (tempStreak > bestStreak) bestStreak = tempStreak;
      } else if (diffDays > 1) {
        tempStreak = 1;
      }
    }
  }

  if (currentStreak > bestStreak) bestStreak = currentStreak;

  return { currentStreak, bestStreak };
}

/**
 * Calculates and returns the live, synchronized `GroupGarden` for a group.
 * Ensures the points, level, unlocked plants, and milestones match the actual completed activity records.
 */
export async function getOrComputeGarden(
  userId: string,
  group: ActivityGroup
): Promise<GroupGarden> {
  const db = await getDatabase();

  // 1. Calculate actual completion count for this specific group
  const completionRow = await db.get<{ count: number }>(
    `SELECT COUNT(*) as count FROM activity_completions
     WHERE user_id = ? AND group_name = ? AND (completed = 1 OR completed = TRUE)`,
    [userId, group.name]
  );
  const completedCount = completionRow?.count ? Number(completionRow.count) : 0;

  // 2. Compute group-specific streaks
  const { currentStreak, bestStreak } = await computeGroupStreaks(userId, group.name);

  // 3. Compute growth points: 10 GP per verified completion + streak bonuses
  let bonusPoints = 0;
  if (bestStreak >= 30) bonusPoints += 150;
  else if (bestStreak >= 14) bonusPoints += 70;
  else if (bestStreak >= 7) bonusPoints += 35;
  else if (bestStreak >= 3) bonusPoints += 15;

  const growthPoints = completedCount * 10 + bonusPoints;

  // 4. Calculate Level info
  const levelInfo = calculateGardenLevel(growthPoints);

  // 5. Build unlocked plants for this garden level
  const plants: GardenPlant[] = BASE_PLANT_CATALOG.map((base) => ({
    ...base,
    unlocked: levelInfo.level >= base.levelRequired,
  }));

  // 6. Build milestones for this group
  const milestones = buildGroupMilestones(completedCount, currentStreak, bestStreak, levelInfo.level);

  // 7. Upsert garden row in group_gardens table
  let garden = await db.get<{ id: string; created_at: string; updated_at: string }>(
    `SELECT * FROM group_gardens WHERE user_id = ? AND group_id = ?`,
    [userId, group.id]
  );

  const gardenId = garden ? garden.id : generateId();

  if (garden) {
    await db.run(
      `UPDATE group_gardens
       SET growth_points = ?, level = ?, unlocked_plants = ?, milestones = ?, updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [growthPoints, levelInfo.level, JSON.stringify(plants), JSON.stringify(milestones), gardenId]
    );
  } else {
    await db.run(
      `INSERT INTO group_gardens (id, group_id, user_id, growth_points, level, unlocked_plants, milestones)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [gardenId, group.id, userId, growthPoints, levelInfo.level, JSON.stringify(plants), JSON.stringify(milestones)]
    );
  }

  return {
    id: gardenId,
    group_id: group.id,
    user_id: userId,
    group_name: group.name,
    growth_points: growthPoints,
    level: levelInfo.level,
    level_name: levelInfo.levelName,
    level_progress_percentage: levelInfo.progressPercentage,
    next_level_points: levelInfo.nextLevelPoints,
    current_level_base_points: levelInfo.currentLevelBasePoints,
    activities_completed_count: completedCount,
    current_streak: currentStreak,
    best_streak: bestStreak,
    unlocked_plants: plants,
    milestones: milestones,
    created_at: garden?.created_at || new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
}

/**
 * Retrieves all group gardens for an authenticated user.
 */
export async function getAllGardensForUser(userId: string): Promise<GroupGarden[]> {
  const db = await getDatabase();

  // Find all distinct group names currently active in the user's activities
  const activeGroupRows = await db.all<{ group_name: string }[]>(
    `SELECT DISTINCT group_name FROM activities
     WHERE user_id = ? AND is_active = 1 AND group_name IS NOT NULL AND group_name != ''`,
    [userId]
  );

  const activeNames = new Set(
    (activeGroupRows || []).map((r) => r.group_name.trim()).filter((n) => n.length > 0)
  );

  // If no active groups exist, include default 'General'
  if (activeNames.size === 0) {
    activeNames.add('General');
  }

  // Ensure each active group exists in activity_groups
  const gardens: GroupGarden[] = [];
  for (const name of activeNames) {
    const group = await ensureGroupExists(userId, name);
    const garden = await getOrComputeGarden(userId, group);
    gardens.push(garden);
  }

  return gardens;
}

/**
 * Retrieves the garden for a specific group by its ID.
 */
export async function getGardenByGroupId(userId: string, groupId: string): Promise<GroupGarden | null> {
  const db = await getDatabase();
  const group = await db.get<ActivityGroup>(
    `SELECT * FROM activity_groups WHERE id = ? AND user_id = ?`,
    [groupId, userId]
  );

  if (!group) {
    return null;
  }

  return getOrComputeGarden(userId, group);
}

/**
 * Handles group renaming: preserves the group ID and its attached garden.
 */
export async function renameActivityGroup(
  userId: string,
  groupId: string,
  newName: string
): Promise<GroupGarden | null> {
  const db = await getDatabase();
  const trimmed = newName.trim();
  if (!trimmed) return null;

  const group = await db.get<ActivityGroup>(
    `SELECT * FROM activity_groups WHERE id = ? AND user_id = ?`,
    [groupId, userId]
  );

  if (!group) return null;

  const oldName = group.name;

  // 1. Update activity_groups name (ID stays identical!)
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

  const updatedGroup: ActivityGroup = {
    ...group,
    name: trimmed,
    updated_at: new Date().toISOString(),
  };

  return getOrComputeGarden(userId, updatedGroup);
}

/**
 * Handles group deletion: cleans up activities, group, and associated garden.
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

  // 2. Delete garden
  await db.run(
    `DELETE FROM group_gardens WHERE group_id = ? AND user_id = ?`,
    [groupId, userId]
  );

  // 3. Delete group
  await db.run(
    `DELETE FROM activity_groups WHERE id = ? AND user_id = ?`,
    [groupId, userId]
  );

  return { deleted: true, groupName: group.name };
}
