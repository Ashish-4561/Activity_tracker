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

class AddActivitySheet extends StatefulWidget {
  /// When provided, the group field is pre-filled and locked to this value.
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
  String _frequencyUnit = 'days';
  String _durationUnit = 'months';
  String? _selectedIcon;
  DateTime _startDate = DateTime.now();
  bool _showEmojiPicker = false;
  bool _isSubmitting = false;

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

    setState(() => _isSubmitting = true);

    try {
      await context.read<ActivityService>().addActivity(
        name: name,
        frequency: 'custom',
        groupName: _groupController.text.trim().isEmpty
            ? 'General'
            : _groupController.text.trim(),
        icon: _selectedIcon,
        frequencyValue: frequencyValue,
        frequencyUnit: _frequencyUnit,
        durationValue: durationValue,
        durationUnit: _durationUnit,
        startDate: _startDate.toIso8601String().split('T').first,
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
                          : 'Create New Habit',
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
                        _selectedIcon ?? '📌',
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
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g., Coding, Meditation, Gym',
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

              // Frequency
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

              // Duration
              _sectionLabel(context, 'Activity Duration Target'),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(
                  width: 76,
                  child: TextField(
                    controller: _durationController,
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
                    initialValue: _durationUnit,
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
                        setState(() => _durationUnit = value ?? 'months'),
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
                  hintText: 'e.g. STUDY, HEALTH, PERSONAL, WORK',
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
                  helperText: 'Type or change the group category for this activity',
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
                      : const Text(
                          'Add Activity',
                          style: TextStyle(
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

  Widget _sectionLabel(BuildContext context, String label) => Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
      );
}
