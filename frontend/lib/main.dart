import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/api_config.dart';
import 'services/auth_service.dart';
import 'services/activity_service.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  await ApiConfig.init();
  debugPrint('✓ API Base URL configured: ${ApiConfig.getBaseUrl()}');

  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ??
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ??
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ??
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      debugPrint('✓ Supabase initialized successfully: $supabaseUrl');
    } catch (e) {
      debugPrint('⚠ Supabase initialization failed: $e');
    }
  } else {
    debugPrint('ℹ Supabase config pending in .env (SUPABASE_ANON_KEY)');
  }

  runApp(const ActivityTrackerApp());
}

class ActivityTrackerApp extends StatelessWidget {
  const ActivityTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<AuthService>(
          create: (context) => AuthService(context.read<ApiService>()),
        ),
        ChangeNotifierProvider<ActivityService>(
          create: (context) => ActivityService(
            context.read<ApiService>(),
            context.read<AuthService>(),
            previewMode: false,
          ),
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'DayTrack - Activity Tracker',
            debugShowCheckedModeBanner: false,
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            themeMode: themeService.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
