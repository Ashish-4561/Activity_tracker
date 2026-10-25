import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/daytrack_logo.dart';
import '../../widgets/neumorphic_card.dart';
import '../app_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;

  const LoginScreen({super.key, this.initialEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  int _authMethodIndex = 0; // 0: Email, 1: Phone

  // Email form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // Phone form controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;
  bool _hasNavigated = false;
  bool _isGoogleSigningIn = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      if (auth.isLoggedIn) {
        _navigateToHome();
      } else {
        auth.addListener(_onAuthStatusChanged);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = context.read<AuthService>();
      if (auth.isLoggedIn && !_hasNavigated && mounted) {
        _navigateToHome();
      } else if (_isGoogleSigningIn && mounted) {
        // Returned from browser; give Supabase onAuthStateChange a moment to process callback
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && !context.read<AuthService>().isLoggedIn) {
            setState(() => _isGoogleSigningIn = false);
          }
        });
      }
    }
  }

  void _onAuthStatusChanged() {
    if (!mounted || _hasNavigated) return;
    final auth = context.read<AuthService>();
    if (auth.isLoggedIn) {
      _navigateToHome();
    }
  }

  Future<void> _navigateToHome() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    final userName = context.read<AuthService>().currentUser?.name ?? 'User';

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
    _showMessage('Successfully logged in! Welcome, $userName.', isError: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      context.read<AuthService>().removeListener(_onAuthStatusChanged);
    } catch (_) {}
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.roseError : AppColors.emeraldSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showMessage('Please enter your email address', isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address (e.g. name@example.com)', isError: true);
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter your password', isError: true);
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters', isError: true);
      return;
    }

    final authService = context.read<AuthService>();

    try {
      await authService.login(email: email, password: password);
      if (mounted) {
        await _navigateToHome();
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.toLowerCase().contains('not confirmed')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.amberFlame,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Resend Link',
              textColor: Colors.black,
              onPressed: () async {
                try {
                  await authService.resendConfirmationEmail(email: email);
                  _showMessage('Confirmation email resent! Please check your inbox.');
                } catch (err) {
                  _showMessage(err.toString().replaceAll('Exception: ', ''), isError: true);
                }
              },
            ),
          ),
        );
      } else {
        _showMessage(msg, isError: true);
      }
    }
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      _showMessage('Please enter a valid phone number with country code (e.g. +91 9876543210)', isError: true);
      return;
    }

    final authService = context.read<AuthService>();
    try {
      final res = await authService.sendPhoneOtp(phone);
      setState(() {
        _otpSent = true;
        _resendCountdown = 60;
      });

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCountdown > 0) {
          setState(() => _resendCountdown--);
        } else {
          timer.cancel();
        }
      });

      final devOtp = res['otp'] != null ? ' (Dev Code: ${res['otp']})' : '';
      _showMessage('Verification code sent to $phone$devOtp');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showMessage('Please enter the 6-digit OTP code', isError: true);
      return;
    }

    final authService = context.read<AuthService>();

    try {
      await authService.verifyPhoneOtp(phone, otp);
      if (mounted) {
        await _navigateToHome();
      }
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authService = context.read<AuthService>();
    setState(() => _isGoogleSigningIn = true);

    try {
      await authService.signInWithGoogleOAuth();
      // On web or immediate session completion:
      if (mounted && authService.isLoggedIn) {
        await _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Branding Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (Navigator.canPop(context))
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                                tooltip: 'Back to App',
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          const DayTrackLogo(
                            variant: DayTrackLogoVariant.horizontal,
                            iconSize: 42,
                            size: 21,
                            showTagline: true,
                          ),
                        ],
                      ),
                      if (!Navigator.canPop(context))
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AppShell()),
                              (_) => false,
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Guest Mode', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Welcome Back',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose your preferred sign-in method below',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Method Switcher
                  NeumorphicCard(
                    padding: const EdgeInsets.all(4),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _authMethodIndex = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _authMethodIndex == 0
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: _authMethodIndex == 0 ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email & Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _authMethodIndex == 0 ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _authMethodIndex = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _authMethodIndex == 1
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_android_rounded,
                                    size: 16,
                                    color: _authMethodIndex == 1 ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Phone Number',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _authMethodIndex == 1 ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email Form
                  if (_authMethodIndex == 0) ...[
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: authService.isLoading ? null : _handleEmailLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: authService.isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],

                  // Phone Form
                  if (_authMethodIndex == 1) ...[
                    TextField(
                      controller: _phoneController,
                      enabled: !_otpSent,
                      decoration: InputDecoration(
                        labelText: 'Phone Number (with Country Code)',
                        hintText: '+1 555-0199 or +91 9876543210',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                        suffixIcon: _otpSent
                            ? IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                }),
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _otpController,
                        decoration: InputDecoration(
                          labelText: '6-Digit Verification Code',
                          hintText: '123456',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurfaceRaised : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Didn\'t receive code?',
                            style: theme.textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: _resendCountdown == 0 ? _handleSendOtp : null,
                            child: const Text('Resend OTP'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: authService.isLoading ? null : _handleVerifyOtp,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: authService.isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Verify & Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: authService.isLoading ? null : _handleSendOtp,
                          icon: const Icon(Icons.sms_outlined, size: 20),
                          label: const Text('Send Verification Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Google Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: (authService.isLoading || _isGoogleSigningIn) ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isGoogleSigningIn)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Image.network(
                              'https://developers.google.com/identity/images/g-logo.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: AppColors.cyanAccent, size: 24),
                            ),
                          const SizedBox(width: 12),
                          Text(
                            _isGoogleSigningIn ? 'Opening Google Sign-In...' : 'Continue with Google',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Continue as Guest Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final auth = context.read<AuthService>();
                        final navigator = Navigator.of(context);
                        await auth.continueAsGuest();
                        if (!mounted) return;
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AppShell()),
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.person_outline_rounded, size: 20),
                      label: const Text('Continue as Guest', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Switch to Signup
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const SignupScreen()),
                            );
                          },
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
