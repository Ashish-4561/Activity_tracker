import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/activity_service.dart';
import '../services/theme_service.dart';
import 'ai/ai_screen.dart';
import 'home/progress_home_screen.dart';
import 'profile/profile_screen.dart';
import 'progress/progress_screen.dart';

class AppShell extends StatefulWidget {
  final bool previewMode;

  const AppShell({super.key, this.previewMode = false});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<ActivityService>().checkDayRollover();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pages = [
      ProgressHomeScreen(previewMode: widget.previewMode),
      ProgressScreen(previewMode: widget.previewMode),
      AiScreen(previewMode: widget.previewMode),
      ProfileScreen(previewMode: widget.previewMode),
    ];

    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x70080B10) : const Color(0x1594A3B8),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard_rounded,
                  label: 'Home',
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.insights_outlined,
                  selectedIcon: Icons.insights_rounded,
                  label: 'Progress',
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.auto_awesome_outlined,
                  selectedIcon: Icons.auto_awesome_rounded,
                  label: 'AI Coach',
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFE0F7FA))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(
                  color: isDark ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 20,
              color: isSelected
                  ? (isDark ? AppColors.darkPrimaryAccent : AppColors.lightPrimaryAccent)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? AppColors.darkPrimaryAccent : AppColors.lightPrimaryAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
