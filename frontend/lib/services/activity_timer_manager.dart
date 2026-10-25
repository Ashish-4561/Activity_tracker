import 'dart:async';
import 'package:flutter/foundation.dart';
import 'activity_service.dart';

/// Manages active time tracking sessions (stopwatch) for duration goals and flexible activities.
class ActivityTimerManager extends ChangeNotifier {
  static final ActivityTimerManager _instance = ActivityTimerManager._internal();
  factory ActivityTimerManager() => _instance;
  ActivityTimerManager._internal();

  Timer? _ticker;
  String? _activeActivityId;
  String? _activeActivityName;
  bool _isRunning = false;
  int _elapsedSeconds = 0;
  DateTime? _sessionStartTime;

  String? get activeActivityId => _activeActivityId;
  String? get activeActivityName => _activeActivityName;
  bool get isRunning => _isRunning;
  int get elapsedSeconds => _elapsedSeconds;
  DateTime? get sessionStartTime => _sessionStartTime;
  bool get hasActiveSession => _activeActivityId != null;

  bool isTracking(String activityId) => _activeActivityId == activityId;

  String get formattedElapsed {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void start(String activityId, String activityName) {
    if (_activeActivityId != null && _activeActivityId != activityId) {
      // Another activity is currently being tracked
      return;
    }

    _activeActivityId = activityId;
    _activeActivityName = activityName;
    _sessionStartTime ??= DateTime.now();
    _isRunning = true;

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    _isRunning = false;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void resume() {
    if (_activeActivityId == null) return;
    _isRunning = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<int> stopAndSave(ActivityService service) async {
    final durationToSave = _elapsedSeconds;
    final actId = _activeActivityId;
    final start = _sessionStartTime;
    final end = DateTime.now();

    // Reset state
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _elapsedSeconds = 0;
    _activeActivityId = null;
    _activeActivityName = null;
    _sessionStartTime = null;
    notifyListeners();

    if (actId != null && durationToSave > 0) {
      await service.logDurationSession(
        activityId: actId,
        durationSeconds: durationToSave,
        startTime: start,
        endTime: end,
      );
    }

    return durationToSave;
  }

  void discard() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _elapsedSeconds = 0;
    _activeActivityId = null;
    _activeActivityName = null;
    _sessionStartTime = null;
    notifyListeners();
  }
}
