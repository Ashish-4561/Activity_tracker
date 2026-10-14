import 'package:flutter_test/flutter_test.dart';
import 'package:activity_tracker/services/activity_service.dart';
import 'package:activity_tracker/services/auth_service.dart';

void main() {
  group('Activity Model Unit Tests', () {
    test('Activity.fromJson parses standard daily activity correctly', () {
      final json = {
        'id': 'act-123',
        'user_id': 'user-456',
        'name': 'Drink 3L Water',
        'group_name': 'Health & Fitness',
        'icon': '💧',
        'frequency': 'daily',
        'start_date': '2026-10-01',
        'frequency_value': 1,
        'frequency_unit': 'days',
        'duration_value': 12,
        'duration_unit': 'months',
        'is_active': 1,
        'color': '#4CAF50',
        'description': 'Daily hydration target',
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
        'completed': 1,
      };

      final activity = Activity.fromJson(json);

      expect(activity.id, 'act-123');
      expect(activity.userId, 'user-456');
      expect(activity.name, 'Drink 3L Water');
      expect(activity.groupName, 'Health & Fitness');
      expect(activity.icon, '💧');
      expect(activity.frequency, 'daily');
      expect(activity.isActive, true);
      expect(activity.frequencyValue, 1);
      expect(activity.durationValue, 12);
      expect(activity.isCompleted, true);
    });

    test('Activity.toJson produces matching serialized map', () {
      final activity = Activity(
        id: 'act-999',
        userId: 'user-000',
        name: 'Morning Jog',
        groupName: 'Fitness',
        icon: '🏃',
        frequency: 'daily',
        startDate: '2026-10-14',
        frequencyValue: 1,
        frequencyUnit: 'days',
        durationValue: 6,
        durationUnit: 'months',
        isActive: true,
        color: '#FF9800',
        description: '30 min jog',
        createdAt: '2026-10-14T06:00:00Z',
        updatedAt: '2026-10-14T06:00:00Z',
        isCompleted: false,
      );

      final map = activity.toJson();

      expect(map['id'], 'act-999');
      expect(map['name'], 'Morning Jog');
      expect(map['group_name'], 'Fitness');
      expect(map['icon'], '🏃');
      expect(map['is_active'], true);
      expect(map['completed'], false);
    });
  });

  group('DailyProgress Model Unit Tests', () {
    test('DailyProgress.fromJson parses daily progress correctly', () {
      final json = {
        'date': '2026-10-14',
        'completed': 3,
        'total': 5,
        'percentage': 60,
      };

      final progress = DailyProgress.fromJson(json);

      expect(progress.date, '2026-10-14');
      expect(progress.completed, 3);
      expect(progress.total, 5);
      expect(progress.percentage, 60);
    });
  });

  group('User Model Unit Tests', () {
    test('User.fromJson parses user correctly', () {
      final json = {
        'id': 'user-123',
        'name': 'Ashish Goud',
        'email': 'ashishgoud281@gmail.com',
        'theme': 'dark',
        'ai_enabled': true,
        'auth_provider': 'google',
      };

      final user = User.fromJson(json);

      expect(user.id, 'user-123');
      expect(user.name, 'Ashish Goud');
      expect(user.email, 'ashishgoud281@gmail.com');
      expect(user.theme, 'dark');
      expect(user.aiEnabled, true);
    });
  });
}
