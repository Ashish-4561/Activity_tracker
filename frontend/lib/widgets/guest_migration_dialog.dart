import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/activity_service.dart';
import '../services/theme_service.dart';
import 'daytrack_logo.dart';

class GuestMigrationDialog extends StatelessWidget {
  const GuestMigrationDialog({super.key});

  static Future<void> showIfGuestHasData(BuildContext context) async {
    try {
      final activityService = context.read<ActivityService>();
      final hasGuestData = activityService.hasGuestActivities || await activityService.hasStoredGuestActivities();
      if (!hasGuestData) return;

      if (!context.mounted) return;
      final shouldMigrate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const GuestMigrationDialog(),
      );

      if (shouldMigrate == true) {
        await activityService.migrateGuestDataToCloud();
      } else {
        await activityService.clearGuestData();
      }
      await activityService.fetchActivities();
    } catch (e) {
      debugPrint('Guest migration dialog skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DayTrackLogo(
                  variant: DayTrackLogoVariant.iconOnly,
                  iconSize: 42,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Save Guest Activities?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to save and transfer the activities from your guest trial into your new account?',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Start Fresh',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.cyanAccent, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyanAccent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check_rounded, size: 18, color: Colors.black),
                      label: const Text(
                        'Save Them',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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
}
