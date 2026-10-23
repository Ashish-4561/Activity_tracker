import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/activity_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/neumorphic_card.dart';

class ProgressScreen extends StatefulWidget {
  final bool previewMode;

  const ProgressScreen({super.key, this.previewMode = false});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const List<String> _rangePresets = [
    'Last 7 Days',
    'Last 14 Days',
    'Last 30 Days',
    'Last 3 Months',
    'Last 6 Months',
    'Last 12 Months',
    'Custom Range',
  ];

  static const String _kMatrixCacheKey = 'daytrack_matrix_completions_cache_v2';

  String _selectedPreset = 'Last 7 Days';
  String _selectedGroup = 'All Groups';
  DateTimeRange? _customRange;
  late DateTime _currentEndDate;
  late int _rangeDays;

  bool _loading = true;
  String? _errorMessage;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedCalendarDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  bool _calendarExpanded = true;

  // Data cache
  List<Activity> _userActivities = [];
  Map<String, Set<String>> _completedDatesByActivity = {}; // activityId -> Set of YYYY-MM-DD

  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentEndDate = _dateOnly(DateTime.now());
    _selectedCalendarDay = _currentEndDate;
    _focusedDay = _currentEndDate;
    _rangeDays = 7;
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  DateTimeRange _computeActiveRange() {
    if (_selectedPreset == 'Custom Range' && _customRange != null) {
      return _customRange!;
    }
    final start = _currentEndDate.subtract(Duration(days: _rangeDays - 1));
    return DateTimeRange(start: start, end: _currentEndDate);
  }

  void _onPresetChanged(String preset) {
    if (preset == 'Custom Range') {
      _showCustomRangePicker();
      return;
    }

    int days = 7;
    if (preset == 'Last 7 Days') {
      days = 7;
    } else if (preset == 'Last 14 Days') {
      days = 14;
    } else if (preset == 'Last 30 Days') {
      days = 30;
    } else if (preset == 'Last 3 Months') {
      days = 90;
    } else if (preset == 'Last 6 Months') {
      days = 180;
    } else if (preset == 'Last 12 Months') {
      days = 365;
    }

    setState(() {
      _selectedPreset = preset;
      _rangeDays = days;
      _currentEndDate = _dateOnly(DateTime.now());
    });
    _loadData();
  }

  Future<void> _showCustomRangePicker() async {
    final today = _dateOnly(DateTime.now());
    final initialStart = _customRange?.start ?? today.subtract(const Duration(days: 6));
    final initialEnd = _customRange?.end ?? today;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'SELECT DATE RANGE (MINIMUM 7 DAYS)',
    );

    if (picked != null) {
      var start = _dateOnly(picked.start);
      var end = _dateOnly(picked.end);
      if (end.difference(start).inDays < 6) {
        start = end.subtract(const Duration(days: 6));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Minimum range is 7 days. Adjusted start date automatically.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      setState(() {
        _selectedPreset = 'Custom Range';
        _customRange = DateTimeRange(start: start, end: end);
        _rangeDays = end.difference(start).inDays + 1;
        _currentEndDate = end;
      });
      _loadData();
    }
  }

  void _navigatePeriod(int direction) {
    final today = _dateOnly(DateTime.now());
    final newEnd = _currentEndDate.add(Duration(days: direction * _rangeDays));

    if (newEnd.isAfter(today) && direction > 0) {
      if (_currentEndDate.isAtSameMomentAs(today)) return;
      setState(() {
        _currentEndDate = today;
      });
    } else {
      setState(() {
        _currentEndDate = newEnd;
      });
    }
    _loadData();
  }

