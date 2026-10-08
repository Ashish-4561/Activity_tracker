import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'neumorphic_card.dart';

/// Reusable stat badge with soft neomorphic card surface, glowing icon, and responsive metrics
class StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;

  const StatBadge({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = iconColor ?? AppColors.primary;

    return NeumorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
