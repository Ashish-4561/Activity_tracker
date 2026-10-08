import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  String _selectedPreset = 'Last 7 Days';
  String _selectedGroup = 'All Groups';
  DateTimeRange? _customRange;
  late DateTime _currentEndDate;
  late int _rangeDays;

  bool _loading = true;
  String? _errorMessage;

  // Data cache
  List<Activity> _userActivities = [];
  Map<String, Set<String>> _completedDatesByActivity = {}; // activityId -> Set of YYYY-MM-DD

  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentEndDate = _dateOnly(DateTime.now());
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

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final range = _computeActiveRange();
    final fromStr = _formatDate(range.start);
    final toStr = _formatDate(range.end);

    final activityService = context.read<ActivityService>();

    try {
      final authService = context.read<AuthService>();
      final apiService = context.read<ApiService>();

      if (!authService.isLoggedIn || widget.previewMode) {
        _userActivities = activityService.activities;
        final history = activityService.getGuestCompletionHistory();
        final compMap = <String, Set<String>>{};
        for (final act in _userActivities) {
          compMap[act.id] = Set<String>.from(history[act.id] ?? <String>{});
        }
        _completedDatesByActivity = compMap;
      } else {
        final response = await apiService.getRangeProgress(
          from: fromStr,
          to: toStr,
          group: _selectedGroup == 'All Groups' ? null : _selectedGroup,
        );

        final actRes = await apiService.getActivities();
        final rawList = actRes['activities'] as List? ?? [];
        _userActivities = rawList.map((j) => Activity.fromJson(j)).toList();

        final compMap = <String, Set<String>>{};
        for (final act in _userActivities) {
          compMap[act.id] = {};
        }

        final completionsList = response['completion_history'] as List? ?? [];
        for (final c in completionsList) {
          if (c is Map && c['activity_id'] != null && c['date'] != null) {
            final actId = c['activity_id'].toString();
            final date = c['date'].toString().split('T').first;
            final isComp = c['completed'] == 1 || c['completed'] == true;
            if (isComp) {
              compMap.putIfAbsent(actId, () => {}).add(date);
            }
          }
        }
        _completedDatesByActivity = compMap;
      }
    } catch (e) {
      // Graceful fallback when backend is unreachable (e.g. mobile accessing localhost:5000)
      _userActivities = activityService.activities;
      final history = activityService.getGuestCompletionHistory();
      final compMap = <String, Set<String>>{};
      for (final act in _userActivities) {
        compMap[act.id] = Set<String>.from(history[act.id] ?? <String>{});
        if (act.isCompleted) {
          compMap[act.id]!.add(_formatDate(_dateOnly(DateTime.now())));
        }
      }
      _completedDatesByActivity = compMap;
      _errorMessage = null;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isScheduled(Activity activity, DateTime date) {
    try {
      final start = DateTime.tryParse(activity.startDate) ?? DateTime(2020);
      final dateOnlyVal = _dateOnly(date);
      final startOnlyVal = _dateOnly(start);

      if (dateOnlyVal.isBefore(startOnlyVal)) return false;

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
        if (_isScheduled(act, d)) {
          totalScheduled++;
          if (compSet.contains(_formatDate(d))) {
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
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Filter Controls Card
                  _buildControlsCard(theme, isDark, range, canGoNext, allGroups),
                  const SizedBox(height: 16),

                  // Overall Stats Grid
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

                  // Progress Matrix Table
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
                                    'Date × Habit History',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              _buildLegend(isDark),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                  'Total Checks',
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.cyanAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.cyanAccent,
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
        _legendItem('Done', AppColors.emeraldSuccess, icon: Icons.check_rounded),
        const SizedBox(width: 8),
        _legendItem('Missed', isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, icon: Icons.circle_outlined),
        const SizedBox(width: 8),
        _legendItem('Off', isDark ? AppColors.darkBorder : AppColors.lightBorder, icon: Icons.remove_rounded),
      ],
    );
  }

  Widget _legendItem(String label, Color color, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTable(
    ThemeData theme,
    bool isDark,
    Map<String, List<Activity>> groupedActivities,
    List<DateTime> dates,
  ) {
    const double colWidth = 42.0;
    const double titleWidth = 140.0;
    final todayStr = _formatDate(_dateOnly(DateTime.now()));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              SizedBox(
                width: titleWidth,
                child: const Text(
                  'Habit',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              ...dates.map((d) {
                final dStr = _formatDate(d);
                final isToday = dStr == todayStr;
                final dayName = DateFormat('E').format(d).substring(0, 1);
                final dayNum = d.day.toString();

                return Container(
                  width: colWidth,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: isToday
                      ? BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        )
                      : null,
                  child: Column(
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isToday ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      ),
                      Text(
                        dayNum,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                          color: isToday ? AppColors.primary : null,
                        ),
                      ),
                    ],
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

                      // Date Matrix Cells
                      ...dates.map((d) {
                        final dStr = _formatDate(d);
                        final scheduled = _isScheduled(act, d);
                        final completed = scheduled && compSet.contains(dStr);

                        return SizedBox(
                          width: colWidth,
                          height: 28,
                          child: Center(
                            child: _buildMatrixCell(scheduled, completed, isDark),
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

  Widget _buildMatrixCell(bool isScheduled, bool isCompleted, bool isDark) {
    if (!isScheduled) {
      return Icon(
        Icons.remove_rounded,
        size: 14,
        color: isDark
            ? AppColors.darkTextMuted.withValues(alpha: 0.35)
            : AppColors.lightTextMuted.withValues(alpha: 0.35),
      );
    }

    if (isCompleted) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.emeraldSuccess,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: AppColors.emeraldSuccess.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
        ),
      );
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.5) : AppColors.lightTextMuted.withValues(alpha: 0.5),
          width: 1.5,
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
