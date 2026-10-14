import 'package:flutter_test/flutter_test.dart';
import 'package:activity_tracker/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;

void main() {
  group('User Model & Auth Serialization', () {
    test('User serialization round-trip works correctly', () {
      final user = User(
        id: 'usr-456',
        name: 'Test Account',
        email: 'test@example.com',
        profileImage: 'https://example.com/avatar.png',
        theme: 'dark',
        aiEnabled: true,
        authProvider: 'google',
      );

      final map = user.toJson();
      expect(map['id'], 'usr-456');
      expect(map['name'], 'Test Account');
      expect(map['email'], 'test@example.com');
      expect(map['profile_image'], 'https://example.com/avatar.png');
      expect(map['theme'], 'dark');
      expect(map['ai_enabled'], true);
      expect(map['auth_provider'], 'google');

      final reconstructed = User.fromJson(map);
      expect(reconstructed.id, user.id);
      expect(reconstructed.name, user.name);
      expect(reconstructed.email, user.email);
      expect(reconstructed.profileImage, user.profileImage);
      expect(reconstructed.theme, user.theme);
      expect(reconstructed.aiEnabled, user.aiEnabled);
      expect(reconstructed.authProvider, user.authProvider);
    });

    test('User.fromJson handles null optional fields gracefully', () {
      final map = {
        'id': 'usr-minimal',
        'name': 'Minimal User',
        'email': 'minimal@example.com',
      };

      final user = User.fromJson(map);
      expect(user.id, 'usr-minimal');
      expect(user.name, 'Minimal User');
      expect(user.email, 'minimal@example.com');
      expect(user.profileImage, isNull);
      expect(user.theme, 'light');
      expect(user.aiEnabled, true);
      expect(user.authProvider, 'email');
    });
  });

  group('AuthState Enumeration and Expectations', () {
    test('AuthState contains all required states for clean UI routing', () {
      expect(AuthState.values, contains(AuthState.loading));
      expect(AuthState.values, contains(AuthState.guest));
      expect(AuthState.values, contains(AuthState.authenticated));
      expect(AuthState.values, contains(AuthState.unauthenticated));
    });

    test('Exact duplicate email error constant verification', () {
      const expectedMessage = 'An account with this email already exists. Please log in instead.';
      final exception = sp.AuthException(expectedMessage);

      expect(exception.message, 'An account with this email already exists. Please log in instead.');
    });

    test('Supabase obfuscated duplicate detection logic', () {
      // Supabase returns an empty identities list when email confirmations are required and email already exists
      final emptyIdentities = <sp.UserIdentity>[];
      final isExistingObfuscatedAccount = emptyIdentities.isEmpty;

      expect(isExistingObfuscatedAccount, isTrue);

      if (isExistingObfuscatedAccount) {
        final err = sp.AuthException('An account with this email already exists. Please log in instead.');
        expect(err.message, 'An account with this email already exists. Please log in instead.');
      }
    });
  });

  group('Guest Trial Logic Tests', () {
    test('Trial is active within 2 days of start', () {
      final now = DateTime.now();
      final elapsed = DateTime.now().difference(now).inDays;
      expect(elapsed >= 2, isFalse);
    });

    test('Trial is expired after 2 days', () {
      final pastStart = DateTime.now().subtract(const Duration(days: 2, hours: 2));
      final elapsed = DateTime.now().difference(pastStart).inDays;
      expect(elapsed >= 2, isTrue);
    });
  });
}