  Future<void> _loadCachedLocalData() async {
    try {
      final activityService = context.read<ActivityService>();
      _userActivities = List.from(activityService.activities);

      final compMap = <String, Set<String>>{};
      for (final act in _userActivities) {
        compMap[act.id] = <String>{};
      }

      // 1. Pull from activity service in-memory guest/local history
      final serviceHistory = activityService.getGuestCompletionHistory();
      for (final entry in serviceHistory.entries) {
        compMap.putIfAbsent(entry.key, () => <String>{}).addAll(entry.value);
      }

      // 2. Pull from persistent matrix cache
      final prefs = await SharedPreferences.getInstance();
      final rawCache = prefs.getString(_kMatrixCacheKey);
      if (rawCache != null && rawCache.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(rawCache);
        for (final entry in decoded.entries) {
          if (entry.value is List) {
            final datesList = (entry.value as List).map((e) => e.toString()).toSet();
            compMap.putIfAbsent(entry.key, () => <String>{}).addAll(datesList);
          }
        }
      }

      _completedDatesByActivity = compMap;
    } catch (_) {}
  }

  Future<void> _saveCompletionsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final exported = <String, List<String>>{};
      for (final entry in _completedDatesByActivity.entries) {
        exported[entry.key] = entry.value.toList();
      }
      await prefs.setString(_kMatrixCacheKey, jsonEncode(exported));
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final activityService = context.read<ActivityService>();
    final authService = context.read<AuthService>();
    final apiService = context.read<ApiService>();

    // Instant rendering with cached data to eliminate loading delays
    await _loadCachedLocalData();
    if (!mounted) return;

