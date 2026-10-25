import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/activity_service.dart';
import '../../services/activity_timer_manager.dart';
import '../../services/theme_service.dart';
import '../../widgets/neumorphic_card.dart';

const _kDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A modern soft neomorphic activity card supporting Scheduled, Duration Goal, and Flexible activities.
class ActivityCard extends StatelessWidget {
  final Activity activity;
  final int? progressOverride;

  const ActivityCard({
    super.key,
    required this.activity,
    this.progressOverride,
  });

  String _formatSeconds(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m';
  }

  String _formatTimeStr(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '';
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer2<ActivityService, ActivityTimerManager>(
      builder: (context, service, timerManager, _) {
        final pct = progressOverride ?? service.activityProgress(activity.id);
        final completionPct = activity.isCompleted ? 100 : pct;
        final streak = service.activityStreak(activity.id);
        final isTrackingThis = timerManager.isTracking(activity.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: NeumorphicCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: 18,
            isSelected: activity.isCompleted,
            border: isTrackingThis
                ? Border.all(color: AppColors.primary, width: 2)
                : (activity.isCompleted
                    ? Border.all(
                        color: AppColors.emeraldSuccess.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null),
            onTap: () => _showActivityDetails(context, activity, service),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Emoji Icon Container
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: activity.isCompleted
                            ? AppColors.emeraldSuccess.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: activity.isCompleted
                              ? AppColors.emeraldSuccess.withValues(alpha: 0.3)
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          activity.icon ?? (activity.activityType == 'scheduled' ? '🕒' : (activity.activityType == 'duration' ? '⏳' : '🎯')),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name + Type Metadata + Progress Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  activity.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Type Metadata Pill
                          _buildMetadataRow(isDark, streak),
                          const SizedBox(height: 8),

                          // Progress Bar
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: completionPct / 100,
                                    minHeight: 5,
                                    backgroundColor: isDark ? const Color(0xFF1E2438) : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      activity.isCompleted ? AppColors.emeraldSuccess : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$completionPct%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: activity.isCompleted
                                      ? AppColors.emeraldSuccess
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Tactile Completion Checkbox
                    GestureDetector(
                      onTap: () {
                        service.toggleActivityCompletion(
                          activity.id,
                          !activity.isCompleted,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: activity.isCompleted
                              ? AppColors.emeraldSuccess
                              : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: activity.isCompleted
                                ? AppColors.emeraldSuccess
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: 1.5,
                          ),
                          boxShadow: activity.isCompleted
                              ? [
                                  BoxShadow(
                                    color: AppColors.emeraldSuccess.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: activity.isCompleted ? Colors.white : Colors.transparent,
                          ),
                        ),
                      ),
                    ),

                    // Three-dot menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      onSelected: (value) => _handleMenuAction(context, service, value),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Details & Sessions'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.roseError),
                            SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: AppColors.roseError)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),

                // Live Session Timer Controls (for Duration Goals or Flexible activities)
                if (activity.activityType == 'duration' || isTrackingThis) ...[
                  const SizedBox(height: 10),
                  _buildTimerBar(context, service, timerManager, isDark),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetadataRow(bool isDark, int streak) {
    if (activity.activityType == 'scheduled') {
      final start = _formatTimeStr(activity.startTime);
      final end = _formatTimeStr(activity.endTime);
      final timeRange = (start.isNotEmpty && end.isNotEmpty) ? '$start - $end' : (start.isNotEmpty ? start : _frequencyLabel());
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 11, color: AppColors.primary),
                const SizedBox(width: 3),
                Text(
                  timeRange,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (activity.remindersEnabled) ...[
            const SizedBox(width: 5),
            Icon(Icons.notifications_active_rounded, size: 12, color: AppColors.primary),
          ],
          if (streak > 0) ...[
            const SizedBox(width: 6),
            _streakBadge(streak),
          ],
        ],
      );
    } else if (activity.activityType == 'duration') {
      final targetMins = activity.targetDurationMinutes ?? 60;
      final targetStr = _formatSeconds(targetMins * 60);
      final trackedStr = _formatSeconds(activity.trackedDurationSeconds);
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.amberFlame.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_bottom_rounded, size: 11, color: AppColors.amberFlame),
                const SizedBox(width: 3),
                Text(
                  '$trackedStr / $targetStr',
                  style: const TextStyle(
                    color: AppColors.amberFlame,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (activity.sessions.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              '(${activity.sessions.length} sessions)',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (streak > 0) ...[
            const SizedBox(width: 6),
            _streakBadge(streak),
          ],
        ],
      );
    } else {
      // Flexible
      return Row(
        children: [
          Text(
            _frequencyLabel(),
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          if (activity.trackedDurationSeconds > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _formatSeconds(activity.trackedDurationSeconds),
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (streak > 0) ...[
            const SizedBox(width: 6),
            _streakBadge(streak),
          ],
        ],
      );
    }
  }

  Widget _streakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.amberFlame.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: AppColors.amberFlame,
          ),
          const SizedBox(width: 2),
          Text(
            '$streak d',
            style: const TextStyle(
              color: AppColors.amberFlame,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar(
    BuildContext context,
    ActivityService service,
    ActivityTimerManager timerManager,
    bool isDark,
  ) {
    final isTrackingThis = timerManager.isTracking(activity.id);

    if (isTrackingThis) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: timerManager.isRunning ? AppColors.roseError : Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timerManager.isRunning ? 'Tracking:' : 'Paused:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              timerManager.formattedElapsed,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            if (timerManager.isRunning)
              IconButton(
                icon: const Icon(Icons.pause_circle_filled_rounded),
                color: Colors.amber,
                iconSize: 26,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Pause',
                onPressed: timerManager.pause,
              )
            else
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded),
                color: AppColors.primary,
                iconSize: 26,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Resume',
                onPressed: timerManager.resume,
              ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.stop_circle_rounded),
              color: AppColors.roseError,
              iconSize: 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Stop & Save Session',
              onPressed: () async {
                final savedSecs = await timerManager.stopAndSave(service);
                if (context.mounted && savedSecs > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Session saved (${_formatSeconds(savedSecs)})'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    }

    // Idle: show Start Session button
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (timerManager.hasActiveSession && !timerManager.isTracking(activity.id)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Another session ("${timerManager.activeActivityName}") is already active.'),
                  duration: const Duration(seconds: 2),
                ),
              );
              return;
            }
            timerManager.start(activity.id, activity.name);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Start Session',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _frequencyLabel() {
    final v = activity.frequencyValue;
    final u = activity.frequencyUnit;
    if (v == 1 && u == 'days') return 'Daily';
    if (v == 1 && u == 'weeks') return 'Weekly';
    if (v == 1 && u == 'months') return 'Monthly';
    if (u == 'weeks') return '$v× per week';
    if (u == 'days') return 'Every $v days';
    return 'Every $v $u';
  }

  void _handleMenuAction(BuildContext context, ActivityService service, String action) {
    if (action == 'details') {
      _showActivityDetails(context, activity, service);
    } else if (action == 'delete') {
      _confirmDelete(context, service);
    } else if (action == 'edit') {
      _showEditSheet(context);
    }
  }

  void _showActivityDetails(BuildContext context, Activity activity, ActivityService service) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final streak = service.activityStreak(activity.id);
    final bestStreak = service.activityBestStreak(activity.id);
    final pct = service.activityProgress(activity.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Consumer<ActivityTimerManager>(
        builder: (context, timerManager, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            activity.icon ?? '📌',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.name,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${activity.groupName} • ${activity.activityType.toUpperCase()}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Streak & Progress Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Streak', style: theme.textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 18,
                                    color: AppColors.amberFlame,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$streak d', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Best Streak', style: theme.textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('⭐ ', style: TextStyle(fontSize: 14)),
                                  Text('$bestStreak d', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Progress', style: theme.textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Scheduled or Duration Details Section
                  if (activity.activityType == 'scheduled') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Schedule Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Time: ${_formatTimeStr(activity.startTime)} - ${_formatTimeStr(activity.endTime)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.repeat_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Repeats: ${activity.repeatDays.isEmpty ? "Every day" : activity.repeatDays.map((d) => _kDayNames[(d - 1).clamp(0, 6)]).join(", ")}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                activity.remindersEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                                size: 16,
                                color: activity.remindersEnabled ? AppColors.primary : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                activity.remindersEnabled
                                    ? 'Reminders: ${activity.reminderMinutesBefore == 0 ? "At start" : "${activity.reminderMinutesBefore}m before"}${activity.reminderAtEnd ? " & at end" : ""}'
                                    : 'Reminders: Disabled',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (activity.activityType == 'duration') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Today\'s Time Tracking', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(
                                '${_formatSeconds(activity.trackedDurationSeconds)} / ${_formatSeconds((activity.targetDurationMinutes ?? 60) * 60)}',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (activity.sessions.isEmpty)
                            Text(
                              'No sessions logged yet today. Use the timer below to start tracking.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            )
                          else ...[
                            Text(
                              'Logged Sessions (${activity.sessions.length}):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...activity.sessions.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              final s = entry.value;
                              final durSec = s['duration_seconds'] is int
                                  ? s['duration_seconds'] as int
                                  : int.tryParse(s['duration_seconds'].toString()) ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.emeraldSuccess),
                                    const SizedBox(width: 6),
                                    Text('Session $idx:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text(_formatSeconds(durSec), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Timer Controls in Details
                  if (activity.activityType == 'duration' || activity.activityType == 'flexible') ...[
                    _buildTimerBar(context, service, timerManager, isDark),
                    const SizedBox(height: 16),
                  ],

                  // Toggle Completion Button
                  FilledButton.icon(
                    onPressed: () {
                      service.toggleActivityCompletion(activity.id, !activity.isCompleted);
                      Navigator.pop(ctx);
                    },
                    icon: Icon(activity.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
                    label: Text(activity.isCompleted ? 'Completed Today (Tap to uncheck)' : 'Mark Completed Today'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: activity.isCompleted ? AppColors.emeraldSuccess : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showEditSheet(context);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Activity'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDelete(context, service);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.roseError),
                          label: const Text('Delete', style: TextStyle(color: AppColors.roseError)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.roseError),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ActivityService service) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Activity?'),
        content: Text(
          'Are you sure you want to delete "${activity.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.roseError),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        service.deleteActivity(activity.id);
      }
    });
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditActivitySheet(activity: activity),
    );
  }
}

/// Dynamic edit sheet supporting Scheduled, Duration Goal, and Flexible activities.
class _EditActivitySheet extends StatefulWidget {
  final Activity activity;
  const _EditActivitySheet({required this.activity});

  @override
  State<_EditActivitySheet> createState() => _EditActivitySheetState();
}

class _EditActivitySheetState extends State<_EditActivitySheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _groupController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _durationController;
  late String _activityType;
  late String _frequencyUnit;
  late String _durationUnit;
  late String? _selectedIcon;
  bool _showEmojiPicker = false;

  // Scheduled fields
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  late Set<int> _repeatDays;
  late bool _remindersEnabled;
  late int _reminderMinutesBefore;
  late bool _reminderAtEnd;

  // Duration fields
  int _targetHours = 2;
  int _targetMinutes = 0;
  TimeOfDay _incompleteReminderTime = const TimeOfDay(hour: 20, minute: 0);

  // Flexible fields
  TimeOfDay _flexibleReminderTime = const TimeOfDay(hour: 9, minute: 0);

  TimeOfDay _parseHHMM(String? hhmm, TimeOfDay defaultTime) {
    if (hhmm == null || !hhmm.contains(':')) return defaultTime;
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? defaultTime.hour,
      minute: int.tryParse(parts[1]) ?? defaultTime.minute,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _timeOfDayToHHMM(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _nameController = TextEditingController(text: a.name);
    _groupController = TextEditingController(text: a.groupName);
    _frequencyController = TextEditingController(text: a.frequencyValue.toString());
    _durationController = TextEditingController(text: a.durationValue.toString());
    _activityType = a.activityType;
    _frequencyUnit = a.frequencyUnit;
    _durationUnit = a.durationUnit;
    _selectedIcon = a.icon;

    _startTime = _parseHHMM(a.startTime, const TimeOfDay(hour: 9, minute: 0));
    _endTime = _parseHHMM(a.endTime, const TimeOfDay(hour: 10, minute: 0));
    _repeatDays = a.repeatDays.isNotEmpty ? a.repeatDays.toSet() : {1, 2, 3, 4, 5, 6, 7};
    _remindersEnabled = a.remindersEnabled;
    _reminderMinutesBefore = a.reminderMinutesBefore;
    _reminderAtEnd = a.reminderAtEnd;

    final targetMins = a.targetDurationMinutes ?? 120;
    _targetHours = targetMins ~/ 60;
    _targetMinutes = targetMins % 60;
    _incompleteReminderTime = _parseHHMM(a.startTime, const TimeOfDay(hour: 20, minute: 0));
    _flexibleReminderTime = _parseHHMM(a.startTime, const TimeOfDay(hour: 9, minute: 0));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final frequencyValue = int.tryParse(_frequencyController.text);
    final durationValue = int.tryParse(_durationController.text);
    if (name.isEmpty) {
      _showError('Activity name cannot be empty');
      return;
    }
    if (frequencyValue == null || frequencyValue < 1) {
      _showError('Frequency must be a positive whole number');
      return;
    }
    if (durationValue == null || durationValue < 1) {
      _showError('Duration must be a positive whole number');
      return;
    }

    try {
      String? startStr;
      String? endStr;
      List<int>? repDays;
      int? targetDur;
      bool reminders = _remindersEnabled;
      int reminderBefore = _reminderMinutesBefore;
      bool reminderEnd = _reminderAtEnd;

      if (_activityType == 'scheduled') {
        startStr = _timeOfDayToHHMM(_startTime);
        endStr = _timeOfDayToHHMM(_endTime);
        repDays = _repeatDays.toList()..sort();
      } else if (_activityType == 'duration') {
        targetDur = (_targetHours * 60) + _targetMinutes;
        if (targetDur <= 0) targetDur = 60;
        startStr = _timeOfDayToHHMM(_incompleteReminderTime);
        repDays = [1, 2, 3, 4, 5, 6, 7];
        reminderEnd = false;
      } else {
        startStr = reminders ? _timeOfDayToHHMM(_flexibleReminderTime) : null;
        repDays = [1, 2, 3, 4, 5, 6, 7];
        reminderEnd = false;
      }

      await context.read<ActivityService>().updateActivity(
        id: widget.activity.id,
        name: name,
        groupName: _groupController.text.trim().isEmpty ? 'General' : _groupController.text.trim(),
        icon: _selectedIcon,
        frequencyValue: frequencyValue,
        frequencyUnit: _frequencyUnit,
        durationValue: durationValue,
        durationUnit: _durationUnit,
        activityType: _activityType,
        startTime: startStr,
        endTime: endStr,
        repeatDays: repDays,
        targetDurationMinutes: targetDur,
        remindersEnabled: reminders,
        reminderMinutesBefore: reminderBefore,
        reminderAtEnd: reminderEnd,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to update: $e');
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const emojis = [
      '🏋️', '📚', '💧', '🏃', '🧘', '🍎', '😴', '💊', '🚴', '🎯',
      '✍️', '🎨', '🎸', '🎹', '📖', '🧹', '🌿', '🧠', '💻', '📝',
      '🏊', '⚽', '🏀', '🎾', '🥗', '🫁', '🦷', '🛁', '🐕', '🌞',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit Activity',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Activity Type Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _typeTab('scheduled', 'Scheduled', Icons.schedule_rounded, isDark),
                  _typeTab('duration', 'Duration', Icons.hourglass_bottom_rounded, isDark),
                  _typeTab('flexible', 'Flexible', Icons.check_circle_outline_rounded, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Icon selector button
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _selectedIcon ?? '📌',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Tap to change icon',
                style: theme.textTheme.bodySmall,
              ),
            ),

            if (_showEmojiPicker) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (_, i) => InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() {
                      _selectedIcon = emojis[i];
                      _showEmojiPicker = false;
                    }),
                    child: Center(
                      child: Text(emojis[i], style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Activity Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _groupController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic fields per type
            if (_activityType == 'scheduled') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text('Start: ${_formatTime(_startTime)}'),
                      onPressed: () async {
                        final p = await showTimePicker(context: context, initialTime: _startTime);
                        if (p != null) setState(() => _startTime = p);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text('End: ${_formatTime(_endTime)}'),
                      onPressed: () async {
                        final p = await showTimePicker(context: context, initialTime: _endTime);
                        if (p != null) setState(() => _endTime = p);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Repeat Days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final dayNum = index + 1;
                  final isSel = _repeatDays.contains(dayNum);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSel) {
                          if (_repeatDays.length > 1) _repeatDays.remove(dayNum);
                        } else {
                          _repeatDays.add(dayNum);
                        }
                      });
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSel ? AppColors.primary : Colors.grey),
                      ),
                      child: Center(
                        child: Text(
                          _kDayNames[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Enable Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _remindersEnabled,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _remindersEnabled = v),
              ),
            ] else if (_activityType == 'duration') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _targetHours > 0 ? () => setState(() => _targetHours--) : null,
                            ),
                            Text('$_targetHours', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _targetHours < 23 ? () => setState(() => _targetHours++) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Minutes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _targetMinutes >= 15 ? () => setState(() => _targetMinutes -= 15) : null,
                            ),
                            Text('$_targetMinutes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _targetMinutes <= 30 ? () => setState(() => _targetMinutes += 15) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Remind if Incomplete', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _remindersEnabled,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _remindersEnabled = v),
              ),
            ] else ...[
              SwitchListTile(
                title: const Text('Daily Reminder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _remindersEnabled,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _remindersEnabled = v),
              ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeTab(String type, String label, IconData icon, bool isDark) {
    final isSel = _activityType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activityType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? (isDark ? AppColors.darkSurface : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSel ? AppColors.primary : Colors.grey),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
