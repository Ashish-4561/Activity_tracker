import 'notification_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

class Activity {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final String frequency;
  final String startDate;
  final int frequencyValue;
  final String frequencyUnit;
  final int durationValue;
  final String durationUnit;
  String groupName;
  final bool isActive;
  final String? color;
  final String? description;
  final String createdAt;
  final String updatedAt;
  bool isCompleted;

  // Scheduling, Duration, and Reminders
  final String activityType; // 'scheduled', 'duration', 'flexible'
  final String? startTime; // "09:00"
  final String? endTime; // "10:30"
  final List<int> repeatDays; // e.g. [1, 2, 3, 4, 5] (1=Mon ... 7=Sun)
  final int? targetDurationMinutes; // e.g. 300 for 5 hours
  final bool remindersEnabled;
  final int reminderMinutesBefore;
  final bool reminderAtEnd;
  int trackedDurationSeconds;
  List<Map<String, dynamic>> sessions;

  Activity({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    required this.frequency,
    required this.startDate,
    required this.frequencyValue,
    required this.frequencyUnit,
    required this.durationValue,
    required this.durationUnit,
    required this.groupName,
    required this.isActive,
    this.color,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.isCompleted = false,
    this.activityType = 'flexible',
    this.startTime,
    this.endTime,
    this.repeatDays = const [],
    this.targetDurationMinutes,
    this.remindersEnabled = false,
    this.reminderMinutesBefore = 10,
    this.reminderAtEnd = false,
    this.trackedDurationSeconds = 0,
    this.sessions = const [],
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return defaultValue;
    }

    List<int> parseRepeatDays(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
      if (val is String && val.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
        } catch (_) {
          return val.split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList();
        }
      }
      return [];
    }

