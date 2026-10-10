import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum DayTrackLogoVariant {
  full, // Stacked 3D icon + DayTrack + ACTIVITY TRACKER
  horizontal, // Icon on left + DayTrack & Tagline on right
  compact, // Small icon + DayTrack title (App bar / Drawer)
  iconOnly, // Icon tile only
  banner, // Dark horizontal banner card
}

enum DayTrackIconStyle {
  auto, // Light in light mode, Dark in dark mode
  light3d,
  dark3d,
  flat,
  monochrome,
}

class DayTrackLogo extends StatelessWidget {
  final DayTrackLogoVariant variant;
  final DayTrackIconStyle iconStyle;
  final double? size;
  final double? iconSize;
  final bool showTagline;
  final bool? isDark;
  final String? heroTag;
  final VoidCallback? onTap;

  const DayTrackLogo({
    super.key,
    this.variant = DayTrackLogoVariant.horizontal,
    this.iconStyle = DayTrackIconStyle.auto,
    this.size,
    this.iconSize,
    this.showTagline = true,
    this.isDark,
    this.heroTag,
    this.onTap,
  });

  /// Factory for Large Hero Login/Signup branding
  factory DayTrackLogo.full({
    Key? key,
    double size = 96,
    double fontSize = 32,
    bool showTagline = true,
    bool? isDark,
    String? heroTag,
  }) {
    return DayTrackLogo(
      key: key,
      variant: DayTrackLogoVariant.full,
      iconSize: size,
      size: fontSize,
      showTagline: showTagline,
      isDark: isDark,
      heroTag: heroTag,
    );
  }

  /// Factory for Header/Navbar compact horizontal logo
  factory DayTrackLogo.horizontal({
    Key? key,
    double iconSize = 40,
    double fontSize = 20,
    bool showTagline = true,
    bool? isDark,
    VoidCallback? onTap,
  }) {
    return DayTrackLogo(
      key: key,
      variant: DayTrackLogoVariant.horizontal,
      iconSize: iconSize,
      size: fontSize,
      showTagline: showTagline,
      isDark: isDark,
      onTap: onTap,
    );
  }

  /// Factory for compact App Bar or Sidebar logo
  factory DayTrackLogo.compact({
    Key? key,
    double iconSize = 34,
    double fontSize = 18,
    bool? isDark,
    VoidCallback? onTap,
  }) {
    return DayTrackLogo(
      key: key,
      variant: DayTrackLogoVariant.compact,
      iconSize: iconSize,
      size: fontSize,
      showTagline: false,
      isDark: isDark,
      onTap: onTap,
    );
  }

  /// Factory for Icon Only
  factory DayTrackLogo.iconOnly({
    Key? key,
    double size = 48,
    DayTrackIconStyle iconStyle = DayTrackIconStyle.auto,
    String? heroTag,
  }) {
    return DayTrackLogo(
      key: key,
      variant: DayTrackLogoVariant.iconOnly,
      iconSize: size,
      iconStyle: iconStyle,
      heroTag: heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget content;
    switch (variant) {
      case DayTrackLogoVariant.full:
        content = _buildFullStacked(context, effectiveDark);
        break;
      case DayTrackLogoVariant.horizontal:
        content = _buildHorizontal(context, effectiveDark);
        break;
      case DayTrackLogoVariant.compact:
        content = _buildCompact(context, effectiveDark);
        break;
      case DayTrackLogoVariant.iconOnly:
        content = _buildIcon(context, effectiveDark, iconSize ?? size ?? 48);
        break;
      case DayTrackLogoVariant.banner:
        content = _buildBanner(context);
        break;
    }

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }

  String _getAssetPath(bool effectiveDark) {
    switch (iconStyle) {
      case DayTrackIconStyle.light3d:
        return 'assets/branding/app_icon_light.png';
      case DayTrackIconStyle.dark3d:
        return 'assets/branding/app_icon_dark.png';
      case DayTrackIconStyle.flat:
        return 'assets/branding/app_icon_flat.png';
      case DayTrackIconStyle.monochrome:
        return 'assets/branding/app_icon_monochrome.png';
      case DayTrackIconStyle.auto:
        return effectiveDark
            ? 'assets/branding/app_icon_dark.png'
            : 'assets/branding/app_icon_light.png';
    }
  }

  Widget _buildIcon(BuildContext context, bool effectiveDark, double sz) {
    final asset = _getAssetPath(effectiveDark);
    return Container(
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(sz * 0.23),
        boxShadow: [
          BoxShadow(
            color: effectiveDark
                ? const Color(0x60000000)
                : const Color(0x220066FF),
            blurRadius: sz * 0.2,
            offset: Offset(0, sz * 0.08),
          ),
          BoxShadow(
            color: effectiveDark
                ? const Color(0x1835D6F5)
                : const Color(0x40FFFFFF),
            blurRadius: sz * 0.12,
            offset: Offset(0, -sz * 0.04),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(sz * 0.23),
        child: Image.asset(
          asset,
          width: sz,
          height: sz,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(sz, effectiveDark),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(double sz, bool effectiveDark) {
    return Container(
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: effectiveDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(sz * 0.23),
      ),
      child: Center(
        child: Icon(
          Icons.insights_rounded,
          size: sz * 0.55,
          color: const Color(0xFF0066FF),
        ),
      ),
    );
  }

  Widget _buildFullStacked(BuildContext context, bool effectiveDark) {
    final effectiveIconSize = iconSize ?? 96.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIcon(context, effectiveDark, effectiveIconSize),
        const SizedBox(height: 16),
        _buildBrandText(context, effectiveDark, fontSize: size ?? 30),
        if (showTagline) ...[
          const SizedBox(height: 6),
          _buildTagline(effectiveDark, fontSize: (size ?? 30) * 0.32),
        ],
      ],
    );
  }

  Widget _buildHorizontal(BuildContext context, bool effectiveDark) {
    final effectiveIconSize = iconSize ?? 42.0;
    final effectiveFontSize = size ?? 22.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIcon(context, effectiveDark, effectiveIconSize),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandText(context, effectiveDark, fontSize: effectiveFontSize),
            if (showTagline) ...[
              const SizedBox(height: 2),
              _buildTagline(effectiveDark, fontSize: effectiveFontSize * 0.36),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context, bool effectiveDark) {
    final effectiveIconSize = iconSize ?? 32.0;
    final effectiveFontSize = size ?? 19.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIcon(context, effectiveDark, effectiveIconSize),
        const SizedBox(width: 10),
        _buildBrandText(context, effectiveDark, fontSize: effectiveFontSize),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131924),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF232D3F), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(context, true, 42),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBrandText(context, true, fontSize: 22),
              if (showTagline) ...[
                const SizedBox(height: 2),
                _buildTagline(true, fontSize: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandText(BuildContext context, bool effectiveDark, {required double fontSize}) {
    final dayColor = effectiveDark ? const Color(0xFFF8FAFC) : const Color(0xFF0D1326);

    return RichText(
      text: TextSpan(
        style: GoogleFonts.montserrat(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        children: [
          TextSpan(
            text: 'Day',
            style: TextStyle(color: dayColor),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF0066FF), // Royal Blue
                  Color(0xFF0096FF), // Sky Blue
                  Color(0xFF00C8FF), // Vibrant Electric Cyan
                ],
                stops: [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: Text(
                'Track',
                style: GoogleFonts.montserrat(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline(bool effectiveDark, {required double fontSize}) {
    final tagColor = effectiveDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Text(
      'ACTIVITY TRACKER',
      style: GoogleFonts.montserrat(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.2,
        color: tagColor,
      ),
    );
  }
}
