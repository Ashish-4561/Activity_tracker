import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_tracker/models/garden.dart';
import 'package:activity_tracker/services/api_service.dart';
import 'package:activity_tracker/services/auth_service.dart';
import 'package:activity_tracker/services/garden_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Garden Models Unit Tests', () {
    test('GroupGarden.fromJson & toJson serialization', () {
      final json = {
        'id': 'garden-abc',
        'group_id': 'grp-123',
        'user_id': 'user-456',
        'group_name': 'Physical Health',
        'growth_points': 140,
        'level': 3,
        'level_name': 'Blooming Meadow',
        'level_progress_percentage': 20,
        'next_level_points': 220,
        'current_level_base_points': 120,
        'activities_completed_count': 14,
        'current_streak': 5,
        'best_streak': 7,
        'unlocked_plants': [
          {
            'id': 'sprout_clover',
            'name': 'Lucky Sprout',
            'emoji': '🌱',
            'stage': 'seedling',
            'rarity': 'common',
            'levelRequired': 1,
            'description': 'A fresh green clover sprout.',
            'unlocked': true,
          }
        ],
        'milestones': [
          {
            'id': 'first_sprout',
            'title': 'First Sprout',
            'description': 'Completed first activity',
            'badge': '🌱',
            'achieved': true,
          }
        ],
        'created_at': '2026-10-15T00:00:00Z',
        'updated_at': '2026-10-15T00:00:00Z',
      };

      final garden = GroupGarden.fromJson(json);

      expect(garden.id, 'garden-abc');
      expect(garden.groupId, 'grp-123');
      expect(garden.groupName, 'Physical Health');
      expect(garden.level, 3);
      expect(garden.levelName, 'Blooming Meadow');
      expect(garden.growthPoints, 140);
      expect(garden.unlockedPlants.length, 1);
      expect(garden.milestones.length, 1);
      expect(garden.levelProgressPercentage, 20);

      final exported = garden.toJson();
      expect(exported['group_id'], 'grp-123');
      expect(exported['level'], 3);
      expect(exported['growth_points'], 140);
    });
  });

  group('GardenService Independent Group Progression Tests', () {
    late ApiService apiService;
    late AuthService authService;
    late GardenService gardenService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'guest_mode_enabled': true,
      });
      apiService = ApiService();
      authService = AuthService(apiService);
      gardenService = GardenService(
        apiService: apiService,
        authService: authService,
      );
    });

    test('Two separate groups maintain distinct levels, growth points, and plants', () async {
      // Group A: Fitness (15 completions, 7 day streak)
      await gardenService.updateGuestGardenProgress(
        groupName: 'Fitness',
        completedCount: 15,
        currentStreak: 7,
        bestStreak: 7,
      );
      final gardenFitness = gardenService.getGardenForGroup('Fitness');
      expect(gardenFitness, isNotNull);

      // Group B: Reading (2 completions, 1 day streak)
      await gardenService.updateGuestGardenProgress(
        groupName: 'Reading',
        completedCount: 2,
        currentStreak: 1,
        bestStreak: 1,
      );
      final gardenReading = gardenService.getGardenForGroup('Reading');
      expect(gardenReading, isNotNull);

      // Verify Fitness stats: 15 * 10 = 150 + 35 (streak bonus) = 185 GP -> Level 3
      expect(gardenFitness!.growthPoints, 185);
      expect(gardenFitness.level, 3);
      expect(gardenFitness.levelName, 'Blooming Meadow');
      expect(gardenFitness.unlockedPlants.where((p) => p.unlocked).length, greaterThanOrEqualTo(5));

      // Verify Reading stats: 2 * 10 = 20 GP -> Level 1
      expect(gardenReading!.growthPoints, 20);
      expect(gardenReading.level, 1);
      expect(gardenReading.levelName, 'Sprout Haven');
      expect(gardenReading.unlockedPlants.where((p) => p.unlocked).length, 2);

      // Group A must never alter Group B
      expect(gardenFitness.growthPoints, isNot(equals(gardenReading.growthPoints)));
      expect(gardenFitness.level, isNot(equals(gardenReading.level)));
      expect(gardenFitness.groupId, isNot(equals(gardenReading.groupId)));
    });

    test('Renaming a group preserves the same group ID and garden state', () async {
      await gardenService.updateGuestGardenProgress(
        groupName: 'Work Projects',
        completedCount: 10,
        currentStreak: 3,
        bestStreak: 3,
      );

      final initialGarden = gardenService.getGardenForGroup('Work Projects');
      expect(initialGarden, isNotNull);
      final originalGroupId = initialGarden!.groupId;
      final originalPoints = initialGarden.growthPoints;

      // Rename from "Work Projects" to "Career Mastery"
      await gardenService.handleGroupRenamed('Work Projects', 'Career Mastery');

      final renamedGarden = gardenService.getGardenForGroup('Career Mastery');
      expect(renamedGarden, isNotNull);
      expect(renamedGarden!.groupId, originalGroupId);
      expect(renamedGarden.growthPoints, originalPoints);
      expect(renamedGarden.groupName, 'Career Mastery');
    });

    test('Deleting a group safely cleans up that group garden', () async {
      await gardenService.updateGuestGardenProgress(
        groupName: 'Temporary Group',
        completedCount: 5,
        currentStreak: 1,
        bestStreak: 1,
      );

      expect(gardenService.getGardenForGroup('Temporary Group'), isNotNull);

      await gardenService.handleGroupDeleted('Temporary Group');

      expect(gardenService.getGardenForGroup('Temporary Group'), isNull);
    });
  });
}