    List<Map<String, dynamic>> parseSessions(dynamic val) {
      if (val == null) return [];
      if (val is List) {
        return val.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (val is String && val.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    return Activity(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString(),
      frequency: json['frequency']?.toString() ?? 'daily',
      startDate: json['start_date']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
      frequencyValue: json['frequency_value'] is int ? json['frequency_value'] : int.tryParse(json['frequency_value']?.toString() ?? '1') ?? 1,
      frequencyUnit: json['frequency_unit']?.toString() ?? ((json['frequency'] ?? 'daily') == 'weekly' ? 'weeks' : 'days'),
      durationValue: json['duration_value'] is int ? json['duration_value'] : int.tryParse(json['duration_value']?.toString() ?? '12') ?? 12,
      durationUnit: json['duration_unit']?.toString() ?? 'months',
      groupName: json['group_name']?.toString() ?? 'General',
      isActive: parseBool(json['is_active'], true),
      color: json['color']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      isCompleted: parseBool(json['completed'], false),
      activityType: json['activity_type']?.toString() ?? 'flexible',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      repeatDays: parseRepeatDays(json['repeat_days']),
      targetDurationMinutes: json['target_duration_minutes'] != null ? int.tryParse(json['target_duration_minutes'].toString()) : null,
      remindersEnabled: parseBool(json['reminders_enabled'], false),
      reminderMinutesBefore: int.tryParse(json['reminder_minutes_before']?.toString() ?? '10') ?? 10,
      reminderAtEnd: parseBool(json['reminder_at_end'], false),
      trackedDurationSeconds: int.tryParse((json['tracked_duration_seconds'] ?? json['duration_seconds'])?.toString() ?? '0') ?? 0,
      sessions: parseSessions(json['sessions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'icon': icon,
      'frequency': frequency,
      'start_date': startDate,
      'frequency_value': frequencyValue,
      'frequency_unit': frequencyUnit,
      'duration_value': durationValue,
      'duration_unit': durationUnit,
      'group_name': groupName,
      'is_active': isActive,
      'color': color,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'completed': isCompleted,
      'activity_type': activityType,
      'start_time': startTime,
      'end_time': endTime,
      'repeat_days': repeatDays,
      'target_duration_minutes': targetDurationMinutes,
      'reminders_enabled': remindersEnabled,
      'reminder_minutes_before': reminderMinutesBefore,
      'reminder_at_end': reminderAtEnd,
      'duration_seconds': trackedDurationSeconds,
      'tracked_duration_seconds': trackedDurationSeconds,
      'sessions': sessions,
    };
  }
}

class DailyProgress {
  final String date;
  final int completed;
  final int total;
  final int percentage;

  DailyProgress({
    required this.date,
    required this.completed,
    required this.total,
    required this.percentage,
  });

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    return DailyProgress(
      date: json['date']?.toString() ?? '',
      completed: json['completed'] is int ? json['completed'] : int.tryParse(json['completed']?.toString() ?? '0') ?? 0,
      total: json['total'] is int ? json['total'] : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      percentage: json['percentage'] is int ? json['percentage'] : int.tryParse(json['percentage']?.toString() ?? '0') ?? 0,
    );
  }
}

class ActivityService extends ChangeNotifier {
  final ApiService apiService;
  final AuthService authService;
  final bool previewMode;
  NotificationService? notificationService;

  void setNotificationService(NotificationService ns) {
    notificationService = ns;
  }

  List<Activity> _activities = [];
  DailyProgress? _dailyProgress;
  bool _isLoading = false;
  String? _error;

  /// Per-activity progress percentage (0–100)
  Map<String, int> _activityProgress = {};

  /// Per-group progress percentage (0–100) derived from individual activities.
  Map<String, int> _groupProgress = {};

  /// Per-activity streaks
  Map<String, int> _activityStreaks = {};
  Map<String, int> _activityBestStreaks = {};

  /// Per-group streaks & weekly progress
  final Map<String, int> _groupStreaks = {};
  final Map<String, int> _groupBestStreaks = {};
  final Map<String, int> _groupWeeklyProgress = {};

  static const String _kGuestActivitiesKey = 'guest_local_activities_v1';
  static const String _kGuestCompletionsKey = 'guest_local_completions_v2';
  static const String _kGuestInitializedKey = 'guest_local_initialized_v1';

  bool _isFetchingActivities = false;
  Map<String, bool> _guestCompletions = {};
  String _currentDate = DateTime.now().toIso8601String().split('T').first;
  Timer? _dayCheckTimer;

  int _overallCurrentStreak = 0;
  int _overallBestStreak = 0;
  int _overallWeeklyProgress = 0;

  ActivityService(this.apiService, this.authService, {this.previewMode = false}) {
    _currentDate = _todayDateString();
    authService.addListener(_onAuthChanged);
    if (authService.isLoggedIn) {
      fetchActivities();
    } else {
      _loadGuestActivitiesFromStorage();
    }
    // Check every 30 seconds if calendar day rolled over
    _dayCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkDayRollover();
    });
  }

  @override
  void dispose() {
    _dayCheckTimer?.cancel();
    authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  String _todayDateString() => DateTime.now().toIso8601String().split('T').first;

  String get currentDate => _currentDate;

  /// Checks if calendar date has changed and automatically resets tasks for the new day.
  bool checkDayRollover() {
    final today = _todayDateString();
    if (_currentDate != today) {
      _currentDate = today;
      refreshForNewDay();
      return true;
    }
    return false;
  }

  Future<void> refreshForNewDay() async {
    if (isGuest || previewMode) {
      _syncGuestActivitiesForDate(_currentDate);
      _rebuildPreviewProgress();
      notifyListeners();
    } else {
      await fetchActivities(date: _currentDate);
      await fetchDailyProgress(date: _currentDate);
    }
  }

  void _syncGuestActivitiesForDate(String date) {
    for (final act in _activities) {
      act.isCompleted = _guestCompletions['${act.id}:$date'] == true;
    }
  }

  Map<String, Set<String>> getGuestCompletionHistory() {
    final map = <String, Set<String>>{};
    for (final act in _activities) {
      map[act.id] = {};
    }
    for (final entry in _guestCompletions.entries) {
      if (entry.value == true) {
        final parts = entry.key.split(':');
        if (parts.length >= 2) {
          final actId = parts[0];
          final date = parts[1];
          map.putIfAbsent(actId, () => {}).add(date);
        }
      }
    }
    return map;
  }

  bool get isGuest => !authService.isLoggedIn;
  bool get hasGuestActivities => isGuest && _activities.isNotEmpty;

  /// Checks if there is any guest activity data stored locally in SharedPreferences
  Future<bool> hasStoredGuestActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kGuestActivitiesKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        return list.isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  void _onAuthChanged() {
    clearData();
    if (authService.isLoggedIn) {
      final userId = authService.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        _loadUserActivitiesFromStorage(userId);
      }
      fetchActivities();
    } else {
      // User logged out: clear memory and ensure guest mode has no lingering user tasks
      _activities = [];
      _guestCompletions.clear();
      _dailyProgress = null;
      notifyListeners();
    }
  }

  Future<void> migrateGuestDataToCloud() async {
    if (!authService.isLoggedIn) return;
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      List<Activity> guestActivitiesToMigrate = [];
      final raw = prefs.getString(_kGuestActivitiesKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        guestActivitiesToMigrate = list
            .map((item) => Activity.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      if (guestActivitiesToMigrate.isEmpty && _activities.isNotEmpty) {
        guestActivitiesToMigrate = List<Activity>.from(_activities);
      }

      for (final act in guestActivitiesToMigrate) {
        final res = await apiService.createActivity(
          name: act.name,
          frequency: act.frequency,
          groupName: act.groupName,
          icon: act.icon,
          startDate: act.startDate,
          frequencyValue: act.frequencyValue,
          frequencyUnit: act.frequencyUnit,
          durationValue: act.durationValue,
          durationUnit: act.durationUnit,
          color: act.color,
          description: act.description,
        );
        final createdId = res['activity']?['id']?.toString();
        if (act.isCompleted && createdId != null) {
          await apiService.completeActivity(activityId: createdId);
        }
      }
      await clearGuestData();
      await fetchActivities();
      await fetchDailyProgress();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _activities = [];
    _dailyProgress = null;
    _activityProgress.clear();
    _groupProgress.clear();
    _activityStreaks.clear();
    _activityBestStreaks.clear();
    _groupStreaks.clear();
    _groupBestStreaks.clear();
    _groupWeeklyProgress.clear();
    _overallCurrentStreak = 0;
    _overallBestStreak = 0;
    _overallWeeklyProgress = 0;
    notifyListeners();
  }

  List<Activity> get activities => _activities;
  DailyProgress? get dailyProgress => _dailyProgress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int activityProgress(String activityId) {
    final act = _activities.firstWhere((a) => a.id == activityId, orElse: () => Activity(
      id: '', userId: '', name: '', frequency: '', startDate: '', frequencyValue: 1, frequencyUnit: '', durationValue: 1, durationUnit: '', groupName: '', isActive: true, createdAt: '', updatedAt: '',
    ));
    if (act.id.isNotEmpty) {
      if (act.isCompleted) return 100;
      if (act.activityType == 'duration' && act.targetDurationMinutes != null && act.targetDurationMinutes! > 0) {
        final targetSec = act.targetDurationMinutes! * 60;
        return ((act.trackedDurationSeconds / targetSec) * 100).clamp(0, 100).toInt();
      }
    }
    return _activityProgress[activityId] ?? 0;
  }
  int groupProgress(String groupName) => _groupProgress[groupName] ?? 0;

  int activityStreak(String activityId) {
    if (_activityStreaks.containsKey(activityId)) {
      return _activityStreaks[activityId]!;
    }
    final act = _activities.firstWhere((a) => a.id == activityId, orElse: () => Activity(
      id: '', userId: '', name: '', frequency: '', startDate: '', frequencyValue: 1, frequencyUnit: '', durationValue: 1, durationUnit: '', groupName: '', isActive: true, createdAt: '', updatedAt: '',
    ));
    return act.isCompleted ? 1 : 0;
  }

  int activityBestStreak(String activityId) => _activityBestStreaks[activityId] ?? activityStreak(activityId);

  int groupStreak(String groupName) {
    if (_groupStreaks.containsKey(groupName)) {
      return _groupStreaks[groupName]!;
    }
    final groupActs = _activities.where((a) => a.groupName == groupName).toList();
    if (groupActs.isEmpty) return 0;
    final allCompleted = groupActs.every((a) => a.isCompleted);
    return allCompleted ? 1 : 0;
  }

  int groupBestStreak(String groupName) => _groupBestStreaks[groupName] ?? groupStreak(groupName);

  int groupWeeklyProgress(String groupName) {
    if (_groupWeeklyProgress.containsKey(groupName)) {
      return _groupWeeklyProgress[groupName]!;
    }
    return groupProgress(groupName);
  }

  int get overallCurrentStreak => _overallCurrentStreak;
  int get overallBestStreak => _overallBestStreak;
  int get overallWeeklyProgress => _overallWeeklyProgress;

  Future<void> fetchActivities({String? date}) async {
    if (previewMode) return;
    if (isGuest) {
      await _loadGuestActivitiesFromStorage();
      return;
    }
    if (_isFetchingActivities) return;
    _isFetchingActivities = true;

    final currentUserId = authService.currentUser?.id;
    if (_activities.isEmpty && currentUserId != null && currentUserId.isNotEmpty) {
      await _loadUserActivitiesFromStorage(currentUserId);
    }
    if (_activities.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final targetDate = date ?? _todayDateString();
      _currentDate = targetDate;

      // Parallelize fetching activities and completions for maximum speed
      final results = await Future.wait([
        apiService.getActivities(date: targetDate),
        apiService.getCompletionsByDate(date: targetDate).catchError((_) => <String, dynamic>{}),
      ]);
      final response = results[0];
      final completionsRes = results[1];

      final completedMap = <String, bool>{};
      final completionsList = completionsRes['completions'] as List? ?? [];
      for (final c in completionsList) {
        if (c is Map && c['activity_id'] != null) {
          final isComp = c['completed'] == true || c['completed'] == 1;
          completedMap[c['activity_id'].toString()] = isComp;
        }
      }

      _activities = (response['activities'] as List?)
              ?.map((json) {
                final act = Activity.fromJson(json);
                final isLocallyCompleted = _guestCompletions['${act.id}:$targetDate'] == true;
                if (completedMap.containsKey(act.id)) {
                  act.isCompleted = completedMap[act.id] ?? isLocallyCompleted;
                  if (completedMap[act.id] == true) {
                    _guestCompletions['${act.id}:$targetDate'] = true;
                  }
                } else {
                  act.isCompleted = isLocallyCompleted;
                }
                return act;
              })
              .toList() ??
          [];
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await _saveUserActivitiesToStorage(currentUserId);
      }
      notificationService?.syncAllActivities(_activities);
      _isLoading = false;
      notifyListeners();

      // Parallelize streaks and daily progress
      await Future.wait([
        fetchActivityProgress().catchError((_) {}),
        fetchDailyProgress(date: targetDate).catchError((_) {}),
      ]);
    } catch (e) {
      if (currentUserId != null && currentUserId.isNotEmpty && _activities.isEmpty) {
        await _loadUserActivitiesFromStorage(currentUserId);
      }
      _isLoading = false;
      notifyListeners();
    } finally {
      _isFetchingActivities = false;
    }
  }

  Future<void> fetchDailyProgress({String? date}) async {
    if (previewMode) {
      _updatePreviewProgress();
      return;
    }
    try {
      final response = await apiService.getDailyProgress(date: date);
      _dailyProgress = DailyProgress.fromJson(response);
      notifyListeners();
    } catch (e) {
      final total = _activities.length;
      final completed = _activities.where((a) => a.isCompleted).length;
      final percentage = total > 0 ? ((completed / total) * 100).round() : 0;
      _dailyProgress = DailyProgress(
        date: date ?? _currentDate,
        completed: completed,
        total: total,
        percentage: percentage,
      );
      notifyListeners();
    }
  }

  /// Fetches history-based progress for rolling 30 days and calculates streaks.
  Future<void> fetchActivityProgress() async {
    if (previewMode) {
      _rebuildPreviewProgress();
      return;
    }
    try {
      final to = DateTime.now();
      final from = to.subtract(const Duration(days: 29));
      final fromStr = from.toIso8601String().split('T').first;
      final toStr = to.toIso8601String().split('T').first;

      final response = await apiService.getRangeProgress(from: fromStr, to: toStr);

      final activityList = response['activities'] as List? ?? [];
      final newActivityProgress = <String, int>{};
      final newActivityStreaks = <String, int>{};
      final newActivityBestStreaks = <String, int>{};

      for (final item in activityList) {
        final id = item['id'] as String? ?? '';
        final pct = item['percentage'] as int? ?? 0;
        if (id.isNotEmpty) {
          newActivityProgress[id] = pct;
          final history = (item['history'] as List? ?? []).map((e) => e == true).toList();
          int current = 0;
          for (int i = history.length - 1; i >= 0; i--) {
            if (history[i]) {
              current++;
            } else {
              break;
            }
          }
          int best = 0;
          int streak = 0;
          for (final completed in history) {
            if (completed) {
              streak++;
              if (streak > best) best = streak;
            } else {
              streak = 0;
            }
          }
          newActivityStreaks[id] = current;
          newActivityBestStreaks[id] = best;
        }
      }

      _activityProgress = newActivityProgress;
      _activityStreaks = newActivityStreaks;
      _activityBestStreaks = newActivityBestStreaks;

      _overallCurrentStreak = response['current_streak'] as int? ?? 0;
      _overallBestStreak = response['best_streak'] as int? ?? 0;
      _overallWeeklyProgress = response['average_daily_percentage'] as int? ?? 0;

      // Populate local completion cache with all historical records from server
      final completionsList = response['completion_history'] as List? ?? [];
      for (final c in completionsList) {
        if (c is Map && c['activity_id'] != null && c['date'] != null) {
          final actId = c['activity_id'].toString();
          final d = c['date'].toString().split('T').first;
          final isComp = c['completed'] == true || c['completed'] == 1;
          if (isComp) {
            _guestCompletions['$actId:$d'] = true;
          } else {
            _guestCompletions.remove('$actId:$d');
          }
        }
      }
      final currentUserId = authService.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        _saveUserActivitiesToStorage(currentUserId);
      }

      _rebuildGroupProgress();

      final dailyList = response['daily_progress'] as List? ?? [];
      if (dailyList.length >= 7) {
        final last7 = dailyList.sublist(dailyList.length - 7);
        final completed7 = last7.fold<int>(0, (acc, item) => acc + (item['completed'] as int? ?? 0));
        final total7 = last7.fold<int>(0, (acc, item) => acc + (item['total'] as int? ?? 0));
        if (total7 > 0) {
          _overallWeeklyProgress = ((completed7 / total7) * 100).round();
        }
      }

      notifyListeners();
    } catch (_) {
      _rebuildPreviewProgress();
    }
  }

  void _rebuildGroupProgress() {
    final groupTotals = <String, List<int>>{};
    for (final activity in _activities) {
      groupTotals.putIfAbsent(activity.groupName, () => []);
      // If completed today, treat today as contributing 100% or stored progress
      final pct = activity.isCompleted ? 100 : (_activityProgress[activity.id] ?? 0);
      groupTotals[activity.groupName]!.add(pct);
    }
    _groupProgress = groupTotals.map((name, percentages) {
      if (percentages.isEmpty) return MapEntry(name, 0);
      final avg = percentages.reduce((a, b) => a + b) ~/ percentages.length;
      return MapEntry(name, avg);
    });

    // Derive group streaks
    for (final groupName in groupTotals.keys) {
      final acts = _activities.where((a) => a.groupName == groupName).toList();
      if (acts.isEmpty) continue;
      final completedToday = acts.where((a) => a.isCompleted).length;
      final total = acts.length;
      final todayAll = completedToday == total;

      int maxActStreak = 0;
      int maxActBest = 0;
      for (final a in acts) {
        final s = activityStreak(a.id);
        if (s > maxActStreak) maxActStreak = s;
        final b = activityBestStreak(a.id);
        if (b > maxActBest) maxActBest = b;
      }

      _groupStreaks[groupName] = todayAll ? (maxActStreak > 0 ? maxActStreak : 1) : 0;
      _groupBestStreaks[groupName] = maxActBest > 0 ? maxActBest : (todayAll ? 1 : 0);
      _groupWeeklyProgress[groupName] = _groupProgress[groupName] ?? 0;
    }
  }

  void _rebuildPreviewProgress() {
    final today = _currentDate;
    DateTime todayDt;
    try {
      todayDt = DateTime.parse(today);
    } catch (_) {
      todayDt = DateTime.now();
    }

    final newActivityProgress = <String, int>{};
    for (final activity in _activities) {
      final isDoneToday = _guestCompletions['${activity.id}:$today'] == true;
      activity.isCompleted = isDoneToday;
      newActivityProgress[activity.id] = isDoneToday ? 100 : 0;

      // Calculate streak backwards from today
      int streak = isDoneToday ? 1 : 0;
      for (int i = 1; i <= 365; i++) {
        final pastDate = todayDt.subtract(Duration(days: i)).toIso8601String().split('T').first;
        if (_guestCompletions['${activity.id}:$pastDate'] == true) {
          streak++;
        } else {
          break;
        }
      }
      _activityStreaks[activity.id] = streak;
      _activityBestStreaks[activity.id] = (_activityBestStreaks[activity.id] ?? 0) < streak
          ? streak
          : (_activityBestStreaks[activity.id] ?? streak);
    }
    _activityProgress = newActivityProgress;
    _rebuildGroupProgress();
  }

  String _getUserActivitiesKey(String userId) => 'user_activities_$userId';
  String _getUserCompletionsKey(String userId) => 'user_completions_$userId';

  Future<void> _loadUserActivitiesFromStorage(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_getUserActivitiesKey(userId));
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        _activities = list
            .map((item) => Activity.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else {
        _activities = [];
      }

      final rawComp = prefs.getString(_getUserCompletionsKey(userId));
      if (rawComp != null && rawComp.isNotEmpty) {
        final Map<String, dynamic> compMap = jsonDecode(rawComp);
        _guestCompletions = compMap.map((k, v) => MapEntry(k, v == true));
      } else {
        _guestCompletions = {};
      }

      _currentDate = _todayDateString();
      _syncGuestActivitiesForDate(_currentDate);
    } catch (_) {
      _activities = [];
      _guestCompletions = {};
    }
    _rebuildPreviewProgress();
    _updatePreviewProgress();
    notifyListeners();
  }

