import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/activity_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/neumorphic_card.dart';

/// A modern soft neomorphic activity card displayed inside the group activities list.
/// Shows: icon · name · frequency · individual progress bar · current streak · checkbox · three-dot menu.
class ActivityCard extends StatelessWidget {
  final Activity activity;
  final int? progressOverride;

  const ActivityCard({
    super.key,
    required this.activity,
    this.progressOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<ActivityService>(
      builder: (context, service, _) {
        final pct = progressOverride ?? service.activityProgress(activity.id);
        final completionPct = activity.isCompleted ? 100 : pct;
        final streak = service.activityStreak(activity.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: NeumorphicCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: 18,
            isSelected: activity.isCompleted,
            border: activity.isCompleted
                ? Border.all(
                    color: AppColors.emeraldSuccess.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
            onTap: () => _showActivityDetails(context, activity, service),
            child: Row(
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
                      activity.icon ?? '📌',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + Frequency/Streak + Progress bar
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
                                color: activity.isCompleted
                                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            _frequencyLabel(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (streak > 0) ...[
                            const SizedBox(width: 8),
                            Container(
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
                            ),
                          ],
                        ],
                      ),
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
                        Text('Details & History'),
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
          ),
        );
      },
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                        '${activity.groupName} • ${_frequencyLabel()}',
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
            const SizedBox(height: 24),

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

            const SizedBox(height: 24),

            // Toggle Button
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

/// Inline soft neomorphic edit sheet for an existing activity.
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
  late String _frequencyUnit;
  late String _durationUnit;
  late String? _selectedIcon;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activity.name);
    _groupController = TextEditingController(text: widget.activity.groupName);
    _frequencyController =
        TextEditingController(text: widget.activity.frequencyValue.toString());
    _durationController =
        TextEditingController(text: widget.activity.durationValue.toString());
    _frequencyUnit = widget.activity.frequencyUnit;
    _durationUnit = widget.activity.durationUnit;
    _selectedIcon = widget.activity.icon;
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
      await context.read<ActivityService>().updateActivity(
        id: widget.activity.id,
        name: name,
        groupName: _groupController.text.trim().isEmpty
            ? 'General'
            : _groupController.text.trim(),
        icon: _selectedIcon,
        frequencyValue: frequencyValue,
        frequencyUnit: _frequencyUnit,
        durationValue: durationValue,
        durationUnit: _durationUnit,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity updated')),
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

            // Icon selector button
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _selectedIcon ?? '📌',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Tap to change icon',
                style: theme.textTheme.bodySmall,
              ),
            ),

            if (_showEmojiPicker) ...[
              const SizedBox(height: 12),
              Container(
                height: 140,
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
                      child: Text(emojis[i], style: const TextStyle(fontSize: 24)),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _frequencyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Every',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _frequencyUnit,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'days', child: Text('Days')),
                      DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
                      DropdownMenuItem(value: 'months', child: Text('Months')),
                    ],
                    onChanged: (v) => setState(() => _frequencyUnit = v ?? _frequencyUnit),
                  ),
                ),
              ],
            ),
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
}
