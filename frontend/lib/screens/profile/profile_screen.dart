import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/activity_service.dart';
import '../../services/theme_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../widgets/daytrack_logo.dart';
import '../../widgets/neumorphic_card.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool previewMode;

  const ProfileScreen({super.key, this.previewMode = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TimeOfDay _parseHHMM(String? hhmm, TimeOfDay defaultTime) {
    if (hhmm == null || !hhmm.contains(':')) return defaultTime;
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? defaultTime.hour,
      minute: int.tryParse(parts[1]) ?? defaultTime.minute,
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _showQuietHoursDialog(NotificationService notifService) {
    final authService = context.read<AuthService>();
    bool enabled = notifService.quietHoursEnabled;
    TimeOfDay startTime = _parseHHMM(notifService.quietHoursStart, const TimeOfDay(hour: 22, minute: 0));
    TimeOfDay endTime = _parseHHMM(notifService.quietHoursEnd, const TimeOfDay(hour: 7, minute: 0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.bedtime_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Quiet Hours & Reminders'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'During quiet hours, scheduled notifications are paused and shifted to when quiet hours end.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Quiet Hours', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    value: enabled,
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => enabled = val),
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.nightlight_round, size: 16),
                            label: Text('Starts: ${_formatTimeOfDay(startTime)}'),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: startTime);
                              if (picked != null) setDialogState(() => startTime = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                            label: Text('Ends: ${_formatTimeOfDay(endTime)}'),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: endTime);
                              if (picked != null) setDialogState(() => endTime = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text('Test Notification & Snooze', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Send an instant test notification to check sound and 10-minute snooze action.', style: TextStyle(fontSize: 11.5)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_active_rounded, size: 16),
                      label: const Text('Send Test Notification'),
                      onPressed: () async {
                        await notifService.showTestNotification();
                        if (mounted) {
                          _showMessage('Test notification triggered!');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                  final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
                  await notifService.updateSettings(
                    quietHoursEnabled: enabled,
                    quietHoursStart: startStr,
                    quietHoursEnd: endStr,
                  );
                  try {
                    await authService.updateProfile(
                      quietHoursEnabled: enabled,
                      quietHoursStart: startStr,
                      quietHoursEnd: endStr,
                    );
                  } catch (_) {}
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    _showMessage('Quiet hours settings saved!');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.roseError : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showEditNameDialog(User user) {
    final nameController = TextEditingController(text: user.name);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Edit Display Name'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  _showMessage('Name cannot be empty', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await context.read<AuthService>().updateProfile(name: newName);
                  _showMessage('Name updated successfully!');
                } catch (e) {
                  _showMessage('Failed to update name: $e', isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool hideCurrent = true;
    bool hideNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Change Password'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPassController,
                    obscureText: hideCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      suffixIcon: IconButton(
                        icon: Icon(hideCurrent ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => hideCurrent = !hideCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: newPassController,
                    obscureText: hideNew,
                    decoration: InputDecoration(
                      labelText: 'New Password (min 6 chars)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      suffixIcon: IconButton(
                        icon: Icon(hideNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => hideNew = !hideNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmPassController,
                    obscureText: hideNew,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final cur = currentPassController.text.trim();
                  final next = newPassController.text.trim();
                  final conf = confirmPassController.text.trim();

                  if (cur.isEmpty || next.isEmpty) {
                    _showMessage('Please fill in all password fields', isError: true);
                    return;
                  }
                  if (next.length < 6) {
                    _showMessage('New password must be at least 6 characters', isError: true);
                    return;
                  }
                  if (next != conf) {
                    _showMessage('New passwords do not match', isError: true);
                    return;
                  }

                  Navigator.pop(ctx);
                  try {
                    await context.read<AuthService>().changePassword(
                      currentPassword: cur,
                      newPassword: next,
                    );
                    _showMessage('Password changed successfully!');
                  } catch (e) {
                    _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
                  }
                },
                child: const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.roseError),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This will permanently delete your account, habits, and progress from the cloud. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.roseError),
            onPressed: () async {
              final auth = context.read<AuthService>();
              final activity = context.read<ActivityService>();
              Navigator.pop(ctx);
              try {
                await auth.deleteAccount();
                activity.clearData();
                _showMessage('Account permanently deleted.');
              } catch (e) {
                _showMessage('Failed to delete account: $e', isError: true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final themeService = context.watch<ThemeService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isLoggedIn = authService.isLoggedIn;
    final isGuest = authService.isGuest;
    final displayName = user?.name ?? (isLoggedIn ? 'User' : 'Guest Explorer');
    final identifier = user?.email ?? user?.phone ?? (isLoggedIn ? 'Cloud Profile' : 'Guest Mode (Offline)');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Hero Profile Avatar Card ───────────────────────────────────────
          NeumorphicCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: !isLoggedIn
                            ? const Icon(Icons.explore_rounded, size: 30, color: Colors.white)
                            : Text(
                                displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            identifier,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isGuest) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: authService.isTrialExpired
                                    ? AppColors.roseError.withValues(alpha: 0.15)
                                    : AppColors.amberFlame.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                authService.isTrialExpired
                                    ? 'Trial Expired'
                                    : '${authService.guestTrialDaysRemaining} Days Trial Remaining',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: authService.isTrialExpired ? AppColors.roseError : AppColors.amberFlame,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (user != null)
                      IconButton(
                        tooltip: 'Edit Name',
                        onPressed: () => _showEditNameDialog(user),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                  ],
                ),
                if (!isLoggedIn) ...[
                  const SizedBox(height: 18),
                  Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Guest data is stored locally. Create a free account or log in to sync all habits and history to the cloud.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignupScreen()),
                            );
                          },
                          icon: const Icon(Icons.person_add_outlined, size: 18),
                          label: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Appearance Section ─────────────────────────────────────────────
          _sectionTitle(context, 'Appearance'),
          const SizedBox(height: 10),
          NeumorphicCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme Mode',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded, size: 18),
                        label: Text('Dark'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                        label: Text('System'),
                      ),
                    ],
                    selected: {themeService.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      themeService.setThemeMode(newSelection.first);
                    },
                    style: ButtonStyle(
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Preferences Section ───────────────────────────────────────────
          _sectionTitle(context, 'Preferences'),
          const SizedBox(height: 10),
          NeumorphicCard(
            padding: EdgeInsets.zero,
            borderRadius: 20,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: const Text('AI Assistant Coach', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('Smart habit insights & planning', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  value: user?.aiEnabled ?? true,
                  onChanged: user != null
                      ? (val) => context.read<AuthService>().updateProfile(aiEnabled: val)
                      : (val) => AuthPromptDialog.show(context),
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1, indent: 56),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: AppColors.cyanAccent, size: 20),
                  ),
                  title: const Text('Daily Habit Reminders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('Notifications for scheduled targets', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  value: user?.notificationsEnabled ?? true,
                  onChanged: user != null
                      ? (val) => context.read<AuthService>().updateProfile(notificationsEnabled: val)
                      : (val) => AuthPromptDialog.show(context),
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1, indent: 56),
                Consumer<NotificationService>(
                  builder: (context, notif, _) {
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bedtime_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: const Text('Quiet Hours & Reminders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(
                        notif.quietHoursEnabled
                            ? 'Active (${notif.quietHoursStart} - ${notif.quietHoursEnd})'
                            : 'Disabled (Tap to configure)',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () => _showQuietHoursDialog(notif),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Account & Security (Authenticated Users) ───────────────────────
          if (user != null) ...[
            _sectionTitle(context, 'Account & Security'),
            const SizedBox(height: 10),
            NeumorphicCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: _showChangePasswordDialog,
                  ),
                  Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.roseError.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.roseError, size: 20),
                    ),
                    title: const Text('Delete Account', style: TextStyle(color: AppColors.roseError, fontWeight: FontWeight.w700, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.roseError),
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final auth = context.read<AuthService>();
                  final activity = context.read<ActivityService>();
                  await auth.logout();
                  activity.clearData();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],

          if (!isLoggedIn) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('Log In to DayTrack Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Create New Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],

          // DayTrack Branding Footer
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DayTrackLogo(
                  variant: DayTrackLogoVariant.compact,
                  iconSize: 26,
                  size: 16,
                ),
                const SizedBox(height: 6),
                Text(
                  'Version 1.0.1 • Personal Daily Productivity',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
