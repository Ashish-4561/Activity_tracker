import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garden.dart';
import 'api_service.dart';
import 'auth_service.dart';

class GardenService extends ChangeNotifier {
  final ApiService apiService;
  final AuthService authService;

  bool _isLoading = false;
  String? _error;
  final Map<String, GroupGarden> _gardensByGroupId = {};
  final Map<String, String> _groupIdByName = {};

  static const String _kGuestGardensKey = 'daytrack_guest_gardens_v1';
  static const String _kCachedGardensKey = 'daytrack_cached_gardens_v1';

  GardenService({
    required this.apiService,
    required this.authService,
  });

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<GroupGarden> get gardens => _gardensByGroupId.values.toList();

  /// Gets the garden for a group by its name or ID
  GroupGarden? getGardenForGroup(String? groupNameOrId) {
    if (groupNameOrId == null || groupNameOrId.trim().isEmpty) return null;
    final trimmed = groupNameOrId.trim();

    // 1. Check direct groupId match
    if (_gardensByGroupId.containsKey(trimmed)) {
      return _gardensByGroupId[trimmed];
    }

    // 2. Check groupName mapping
    final mappedId = _groupIdByName[trimmed.toLowerCase()];
    if (mappedId != null && _gardensByGroupId.containsKey(mappedId)) {
      return _gardensByGroupId[mappedId];
    }

    // 3. Fallback search by group_name in garden list
    for (final garden in _gardensByGroupId.values) {
      if (garden.groupName.trim().toLowerCase() == trimmed.toLowerCase()) {
        return garden;
      }
    }

    return null;
  }