    if (_userActivities.isNotEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = null;
      });
    }

    final range = _computeActiveRange();
    final fromStr = _formatDate(range.start);
    final toStr = _formatDate(range.end);

    try {

      if (!authService.isLoggedIn || widget.previewMode) {
        _userActivities = List.from(activityService.activities);
        final history = activityService.getGuestCompletionHistory();
        final compMap = <String, Set<String>>{};
        for (final act in _userActivities) {
          compMap[act.id] = Set<String>.from(history[act.id] ?? <String>{});
          if (_completedDatesByActivity.containsKey(act.id)) {
            compMap[act.id]!.addAll(_completedDatesByActivity[act.id]!);
          }
        }
        _completedDatesByActivity = compMap;
        await _saveCompletionsToCache();
      } else {
        // Parallelize API queries for maximum performance
        final results = await Future.wait([
          apiService.getRangeProgress(
            from: fromStr,
            to: toStr,
            group: _selectedGroup == 'All Groups' ? null : _selectedGroup,
          ),
          apiService.getActivities(),
        ]);

        final response = results[0];
        final actRes = results[1];

        final rawList = actRes['activities'] as List? ?? [];
        _userActivities = rawList.map((j) => Activity.fromJson(j)).toList();

        final compMap = <String, Set<String>>{};
        for (final act in _userActivities) {
          compMap[act.id] = Set<String>.from(_completedDatesByActivity[act.id] ?? <String>{});
        }

        final completionsList = response['completion_history'] as List? ?? [];
        for (final c in completionsList) {
          if (c is Map && c['activity_id'] != null && c['date'] != null) {
            final actId = c['activity_id'].toString();
            final date = c['date'].toString().split('T').first;
            final isComp = c['completed'] == 1 || c['completed'] == true || c['completed'] == 'true';
            if (isComp) {
              compMap.putIfAbsent(actId, () => <String>{}).add(date);
            } else {
              compMap[actId]?.remove(date);
            }
          }
        }
        _completedDatesByActivity = compMap;
        await _saveCompletionsToCache();
      }
    } catch (e) {
      // Offline fallback: Preserve all locally tracked data
      _userActivities = List.from(activityService.activities);
      final history = activityService.getGuestCompletionHistory();
      for (final act in _userActivities) {
        _completedDatesByActivity.putIfAbsent(act.id, () => <String>{}).addAll(history[act.id] ?? <String>{});
        if (act.isCompleted) {
          _completedDatesByActivity[act.id]!.add(_formatDate(_dateOnly(DateTime.now())));
        }
      }
      _errorMessage = null;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showRestrictedDateMessage(DateTime date) {
    if (!mounted) return;
    final now = _dateOnly(DateTime.now());
    final target = _dateOnly(date);
    final String message;
    if (target.isBefore(now)) {
      message = 'Cannot edit previous days. You can only update today\'s tasks.';
    } else {
      message = 'Future dates cannot be marked as completed.';
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  Future<void> _toggleCellCompletion(Activity act, DateTime date) async {
    final today = _dateOnly(DateTime.now());
    final target = _dateOnly(date);
    if (!isSameDay(target, today)) {
      _showRestrictedDateMessage(date);
      return;
    }

    final dStr = _formatDate(date);
    final compSet = _completedDatesByActivity.putIfAbsent(act.id, () => <String>{});
    final wasCompleted = compSet.contains(dStr);
    final willComplete = !wasCompleted;

    // 1. Instant optimistic UI update
    setState(() {
      if (willComplete) {
        compSet.add(dStr);
      } else {
        compSet.remove(dStr);
      }
    });

    // 2. Persist to cache
    await _saveCompletionsToCache();

    // 3. Sync through ActivityService (persists to backend and handles streaks & gardens)
    if (mounted) {
      final activityService = context.read<ActivityService>();
      await activityService.toggleActivityCompletion(
        act.id,
        willComplete,
        date: dStr,
      );
    }
  }

  bool _isScheduled(Activity activity, DateTime date) {
    try {
      final dStr = _formatDate(date);
      // If a completion already exists for this date, it's definitely tracked
      if (_completedDatesByActivity[activity.id]?.contains(dStr) == true) {
        return true;
      }

      final start = DateTime.tryParse(activity.startDate) ?? DateTime(2020);
      final dateOnlyVal = _dateOnly(date);
      final startOnlyVal = _dateOnly(start);

      // Allow backfilling: if within 30 days before start date, show scheduled
      if (dateOnlyVal.isBefore(startOnlyVal.subtract(const Duration(days: 30)))) {
        return false;
      }

      final durVal = activity.durationValue > 0 ? activity.durationValue : 12;
      DateTime endDate;
      if (activity.durationUnit == 'days') {
        endDate = startOnlyVal.add(Duration(days: durVal));
      } else if (activity.durationUnit == 'weeks') {
        endDate = startOnlyVal.add(Duration(days: durVal * 7));
      } else if (activity.durationUnit == 'years') {
        endDate = DateTime(startOnlyVal.year + durVal, startOnlyVal.month, startOnlyVal.day);
      } else {
        endDate = DateTime(startOnlyVal.year, startOnlyVal.month + durVal, startOnlyVal.day);
      }

      if (dateOnlyVal.isAfter(endDate)) return false;

      final freq = activity.frequency.toLowerCase();
      final freqVal = activity.frequencyValue > 0 ? activity.frequencyValue : 1;
      final freqUnit = activity.frequencyUnit.toLowerCase();

      if (freq == 'daily' || (freqUnit == 'days' && freqVal == 1)) {
        return true;
      }

      final daysDiff = dateOnlyVal.difference(startOnlyVal).inDays;
      if (freqUnit == 'weeks' || freq == 'weekly') {
        final step = freqVal * 7;
        return (daysDiff % step) == 0;
      } else if (freqUnit == 'days') {
        return (daysDiff % freqVal) == 0;
      }

      return true;
    } catch (_) {
      return true;
    }
  }

  List<String> _getCompletedActivitiesForDate(DateTime day) {
    final dStr = _formatDate(day);
    final completed = <String>[];
    for (final act in _userActivities) {
      if (_completedDatesByActivity[act.id]?.contains(dStr) == true) {
        completed.add(act.name);
      }
    }
    return completed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final range = _computeActiveRange();
    final today = _dateOnly(DateTime.now());
    final canGoNext = _currentEndDate.isBefore(today);

    final filteredActivities = _selectedGroup == 'All Groups'
        ? _userActivities
        : _userActivities.where((a) => a.groupName == _selectedGroup).toList();

    final groupedActivities = <String, List<Activity>>{};
    for (final act in filteredActivities) {
      final g = act.groupName.trim().isEmpty ? 'General' : act.groupName.trim();
      groupedActivities.putIfAbsent(g, () => []).add(act);
    }

    final dates = <DateTime>[];
    for (var d = range.start; !d.isAfter(range.end); d = d.add(const Duration(days: 1))) {
      dates.add(d);
    }

    int totalScheduled = 0;
    int totalCompleted = 0;
    for (final act in filteredActivities) {
      final compSet = _completedDatesByActivity[act.id] ?? {};
      for (final d in dates) {
        final dStr = _formatDate(d);
        final isDone = compSet.contains(dStr);
        final scheduled = isDone || _isScheduled(act, d);
        if (scheduled) {
          totalScheduled++;
          if (isDone) {
            totalCompleted++;
          }
        }
      }
    }
    final overallPct = totalScheduled > 0 ? ((totalCompleted / totalScheduled) * 100).round() : 0;
    final allGroups = {'All Groups', ..._userActivities.map((a) => a.groupName.trim().isEmpty ? 'General' : a.groupName.trim())}.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Matrix', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: _calendarExpanded ? 'Collapse Calendar' : 'Expand Calendar',
            icon: Icon(_calendarExpanded ? Icons.calendar_view_month_rounded : Icons.calendar_month_outlined),
            onPressed: () => setState(() => _calendarExpanded = !_calendarExpanded),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: (_loading && _userActivities.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  // 1. Interactive Calendar Card
                  _buildCalendarCard(theme, isDark),
                  const SizedBox(height: 16),

                  // 2. Selected Day Inspector (Instant check/uncheck for past dates like yesterday)
                  _buildDayInspectorCard(theme, isDark, filteredActivities),
                  const SizedBox(height: 16),

                  // 3. Filter Controls Card
                  _buildControlsCard(theme, isDark, range, canGoNext, allGroups),
                  const SizedBox(height: 16),

                  // 4. Overall Stats Grid
                  _buildStatsRow(theme, isDark, overallPct, totalCompleted, totalScheduled, filteredActivities.length),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.roseError.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.roseError.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.roseError),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.roseError, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 5. Progress Matrix Table
                  if (filteredActivities.isEmpty)
                    _buildEmptyState(isDark)
                  else ...[
                    NeumorphicCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Date × Habit Matrix',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              _buildLegend(isDark),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap today\'s cells to toggle habit completions. Previous days are locked.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
                          const SizedBox(height: 10),

                          _buildProgressTable(theme, isDark, groupedActivities, dates),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendarCard(ThemeData theme, bool isDark) {
    return NeumorphicCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Activity Calendar',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Row(
                children: [
                  // Format Selector (Month / 2-Weeks / Week)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFormatChip('2W', CalendarFormat.twoWeeks, isDark),
                        _buildFormatChip('M', CalendarFormat.month, isDark),
                        _buildFormatChip('W', CalendarFormat.week, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _calendarExpanded = !_calendarExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _calendarExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_calendarExpanded) ...[
            const SizedBox(height: 12),
            Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
            const SizedBox(height: 10),

            TableCalendar<String>(
              firstDay: DateTime(2022, 1, 1),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) => isSameDay(_selectedCalendarDay, day),
              eventLoader: _getCompletedActivitiesForDate,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedCalendarDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                weekendTextStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                todayTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                selectedDecoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF6366F1)],
                  ),
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                markerDecoration: const BoxDecoration(
                  color: AppColors.emeraldSuccess,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatChip(String label, CalendarFormat format, bool isDark) {
    final isSelected = _calendarFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _calendarFormat = format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildDayInspectorCard(ThemeData theme, bool isDark, List<Activity> activities) {
    final dayStr = _formatDate(_selectedCalendarDay);
    final today = _dateOnly(DateTime.now());
    final selectedOnly = _dateOnly(_selectedCalendarDay);
    final diffDays = selectedOnly.difference(today).inDays;

    String relativeText;
    if (diffDays == 0) {
      relativeText = 'Today';
    } else if (diffDays == -1) {
      relativeText = 'Yesterday';
    } else if (diffDays < -1) {
      relativeText = '${diffDays.abs()} days ago';
    } else {
      relativeText = 'In $diffDays days';
    }

    final formattedHeader = DateFormat('EEEE, MMM dd, yyyy').format(_selectedCalendarDay);
    final completedCount = activities.where((a) => _completedDatesByActivity[a.id]?.contains(dayStr) == true).length;
    final totalCount = activities.length;
    final pct = totalCount > 0 ? ((completedCount / totalCount) * 100).round() : 0;

    return NeumorphicCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          formattedHeader,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: diffDays == 0
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : (diffDays == -1 ? AppColors.emeraldSuccess.withValues(alpha: 0.15) : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFE2E8F0))),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (diffDays != 0) ...[
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                diffDays != 0 ? '$relativeText (Locked)' : relativeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: diffDays == 0 ? AppColors.primary : (diffDays == -1 ? AppColors.emeraldSuccess : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedCount of $totalCount completed ($pct%)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.today_rounded, size: 20),
                tooltip: 'Jump to Today',
                onPressed: () {
                  setState(() {
                    _selectedCalendarDay = today;
                    _focusedDay = today;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
          const SizedBox(height: 8),

          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No activities found for this filter.',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
            )
          else
            ...activities.map((act) {
              final isDone = _completedDatesByActivity[act.id]?.contains(dayStr) == true;
              final isSelectedToday = isSameDay(_selectedCalendarDay, DateTime.now());
              return InkWell(
                onTap: isSelectedToday
                    ? () => _toggleCellCompletion(act, _selectedCalendarDay)
                    : () => _showRestrictedDateMessage(_selectedCalendarDay),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Text(act.icon ?? '📌', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone
                                    ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                            Text(
                              act.groupName,
                              style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (!isSelectedToday)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.6) : AppColors.lightTextMuted.withValues(alpha: 0.6),
                          ),
                        ),
                      // Interactive checkbox for today, locked indicator for other dates
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isDone
                              ? (isSelectedToday ? AppColors.emeraldSuccess : AppColors.emeraldSuccess.withValues(alpha: 0.8))
                              : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDone
                                ? AppColors.emeraldSuccess
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: 1.5,
                          ),
                        ),
                        child: isDone
                            ? const Center(child: Icon(Icons.check_rounded, size: 16, color: Colors.white))
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildControlsCard(
    ThemeData theme,
    bool isDark,
    DateTimeRange range,
    bool canGoNext,
    List<String> allGroups,
  ) {
    final startFmt = DateFormat('MMM dd').format(range.start);
    final endFmt = DateFormat('MMM dd, yyyy').format(range.end);

    return NeumorphicCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Preset Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPreset,
                    dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    items: _rangePresets.map((preset) {
                      return DropdownMenuItem(value: preset, child: Text(preset));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _onPresetChanged(val);
                    },
                  ),
                ),
              ),

              // Group Filter Dropdown
              if (allGroups.length > 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGroup,
                      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      icon: const Icon(Icons.filter_list_rounded),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      items: allGroups.map((g) {
                        return DropdownMenuItem(value: g, child: Text(g));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedGroup = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Period Navigator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous period',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _navigatePeriod(-1),
                ),
                const Spacer(),
                const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '$startFmt – $endFmt',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_rangeDays days',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next period',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: canGoNext ? () => _navigatePeriod(1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    ThemeData theme,
    bool isDark,
    int overallPct,
    int totalCompleted,
    int totalScheduled,
    int totalActivities,
  ) {
    return Row(
      children: [
        Expanded(
          child: NeumorphicCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Range Score',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$overallPct%',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: overallPct >= 70 ? AppColors.emeraldSuccess : AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (overallPct >= 70 ? AppColors.emeraldSuccess : AppColors.primary).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        overallPct >= 70 ? Icons.trending_up_rounded : Icons.insights_rounded,
                        color: overallPct >= 70 ? AppColors.emeraldSuccess : AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: NeumorphicCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$totalCompleted / $totalScheduled',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.emeraldSuccess,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text('Done', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
        const SizedBox(width: 10),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
        const SizedBox(width: 4),
        Text('Missed', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
      ],
    );
  }

  Widget _buildProgressTable(
    ThemeData theme,
    bool isDark,
    Map<String, List<Activity>> groupedActivities,
    List<DateTime> dates,
  ) {
    final todayStr = _formatDate(_dateOnly(DateTime.now()));
    const double titleWidth = 140.0;
    const double colWidth = 32.0;

    return SingleChildScrollView(
      controller: _horizontalScrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Date Headers
          Row(
            children: [
              Container(
                width: titleWidth,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Text(
                  'Habit',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              ...dates.map((d) {
                final dStr = _formatDate(d);
                final isToday = dStr == todayStr;
                final isSelected = isSameDay(_selectedCalendarDay, d);
                final dayName = DateFormat('E').format(d).substring(0, 1);
                final dayNum = d.day.toString();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCalendarDay = d;
                      _focusedDay = d;
                    });
                  },
                  child: Container(
                    width: colWidth,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          )
                        : (isToday
                            ? BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              )
                            : null),
                    child: Column(
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                          ),
                        ),
                        Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday || isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? AppColors.primary : null),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),

          // Category Groups and Activities
          ...groupedActivities.entries.expand((entry) {
            final groupName = entry.key;
            final activities = entry.value;

            return [
              // Group Banner
              Container(
                width: titleWidth + (dates.length * colWidth),
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  groupName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // Activity Rows
              ...activities.map((act) {
                final compSet = _completedDatesByActivity[act.id] ?? {};

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0x10FFFFFF) : const Color(0x10000000),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Activity Title & Icon
                      SizedBox(
                        width: titleWidth,
                        child: Row(
                          children: [
                            Text(act.icon ?? '📌', style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                act.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Interactive Date Matrix Cells (Only today is interactive for toggling; past days are locked)
                      ...dates.map((d) {
                        final dStr = _formatDate(d);
                        final isToday = dStr == todayStr;
                        final isCompleted = compSet.contains(dStr);
                        final scheduled = isCompleted || _isScheduled(act, d);

                        return GestureDetector(
                          onTap: isToday
                              ? () => _toggleCellCompletion(act, d)
                              : () => _showRestrictedDateMessage(d),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: colWidth,
                            height: 28,
                            child: Center(
                              child: _buildMatrixCell(scheduled, isCompleted, isDark, isToday: isToday),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ];
          }),
        ],
      ),
    );
  }

  Widget _buildMatrixCell(bool isScheduled, bool isCompleted, bool isDark, {bool isToday = true}) {
    if (isCompleted) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isToday ? AppColors.emeraldSuccess : AppColors.emeraldSuccess.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: AppColors.emeraldSuccess.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: const Center(
          child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
        ),
      );
    }

    if (!isScheduled) {
      return Icon(
        Icons.remove_rounded,
        size: 14,
        color: isDark
            ? AppColors.darkTextMuted.withValues(alpha: 0.35)
            : AppColors.lightTextMuted.withValues(alpha: 0.35),
      );
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday
              ? (isDark ? AppColors.darkTextMuted.withValues(alpha: 0.8) : AppColors.lightTextMuted.withValues(alpha: 0.8))
              : (isDark ? AppColors.darkTextMuted.withValues(alpha: 0.35) : AppColors.lightTextMuted.withValues(alpha: 0.35)),
          width: isToday ? 1.8 : 1.2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return NeumorphicCard(
      padding: const EdgeInsets.all(32),
      borderRadius: 20,
      child: Column(
        children: [
          const Icon(Icons.show_chart_rounded, size: 48, color: AppColors.primary),
          const SizedBox(height: 14),
          const Text(
            'No Progress Data',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Add activities and mark them completed to see your historical matrix.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
