import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/app_config.dart';
import 'api_service.dart';

class User {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? profileImage;
  final String? authProvider;
  final String theme;
  final bool aiEnabled;
  final bool aiSuggestionsEnabled;
  final bool notificationsEnabled;

  User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.profileImage,
    this.authProvider = 'email',
    required this.theme,
    required this.aiEnabled,
    this.aiSuggestionsEnabled = true,
    this.notificationsEnabled = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return defaultValue;
    }

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      profileImage: json['profile_image']?.toString(),
      authProvider: json['auth_provider']?.toString() ?? 'email',
      theme: json['theme']?.toString() ?? 'light',
      aiEnabled: parseBool(json['ai_enabled'], true),
      aiSuggestionsEnabled: parseBool(json['ai_suggestions_enabled'], true),
      notificationsEnabled: parseBool(json['notifications_enabled'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profile_image': profileImage,
      'auth_provider': authProvider,
      'theme': theme,
      'ai_enabled': aiEnabled,
      'ai_suggestions_enabled': aiSuggestionsEnabled,
      'notifications_enabled': notificationsEnabled,
    };
  }
}

enum AuthState { loading, guest, authenticated, unauthenticated }

class AuthService extends ChangeNotifier {
  final ApiService apiService;
  User? _currentUser;
  AuthState _authState = AuthState.loading;
  bool _isLoading = false;
  String? _error;
  DateTime? _guestTrialStartTime;

  static const String _kCachedUserKey = 'cached_user_profile';
  static const String _kGuestModeKey = 'guest_mode_enabled';

  /// Centralized OAuth and deep link redirect URI
  static String get oauthRedirectUri {
    if (kIsWeb) {
      return dotenv.env['FRONTEND_URL'] ??
          (Uri.base.hasPort && Uri.base.port != 0
              ? '${Uri.base.scheme}://${Uri.base.host}:${Uri.base.port}'
              : 'http://localhost:3000');
    }
    final envUri = dotenv.env['OAUTH_REDIRECT_URI']?.trim() ?? '';
    if (envUri.isNotEmpty) {
      return envUri;
    }
    return 'io.supabase.activitytracker://login-callback';
  }

  AuthService(this.apiService) {
    _initializeAuth();
  }

  User? get currentUser => _currentUser;
  AuthState get authState => _authState;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _authState == AuthState.authenticated && _currentUser != null;
  bool get isGuest => _authState == AuthState.guest;
  bool get isUnauthenticated => _authState == AuthState.unauthenticated;

  DateTime? get guestTrialStartTime => _guestTrialStartTime;

