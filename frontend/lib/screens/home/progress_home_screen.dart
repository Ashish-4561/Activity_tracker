import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/activity_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../widgets/daytrack_logo.dart';
import '../../widgets/neumorphic_card.dart';
import '../../widgets/progress_ring.dart';
import '../profile/profile_screen.dart';
import '../auth/login_screen.dart';
import 'activity_card.dart';
import 'add_activity_sheet.dart';

class ProgressHomeScreen extends StatefulWidget {
  final bool previewMode;

  const ProgressHomeScreen({super.key, this.previewMode = false});

  @override
  State<ProgressHomeScreen> createState() => _ProgressHomeScreenState();
}

class _ProgressHomeScreenState extends State<ProgressHomeScreen> {
  /// Selected group name. `null` means "All".
  String? _selectedGroup;

  /// Selected period filter
  String _selectedPeriod = 'Today';
  DateTimeRange? _customDateRange;

  /// Cached range progress data when a non-Today period is selected
  Map<String, dynamic>? _rangeData;

  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'Custom Range',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.previewMode) return;
      final service = context.read<ActivityService>();
      service.fetchActivities();
      service.fetchDailyProgress();
    });
  }

  Future<void> _onPeriodChanged(String period) async {
    if (period == 'Custom Range') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customDateRange ??
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      );
      if (picked == null) return;
      setState(() {
        _selectedPeriod = period;
        _customDateRange = picked;
      });
    } else {
      setState(() {
        _selectedPeriod = period;
      });
    }

    await _fetchPeriodData();
  }

  Future<void> _fetchPeriodData() async {
    if (_selectedPeriod == 'Today' || widget.previewMode) {
      setState(() {
        _rangeData = null;
      });
      return;
    }

    final service = context.read<ActivityService>();
    final range = service.getRangeForPeriod(_selectedPeriod, customRange: _customDateRange);
    final fromStr = DateFormat('yyyy-MM-dd').format(range.start);
    final toStr = DateFormat('yyyy-MM-dd').format(range.end);

    try {
      final apiService = context.read<ApiService>();
      final data = await apiService.getRangeProgress(
        from: fromStr,
        to: toStr,
        group: _selectedGroup,
      );
      if (mounted) {
        setState(() {
          _rangeData = data;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rangeData = null;
        });
      }
    }
  }

  Future<void> _selectGroup(String? group) async {
    if (_selectedGroup == group) return;
    setState(() {
      _selectedGroup = group;
    });
    if (_selectedPeriod != 'Today') {
      await _fetchPeriodData();
    }
  }

  void _confirmDeleteGroup(BuildContext context, String groupName) {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<ActivityService>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Group "$groupName"?'),
        content: Text(
          'Are you sure you want to delete the group "$groupName" and all of its activities? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.roseError,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await service.deleteGroup(groupName);
                if (mounted && _selectedGroup == groupName) {
                  setState(() {
                    _selectedGroup = null;
                  });
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('Group "$groupName" deleted')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete group: $e'),
                    backgroundColor: AppColors.roseError,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRenameGroupDialog(BuildContext context, String currentGroupName) {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<ActivityService>();
    final controller = TextEditingController(text: currentGroupName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter a new name for "$currentGroupName":'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'New group name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              if (newName == currentGroupName) {
                Navigator.pop(dialogContext);
                return;
              }
              Navigator.pop(dialogContext);
              try {
                await service.renameGroup(currentGroupName, newName);
                if (mounted && _selectedGroup == currentGroupName) {
                  setState(() {
                    _selectedGroup = newName;
                  });
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('Renamed group to "$newName"')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to rename group: $e'),
                    backgroundColor: AppColors.roseError,
                  ),
                );
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showManageGroupsSheet(BuildContext context, Map<String, List<Activity>> allGroups) {
    final groupNames = allGroups.keys.toList();
    if (groupNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No groups available to adjust.')),
      );
      return;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedForDeletion = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allSelected = selectedForDeletion.length == groupNames.length && groupNames.isNotEmpty;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Adjust & Manage Groups',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  'Check groups to delete or rename them',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Select All / Deselect Toolbar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: allSelected,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              onChanged: (bool? value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selectedForDeletion.addAll(groupNames);
                                  } else {
                                    selectedForDeletion.clear();
                                  }
                                });
                              },
                            ),
                            Text(
                              allSelected ? 'Deselect All' : 'Select All (${groupNames.length})',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const Spacer(),
                            if (selectedForDeletion.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.roseError.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${selectedForDeletion.length} checked',
                                  style: const TextStyle(
                                    color: AppColors.roseError,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Group list with checkboxes
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: groupNames.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final gName = groupNames[index];
                            final acts = allGroups[gName] ?? [];
                            final isChecked = selectedForDeletion.contains(gName);

                            return Container(
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? (isDark
                                        ? AppColors.roseError.withValues(alpha: 0.12)
                                        : const Color(0xFFFFF1F2))
                                    : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isChecked
                                      ? AppColors.roseError.withValues(alpha: 0.5)
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: isChecked ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: Checkbox(
                                  value: isChecked,
                                  activeColor: AppColors.roseError,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (bool? val) {
                                    setSheetState(() {
                                      if (val == true) {
                                        selectedForDeletion.add(gName);
                                      } else {
                                        selectedForDeletion.remove(gName);
                                      }
                                    });
                                  },
                                ),
                                title: Text(
                                  gName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isChecked ? AppColors.roseError : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${acts.length} ${acts.length == 1 ? 'activity' : 'activities'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      ),
                                      tooltip: 'Rename "$gName"',
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        _showRenameGroupDialog(context, gName);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.roseError,
                                      ),
                                      tooltip: 'Delete "$gName"',
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        _confirmDeleteGroup(context, gName);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setSheetState(() {
                                    if (isChecked) {
                                      selectedForDeletion.remove(gName);
                                    } else {
                                      selectedForDeletion.add(gName);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: selectedForDeletion.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      _confirmDeleteMultipleGroups(context, selectedForDeletion.toList());
                                    },
                              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                              label: Text(
                                selectedForDeletion.isEmpty
                                    ? 'Delete Checked'
                                    : 'Delete Checked (${selectedForDeletion.length})',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.roseError,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteMultipleGroups(BuildContext context, List<String> groupsToDelete) {
    if (groupsToDelete.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<ActivityService>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${groupsToDelete.length} ${groupsToDelete.length == 1 ? 'Group' : 'Groups'}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete the following ${groupsToDelete.length == 1 ? 'group and all of its activities' : 'groups and all of their activities'}?',
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceRaised
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView(
                shrinkWrap: true,
                children: groupsToDelete
                    .map(
                      (g) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.label_outline_rounded, size: 14, color: AppColors.roseError),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                g,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontSize: 12, color: AppColors.roseError, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.roseError,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                for (final gName in groupsToDelete) {
                  await service.deleteGroup(gName);
                }
                if (mounted && groupsToDelete.contains(_selectedGroup)) {
                  setState(() {
                    _selectedGroup = null;
                  });
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Deleted ${groupsToDelete.length} ${groupsToDelete.length == 1 ? 'group' : 'groups'}',
                    ),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete groups: $e'),
                    backgroundColor: AppColors.roseError,
                  ),
                );
              }
            },
            child: Text('Delete (${groupsToDelete.length})'),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser?.name ?? 'Guest';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (!widget.previewMode) {
              final svc = context.read<ActivityService>();
              svc.checkDayRollover();
              await svc.fetchActivities();
              await svc.fetchDailyProgress();
              if (_selectedPeriod != 'Today') {
                await _fetchPeriodData();
              }
            }
          },
          child: Consumer<ActivityService>(
            builder: (context, service, _) {
              // Build group map from all activities
              final allGroups = <String, List<Activity>>{};
              for (final activity in service.activities) {
                allGroups.putIfAbsent(activity.groupName, () => []).add(activity);
              }
              final groupNames = allGroups.keys.toList();

              // Validate selected group
              if (_selectedGroup != null && !groupNames.contains(_selectedGroup)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedGroup = null);
                });
              }

              // Determine activities to display
              final List<Activity> displayActivities;
              if (_selectedGroup == null) {
                displayActivities = service.activities;
              } else {
                displayActivities = allGroups[_selectedGroup!] ?? [];
              }

              // Calculate progress for current context
              final int completedCount;
              final int totalCount;
              final int progressPct;

              if (_selectedPeriod != 'Today' && _rangeData != null) {
                completedCount = _rangeData!['completed'] as int? ?? 0;
                totalCount = _rangeData!['total'] as int? ?? 0;
                progressPct = _rangeData!['percentage'] as int? ?? 0;
              } else {
                completedCount = displayActivities.where((a) => a.isCompleted).length;
                totalCount = displayActivities.length;
                progressPct = totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round();
              }

              final remainingCount = totalCount > completedCount ? totalCount - completedCount : 0;

              // Other groups list when a single group is selected
              final otherGroupNames = _selectedGroup == null
                  ? <String>[]
                  : groupNames.where((g) => g != _selectedGroup).toList();

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      // ── Top Brand Header & Profile ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const DayTrackLogo(
                            variant: DayTrackLogoVariant.horizontal,
                            iconSize: 36,
                            size: 19,
                            showTagline: true,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (auth.isGuest) ...[
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.login_rounded, size: 16),
                                  label: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                tooltip: 'Profile & Settings',
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  ),
                                  child: const Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
                                ),
                                onPressed: () => _showProfileMenu(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Greeting Row ───────────────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, $userName',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, MMMM d').format(DateTime.now()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                  // ── Guest Trial Status Banner ──────────────────────────────
                  if (auth.isGuest) ...[
                    NeumorphicCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: 16,
                      color: isDark ? const Color(0xFF161A2B) : const Color(0xFFEEF2FF),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.cloud_queue_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.isTrialExpired
                                      ? 'Guest Trial Expired'
                                      : 'Guest Trial • ${auth.guestTrialDaysRemaining} Days Left',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                Text(
                                  'Sync habits & progress to your encrypted cloud',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Log In / Sync', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ── Hero Section: Neumorphic Progress Ring ─────────────────
                  NeumorphicCard(
                    padding: const EdgeInsets.all(22),
                    borderRadius: 24,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedGroup ?? 'All Activities',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${displayActivities.length} habits • ${_periodSubtitle(_selectedPeriod)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            _buildPeriodFilter(context),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Center Progress Ring
                        ProgressRing(
                          percentage: progressPct.toDouble(),
                          completedCount: completedCount,
                          totalCount: totalCount,
                          size: 190,
                          strokeWidth: 16,
                          subtitle: remainingCount > 0 ? '$remainingCount remaining' : 'All done today!',
                        ),
                        const SizedBox(height: 18),

                        // Subtitle status pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: progressPct >= 100
                                ? AppColors.emeraldSuccess.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (progressPct >= 100) ...[
                                const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.emeraldSuccess),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                progressPct >= 100
                                    ? 'All daily targets achieved!'
                                    : '$completedCount of $totalCount habits finished today',
                                style: TextStyle(
                                  color: progressPct >= 100 ? AppColors.emeraldSuccess : AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Group Selector Filter Chips ────────────────────────────
                  _buildGroupSelector(context, groupNames, allGroups),
                  const SizedBox(height: 20),

                  // ── Activities Header ──────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Activities',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Text(
                          '${displayActivities.length} total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Activities List
                  if (service.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (displayActivities.isEmpty)
                    _buildEmptyActivities(context, _selectedGroup)
                  else
                    ...displayActivities.map(
                      (activity) => ActivityCard(
                        key: ValueKey(activity.id),
                        activity: activity,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // "+ Add Activity" Neumorphic Button
                  FilledButton.icon(
                    onPressed: () => _showAdd(context, _selectedGroup),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      _selectedGroup != null
                          ? 'Add Activity to ${_selectedGroup!}'
                          : 'Add New Habit',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                  // ── Other Groups Section ──────────────────────────────────
                  if (otherGroupNames.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Other Groups',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showManageGroupsSheet(context, allGroups),
                          icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                          label: const Text(
                            'Adjust Groups',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    NeumorphicCard(
                      padding: EdgeInsets.zero,
                      borderRadius: 20,
                      child: Column(
                        children: otherGroupNames.map((otherName) {
                          final otherActs = allGroups[otherName] ?? [];
                          final otherCompleted = otherActs.where((a) => a.isCompleted).length;
                          final otherTotal = otherActs.length;
                          final otherPct = otherTotal == 0
                              ? 0
                              : ((otherCompleted / otherTotal) * 100).round();

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                              child: Center(
                                child: Text(
                                  otherName.isNotEmpty ? otherName.substring(0, 1).toUpperCase() : 'G',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              otherName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${otherActs.length} ${otherActs.length == 1 ? 'activity' : 'activities'} • $otherPct%',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$otherPct%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                  tooltip: 'Rename "$otherName"',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showRenameGroupDialog(context, otherName),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AppColors.roseError,
                                  ),
                                  tooltip: 'Delete "$otherName"',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmDeleteGroup(context, otherName),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, size: 20),
                              ],
                            ),
                            onTap: () => _selectGroup(otherName),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  ),
);
}

  Widget _buildPeriodFilter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      onSelected: _onPeriodChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      itemBuilder: (context) => _periods.map((period) {
        final isSelected = _selectedPeriod == period;
        return PopupMenuItem<String>(
          value: period,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 18,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              const SizedBox(width: 10),
              Text(
                period,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              _selectedPeriod,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector(
    BuildContext context,
    List<String> groupNames,
    Map<String, List<Activity>> allGroups,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "All" chip
          _buildGroupChip(
            context: context,
            title: 'All',
            isSelected: _selectedGroup == null,
            onTap: () => _selectGroup(null),
          ),

          // Group chips
          ...groupNames.map((name) {
            final isSelected = _selectedGroup == name;
            return _buildGroupChip(
              context: context,
              title: name,
              isSelected: isSelected,
              onTap: () => _selectGroup(isSelected ? null : name),
              onLongPress: () => _showGroupQuickOptions(context, name, allGroups),
            );
          }),

          // "+" Add group / activity chip
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showAdd(context, null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'New Group',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // "Adjust" / Manage Groups chip with checking to delete
          if (groupNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showManageGroupsSheet(context, allGroups),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 15, color: AppColors.primary),
                      SizedBox(width: 5),
                      Text(
                        'Adjust',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showGroupQuickOptions(
    BuildContext context,
    String groupName,
    Map<String, List<Activity>> allGroups,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Group: "$groupName"',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const Divider(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Rename Group', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showRenameGroupDialog(context, groupName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.roseError),
                title: const Text('Delete Group', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.roseError)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmDeleteGroup(context, groupName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded, color: AppColors.primary),
                title: const Text('Adjust All Groups (Multi-select Delete)', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showManageGroupsSheet(context, allGroups);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupChip({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivities(BuildContext context, String? groupName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NeumorphicCard(
      padding: const EdgeInsets.all(32),
      borderRadius: 20,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined, size: 42, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            groupName != null ? 'No activities in $groupName' : 'No activities yet',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your first daily habit to start building streaks and tracking progress.',
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

  String _periodSubtitle(String period) {
    if (period == 'Today') return 'today';
    if (period == 'This Week') return 'this week';
    if (period == 'This Month') return 'this month';
    if (period == 'This Year') return 'this year';
    return 'in period';
  }

  void _showAdd(BuildContext context, String? groupName) {
    final authService = context.read<AuthService>();
    if (authService.isGuest && authService.isTrialExpired) {
      AuthPromptDialog.show(
        context,
        title: 'Trial Expired',
        message: 'Your 2-day guest trial has expired. Create an account or log in to create and save new activities.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddActivitySheet(initialGroupName: groupName),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final authService = context.read<AuthService>();
    final isGuest = authService.isGuest;

    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 56, 16, 0),
      items: [
        PopupMenuItem(
          onTap: () {
            Future.microtask(() {
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(previewMode: widget.previewMode),
                  ),
                );
              }
            });
          },
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 18),
              const SizedBox(width: 10),
              Text(isGuest ? 'Guest Profile & Settings' : 'Profile & Settings'),
            ],
          ),
        ),
        if (isGuest)
          PopupMenuItem(
            onTap: () {
              Future.microtask(() {
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              });
            },
            child: const Row(
              children: [
                Icon(Icons.login_rounded, size: 18, color: AppColors.cyanAccent),
                SizedBox(width: 10),
                Text('Log In / Create Account', style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        else
          PopupMenuItem(
            onTap: () async {
              await context.read<AuthService>().logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out. You are now in Guest Mode.')),
                );
              }
            },
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, size: 18, color: AppColors.roseError),
                SizedBox(width: 10),
                Text('Sign Out', style: TextStyle(color: AppColors.roseError)),
              ],
            ),
          ),
      ],
    );
  }
}
