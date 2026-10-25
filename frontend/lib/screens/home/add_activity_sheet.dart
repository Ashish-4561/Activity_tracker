import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/activity_service.dart';
import '../../services/theme_service.dart';

// Curated list of common activity emojis.
const _kEmojis = [
  '🏋️', '📚', '💧', '🏃', '🧘', '🍎', '😴', '💊', '🚴', '🎯',
  '✍️', '🎨', '🎸', '🎹', '📖', '🧹', '🌿', '🧠', '💻', '📝',
  '🏊', '⚽', '🏀', '🎾', '🥗', '🫁', '🦷', '🛁', '🐕', '🌞',
  '🧘‍♂️', '🤸', '🏄', '🚶', '🎭', '🍵', '☕', '🥤', '🎬', '📷',
  '🎮', '📱', '💰', '📊', '🌍', '🌱', '🕯️', '🧗', '🛌', '❤️',
];

const _kDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class AddActivitySheet extends StatefulWidget {
  final String? initialGroupName;

  const AddActivitySheet({super.key, this.initialGroupName});

  @override
  State<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<AddActivitySheet> {
  final _nameController = TextEditingController();
  final _frequencyController = TextEditingController(text: '1');
  final _durationController = TextEditingController(text: '3');
  late final TextEditingController _groupController;

  String _activityType = 'scheduled'; // 'scheduled', 'duration', 'flexible'
  String _frequencyUnit = 'days';
  final String _durationUnit = 'months';
  String? _selectedIcon;
  DateTime _startDate = DateTime.now();
  bool _showEmojiPicker = false;
  bool _isSubmitting = false;

  // Scheduled fields
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final Set<int> _repeatDays = {1, 2, 3, 4, 5, 6, 7}; // 1 = Mon ... 7 = Sun
  bool _remindersEnabled = true;
  int _reminderMinutesBefore = 10;
  bool _reminderAtEnd = true;

  // Duration fields
  int _targetHours = 2;
  int _targetMinutes = 0;
  TimeOfDay _incompleteReminderTime = const TimeOfDay(hour: 20, minute: 0);

  // Flexible fields
  TimeOfDay _flexibleReminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _groupController = TextEditingController(
      text: widget.initialGroupName ?? 'General',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _groupController.dispose();
    super.dispose();
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

  Future<void> _handleAddActivity() async {
    if (_isSubmitting) return;

    final name = _nameController.text.trim();
    final frequencyValue = int.tryParse(_frequencyController.text);
    final durationValue = int.tryParse(_durationController.text);

    if (name.isEmpty) {
      _showError('Please enter an activity name');
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

    if (_activityType == 'scheduled' && _repeatDays.isEmpty) {
      _showError('Please select at least one repeat day');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? startTimeStr;
      String? endTimeStr;
      List<int>? repDays;
      int? targetDur;
      bool reminders = _remindersEnabled;
      int reminderBefore = _reminderMinutesBefore;
      bool reminderEnd = _reminderAtEnd;

      if (_activityType == 'scheduled') {
        startTimeStr = _timeOfDayToHHMM(_startTime);
        endTimeStr = _timeOfDayToHHMM(_endTime);
        repDays = _repeatDays.toList()..sort();
      } else if (_activityType == 'duration') {
        targetDur = (_targetHours * 60) + _targetMinutes;
        if (targetDur <= 0) targetDur = 60; // minimum 1 hour default
        startTimeStr = _timeOfDayToHHMM(_incompleteReminderTime); // incomplete reminder time
        repDays = [1, 2, 3, 4, 5, 6, 7];
        reminderEnd = false;
      } else {
        // flexible
        startTimeStr = reminders ? _timeOfDayToHHMM(_flexibleReminderTime) : null;
        repDays = [1, 2, 3, 4, 5, 6, 7];
        reminderEnd = false;
      }

      await context.read<ActivityService>().addActivity(
        name: name,
        frequency: 'custom',
        groupName: _groupController.text.trim().isEmpty ? 'General' : _groupController.text.trim(),
        icon: _selectedIcon ?? (_activityType == 'scheduled' ? '🕒' : (_activityType == 'duration' ? '⏳' : '🎯')),
        frequencyValue: frequencyValue,
        frequencyUnit: _frequencyUnit,
        durationValue: durationValue,
        durationUnit: _durationUnit,
        startDate: _startDate.toIso8601String().split('T').first,
        activityType: _activityType,
        startTime: startTimeStr,
        endTime: endTimeStr,
        repeatDays: repDays,
        targetDurationMinutes: targetDur,
        remindersEnabled: reminders,
        reminderMinutesBefore: reminderBefore,
        reminderAtEnd: reminderEnd,
      );

      if (mounted && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity added successfully')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to add activity: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
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
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _groupController.text.trim().isNotEmpty
                          ? 'Add to "${_groupController.text.trim()}"'
                          : 'Create Activity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Activity Type Selector
              _sectionLabel(context, 'Activity Type'),
              const SizedBox(height: 8),
              _buildTypeSelector(isDark),
              const SizedBox(height: 18),

              // Icon Picker Row
              _sectionLabel(context, 'Choose Icon'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedIcon ?? (_activityType == 'scheduled' ? '🕒' : (_activityType == 'duration' ? '⏳' : '🎯')),
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _selectedIcon == null ? 'Tap to choose an emoji' : 'Change icon',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showEmojiPicker
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showEmojiPicker) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kEmojis.map((emoji) {
                      final isSelected = _selectedIcon == emoji;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedIcon = emoji;
                          _showEmojiPicker = false;
                        }),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Activity Name
              _sectionLabel(context, 'Activity Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: _activityType == 'scheduled'
                      ? 'e.g., Morning Run, Team Standup, Gym'
                      : (_activityType == 'duration'
                          ? 'e.g., Study Flutter, Read Books, Deep Work'
                          : 'e.g., Drink Water, Meditate, Journal'),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Type-Specific Fields
              if (_activityType == 'scheduled') ...[
                _buildScheduledFields(isDark),
              ] else if (_activityType == 'duration') ...[
                _buildDurationFields(isDark),
              ] else ...[
                _buildFlexibleFields(isDark),
              ],

              const SizedBox(height: 18),

              // Frequency & Cadence (Common)
              _sectionLabel(context, 'Frequency & Cadence'),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: const Text('Every', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 76,
                  child: TextField(
                    controller: _frequencyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _frequencyUnit,
                    dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'days', child: Text('Days')),
                      DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
                      DropdownMenuItem(value: 'months', child: Text('Months')),
                    ],
                    onChanged: (value) =>
                        setState(() => _frequencyUnit = value ?? 'days'),
                  ),
                ),
              ]),
              const SizedBox(height: 18),

              // Start Date
              _sectionLabel(context, 'Start Date'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                  '${_startDate.day.toString().padLeft(2, '0')} / ${_startDate.month.toString().padLeft(2, '0')} / ${_startDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
              ),
              const SizedBox(height: 18),

              // Group Name
              _sectionLabel(context, 'Group Category'),
              const SizedBox(height: 8),
              TextField(
                controller: _groupController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'e.g. STUDY, HEALTH, WORK, PERSONAL',
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  suffixIcon: Icon(
                    Icons.folder_open_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _handleAddActivity,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create ${_activityType == "scheduled" ? "Scheduled Activity" : (_activityType == "duration" ? "Duration Goal" : "Flexible Activity")}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Dynamic Sub-Views ---

  Widget _buildTypeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _typeOption('scheduled', 'Scheduled', Icons.schedule_rounded, isDark),
          _typeOption('duration', 'Duration Goal', Icons.hourglass_bottom_rounded, isDark),
          _typeOption('flexible', 'Flexible', Icons.check_circle_outline_rounded, isDark),
        ],
      ),
    );
  }

  Widget _typeOption(String type, String label, IconData icon, bool isDark) {
    final isSelected = _activityType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activityType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkSurface : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledFields(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Activity Time Window'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTimePickerTile(
                title: 'Start Time',
                time: _startTime,
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _startTime);
                  if (picked != null) setState(() => _startTime = picked);
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimePickerTile(
                title: 'End Time',
                time: _endTime,
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _endTime);
                  if (picked != null) setState(() => _endTime = picked);
                },
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _sectionLabel(context, 'Repeat Days'),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final dayNumber = index + 1; // 1 = Mon ... 7 = Sun
            final isSelected = _repeatDays.contains(dayNumber);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    if (_repeatDays.length > 1) _repeatDays.remove(dayNumber);
                  } else {
                    _repeatDays.add(dayNumber);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Center(
                  child: Text(
                    _kDayNames[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),

        // Reminders Box
        _buildRemindersContainer(
          isDark: isDark,
          title: 'Reminders & Notifications',
          enabled: _remindersEnabled,
          onToggle: (val) => setState(() => _remindersEnabled = val),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Remind before start',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                DropdownButton<int>(
                  value: _reminderMinutesBefore,
                  dropdownColor: isDark ? AppColors.darkSurfaceRaised : Colors.white,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('At start time')),
                    DropdownMenuItem(value: 5, child: Text('5 mins before')),
                    DropdownMenuItem(value: 10, child: Text('10 mins before')),
                    DropdownMenuItem(value: 15, child: Text('15 mins before')),
                    DropdownMenuItem(value: 30, child: Text('30 mins before')),
                    DropdownMenuItem(value: 60, child: Text('1 hour before')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _reminderMinutesBefore = val);
                  },
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Remind at activity end',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Switch(
                  value: _reminderAtEnd,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _reminderAtEnd = val),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationFields(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Daily Duration Target'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hours Picker
                  _durationCounter(
                    label: 'Hours',
                    value: _targetHours,
                    min: 0,
                    max: 23,
                    onChanged: (val) {
                      setState(() {
                        _targetHours = val;
                        if (_targetHours == 0 && _targetMinutes == 0) _targetMinutes = 15;
                      });
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 24),
                  const Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 24),
                  // Minutes Picker
                  _durationCounter(
                    label: 'Minutes',
                    value: _targetMinutes,
                    step: 15,
                    min: 0,
                    max: 45,
                    onChanged: (val) {
                      setState(() {
                        _targetMinutes = val;
                        if (_targetHours == 0 && _targetMinutes == 0) _targetMinutes = 15;
                      });
                    },
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Daily Goal: ${_targetHours}h ${_targetMinutes.toString().padLeft(2, '0')}m (supports multiple sessions)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Incomplete Reminder Box
        _buildRemindersContainer(
          isDark: isDark,
          title: 'Daily Progress Reminder',
          enabled: _remindersEnabled,
          onToggle: (val) => setState(() => _remindersEnabled = val),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Remind if goal incomplete at',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(_formatTime(_incompleteReminderTime)),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _incompleteReminderTime,
                    );
                    if (picked != null) setState(() => _incompleteReminderTime = picked);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlexibleFields(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Flexible activities can be checked off anytime, or timed optionally with the built-in stopwatch.',
                  style: TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _buildRemindersContainer(
          isDark: isDark,
          title: 'Optional Daily Reminder',
          enabled: _remindersEnabled,
          onToggle: (val) => setState(() => _remindersEnabled = val),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Reminder Time',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(_formatTime(_flexibleReminderTime)),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _flexibleReminderTime,
                    );
                    if (picked != null) setState(() => _flexibleReminderTime = picked);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _durationCounter({
    required String label,
    required int value,
    int step = 1,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: value > min ? () => onChanged(value - step) : null,
              iconSize: 22,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: value < max ? () => onChanged(value + step) : null,
              iconSize: 22,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePickerTile({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _formatTime(time),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersContainer({
    required bool isDark,
    required String title,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    enabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                    color: enabled ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              Switch(
                value: enabled,
                activeThumbColor: AppColors.primary,
                onChanged: onToggle,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
      );
}
