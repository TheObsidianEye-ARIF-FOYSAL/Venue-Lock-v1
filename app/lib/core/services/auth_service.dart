import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Server URL configured at build time:
//   flutter run --dart-define=SERVER_BASE_URL=https://your-server.com/path
const _kDefaultBaseUrl = String.fromEnvironment(
  'SERVER_BASE_URL',
  defaultValue: 'https://ruetandroiddevelopers.com/ARIF(VL)',
);

const _kHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

/// Gate 2 of the two-gate auth flow: phone+password admin login, backed by
/// the PHP+SQLite server in ARIF(VL). No Firebase — the server hashes and
/// verifies passwords with PHP's password_hash/password_verify, and sessions
/// are opaque bearer tokens stored alongside the phone number.
class AuthService extends ChangeNotifier {
  static const _prefsPhoneKey = 'venuelock_session_phone';
  static const _prefsTokenKey = 'venuelock_session_token';

  final String _baseUrl;
  String? _phone;
  String? _name;
  String? _token;

  // Forgot-password flow state (phone -> OTP -> new password), independent
  // of the logged-in session above.
  String? _resetPhone;
  final Map<String, String> _resetReferenceByPhone = {};

  /// Awaited once in main() before runApp() so the router's first redirect
  /// decision already knows the real login state (mirrors SubscriptionService.init).
  late final Future<void> ready;

  AuthService({String? baseUrl})
      : _baseUrl = _sanitize(baseUrl ?? _kDefaultBaseUrl) {
    ready = _restoreSession();
  }

  bool get isLoggedIn => _token != null;
  String? get phone => _phone;
  String? get token => _token;
  String get displayName => _name ?? _phone ?? '';

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_prefsPhoneKey);
    final token = prefs.getString(_prefsTokenKey);
    if (phone == null || token == null) return;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_profile.php'),
            headers: _kHeaders,
            body: jsonEncode({'phone': phone, 'token': token}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('Invalid session');

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      _phone = map['phone'] as String;
      _name = map['name'] as String?;
      _token = token;
      notifyListeners();
    } catch (_) {
      await prefs.remove(_prefsPhoneKey);
      await prefs.remove(_prefsTokenKey);
    }
  }

  Future<String?> register(String phone, String name, String password) =>
      _authRequest('venuelock_register.php', {
        'phone': phone,
        'name': name,
        'password': password,
      });

  Future<String?> login(String phone, String password) =>
      _authRequest('venuelock_login.php', {
        'phone': phone,
        'password': password,
      });

  Future<String?> _authRequest(String path, Map<String, String> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$path'),
            headers: _kHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      final map = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return (map['error'] as String?) ??
            'Something went wrong. Please try again.';
      }

      await _persistSession(
        phone: map['phone'] as String,
        name: map['name'] as String?,
        token: map['token'] as String,
      );
      notifyListeners();
      return null;
    } catch (_) {
      return 'Network error. Please check your connection and try again.';
    }
  }

  Future<void> _persistSession({
    required String phone,
    String? name,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPhoneKey, phone);
    await prefs.setString(_prefsTokenKey, token);
    _phone = phone;
    _name = name;
    _token = token;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPhoneKey);
    await prefs.remove(_prefsTokenKey);
    _phone = null;
    _name = null;
    _token = null;
    notifyListeners();
  }

  /// Deletes the signed-in user's account server-side. Requires the current
  /// password to confirm, mirroring the sensitive-operation guard Firebase
  /// used to enforce via reauthentication.
  Future<String?> deleteAccount({String? password}) async {
    if (_phone == null || _token == null) return 'No account is signed in.';
    if (password == null || password.isEmpty) {
      return 'Password required to confirm deletion.';
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_delete_account.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'phone': _phone,
              'token': _token,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final map = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return (map['error'] as String?) ?? 'Account deletion failed.';
      }
      await logout();
      return null;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  static String _sanitize(String raw) {
    final t = raw.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}
