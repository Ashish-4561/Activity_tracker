import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide Midnight Cyan modern soft neomorphic color & styling tokens
class AppColors {
  // ── Dark Mode Tokens (Midnight Cyan) ──────────────────────────────────────
  static const darkBackground = Color(0xFF11151C);
  static const darkSurface = Color(0xFF1A2029);
  static const darkSurfaceRaised = Color(0xFF202732);
  static const darkSurfaceHighlight = Color(0xFF27303E);
  static const darkBorder = Color(0xFF28313E);
  static const darkTextPrimary = Color(0xFFF4F7FA);
  static const darkTextSecondary = Color(0xFF9AA5B1);
  static const darkTextMuted = Color(0xFF6B7A8D);
  static const darkPrimaryAccent = Color(0xFF35D6F5);
  static const darkSecondaryAccent = Color(0xFF6EE7D8);
  static const darkSuccess = Color(0xFF65D6A5);
  static const darkWarning = Color(0xFFF5C451);
  static const darkError = Color(0xFFF07178);

  // ── Light Mode Tokens (Porcelain Cyan) ────────────────────────────────────
  static const lightBackground = Color(0xFFEEF2F5);
  static const lightSurface = Color(0xFFF5F7F9);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightTextPrimary = Color(0xFF17202A);
  static const lightTextSecondary = Color(0xFF6F7B87);
  static const lightTextMuted = Color(0xFF9AA5B1);
  static const lightPrimaryAccent = Color(0xFF16BFD6);
  static const lightSecondaryAccent = Color(0xFF55CFC0);
  static const lightSuccess = Color(0xFF42B883);
  static const lightWarning = Color(0xFFD9A62E);
  static const lightError = Color(0xFFD95C65);

  // ── Core Shared Accents ───────────────────────────────────────────────────
  static const primary = Color(0xFF35D6F5); // Midnight Cyan
  static const primaryGradientStart = Color(0xFF35D6F5);
  static const primaryGradientEnd = Color(0xFF6EE7D8);
  static const cyanAccent = Color(0xFF35D6F5);
  static const secondaryAqua = Color(0xFF6EE7D8);
  static const emeraldSuccess = Color(0xFF65D6A5);
  static const amberFlame = Color(0xFFF5C451);
  static const roseError = Color(0xFFF07178);
  static const meditationViolet = Color(0xFFA78BFA);
  static const studyBlue = Color(0xFF38BDF8);
}

class ThemeService extends ChangeNotifier {
  static const String _prefKey = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {
      // Non-fatal, fallback to system
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system';
      await prefs.setString(_prefKey, str);
    } catch (_) {}
  }

  /// Neumorphic soft shadows helper
  static List<BoxShadow> neumorphicShadows({
    required BuildContext context,
    bool isPressed = false,
  }) {
    if (isPressed) return [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkShadow = isDark ? const Color(0x80080B10) : const Color(0x1E94A3B8);
    final lightHighlight = isDark ? const Color(0x14FFFFFF) : const Color(0xC8FFFFFF);

    return [
      BoxShadow(
        color: darkShadow,
        offset: const Offset(3, 5),
        blurRadius: 12,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: lightHighlight,
        offset: const Offset(-3, -3),
        blurRadius: 10,
        spreadRadius: 0,
      ),
    ];
  }

  /// Neumorphic soft raised decoration for dark / light modes
  static BoxDecoration neumorphicDecoration({
    required BuildContext context,
    double borderRadius = 20,
    bool isPressed = false,
    Color? customColor,
    Border? border,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = customColor ?? (isDark ? AppColors.darkSurface : AppColors.lightSurface);

    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        width: 1,
      ),
      boxShadow: neumorphicShadows(context: context, isPressed: isPressed),
    );
  }

  static const List<String> fontFallbacks = [
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Roboto',
    'sans-serif',
  ];

  /// Light theme: soft cool porcelain background with crisp raised cards & Montserrat typography
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.montserratTextTheme(ThemeData.light().textTheme).apply(
      fontFamilyFallback: fontFallbacks,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimaryAccent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE0F7FA),
        onPrimaryContainer: Color(0xFF006064),
        secondary: AppColors.lightSecondaryAccent,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE6FFFA),
        onSecondaryContainer: Color(0xFF004D40),
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerHighest: AppColors.lightSurfaceRaised,
        onSurfaceVariant: AppColors.lightTextSecondary,
        outline: AppColors.lightBorder,
        outlineVariant: Color(0xFFCBD5E1),
        error: AppColors.lightError,
      ),
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          fontFamilyFallback: fontFallbacks,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontFamilyFallback: fontFallbacks,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: fontFallbacks,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: fontFallbacks,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: fontFallbacks,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.lightTextPrimary,
          height: 1.4,
          fontFamilyFallback: fontFallbacks,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.lightTextSecondary,
          height: 1.4,
          fontFamilyFallback: fontFallbacks,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: AppColors.lightTextMuted,
          fontFamilyFallback: fontFallbacks,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.montserrat(
          color: AppColors.lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightPrimaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lightPrimaryAccent,
        linearTrackColor: Color(0xFFE2E8F0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        indicatorColor: const Color(0xFFE0F7FA),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.lightPrimaryAccent);
          }
          return GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.lightTextSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.lightPrimaryAccent);
          }
          return const IconThemeData(color: AppColors.lightTextSecondary);
        }),
      ),
    );
  }

  /// Dark theme: deep Midnight Cyan background, soft raised cards, cyan accents & Montserrat typography
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).apply(
      fontFamilyFallback: fontFallbacks,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimaryAccent,
        onPrimary: Color(0xFF11151C),
        primaryContainer: Color(0xFF1A3340),
        onPrimaryContainer: Color(0xFFE0F7FA),
        secondary: AppColors.darkSecondaryAccent,
        onSecondary: Color(0xFF11151C),
        secondaryContainer: Color(0xFF15332F),
        onSecondaryContainer: Color(0xFFE6FFFA),
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: AppColors.darkSurfaceRaised,
        onSurfaceVariant: AppColors.darkTextSecondary,
        outline: AppColors.darkBorder,
        outlineVariant: Color(0xFF28313E),
        error: AppColors.darkError,
      ),
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          fontFamilyFallback: fontFallbacks,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontFamilyFallback: fontFallbacks,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: fontFallbacks,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: fontFallbacks,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: fontFallbacks,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.darkTextPrimary,
          height: 1.4,
          fontFamilyFallback: fontFallbacks,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.darkTextSecondary,
          height: 1.4,
          fontFamilyFallback: fontFallbacks,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: AppColors.darkTextMuted,
          fontFamilyFallback: fontFallbacks,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.montserrat(
          color: AppColors.darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkPrimaryAccent,
          foregroundColor: const Color(0xFF11151C),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.darkPrimaryAccent,
        linearTrackColor: Color(0xFF1A2029),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        indicatorColor: const Color(0xFF1A3340),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.darkPrimaryAccent);
          }
          return GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.darkTextSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.darkPrimaryAccent);
          }
          return const IconThemeData(color: AppColors.darkTextSecondary);
        }),
      ),
    );
  }
}
