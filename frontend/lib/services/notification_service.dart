import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'activity_service.dart';

/// Service managing real local notifications, scheduling, reminders, snooze, and quiet hours.
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Quiet hours settings
  bool _quietHoursEnabled = false;
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '07:00';
  bool _notificationsGloballyEnabled = true;

  bool get quietHoursEnabled => _quietHoursEnabled;
  String get quietHoursStart => _quietHoursStart;
  String get quietHoursEnd => _quietHoursEnd;
  bool get notificationsGloballyEnabled => _notificationsGloballyEnabled;

  static const String _kQuietHoursEnabledKey = 'daytrack_quiet_hours_enabled';
  static const String _kQuietHoursStartKey = 'daytrack_quiet_hours_start';
  static const String _kQuietHoursEndKey = 'daytrack_quiet_hours_end';
  static const String _kGlobalNotifKey = 'daytrack_notifications_enabled';

  // Android Notification Channels
  static const String channelIdScheduled = 'daytrack_scheduled_channel';
  static const String channelNameScheduled = 'Scheduled Activities & Reminders';
  static const String channelDescScheduled = 'Reminders before and at the end of scheduled activities.';

  static const String channelIdDuration = 'daytrack_duration_channel';
  static const String channelNameDuration = 'Duration Goal Reminders';
  static const String channelDescDuration = 'Reminders for daily accumulated time goals.';

  /// Initializes local notifications, timezone database, and loads settings.
  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Initialize timezone database
    tzdata.initializeTimeZones();
    _configureLocalTimeZone();

    // 2. Initialize SharedPreferences settings
    await _loadSettings();

    // 3. Android & iOS Initialization Settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    debugPrint('✓ NotificationService initialized successfully');
  }

  void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      // Best-effort mapping to a standard location or UTC fallback
      final hours = offset.inHours;
      final sign = hours >= 0 ? '+' : '-';
      final customName = 'Etc/GMT$sign${hours.abs()}';

      try {
        tz.setLocalLocation(tz.getLocation(customName));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      debugPrint('Timezone config note: $e');
    }
  }

  /// Request runtime permissions on Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notifGranted = await androidImplementation?.requestNotificationsPermission() ?? false;
      await androidImplementation?.requestExactAlarmsPermission();
      return notifGranted;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Loads quiet hours and global notification preference from storage.
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _quietHoursEnabled = prefs.getBool(_kQuietHoursEnabledKey) ?? false;
      _quietHoursStart = prefs.getString(_kQuietHoursStartKey) ?? '22:00';
      _quietHoursEnd = prefs.getString(_kQuietHoursEndKey) ?? '07:00';
      _notificationsGloballyEnabled = prefs.getBool(_kGlobalNotifKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load notification settings: $e');
    }
  }

  /// Updates quiet hours and global notification settings.
  Future<void> updateSettings({
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? notificationsGloballyEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (quietHoursEnabled != null) {
      _quietHoursEnabled = quietHoursEnabled;
      await prefs.setBool(_kQuietHoursEnabledKey, quietHoursEnabled);
    }
    if (quietHoursStart != null) {
      _quietHoursStart = quietHoursStart;
      await prefs.setString(_kQuietHoursStartKey, quietHoursStart);
    }
    if (quietHoursEnd != null) {
      _quietHoursEnd = quietHoursEnd;
      await prefs.setString(_kQuietHoursEndKey, quietHoursEnd);
    }
    if (notificationsGloballyEnabled != null) {
      _notificationsGloballyEnabled = notificationsGloballyEnabled;
      await prefs.setBool(_kGlobalNotifKey, notificationsGloballyEnabled);
      if (!notificationsGloballyEnabled) {
        await cancelAll();
      }
    }
    notifyListeners();
  }

  /// Checks if a given DateTime falls within active quiet hours.
  bool isWithinQuietHours(DateTime time) {
    if (!_quietHoursEnabled) return false;

    try {
      final startParts = _quietHoursStart.split(':').map(int.parse).toList();
      final endParts = _quietHoursEnd.split(':').map(int.parse).toList();

      final currentMinutes = time.hour * 60 + time.minute;
      final startMinutes = startParts[0] * 60 + startParts[1];
      final endMinutes = endParts[0] * 60 + endParts[1];

      if (startMinutes <= endMinutes) {
        // Normal daytime window (e.g. 13:00 to 15:00)
        return currentMinutes >= startMinutes && currentMinutes < endMinutes;
      } else {
        // Overnight window (e.g. 22:00 to 07:00)
        return currentMinutes >= startMinutes || currentMinutes < endMinutes;
      }
    } catch (_) {
      return false;
    }
  }

  /// Returns adjusted DateTime if target falls within quiet hours (shifts to end of quiet hours).
  DateTime adjustForQuietHours(DateTime time) {
    if (!isWithinQuietHours(time)) return time;

    try {
      final endParts = _quietHoursEnd.split(':').map(int.parse).toList();
      var adjusted = DateTime(time.year, time.month, time.day, endParts[0], endParts[1]);
      if (adjusted.isBefore(time)) {
        adjusted = adjusted.add(const Duration(days: 1));
      }
      return adjusted.add(const Duration(minutes: 5)); // 5 mins after quiet hours end
    } catch (_) {
      return time;
    }
  }

  /// Triggers an immediate test notification with Snooze action.
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      channelIdScheduled,
      channelNameScheduled,
      channelDescription: channelDescScheduled,
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_snooze', 'Snooze (10m)'),
      ],
    );
    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: 99999,
      title: '🎯 DayTrack Test Notification',
      body: 'Local reminders and quiet hours are configured properly!',
      notificationDetails: details,
    );
  }

  /// Handles user tapping notification or snooze action.
  void _onNotificationTapped(NotificationResponse response) {
    if (response.actionId == 'action_snooze') {
      snoozeNotification(
        notificationId: response.id ?? 9999,
        title: response.payload != null ? 'Reminder: ${response.payload}' : 'Snoozed Activity Reminder',
        body: 'Snoozed 10 minutes ago. Time to resume your activity!',
        minutes: 10,
      );
    }
  }

  /// Schedules a snooze reminder for [minutes] in the future (default 10 min).
  Future<void> snoozeNotification({
    required int notificationId,
    required String title,
    required String body,
    int minutes = 10,
  }) async {
    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final adjusted = adjustForQuietHours(snoozeTime);

    const androidDetails = AndroidNotificationDetails(
      channelIdScheduled,
      channelNameScheduled,
      channelDescription: channelDescScheduled,
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_snooze', 'Snooze (10m)'),
      ],
    );
    const notifDetails = NotificationDetails(android: androidDetails);

    final scheduledTz = tz.TZDateTime.from(adjusted, tz.local);
    await _notificationsPlugin.zonedSchedule(
      id: notificationId + 100000,
      title: title,
      body: body,
      scheduledDate: scheduledTz,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('✓ Snoozed notification ($notificationId) until $adjusted');
  }

  /// Shows an immediate test notification.
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelIdScheduled,
      channelNameScheduled,
      channelDescription: channelDescScheduled,
      importance: Importance.high,
      priority: Priority.high,
    );
    const notifDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: notifDetails,
      payload: payload,
    );
  }

  /// Schedules notifications for a single activity based on its type and configuration.
  Future<void> scheduleActivityReminders(Activity activity) async {
    if (!_notificationsGloballyEnabled) return;
    if (!activity.remindersEnabled) {
      await cancelActivityNotifications(activity.id);
      return;
    }

    // Cancel existing reminders for this activity before re-registering
    await cancelActivityNotifications(activity.id);

    final baseId = activity.id.hashCode.abs() % 100000;

    if (activity.activityType == 'scheduled') {
      await _scheduleScheduledActivity(activity, baseId);
    } else if (activity.activityType == 'duration') {
      await _scheduleDurationGoalReminder(activity, baseId);
    } else if (activity.activityType == 'flexible') {
      await _scheduleFlexibleActivityReminder(activity, baseId);
    }
  }

  /// Schedules reminders for a Scheduled Activity across its designated repeat days.
  Future<void> _scheduleScheduledActivity(Activity activity, int baseId) async {
    if (activity.startTime == null || activity.startTime!.isEmpty) return;

    final parts = activity.startTime!.split(':').map((s) => int.tryParse(s) ?? 0).toList();
    if (parts.length < 2) return;
    final startHour = parts[0];
    final startMinute = parts[1];

    final repeatDays = activity.repeatDays.isNotEmpty ? activity.repeatDays : [1, 2, 3, 4, 5, 6, 7];

    final minutesBefore = activity.reminderMinutesBefore;

    for (final dayOfWeek in repeatDays) {
      // 1. Reminder before activity starts
      var remHour = startHour;
      var remMinute = startMinute - minutesBefore;
      while (remMinute < 0) {
        remMinute += 60;
        remHour -= 1;
      }
      if (remHour < 0) remHour += 24;

      final startNotifId = baseId + (dayOfWeek * 10) + 1;
      final startTitle = '${activity.icon ?? "🕒"} Starting Soon: ${activity.name}';
      final startBody = minutesBefore > 0
          ? '${activity.name} starts in $minutesBefore minutes (${activity.startTime})'
          : '${activity.name} starts right now (${activity.startTime})';

      await _scheduleWeeklyDayTime(
        id: startNotifId,
        title: startTitle,
        body: startBody,
        dayOfWeek: dayOfWeek,
        hour: remHour,
        minute: remMinute,
        channelId: channelIdScheduled,
        channelName: channelNameScheduled,
        payload: activity.name,
      );

      // 2. Reminder at end of activity (if enabled)
      if (activity.reminderAtEnd && activity.endTime != null && activity.endTime!.isNotEmpty) {
        final endParts = activity.endTime!.split(':').map((s) => int.tryParse(s) ?? 0).toList();
        if (endParts.length >= 2) {
          final endNotifId = baseId + (dayOfWeek * 10) + 2;
          final endTitle = '✅ Time to Wrap Up: ${activity.name}';
          final endBody = 'Scheduled time ending (${activity.endTime}). Did you finish?';

          await _scheduleWeeklyDayTime(
            id: endNotifId,
            title: endTitle,
            body: endBody,
            dayOfWeek: dayOfWeek,
            hour: endParts[0],
            minute: endParts[1],
            channelId: channelIdScheduled,
            channelName: channelNameScheduled,
            payload: activity.name,
          );
        }
      }
    }
  }

  /// Schedules daily check-in reminder for an incomplete Duration Goal.
  Future<void> _scheduleDurationGoalReminder(Activity activity, int baseId) async {
    // Schedule an afternoon reminder (default 17:30 or activity start_time if set)
    var hour = 17;
    var minute = 30;
    if (activity.startTime != null && activity.startTime!.contains(':')) {
      final p = activity.startTime!.split(':').map(int.tryParse).toList();
      hour = p[0] ?? 17;
      minute = p[1] ?? 30;
    }

    final targetMins = activity.targetDurationMinutes ?? 60;
    final hoursStr = (targetMins / 60).toStringAsFixed(targetMins % 60 == 0 ? 0 : 1);

    for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
      final notifId = baseId + (dayOfWeek * 10) + 3;
      await _scheduleWeeklyDayTime(
        id: notifId,
        title: '${activity.icon ?? "⏳"} Daily Goal Check: ${activity.name}',
        body: 'Remember to complete your ${hoursStr}h target today!',
        dayOfWeek: dayOfWeek,
        hour: hour,
        minute: minute,
        channelId: channelIdDuration,
        channelName: channelNameDuration,
        payload: activity.name,
      );
    }
  }

  /// Schedules reminder for a flexible activity with reminder enabled.
  Future<void> _scheduleFlexibleActivityReminder(Activity activity, int baseId) async {
    var hour = 10;
    var minute = 0;
    if (activity.startTime != null && activity.startTime!.contains(':')) {
      final p = activity.startTime!.split(':').map(int.tryParse).toList();
      hour = p[0] ?? 10;
      minute = p[1] ?? 0;
    }

    final repeatDays = activity.repeatDays.isNotEmpty ? activity.repeatDays : [1, 2, 3, 4, 5, 6, 7];

    for (final dayOfWeek in repeatDays) {
      final notifId = baseId + (dayOfWeek * 10) + 4;
      await _scheduleWeeklyDayTime(
        id: notifId,
        title: '${activity.icon ?? "📌"} Reminder: ${activity.name}',
        body: 'Don\'t forget your task: ${activity.name}',
        dayOfWeek: dayOfWeek,
        hour: hour,
        minute: minute,
        channelId: channelIdScheduled,
        channelName: channelNameScheduled,
        payload: activity.name,
      );
    }
  }

  /// Schedules a recurring notification on a specific day of week and time.
  Future<void> _scheduleWeeklyDayTime({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek, // 1 = Monday ... 7 = Sunday
    required int hour,
    required int minute,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    var scheduledDate = _nextInstanceOfDayOfWeekAndTime(dayOfWeek, hour, minute);

    if (isWithinQuietHours(scheduledDate)) {
      scheduledDate = adjustForQuietHours(scheduledDate);
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('action_snooze', 'Snooze (10m)'),
      ],
    );
    final notifDetails = NotificationDetails(android: androidDetails);

    final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling notification $id: $e');
    }
  }

  DateTime _nextInstanceOfDayOfWeekAndTime(int dayOfWeek, int hour, int minute) {
    DateTime scheduledDate = DateTime.now();
    // Shift until the desired day of week
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    scheduledDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(DateTime.now())) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }

  /// Cancels all scheduled notification IDs belonging to an activity.
  Future<void> cancelActivityNotifications(String activityId) async {
    final baseId = activityId.hashCode.abs() % 100000;
    for (int day = 1; day <= 7; day++) {
      for (int typeOffset = 1; typeOffset <= 4; typeOffset++) {
        final id = baseId + (day * 10) + typeOffset;
        await _notificationsPlugin.cancel(id: id);
      }
    }
    debugPrint('✓ Cancelled notifications for activity $activityId');
  }

  /// Re-syncs all activity notifications when list changes.
  Future<void> syncAllActivities(List<Activity> activities) async {
    if (!_notificationsGloballyEnabled) return;
    for (final act in activities) {
      if (act.isActive && !act.isCompleted && act.remindersEnabled) {
        await scheduleActivityReminders(act);
      } else {
        await cancelActivityNotifications(act.id);
      }
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('✓ Cancelled all scheduled notifications');
  }
}
