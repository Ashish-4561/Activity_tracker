class GardenPlant {
  final String id;
  final String name;
  final String emoji;
  final String stage;
  final String rarity;
  final int levelRequired;
  final String description;
  final bool unlocked;
  final String? unlockedAt;

  GardenPlant({
    required this.id,
    required this.name,
    required this.emoji,
    required this.stage,
    required this.rarity,
    required this.levelRequired,
    required this.description,
    required this.unlocked,
    this.unlockedAt,
  });

  factory GardenPlant.fromJson(Map<String, dynamic> json) {
    return GardenPlant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🌱',
      stage: json['stage']?.toString() ?? 'sprout',
      rarity: json['rarity']?.toString() ?? 'common',
      levelRequired: json['levelRequired'] is int
          ? json['levelRequired']
          : int.tryParse(json['levelRequired']?.toString() ?? '1') ?? 1,
      description: json['description']?.toString() ?? '',
      unlocked: json['unlocked'] == true || json['unlocked'] == 1,
      unlockedAt: json['unlockedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'stage': stage,
      'rarity': rarity,
      'levelRequired': levelRequired,
      'description': description,
      'unlocked': unlocked,
      'unlockedAt': unlockedAt,
    };
  }
}

class GardenMilestone {
  final String id;
  final String title;
  final String description;
  final String badge;
  final bool achieved;
  final String? achievedAt;

  GardenMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.achieved,
    this.achievedAt,
  });

  factory GardenMilestone.fromJson(Map<String, dynamic> json) {
    return GardenMilestone(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      badge: json['badge']?.toString() ?? '🌱',
      achieved: json['achieved'] == true || json['achieved'] == 1,
      achievedAt: json['achievedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'badge': badge,
      'achieved': achieved,
      'achievedAt': achievedAt,
    };
  }
}

class GroupGarden {
  final String id;
  final String groupId;
  final String userId;
  final String groupName;
  final int growthPoints;
  final int level;
  final String levelName;
  final int levelProgressPercentage;
  final int nextLevelPoints;
  final int currentLevelBasePoints;
  final int activitiesCompletedCount;
  final int currentStreak;
  final int bestStreak;
  final List<GardenPlant> unlockedPlants;
  final List<GardenMilestone> milestones;
  final String createdAt;
  final String updatedAt;

  GroupGarden({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.groupName,
    required this.growthPoints,
    required this.level,
    required this.levelName,
    required this.levelProgressPercentage,
    required this.nextLevelPoints,
    required this.currentLevelBasePoints,
    required this.activitiesCompletedCount,
    required this.currentStreak,
    required this.bestStreak,
    required this.unlockedPlants,
    required this.milestones,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupGarden.fromJson(Map<String, dynamic> json) {
    final rawPlants = json['unlocked_plants'];
    List<GardenPlant> plants = [];
    if (rawPlants is List) {
      plants = rawPlants.map((p) => GardenPlant.fromJson(p as Map<String, dynamic>)).toList();
    } else if (rawPlants is String) {
      try {
        // Handle encoded string if any
      } catch (_) {}
    }

    final rawMilestones = json['milestones'];
    List<GardenMilestone> milestones = [];
    if (rawMilestones is List) {
      milestones = rawMilestones.map((m) => GardenMilestone.fromJson(m as Map<String, dynamic>)).toList();
    }

    int parseInt(dynamic val, int fallback) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    return GroupGarden(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? 'General',
      growthPoints: parseInt(json['growth_points'], 0),
      level: parseInt(json['level'], 1),
      levelName: json['level_name']?.toString() ?? 'Sprout Haven',
      levelProgressPercentage: parseInt(json['level_progress_percentage'], 0),
      nextLevelPoints: parseInt(json['next_level_points'], 50),
      currentLevelBasePoints: parseInt(json['current_level_base_points'], 0),
      activitiesCompletedCount: parseInt(json['activities_completed_count'], 0),
      currentStreak: parseInt(json['current_streak'], 0),
      bestStreak: parseInt(json['best_streak'], 0),
      unlockedPlants: plants,
      milestones: milestones,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'group_name': groupName,
      'growth_points': growthPoints,
      'level': level,
      'level_name': levelName,
      'level_progress_percentage': levelProgressPercentage,
      'next_level_points': nextLevelPoints,
      'current_level_base_points': currentLevelBasePoints,
      'activities_completed_count': activitiesCompletedCount,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'unlocked_plants': unlockedPlants.map((p) => p.toJson()).toList(),
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Helper to get only currently unlocked plants
  List<GardenPlant> get onlyUnlockedPlants =>
      unlockedPlants.where((p) => p.unlocked).toList();

  /// Helper to get achieved milestones
  List<GardenMilestone> get onlyAchievedMilestones =>
      milestones.where((m) => m.achieved).toList();
}