  Future<void> _saveUserActivitiesToStorage(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_activities.map((a) => a.toJson()).toList());
      await prefs.setString(_getUserActivitiesKey(userId), raw);
      await prefs.setString(_getUserCompletionsKey(userId), jsonEncode(_guestCompletions));
    } catch (_) {}
  }

  Future<void> _loadGuestActivitiesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasInit = prefs.getBool(_kGuestInitializedKey) ?? false;
      if (!hasInit) {
        _activities = [];
        _guestCompletions = {};
        await prefs.setBool(_kGuestInitializedKey, true);
        await prefs.setString(_kGuestActivitiesKey, jsonEncode([]));
        await prefs.setString(_kGuestCompletionsKey, jsonEncode({}));
      } else {
        final raw = prefs.getString(_kGuestActivitiesKey);
        if (raw != null && raw.isNotEmpty) {
          final List<dynamic> list = jsonDecode(raw);
          _activities = list
              .map((item) => Activity.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        } else {
          _activities = [];
        }

        final rawComp = prefs.getString(_kGuestCompletionsKey);
        if (rawComp != null && rawComp.isNotEmpty) {
          final Map<String, dynamic> compMap = jsonDecode(rawComp);
          _guestCompletions = compMap.map((k, v) => MapEntry(k, v == true));
        } else {
          _guestCompletions = {};
        }

        // Apply completion status for TODAY's date.
        _currentDate = _todayDateString();
        _syncGuestActivitiesForDate(_currentDate);
      }
    } catch (_) {
      _activities = [];
      _guestCompletions = {};
    }
    _rebuildPreviewProgress();
    _updatePreviewProgress();
    notifyListeners();
  }

  Future<void> _saveGuestActivitiesToStorage() async {
    if (!isGuest && !previewMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_activities.map((a) => a.toJson()).toList());
      await prefs.setString(_kGuestActivitiesKey, raw);
      await prefs.setString(_kGuestCompletionsKey, jsonEncode(_guestCompletions));
      await prefs.setBool(_kGuestInitializedKey, true);
    } catch (_) {}
  }

  Future<void> clearGuestData() async {
    if (isGuest) {
      _activities = [];
      _guestCompletions.clear();
      clearData();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kGuestActivitiesKey, jsonEncode([]));
      await prefs.setString(_kGuestCompletionsKey, jsonEncode({}));
      await prefs.setBool(_kGuestInitializedKey, true);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> addActivity({
    required String name,
    required String frequency,
    String? groupName,
    String? icon,
    int frequencyValue = 1,
    String frequencyUnit = 'days',
    int durationValue = 12,
    String durationUnit = 'months',
    String? startDate,
    String? color,
    String? description,
    String activityType = 'flexible',
    String? startTime,
    String? endTime,
    List<int>? repeatDays,
    int? targetDurationMinutes,
    bool remindersEnabled = false,
    int reminderMinutesBefore = 10,
    bool reminderAtEnd = false,
  }) async {
    final targetGroup = (groupName == null || groupName.trim().isEmpty) ? 'General' : groupName.trim();
    final repDays = repeatDays ?? [];
    if (isGuest || previewMode) {
      final now = DateTime.now().toIso8601String();
      final newAct = Activity(
        id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
        userId: 'preview-user',
        name: name,
        frequency: frequency,
        startDate: startDate ?? DateTime.now().toIso8601String().split('T').first,
        frequencyValue: frequencyValue,
        frequencyUnit: frequencyUnit,
        durationValue: durationValue,
        durationUnit: durationUnit,
        groupName: targetGroup,
        icon: icon,
        color: color,
        description: description,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        activityType: activityType,
        startTime: startTime,
        endTime: endTime,
        repeatDays: repDays,
        targetDurationMinutes: targetDurationMinutes,
        remindersEnabled: remindersEnabled,
        reminderMinutesBefore: reminderMinutesBefore,
        reminderAtEnd: reminderAtEnd,
      );
      _activities.add(newAct);
      _updatePreviewProgress();
      _rebuildPreviewProgress();
      await _saveGuestActivitiesToStorage();
      notificationService?.scheduleActivityReminders(newAct);
      notifyListeners();
      return;
    }
    final currentUserId = authService.currentUser?.id;
    try {
      final res = await apiService.createActivity(
        name: name,
        frequency: frequency,
        groupName: targetGroup,
        icon: icon,
        frequencyValue: frequencyValue,
        frequencyUnit: frequencyUnit,
        durationValue: durationValue,
        durationUnit: durationUnit,
        startDate: startDate,
        color: color,
        description: description,
        activityType: activityType,
        startTime: startTime,
        endTime: endTime,
        repeatDays: repDays,
        targetDurationMinutes: targetDurationMinutes,
        remindersEnabled: remindersEnabled,
        reminderMinutesBefore: reminderMinutesBefore,
        reminderAtEnd: reminderAtEnd,
      );
      await fetchActivities();
      await fetchDailyProgress();
      if (res['activity'] != null && res['activity']['id'] != null) {
        final created = _activities.firstWhere((a) => a.id == res['activity']['id'], orElse: () => _activities.last);
        notificationService?.scheduleActivityReminders(created);
      }
    } catch (e) {
      // Fallback: save to user local storage if logged in, or guest storage if guest
      final now = DateTime.now().toIso8601String();
      final newAct = Activity(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        userId: currentUserId ?? 'local-user',
        name: name,
        frequency: frequency,
        startDate: startDate ?? DateTime.now().toIso8601String().split('T').first,
        frequencyValue: frequencyValue,
        frequencyUnit: frequencyUnit,
        durationValue: durationValue,
        durationUnit: durationUnit,
        groupName: targetGroup,
        icon: icon,
        color: color,
        description: description,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        activityType: activityType,
        startTime: startTime,
        endTime: endTime,
        repeatDays: repDays,
        targetDurationMinutes: targetDurationMinutes,
        remindersEnabled: remindersEnabled,
        reminderMinutesBefore: reminderMinutesBefore,
        reminderAtEnd: reminderAtEnd,
      );
      _activities.add(newAct);
      _updatePreviewProgress();
      _rebuildPreviewProgress();
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await _saveUserActivitiesToStorage(currentUserId);
      } else {
        await _saveGuestActivitiesToStorage();
      }
      notificationService?.scheduleActivityReminders(newAct);
      notifyListeners();
    }
  }

  Future<void> updateActivity({
    required String id,
    String? name,
    String? frequency,
    String? groupName,
    String? icon,
    String? color,
    int? frequencyValue,
    String? frequencyUnit,
    int? durationValue,
    String? durationUnit,
    String? startDate,
    String? activityType,
    String? startTime,
    String? endTime,
    List<int>? repeatDays,
    int? targetDurationMinutes,
    bool? remindersEnabled,
    int? reminderMinutesBefore,
    bool? reminderAtEnd,
  }) async {
    final index = _activities.indexWhere((a) => a.id == id);
    if (index != -1) {
      final current = _activities[index];
      final updatedAct = Activity(
        id: current.id,
        userId: current.userId,
        name: name ?? current.name,
        frequency: frequency ?? current.frequency,
        groupName: groupName ?? current.groupName,
        icon: icon ?? current.icon,
        color: color ?? current.color,
        frequencyValue: frequencyValue ?? current.frequencyValue,
        frequencyUnit: frequencyUnit ?? current.frequencyUnit,
        durationValue: durationValue ?? current.durationValue,
        durationUnit: durationUnit ?? current.durationUnit,
        startDate: startDate ?? current.startDate,
        isActive: current.isActive,
        description: current.description,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
        isCompleted: current.isCompleted,
        activityType: activityType ?? current.activityType,
        startTime: startTime ?? current.startTime,
        endTime: endTime ?? current.endTime,
        repeatDays: repeatDays ?? current.repeatDays,
        targetDurationMinutes: targetDurationMinutes ?? current.targetDurationMinutes,
        remindersEnabled: remindersEnabled ?? current.remindersEnabled,
        reminderMinutesBefore: reminderMinutesBefore ?? current.reminderMinutesBefore,
        reminderAtEnd: reminderAtEnd ?? current.reminderAtEnd,
        trackedDurationSeconds: current.trackedDurationSeconds,
        sessions: current.sessions,
      );
      _activities[index] = updatedAct;
      notificationService?.scheduleActivityReminders(updatedAct);
    }

    if (isGuest || previewMode) {
      _rebuildPreviewProgress();
      await _saveGuestActivitiesToStorage();
      notifyListeners();
      return;
    }

    try {
      await apiService.updateActivity(
        id: id,
        name: name,
        frequency: frequency,
        groupName: groupName,
        icon: icon,
        color: color,
        frequencyValue: frequencyValue,
        frequencyUnit: frequencyUnit,
        durationValue: durationValue,
        durationUnit: durationUnit,
        startDate: startDate,
        activityType: activityType,
        startTime: startTime,
        endTime: endTime,
        repeatDays: repeatDays,
        targetDurationMinutes: targetDurationMinutes,
        remindersEnabled: remindersEnabled,
        reminderMinutesBefore: reminderMinutesBefore,
        reminderAtEnd: reminderAtEnd,
      );
      await fetchActivities();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Logs an accumulated time session for an activity.
  Future<void> logDurationSession({
    required String activityId,
    required int durationSeconds,
    String? date,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final targetDate = date ?? _currentDate;
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index == -1) return;

    final act = _activities[index];
    final nowIso = DateTime.now().toIso8601String();
    final newSession = {
      'start': startTime?.toIso8601String() ?? nowIso,
      'end': endTime?.toIso8601String() ?? nowIso,
      'duration_seconds': durationSeconds,
    };

    act.trackedDurationSeconds += durationSeconds;
    act.sessions = List.from(act.sessions)..add(newSession);

    // If target duration met, automatically complete the activity
    bool justCompleted = false;
    if (act.activityType == 'duration' && act.targetDurationMinutes != null) {
      final targetSeconds = act.targetDurationMinutes! * 60;
      if (act.trackedDurationSeconds >= targetSeconds) {
        if (!act.isCompleted) {
          act.isCompleted = true;
          justCompleted = true;
          _guestCompletions['$activityId:$targetDate'] = true;
          notificationService?.cancelActivityNotifications(activityId);
        }
      }
    }

    if (isGuest || previewMode) {
      _rebuildPreviewProgress();
      _updatePreviewProgress();
      await _saveGuestActivitiesToStorage();
      notifyListeners();
      return;
    }

    final currentUserId = authService.currentUser?.id;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      await _saveUserActivitiesToStorage(currentUserId);
    }
    notifyListeners();

    try {
      final res = await apiService.trackActivityDuration(
        activityId: activityId,
        sessionDurationSeconds: durationSeconds,
        date: targetDate,
        startTimestamp: startTime?.toIso8601String(),
        endTimestamp: endTime?.toIso8601String(),
      );
      if (res['total_duration_seconds'] != null) {
        act.trackedDurationSeconds = res['total_duration_seconds'] as int;
      }
      if (res['completed'] == true) {
        act.isCompleted = true;
        _guestCompletions['$activityId:$targetDate'] = true;
      }
      if (justCompleted) {
        await fetchDailyProgress(date: targetDate);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Sync duration to backend note: $e');
    }
  }

  Future<void> deleteActivity(String id) async {
    notificationService?.cancelActivityNotifications(id);
    if (isGuest || previewMode) {
      _activities.removeWhere((activity) => activity.id == id);
      _activityProgress.remove(id);
      _activityStreaks.remove(id);
      _activityBestStreaks.remove(id);
      _updatePreviewProgress();
      _rebuildPreviewProgress();
      await _saveGuestActivitiesToStorage();
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await apiService.deleteActivity(id);
      _activityProgress.remove(id);
      _activityStreaks.remove(id);
      _activityBestStreaks.remove(id);
      await fetchActivities();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteGroup(String groupName) async {
    if (isGuest || previewMode) {
      final removedIds = _activities
          .where((a) => a.groupName == groupName)
          .map((a) => a.id)
          .toList();
      _activities.removeWhere((activity) => activity.groupName == groupName);
      for (final id in removedIds) {
        _activityProgress.remove(id);
        _activityStreaks.remove(id);
        _activityBestStreaks.remove(id);
      }
      _updatePreviewProgress();
      _rebuildPreviewProgress();
      await _saveGuestActivitiesToStorage();
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await apiService.deleteGroup(groupName);
      final removedIds = _activities
          .where((a) => a.groupName == groupName)
          .map((a) => a.id)
          .toList();
      for (final id in removedIds) {
        _activityProgress.remove(id);
        _activityStreaks.remove(id);
        _activityBestStreaks.remove(id);
      }
      await fetchActivities();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> renameGroup(String oldGroupName, String newGroupName) async {
    if (isGuest || previewMode) {
      for (final activity in _activities) {
        if (activity.groupName == oldGroupName) {
          activity.groupName = newGroupName;
        }
      }
      _updatePreviewProgress();
      _rebuildGroupProgress();
      await _saveGuestActivitiesToStorage();
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await apiService.renameGroup(
        oldGroupName: oldGroupName,
        newGroupName: newGroupName,
      );
      await fetchActivities();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleActivityCompletion(String activityId, bool isCompleted, {String? date}) async {
    final targetDate = date ?? _todayDateString();
    final isToday = targetDate == _todayDateString();
    if (!isToday) {
      debugPrint('Restriction: Cannot modify activity completion for dates other than today ($targetDate)');
      return;
    }
    _currentDate = targetDate;

    // 1. Snappy optimistic update
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      if (isToday) {
        _activities[index].isCompleted = isCompleted;
        _activityProgress[activityId] = isCompleted ? 100 : 0;
        if (isCompleted) {
          _activityStreaks[activityId] = (_activityStreaks[activityId] ?? 0) + 1;
          if ((_activityStreaks[activityId] ?? 0) > (_activityBestStreaks[activityId] ?? 0)) {
            _activityBestStreaks[activityId] = _activityStreaks[activityId]!;
          }
        } else {
          if ((_activityStreaks[activityId] ?? 0) > 0) {
            _activityStreaks[activityId] = (_activityStreaks[activityId]! - 1);
          }
        }
        _updatePreviewProgress();
        _rebuildGroupProgress();
      }

      if (isCompleted) {
        _guestCompletions['$activityId:$targetDate'] = true;
      } else {
        _guestCompletions.remove('$activityId:$targetDate');
      }

      final currentUserId = authService.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await _saveUserActivitiesToStorage(currentUserId);
      } else {
        await _saveGuestActivitiesToStorage();
      }

      notifyListeners();
    }

    if (isGuest || previewMode) return;

    try {
      if (isCompleted) {
        await apiService.completeActivity(activityId: activityId, date: targetDate);
      } else {
        await apiService.uncompleteActivity(activityId: activityId, date: targetDate);
      }
      if (isToday) {
        await fetchDailyProgress(date: targetDate);
      }
      notifyListeners();
    } catch (e) {
      // Keep local completion in user storage if backend is unreachable
      debugPrint('Sync completion to backend skipped: $e');
    }
  }

  /// Checks if an activity was completed on a specific date (defaults to today)
  bool isActivityCompletedOnDate(String activityId, String date) {
    if (_guestCompletions.containsKey('$activityId:$date')) {
      return _guestCompletions['$activityId:$date'] == true;
    }
    if (date == _todayDateString()) {
      final index = _activities.indexWhere((a) => a.id == activityId);
      if (index != -1) return _activities[index].isCompleted;
    }
    return false;
  }

  void _updatePreviewProgress() {
    final total = _activities.length;
    final completed = _activities.where((activity) => activity.isCompleted).length;
    _dailyProgress = DailyProgress(
      date: _currentDate,
      completed: completed,
      total: total,
      percentage: total == 0 ? 0 : ((completed / total) * 100).round(),
    );
  }

  /// Calculates period range based on preset and returns computed statistics
  DateTimeRange getRangeForPeriod(String period, {DateTimeRange? customRange}) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (period == 'Today') {
      return DateTimeRange(start: today, end: today);
    } else if (period == 'This Week') {
      final start = today.subtract(Duration(days: today.weekday - 1));
      return DateTimeRange(start: start, end: today);
    } else if (period == 'This Month') {
      final start = DateTime(today.year, today.month, 1);
      return DateTimeRange(start: start, end: today);
    } else if (period == 'This Year') {
      final start = DateTime(today.year, 1, 1);
      return DateTimeRange(start: start, end: today);
    } else if (period == 'Custom Range' && customRange != null) {
      return customRange;
    }
    return DateTimeRange(start: today, end: today);
  }
}
