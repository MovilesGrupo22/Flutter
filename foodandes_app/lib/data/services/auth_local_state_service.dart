import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalStateService {
  AuthLocalStateService._();

  static final AuthLocalStateService instance = AuthLocalStateService._();

  static const _hasLoggedInBeforeKey = 'auth_has_logged_in_before_v1';
  static const _lastEmailKey = 'auth_last_email_v1';
  static const _lastProviderKey = 'auth_last_provider_v1';
  static const _lastLoginAtKey = 'auth_last_login_at_v1';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> markSuccessfulSignIn({
    required String? email,
    required String provider,
  }) async {
    final prefs = await _prefs;
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    await prefs.setBool(_hasLoggedInBeforeKey, true);
    if (normalizedEmail.isNotEmpty) {
      await prefs.setString(_lastEmailKey, normalizedEmail);
    }
    await prefs.setString(_lastProviderKey, provider);
    await prefs.setInt(_lastLoginAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> seedFromCurrentUser(User? user) async {
    if (user == null) return;
    final provider = _resolvePrimaryProvider(user);
    await markSuccessfulSignIn(email: user.email, provider: provider);
  }

  Future<bool> hasLoggedInBefore() async {
    final prefs = await _prefs;
    return prefs.getBool(_hasLoggedInBeforeKey) ?? false;
  }

  Future<String?> loadLastEmail() async {
    final prefs = await _prefs;
    final value = prefs.getString(_lastEmailKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<String?> loadLastProvider() async {
    final prefs = await _prefs;
    final value = prefs.getString(_lastProviderKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<DateTime?> loadLastLoginAt() async {
    final prefs = await _prefs;
    final value = prefs.getInt(_lastLoginAtKey);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  String _resolvePrimaryProvider(User user) {
    const knownProviders = ['google.com', 'password'];

    for (final provider in knownProviders) {
      final match = user.providerData.where(
        (item) => item.providerId == provider,
      );
      if (match.isNotEmpty) return provider;
    }

    for (final provider in user.providerData) {
      if (provider.providerId.isNotEmpty) return provider.providerId;
    }

    return 'password';
  }
}
