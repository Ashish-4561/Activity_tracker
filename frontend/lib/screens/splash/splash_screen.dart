import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/daytrack_logo.dart';
import '../app_shell.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool previewMode;

  const SplashScreen({super.key, this.previewMode = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppAndNavigate();
    });
  }

  Future<void> _initializeAppAndNavigate() async {
    // 1-second minimum splash display for snappy experience
    final completer = Completer<void>();
    _splashTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await completer.future;
    } catch (_) {}

    if (!mounted) return;

    // Allow auth initialization and session restoration to complete
    try {
      final auth = context.read<AuthService>();
      int extraChecks = 0;
      while (auth.authState == AuthState.loading && extraChecks < 20 && mounted) {
        final loopCompleter = Completer<void>();
        _splashTimer = Timer(const Duration(milliseconds: 100), () {
          if (!loopCompleter.isCompleted) loopCompleter.complete();
        });
        try {
          await loopCompleter.future;
        } catch (_) {}
        extraChecks++;
      }
    } catch (_) {}

    if (!mounted) return;

    final auth = context.read<AuthService>();
    final bool shouldOpenApp = widget.previewMode ||
        auth.isLoggedIn ||
        (auth.isGuest && !auth.isTrialExpired);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            shouldOpenApp ? AppShell(previewMode: widget.previewMode) : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient soft background glow
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark
                          ? const Color(0x300066FF)
                          : const Color(0x2535D6F5),
                      Colors.transparent,
                    ],
                    radius: 0.75,
                  ),
                ),
              ),
            ),

            // Main animated logo & branding
            Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: const DayTrackLogo(
                        variant: DayTrackLogoVariant.full,
                        iconSize: 105,
                        size: 32,
                        showTagline: true,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom subtle branding subtitle
            Positioned(
              left: 0,
              right: 0,
              bottom: 42,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Text(
                    'Organize • Track • Grow',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