  /// Fetches gardens for all groups belonging to the user
  Future<void> fetchGardens() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (authService.isGuest) {
        await _loadGuestGardens();
      } else {
        await _loadRemoteGardens();
      }
    } catch (e) {
      debugPrint('Error fetching gardens: $e');
      _error = e.toString();
      // Load cached gardens on error
      await _loadCachedGardens();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads gardens from remote API
  Future<void> _loadRemoteGardens() async {
    try {
      final res = await apiService.getGardens();
      final rawList = res['gardens'] as List? ?? [];

      _gardensByGroupId.clear();
      _groupIdByName.clear();

      for (final raw in rawList) {
        if (raw is Map<String, dynamic>) {
          final garden = GroupGarden.fromJson(raw);
          _gardensByGroupId[garden.groupId] = garden;
          _groupIdByName[garden.groupName.trim().toLowerCase()] = garden.groupId;
        }
      }

      await _cacheGardensLocally();
    } catch (e) {
      debugPrint('Failed to load remote gardens: $e');
      rethrow;
    }
  }

  /// Loads gardens for guest mode from SharedPreferences
  Future<void> _loadGuestGardens() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kGuestGardensKey);

    _gardensByGroupId.clear();
    _groupIdByName.clear();

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as List;
        for (final item in decoded) {
          final garden = GroupGarden.fromJson(item as Map<String, dynamic>);
          _gardensByGroupId[garden.groupId] = garden;
          _groupIdByName[garden.groupName.trim().toLowerCase()] = garden.groupId;
        }
      } catch (e) {
        debugPrint('Failed to parse guest gardens: $e');
      }
    }

    // Ensure a default 'General' garden exists for guest mode if none
    if (_gardensByGroupId.isEmpty) {
      final defaultGarden = _createLocalGarden(groupId: 'guest_group_general', groupName: 'General');
      _gardensByGroupId[defaultGarden.groupId] = defaultGarden;
      _groupIdByName['general'] = defaultGarden.groupId;
      await _saveGuestGardens();
    }
  }

  /// Calculates or updates a group's garden in guest mode based on completed activities
  Future<void> updateGuestGardenProgress({
    required String groupName,
    required int completedCount,
    required int currentStreak,
    required int bestStreak,
  }) async {
    final trimmedName = (groupName.trim().isEmpty) ? 'General' : groupName.trim();
    final groupId = _groupIdByName[trimmedName.toLowerCase()] ??
        'guest_group_${trimmedName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    int bonus = 0;
    if (bestStreak >= 30) {
      bonus += 150;
    } else if (bestStreak >= 14) {
      bonus += 70;
    } else if (bestStreak >= 7) {
      bonus += 35;
    } else if (bestStreak >= 3) {
      bonus += 15;
    }

    final growthPoints = (completedCount * 10) + bonus;
    final levelInfo = _computeLevel(growthPoints);

    final plants = _computePlantsForLevel(levelInfo.level);
    final milestones = _computeMilestones(
      completedCount: completedCount,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      level: levelInfo.level,
    );

    final existing = _gardensByGroupId[groupId];
    final updated = GroupGarden(
      id: existing?.id ?? 'guest_garden_$groupId',
      groupId: groupId,
      userId: 'guest_user',
      groupName: trimmedName,
      growthPoints: growthPoints,
      level: levelInfo.level,
      levelName: levelInfo.name,
      levelProgressPercentage: levelInfo.progressPercentage,
      nextLevelPoints: levelInfo.nextLevelPoints,
      currentLevelBasePoints: levelInfo.currentLevelBasePoints,
      activitiesCompletedCount: completedCount,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      unlockedPlants: plants,
      milestones: milestones,
      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    _gardensByGroupId[groupId] = updated;
    _groupIdByName[trimmedName.toLowerCase()] = groupId;

    await _saveGuestGardens();
    notifyListeners();
  }

  /// Ensures a garden exists for an existing or newly created group
  Future<GroupGarden> ensureGardenForGroup(String groupName) async {
    final trimmed = (groupName.trim().isEmpty) ? 'General' : groupName.trim();
    final existing = getGardenForGroup(trimmed);
    if (existing != null) return existing;

    if (authService.isGuest) {
      final groupId = 'guest_group_${trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
      final newGarden = _createLocalGarden(groupId: groupId, groupName: trimmed);
      _gardensByGroupId[groupId] = newGarden;
      _groupIdByName[trimmed.toLowerCase()] = groupId;
      await _saveGuestGardens();
      notifyListeners();
      return newGarden;
    } else {
      try {
        final res = await apiService.createOrGetGroup(trimmed);
        final garden = GroupGarden.fromJson(res['garden'] as Map<String, dynamic>);
        _gardensByGroupId[garden.groupId] = garden;
        _groupIdByName[garden.groupName.trim().toLowerCase()] = garden.groupId;
        await _cacheGardensLocally();
        notifyListeners();
        return garden;
      } catch (e) {
        debugPrint('Error creating group garden on server: $e');
        final fallbackId = 'local_group_${trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
        final fallback = _createLocalGarden(groupId: fallbackId, groupName: trimmed);
        _gardensByGroupId[fallbackId] = fallback;
        _groupIdByName[trimmed.toLowerCase()] = fallbackId;
        notifyListeners();
        return fallback;
      }
    }
  }

  /// Handles group renaming: preserves the group ID and attached garden
  Future<void> handleGroupRenamed(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (newTrimmed.isEmpty) return;

    final garden = getGardenForGroup(oldTrimmed);
    if (garden == null) return;

    final updated = GroupGarden(
      id: garden.id,
      groupId: garden.groupId, // ID stays identical!
      userId: garden.userId,
      groupName: newTrimmed,   // Name updated!
      growthPoints: garden.growthPoints,
      level: garden.level,
      levelName: garden.levelName,
      levelProgressPercentage: garden.levelProgressPercentage,
      nextLevelPoints: garden.nextLevelPoints,
      currentLevelBasePoints: garden.currentLevelBasePoints,
      activitiesCompletedCount: garden.activitiesCompletedCount,
      currentStreak: garden.currentStreak,
      bestStreak: garden.bestStreak,
      unlockedPlants: garden.unlockedPlants,
      milestones: garden.milestones,
      createdAt: garden.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );

    _gardensByGroupId[garden.groupId] = updated;
    _groupIdByName.remove(oldTrimmed.toLowerCase());
    _groupIdByName[newTrimmed.toLowerCase()] = garden.groupId;

    if (authService.isGuest) {
      await _saveGuestGardens();
    } else {
      await _cacheGardensLocally();
    }
    notifyListeners();
  }

  /// Handles group deletion: cleans up the garden attached to this group
  Future<void> handleGroupDeleted(String groupName) async {
    final trimmed = groupName.trim();
    final garden = getGardenForGroup(trimmed);
    if (garden == null) return;

    _gardensByGroupId.remove(garden.groupId);
    _groupIdByName.remove(trimmed.toLowerCase());

    if (authService.isGuest) {
      await _saveGuestGardens();
    } else {
      await _cacheGardensLocally();
    }
    notifyListeners();
  }

  GroupGarden _createLocalGarden({required String groupId, required String groupName}) {
    final levelInfo = _computeLevel(0);
    final plants = _computePlantsForLevel(1);
    final milestones = _computeMilestones(completedCount: 0, currentStreak: 0, bestStreak: 0, level: 1);

    return GroupGarden(
      id: 'garden_$groupId',
      groupId: groupId,
      userId: authService.currentUser?.id ?? 'guest_user',
      groupName: groupName,
      growthPoints: 0,
      level: 1,
      levelName: levelInfo.name,
      levelProgressPercentage: 0,
      nextLevelPoints: 50,
      currentLevelBasePoints: 0,
      activitiesCompletedCount: 0,
      currentStreak: 0,
      bestStreak: 0,
      unlockedPlants: plants,
      milestones: milestones,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> _saveGuestGardens() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _gardensByGroupId.values.map((g) => g.toJson()).toList();
    await prefs.setString(_kGuestGardensKey, jsonEncode(list));
  }

  Future<void> _cacheGardensLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _gardensByGroupId.values.map((g) => g.toJson()).toList();
    await prefs.setString(_kCachedGardensKey, jsonEncode(list));
  }

  Future<void> _loadCachedGardens() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kCachedGardensKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as List;
        _gardensByGroupId.clear();
        _groupIdByName.clear();
        for (final item in decoded) {
          final garden = GroupGarden.fromJson(item as Map<String, dynamic>);
          _gardensByGroupId[garden.groupId] = garden;
          _groupIdByName[garden.groupName.trim().toLowerCase()] = garden.groupId;
        }
      } catch (_) {}
    }
  }

  _LevelComputation _computeLevel(int points) {
    final List<Map<String, dynamic>> definitions = [
      {'level': 1, 'name': 'Sprout Haven', 'min': 0, 'max': 49},
      {'level': 2, 'name': 'Seedling Sanctuary', 'min': 50, 'max': 119},
      {'level': 3, 'name': 'Blooming Meadow', 'min': 120, 'max': 219},
      {'level': 4, 'name': 'Verdant Oasis', 'min': 220, 'max': 349},
      {'level': 5, 'name': 'Emerald Grove', 'min': 350, 'max': 499},
      {'level': 6, 'name': 'Flourishing Arboretum', 'min': 500, 'max': 699},
      {'level': 7, 'name': 'Enchanted Botanical', 'min': 700, 'max': 949},
      {'level': 8, 'name': 'Celestial Canopy', 'min': 950, 'max': 1249},
      {'level': 9, 'name': 'Evergreen Arcadia', 'min': 1250, 'max': 1599},
      {'level': 10, 'name': 'Mythic Garden of Mastery', 'min': 1600, 'max': 999999},
    ];

    Map<String, dynamic> current = definitions[0];
    for (final def in definitions) {
      if (points >= (def['min'] as int)) {
        current = def;
      } else {
        break;
      }
    }

    final curLevel = current['level'] as int;
    final nextDef = definitions.firstWhere((d) => (d['level'] as int) == curLevel + 1, orElse: () => current);
    final nextMin = nextDef['min'] as int;
    final curMin = current['min'] as int;
    final range = nextMin - curMin;
    final progress = range > 0 ? (((points - curMin) / range) * 100).clamp(0, 100).round() : 100;

    return _LevelComputation(
      level: curLevel,
      name: current['name'] as String,
      progressPercentage: progress,
      nextLevelPoints: nextMin,
      currentLevelBasePoints: curMin,
    );
  }

  List<GardenPlant> _computePlantsForLevel(int gardenLevel) {
    const catalog = [
      {'id': 'plant_golden_sprout', 'name': 'Golden Sprout', 'emoji': '🌱', 'stage': 'sprout', 'rarity': 'common', 'level': 1, 'desc': 'The dawn of a new habit journey.'},
      {'id': 'plant_jade_herb', 'name': 'Jade Herb', 'emoji': '🌿', 'stage': 'seedling', 'rarity': 'common', 'level': 1, 'desc': 'Fresh leaves that thrive with steady daily consistency.'},
      {'id': 'plant_cherry_blossom', 'name': 'Cherry Blossom', 'emoji': '🌸', 'stage': 'budding', 'rarity': 'common', 'level': 2, 'desc': 'Delicate petals celebrating disciplined focus.'},
      {'id': 'plant_zen_bonsai', 'name': 'Zen Bonsai', 'emoji': '🪴', 'stage': 'sprout', 'rarity': 'rare', 'level': 2, 'desc': 'Cultivated with patience and mindful daily repetition.'},
      {'id': 'plant_sunburst_bloom', 'name': 'Sunburst Bloom', 'emoji': '🌻', 'stage': 'blooming', 'rarity': 'rare', 'level': 3, 'desc': 'Radiates warm golden light from sustained momentum.'},
      {'id': 'plant_whispering_bamboo', 'name': 'Whispering Bamboo', 'emoji': '🌾', 'stage': 'sprout', 'rarity': 'rare', 'level': 3, 'desc': 'Flexible yet unbreakable daily routine strength.'},
      {'id': 'plant_lotus_serenity', 'name': 'Lotus of Serenity', 'emoji': '🌺', 'stage': 'blooming', 'rarity': 'rare', 'level': 4, 'desc': 'Emerges pure and calm from focused perseverance.'},
      {'id': 'plant_desert_resilience', 'name': 'Resilience Cactus', 'emoji': '🌵', 'stage': 'budding', 'rarity': 'epic', 'level': 4, 'desc': 'Thrives anywhere through enduring, quiet discipline.'},
      {'id': 'plant_royal_orchid', 'name': 'Royal Orchid', 'emoji': '🌷', 'stage': 'blooming', 'rarity': 'epic', 'level': 5, 'desc': 'Exquisite and vibrant, awarded to master cultivators.'},
      {'id': 'plant_bodhi_tree', 'name': 'Ancient Bodhi Tree', 'emoji': '🌳', 'stage': 'mastery', 'rarity': 'epic', 'level': 5, 'desc': 'Deeply rooted wisdom gained from daily practice.'},
      {'id': 'plant_evergreen_pine', 'name': 'Evergreen Pine', 'emoji': '🌲', 'stage': 'mastery', 'rarity': 'epic', 'level': 6, 'desc': 'Stands tall and unwavering throughout every season.'},
      {'id': 'plant_dew_fountain', 'name': 'Crystal Dew Fountain', 'emoji': '⛲', 'stage': 'mastery', 'rarity': 'epic', 'level': 6, 'desc': 'A serene sanctuary celebrating sustained dedication.'},
      {'id': 'plant_stone_lantern', 'name': 'Luminous Stone Lantern', 'emoji': '🏮', 'stage': 'mastery', 'rarity': 'epic', 'level': 7, 'desc': 'Illuminates your growth path with peaceful radiance.'},
      {'id': 'plant_sunlit_palm', 'name': 'Sunlit Oasis Palm', 'emoji': '🌴', 'stage': 'blooming', 'rarity': 'legendary', 'level': 7, 'desc': 'A tropical beacon of enduring personal achievement.'},
      {'id': 'plant_autumn_maple', 'name': 'Scarlet Autumn Maple', 'emoji': '🍁', 'stage': 'blooming', 'rarity': 'legendary', 'level': 8, 'desc': 'Rich scarlet foliage marking exceptional habit mastery.'},
      {'id': 'plant_butterfly_haven', 'name': 'Butterfly Sanctuary', 'emoji': '🦋', 'stage': 'mastery', 'rarity': 'legendary', 'level': 8, 'desc': 'Fluttering companions drawn to a flourishing ecosystem.'},
      {'id': 'plant_celestial_tree', 'name': 'Prismatic Celestial Tree', 'emoji': '🌈', 'stage': 'mastery', 'rarity': 'legendary', 'level': 9, 'desc': 'A mythical beacon woven from unbreakable daily habits.'},
      {'id': 'plant_star_blossom', 'name': 'Star of Mastery', 'emoji': '🌟', 'stage': 'mastery', 'rarity': 'legendary', 'level': 10, 'desc': 'The crowning testament to personal transformation.'},
    ];

    return catalog.map((raw) {
      final reqLevel = raw['level'] as int;
      return GardenPlant(
        id: raw['id'] as String,
        name: raw['name'] as String,
        emoji: raw['emoji'] as String,
        stage: raw['stage'] as String,
        rarity: raw['rarity'] as String,
        levelRequired: reqLevel,
        description: raw['desc'] as String,
        unlocked: gardenLevel >= reqLevel,
      );
    }).toList();
  }

  List<GardenMilestone> _computeMilestones({
    required int completedCount,
    required int currentStreak,
    required int bestStreak,
    required int level,
  }) {
    return [
      GardenMilestone(
        id: 'ms_first_sprout',
        title: 'First Sprout',
        description: 'Completed the first activity in this group',
        badge: '🌱',
        achieved: completedCount >= 1,
      ),
      GardenMilestone(
        id: 'ms_active_cultivator',
        title: 'Active Cultivator',
        description: 'Completed 5 activities in this group',
        badge: '🌿',
        achieved: completedCount >= 5,
      ),
      GardenMilestone(
        id: 'ms_streak_3',
        title: 'Streak of Life',
        description: 'Maintained a 3-day activity streak in this group',
        badge: '🔥',
        achieved: currentStreak >= 3 || bestStreak >= 3,
      ),
      GardenMilestone(
        id: 'ms_garden_bloom',
        title: 'Blooming Meadow',
        description: 'Reached Garden Level 3 in this group',
        badge: '🌸',
        achieved: level >= 3,
      ),
      GardenMilestone(
        id: 'ms_streak_7',
        title: 'Unstoppable Flow',
        description: 'Maintained a 7-day activity streak in this group',
        badge: '⚡',
        achieved: currentStreak >= 7 || bestStreak >= 7,
      ),
      GardenMilestone(
        id: 'ms_emerald_grove',
        title: 'Grove Guardian',
        description: 'Reached Garden Level 5 in this group',
        badge: '🌳',
        achieved: level >= 5,
      ),
      GardenMilestone(
        id: 'ms_quarter_century',
        title: 'Master Botanist',
        description: 'Completed 25 activities in this group',
        badge: '🏆',
        achieved: completedCount >= 25,
      ),
      GardenMilestone(
        id: 'ms_mythic_mastery',
        title: 'Mythic Garden',
        description: 'Achieved Garden Level 10 in this group',
        badge: '👑',
        achieved: level >= 10,
      ),
    ];
  }
}

class _LevelComputation {
  final int level;
  final String name;
  final int progressPercentage;
  final int nextLevelPoints;
  final int currentLevelBasePoints;

  _LevelComputation({
    required this.level,
    required this.name,
    required this.progressPercentage,
    required this.nextLevelPoints,
    required this.currentLevelBasePoints,
  });
}
