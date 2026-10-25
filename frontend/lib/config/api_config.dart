import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API configuration for DayTrack.
///
/// Handles environment-specific URL resolution across:
/// - Android Emulators (maps localhost/127.0.0.1 to 10.0.2.2)
/// - Physical Android devices (supports local network IP, e.g. 192.168.x.x / 172.x.x.x or adb reverse)
/// - Flutter Web (uses browser-accessible origin or localhost)
/// - Deployed Cloud Backend (uses HTTPS on Render, Railway, etc.)
/// - Build-time `--dart-define=API_URL=...` overrides
class ApiConfig {
  static const String _tokenPrefKey = 'custom_api_url';

  /// Compile-time build flag: flutter run --dart-define=API_URL=http://...
  static const String _dartDefineApiUrl =
      String.fromEnvironment('API_URL', defaultValue: '');

  /// Cached resolved base URL
  static String? _cachedBaseUrl;

  /// Default local development port
  static const int defaultPort = 5000;

  /// Fast health check against candidate backend base URL
  static Future<bool> isUrlHealthy(String url) async {
    try {
      final normalized = _normalizeUrl(url);
      final healthUri = Uri.parse('$normalized/health');
      final res = await http.get(healthUri).timeout(const Duration(milliseconds: 1000));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns the centralized API base URL.
  static String getBaseUrl() {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      return _cachedBaseUrl!;
    }

    // 1. Build-time dart-define override (highest precedence)
    if (_dartDefineApiUrl.isNotEmpty) {
      _cachedBaseUrl = _normalizeUrl(_dartDefineApiUrl);
      return _cachedBaseUrl!;
    }

    // 2. Runtime .env configuration (API_URL, PROD_API_URL, or BACKEND_URL)
    final envUrl = dotenv.env['API_URL']?.trim() ??
        dotenv.env['PROD_API_URL']?.trim() ??
        dotenv.env['BACKEND_URL']?.trim() ??
        '';
    if (envUrl.isNotEmpty) {
      _cachedBaseUrl = _resolveForPlatform(envUrl);
      return _cachedBaseUrl!;
    }

    // 3. Platform fallback
    _cachedBaseUrl = defaultPlatformUrl;
    return _cachedBaseUrl!;
  }

  /// Refreshes and initializes with intelligent fast auto-discovery.
  static Future<String> init() async {
    // 1. Build-time override
    if (_dartDefineApiUrl.isNotEmpty) {
      _cachedBaseUrl = _normalizeUrl(_dartDefineApiUrl);
      return _cachedBaseUrl!;
    }

    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(_tokenPrefKey)?.trim();

    final envUrl = dotenv.env['API_URL']?.trim() ??
        dotenv.env['PROD_API_URL']?.trim() ??
        dotenv.env['BACKEND_URL']?.trim() ??
        '';

    final candidates = <String>[];
    if (customUrl != null && customUrl.isNotEmpty) {
      candidates.add(_resolveForPlatform(customUrl));
    }
    if (envUrl.isNotEmpty) {
      candidates.add(_resolveForPlatform(envUrl));
    }
    // Add current active LAN IP candidate
    candidates.add('http://172.23.51.7:$defaultPort/api');
    candidates.add(defaultPlatformUrl);

    final uniqueCandidates = candidates.toSet().toList();

    // Check candidate URLs sequentially with fast timeout
    for (final candidate in uniqueCandidates) {
      final healthy = await isUrlHealthy(candidate);
      if (healthy) {
        _cachedBaseUrl = candidate;
        if (customUrl != null && customUrl != candidate) {
          await prefs.remove(_tokenPrefKey);
        }
        return candidate;
      }
    }

    // Fallback without blocking when offline
    if (envUrl.isNotEmpty) {
      _cachedBaseUrl = _resolveForPlatform(envUrl);
    } else if (customUrl != null && customUrl.isNotEmpty) {
      _cachedBaseUrl = _resolveForPlatform(customUrl);
    } else {
      _cachedBaseUrl = defaultPlatformUrl;
    }
    return _cachedBaseUrl!;
  }

  /// Sets a runtime custom server override (useful for mobile network testing).
  static Future<void> setCustomApiUrl(String? customUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (customUrl == null || customUrl.trim().isEmpty) {
      await prefs.remove(_tokenPrefKey);
      _cachedBaseUrl = null;
    } else {
      final normalized = _resolveForPlatform(customUrl.trim());
      await prefs.setString(_tokenPrefKey, normalized);
      _cachedBaseUrl = normalized;
    }
  }

  /// Default URL for the current platform when no configuration is specified.
  static String get defaultPlatformUrl {
    if (kIsWeb) {
      return 'http://localhost:$defaultPort/api';
    }
    try {
      if (Platform.isAndroid) {
        // Android emulator loopback alias to host machine
        return 'http://10.0.2.2:$defaultPort/api';
      }
    } catch (_) {}
    return 'http://localhost:$defaultPort/api';
  }

  /// Adapts URLs for mobile platforms (e.g., replaces localhost with 10.0.2.2 on Android emulator).
  static String _resolveForPlatform(String rawUrl) {
    String url = _normalizeUrl(rawUrl);

    if (kIsWeb) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final host = uri.host.toLowerCase();
        // If running Flutter Web locally, map emulator or private LAN IPs to localhost
        // to avoid Wi-Fi DHCP timeouts and cross-network latency. Cloud URLs remain untouched.
        if (host == '10.0.2.2' ||
            host == '127.0.0.1' ||
            host.startsWith('192.168.') ||
            host.startsWith('172.') ||
            host.startsWith('10.')) {
          return uri.replace(host: 'localhost').toString();
        }
      }
      return url;
    }

    try {
      if (Platform.isAndroid) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          // If the configured URL explicitly uses localhost or 127.0.0.1 on Android,
          // map it to 10.0.2.2 for emulator compatibility while preserving port & path.
          if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
            final rewritten = uri.replace(host: '10.0.2.2');
            return rewritten.toString();
          }
        }
      }
    } catch (_) {}

    return url;
  }

  /// Ensures URL is valid, trimmed, has no trailing slash, and includes the /api suffix.
  static String _normalizeUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (!url.endsWith('/api') && !url.contains('/api/')) {
      url = '$url/api';
    }
    return url;
  }
}
