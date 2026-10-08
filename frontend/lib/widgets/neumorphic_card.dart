import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Reusable soft neomorphic raised card with optional tap feedback and custom padding
class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final bool isSelected;
  final double? width;
  final double? height;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.onTap,
    this.color,
    this.border,
    this.isSelected = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBorder = isSelected
        ? Border.all(
            color: isDark ? AppColors.primary : AppColors.primary,
            width: 1.5,
          )
        : border ??
            Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            );

    final effectiveColor = color ??
        (isDark
            ? (isSelected ? AppColors.darkSurfaceRaised : AppColors.darkSurface)
            : (isSelected ? const Color(0xFFF5F7FF) : AppColors.lightSurface));

    final borderSide = effectiveBorder.top != BorderSide.none
        ? effectiveBorder.top
        : BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: ThemeService.neumorphicShadows(context: context),
      ),
      child: Material(
        color: effectiveColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: AppColors.primary.withValues(alpha: 0.1),
                highlightColor: AppColors.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(20),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
      ),
    );
  }
}