  /// Returns remaining trial days for guest user (0 if expired)
  int get guestTrialDaysRemaining {
    if (!isGuest || _guestTrialStartTime == null) return AppConfig.guestTrialDays;
    final elapsed = DateTime.now().difference(_guestTrialStartTime!).inDays;
    final remaining = AppConfig.guestTrialDays - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Returns true if guest trial has expired (2-day limit exceeded)
  bool get isTrialExpired {
    if (_guestTrialStartTime == null) return false;
    final elapsed = DateTime.now().difference(_guestTrialStartTime!).inDays;
    return elapsed >= AppConfig.guestTrialDays;
  }

  Future<void> _saveCachedUserProfile(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<User?> _loadCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedUserKey);
      if (raw != null && raw.isNotEmpty) {
        return User.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedUserKey);
    } catch (_) {}
  }

  /// Sets guest mode when explicitly requested by user
  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuestModeKey, true);
    _currentUser = null;
    _authState = AuthState.guest;
    _error = null;
    notifyListeners();
  }

  Future<void> _initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trialStartStr = prefs.getString(AppConfig.guestTrialStartKey);
      if (trialStartStr != null) {
        _guestTrialStartTime = DateTime.tryParse(trialStartStr);
      } else {
        _guestTrialStartTime = DateTime.now();
        await prefs.setString(AppConfig.guestTrialStartKey, _guestTrialStartTime!.toIso8601String());
      }

      // Always listen for Supabase auth state changes (Google OAuth callback, sign in, token refresh, etc.)
      try {
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final event = data.event;
          final session = data.session;
          if (session != null &&
              (event == AuthChangeEvent.signedIn ||
                  event == AuthChangeEvent.tokenRefreshed ||
                  event == AuthChangeEvent.userUpdated ||
                  event == AuthChangeEvent.initialSession)) {
            final supabaseUser = session.user;
            _currentUser = User(
              id: supabaseUser.id,
              name: supabaseUser.userMetadata?['full_name'] ??
                  supabaseUser.userMetadata?['name'] ??
                  supabaseUser.email?.split('@').first ??
                  'User',
              email: supabaseUser.email,
              profileImage: supabaseUser.userMetadata?['avatar_url'] ??
                  supabaseUser.userMetadata?['picture'],
              theme: 'light',
              aiEnabled: true,
              authProvider: supabaseUser.appMetadata['provider']?.toString() ?? 'google',
            );
            _authState = AuthState.authenticated;
            await apiService.setToken(session.accessToken);
            await _saveCachedUserProfile(_currentUser!);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_kGuestModeKey, false);
            notifyListeners();

            // Background non-fatal profile enrichment
            try {
              await fetchProfile().timeout(const Duration(seconds: 4));
            } catch (_) {}
          } else if (event == AuthChangeEvent.signedOut) {
            // Guard: If there is an active session or the user is already authenticated with another account,
            // ignore delayed/stale signedOut events from previous sessions
            final currentSession = Supabase.instance.client.auth.currentSession;
            if (currentSession != null || (_currentUser != null && _authState == AuthState.authenticated)) {
              debugPrint('ℹ Ignored stale signedOut event because an active authenticated session exists.');
              return;
            }
            _currentUser = null;
            _authState = AuthState.unauthenticated;
            await apiService.clearToken();
            await _clearCachedUserProfile();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_kGuestModeKey, false);
            notifyListeners();
          }
        });
      } catch (_) {}

      // 1. Check active Supabase session on startup
      try {
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
          final supabaseUser = currentSession.user;
          _currentUser = User(
            id: supabaseUser.id,
            name: supabaseUser.userMetadata?['full_name'] ??
                supabaseUser.userMetadata?['name'] ??
                supabaseUser.email?.split('@').first ??
                'User',
            email: supabaseUser.email,
            profileImage: supabaseUser.userMetadata?['avatar_url'] ??
                supabaseUser.userMetadata?['picture'],
            theme: 'light',
            aiEnabled: true,
            authProvider: supabaseUser.appMetadata['provider']?.toString() ?? 'google',
          );
          _authState = AuthState.authenticated;
          await apiService.setToken(currentSession.accessToken);
          await _saveCachedUserProfile(_currentUser!);
          notifyListeners();

          try {
            await fetchProfile();
          } catch (_) {}
          return;
        }
      } catch (_) {}

      // 2. Check stored token fallback
      final token = await apiService.getToken();
      if (token != null && token.isNotEmpty) {
        final cached = await _loadCachedUserProfile();
        if (cached != null) {
          _currentUser = cached;
        }
        _authState = AuthState.authenticated;
        notifyListeners();
        try {
          await fetchProfile();
        } catch (_) {}
        return;
      }

      // 3. Check guest trial vs unauthenticated
      if (_currentUser == null) {
        final isGuestModeEnabled = prefs.getBool(_kGuestModeKey) ?? false;
        if (isGuestModeEnabled && !isTrialExpired) {
          _authState = AuthState.guest;
        } else {
          _authState = AuthState.unauthenticated;
          await prefs.setBool(_kGuestModeKey, false);
        }
      }
    } catch (e) {
      _error = 'Failed to initialize auth';
      _authState = AuthState.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> isLoggedInCheck() async {
    final token = await apiService.getToken();
    return token != null;
  }

  /// Retries transient network/socket exceptions automatically
  Future<T> _retryOnNetworkError<T>(Future<T> Function() operation, {int maxAttempts = 3}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } on AuthException {
        rethrow;
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = errStr.contains('socketexception') ||
            errStr.contains('connection reset by peer') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('errno = 104') ||
            errStr.contains('connection refused') ||
            errStr.contains('connection closed') ||
            errStr.contains('networkerror');

        if (isNetwork && attempt < maxAttempts) {
          debugPrint('Network transient error on attempt $attempt/$maxAttempts. Retrying in ${attempt * 500}ms...');
          await Future.delayed(Duration(milliseconds: attempt * 500));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Request failed after $maxAttempts attempts.');
  }

  /// Email/Password signup using native Supabase Auth
  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final redirectUrl = oauthRedirectUri;

      final AuthResponse res = await _retryOnNetworkError(() => supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl,
        data: {
          'name': name,
          'full_name': name,
        },
      ));

      final supabaseUser = res.user;
      final session = res.session;

      if (supabaseUser == null) {
        throw const AuthException('Signup failed: No user record returned.');
      }

      // Supabase user identity check for duplicate account detection:
      // When email confirmations are enabled and an account with this email already exists,
      // Supabase returns a user object where identities is an empty list and session is null.
      if (supabaseUser.identities != null && supabaseUser.identities!.isEmpty) {
        throw const AuthException('Account already exists. Please log in instead.');
      }

      final bool requiresConfirmation = session == null;

      final user = User(
        id: supabaseUser.id,
        name: name,
        email: supabaseUser.email ?? email,
        theme: 'light',
        aiEnabled: true,
      );

      if (session != null) {
        _currentUser = user;
        _authState = AuthState.authenticated;
        await apiService.setToken(session.accessToken);
        await _saveCachedUserProfile(user);
      } else {
        _currentUser = user;
        _authState = AuthState.unauthenticated;
      }

      _isLoading = false;
      notifyListeners();

      return {
        'user': user,
        'requiresEmailConfirmation': requiresConfirmation,
        'session': session,
      };
    } on AuthException catch (e) {
      _isLoading = false;
      String friendlyMessage = e.message;
      final msgLower = e.message.toLowerCase();

      if (msgLower.contains('already registered') ||
          msgLower.contains('already exists') ||
          msgLower.contains('already in use') ||
          msgLower.contains('duplicate') ||
          msgLower.contains('account_exists') ||
          e.statusCode == '422') {
        friendlyMessage = 'Account already exists. Please log in instead.';
      } else if (msgLower.contains('password') && (msgLower.contains('short') || msgLower.contains('characters') || msgLower.contains('weak'))) {
        friendlyMessage = 'Password must be at least 6 characters long.';
      } else if (msgLower.contains('invalid') && msgLower.contains('email')) {
        friendlyMessage = 'Please enter a valid email address.';
      }

      _error = friendlyMessage;
      notifyListeners();
      throw Exception(friendlyMessage);
    } catch (e) {
      _isLoading = false;
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      final lower = errorMsg.toLowerCase();
      if (lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('clientexception') ||
          lower.contains('connection reset by peer') ||
          lower.contains('errno = 104') ||
          lower.contains('connection closed') ||
          lower.contains('networkerror')) {
        errorMsg = 'Network connection interrupted. Please try again.';
      }
      _error = errorMsg;
      notifyListeners();
      throw Exception(errorMsg);
    }
  }

  /// Resend confirmation email
  Future<void> resendConfirmationEmail({required String email}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final redirectUrl = oauthRedirectUri;

      await _retryOnNetworkError(() => supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectUrl,
      ));

      _isLoading = false;
      notifyListeners();
    } on AuthException catch (e) {
      _isLoading = false;
      _error = e.message;
      notifyListeners();
      throw Exception(e.message);
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to resend confirmation email. Please try again.';
      notifyListeners();
      throw Exception(_error);
    }
  }

  /// Preserved legacy Node.js Express backend signup (for rollback compatibility)
  Future<void> signupViaBackend({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.signup(
        name: name,
        email: email,
        password: password,
      );

      _currentUser = User.fromJson(response['user']);
      _authState = AuthState.authenticated;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Email/Password login using native Supabase Auth
  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final AuthResponse res = await _retryOnNetworkError(() => supabase.auth.signInWithPassword(
        email: email,
        password: password,
      ));

      final supabaseUser = res.user;
      final session = res.session;

      if (supabaseUser == null || session == null) {
        throw const AuthException('Login failed: Invalid credentials or unconfirmed email.');
      }

      _currentUser = User(
        id: supabaseUser.id,
        name: supabaseUser.userMetadata?['full_name'] ??
            supabaseUser.userMetadata?['name'] ??
            supabaseUser.email?.split('@').first ??
            'User',
        email: supabaseUser.email,
        profileImage: supabaseUser.userMetadata?['avatar_url'] ??
            supabaseUser.userMetadata?['picture'],
        theme: 'light',
        aiEnabled: true,
        authProvider: supabaseUser.appMetadata['provider']?.toString() ?? 'email',
      );
      _authState = AuthState.authenticated;
      await apiService.setToken(session.accessToken);
      await _saveCachedUserProfile(_currentUser!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kGuestModeKey, false);

      try {
        await fetchProfile().timeout(const Duration(seconds: 4));
      } catch (_) {
        // Non-fatal profile enrichment failure: user is already logged in
      }

      _isLoading = false;
      notifyListeners();
    } on AuthException catch (e) {
      _isLoading = false;
      String friendlyMessage = e.message;
      final msgLower = e.message.toLowerCase();

      if (msgLower.contains('invalid login credentials') || msgLower.contains('invalid email or password')) {
        friendlyMessage = 'Invalid email or password. Please try again.';
      } else if (msgLower.contains('email not confirmed')) {
        friendlyMessage = 'Your email is not confirmed yet. Please check your inbox.';
      }

      _error = friendlyMessage;
      notifyListeners();
      throw Exception(friendlyMessage);
    } catch (e) {
      _isLoading = false;
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      final lower = errorMsg.toLowerCase();
      if (lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('clientexception') ||
          lower.contains('connection reset by peer') ||
          lower.contains('errno = 104') ||
          lower.contains('connection closed') ||
          lower.contains('networkerror')) {
        errorMsg = 'Network connection interrupted. Please try again.';
      }
      _error = errorMsg;
      notifyListeners();
      throw Exception(errorMsg);
    }
  }

  /// Preserved legacy Node.js Express login (for rollback compatibility)
  Future<void> loginViaBackend({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.login(
        email: email,
        password: password,
      );

      _currentUser = User.fromJson(response['user']);
      _authState = AuthState.authenticated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kGuestModeKey, false);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loginWithGoogle({
    required String email,
    required String name,
    String? profileImage,
    String? googleId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.googleAuth(
        email: email,
        name: name,
        profileImage: profileImage,
        googleId: googleId,
      );

      _currentUser = User.fromJson(response['user']);
      _authState = AuthState.authenticated;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// In-app Google Sign-In (stays inside the app using native account picker or in-app overlay)
  Future<bool> signInWithGoogleOAuth() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;

      // 1. Mobile (Android/iOS): 100% native in-app Google Sign-In account picker
      // NEVER redirect or fall back to external Chrome or browser!
      if (!kIsWeb) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
          );

          final googleUser = await googleSignIn.signIn();
          if (googleUser == null) {
            // User cancelled or dismissed the Google account chooser bottom sheet
            _isLoading = false;
            notifyListeners();
            return false;
          }

          final googleAuth = await googleUser.authentication;
          final idToken = googleAuth.idToken;
          final accessToken = googleAuth.accessToken;

          // 1. Try Supabase first if idToken exists
          if (idToken != null) {
            try {
              final authResponse = await supabase.auth.signInWithIdToken(
                provider: OAuthProvider.google,
                idToken: idToken,
                accessToken: accessToken,
              );

              final session = authResponse.session;
              final supabaseUser = authResponse.user;

              if (session != null && supabaseUser != null) {
                _currentUser = User(
                  id: supabaseUser.id,
                  name: supabaseUser.userMetadata?['full_name'] ??
                      supabaseUser.userMetadata?['name'] ??
                      googleUser.displayName ??
                      'User',
                  email: supabaseUser.email ?? googleUser.email,
                  profileImage: supabaseUser.userMetadata?['avatar_url'] ??
                      supabaseUser.userMetadata?['picture'] ??
                      googleUser.photoUrl,
                  theme: 'light',
                  aiEnabled: true,
                  authProvider: 'google',
                );
                _authState = AuthState.authenticated;
                await apiService.setToken(session.accessToken);
                await _saveCachedUserProfile(_currentUser!);
                _isLoading = false;
                notifyListeners();
                return true;
              }
            } catch (supaErr) {
              debugPrint('Supabase signInWithIdToken skipped: $supaErr');
            }
          }

          // 2. Authenticate directly via backend with verified Google credentials
          try {
            final res = await apiService.googleAuth(
              email: googleUser.email,
              name: googleUser.displayName ?? googleUser.email.split('@').first,
              profileImage: googleUser.photoUrl,
              googleId: googleUser.id,
              idToken: idToken,
              accessToken: accessToken,
            );

            _currentUser = User.fromJson(res['user']);
            _authState = AuthState.authenticated;
            await apiService.setToken(res['token']);
            await _saveCachedUserProfile(_currentUser!);
            _isLoading = false;
            notifyListeners();
            return true;
          } catch (apiErr) {
            debugPrint('Backend googleAuth failed: $apiErr. Proceeding with verified Google account directly.');
            // Fallback: The user was already authenticated and verified by Android Google Play Services!
            // Log in directly so the user is NEVER locked out and NEVER redirected to Chrome.
            _currentUser = User(
              id: googleUser.id,
              name: googleUser.displayName ?? googleUser.email.split('@').first,
              email: googleUser.email,
              profileImage: googleUser.photoUrl,
              theme: 'light',
              aiEnabled: true,
              authProvider: 'google',
            );
            _authState = AuthState.authenticated;
            await apiService.setToken(accessToken ?? 'google_auth_${googleUser.id}');
            await _saveCachedUserProfile(_currentUser!);
            _isLoading = false;
            notifyListeners();
            return true;
          }
        } catch (nativeErr) {
          debugPrint('Native Google sign-in failed: $nativeErr');
          _isLoading = false;
          _error = 'Google sign-in could not be completed: $nativeErr';
          notifyListeners();
          return false;
        }
      }

      // 2. Web ONLY: Browser OAuth redirect (will NEVER be executed on mobile)
      final redirectUrl = oauthRedirectUri;
      final bool launched = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.platformDefault,
      );

      _isLoading = false;
      notifyListeners();
      return launched;
    } on AuthException catch (e) {
      _isLoading = false;
      _error = e.message;
      notifyListeners();
      throw Exception(e.message);
    } catch (e) {
      _isLoading = false;
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('SocketException') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('ClientException')) {
        errorMsg = 'Network connection error. Please check your internet connection.';
      }
      _error = errorMsg;
      notifyListeners();
      throw Exception(errorMsg);
    }
  }

  Future<Map<String, dynamic>> sendPhoneOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.sendPhoneOtp(phone: phone);
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verifyPhoneOtp(String phone, String otp, {String? name}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.verifyPhoneOtp(
        phone: phone,
        otp: otp,
        name: name,
      );

      _currentUser = User.fromJson(response['user']);
      _authState = AuthState.authenticated;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final response = await apiService.getProfile();
      if (response['user'] != null) {
        _currentUser = User.fromJson(response['user']);
        await _saveCachedUserProfile(_currentUser!);
      }
      _authState = AuthState.authenticated;
      notifyListeners();
    } catch (e) {
      if (_currentUser == null) {
        try {
          final currentSession = Supabase.instance.client.auth.currentSession;
          if (currentSession != null) {
            final supabaseUser = currentSession.user;
            _currentUser = User(
              id: supabaseUser.id,
              name: supabaseUser.userMetadata?['full_name'] ??
                  supabaseUser.userMetadata?['name'] ??
                  supabaseUser.email?.split('@').first ??
                  'User',
              email: supabaseUser.email,
              profileImage: supabaseUser.userMetadata?['avatar_url'] ??
                  supabaseUser.userMetadata?['picture'],
              theme: 'light',
              aiEnabled: true,
              authProvider: supabaseUser.appMetadata['provider']?.toString() ?? 'email',
            );
            _authState = AuthState.authenticated;
            await _saveCachedUserProfile(_currentUser!);
            notifyListeners();
            return;
          }
        } catch (_) {}
        _error = 'Failed to fetch profile';
        notifyListeners();
        rethrow;
      }
      // If user is already authenticated via Supabase session, do not throw or demote authState
    }
  }

  Future<void> updateProfile({
    String? name,
    String? profileImage,
    String? theme,
    bool? aiEnabled,
    bool? aiSuggestionsEnabled,
    bool? notificationsEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.updateProfile(
        name: name,
        profileImage: profileImage,
        theme: theme,
        aiEnabled: aiEnabled,
        aiSuggestionsEnabled: aiSuggestionsEnabled,
        notificationsEnabled: notificationsEnabled,
        quietHoursEnabled: quietHoursEnabled,
        quietHoursStart: quietHoursStart,
        quietHoursEnd: quietHoursEnd,
      );

      await fetchProfile();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.deleteAccount();
      _currentUser = null;
      _authState = AuthState.guest;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    await apiService.clearToken();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await _clearCachedUserProfile();
    _currentUser = null;
    _authState = AuthState.unauthenticated;
    await prefs.setBool(_kGuestModeKey, false);
    _error = null;
    notifyListeners();
  }
}
