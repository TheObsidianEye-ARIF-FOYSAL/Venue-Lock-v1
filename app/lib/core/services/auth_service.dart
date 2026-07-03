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

  /// Changes the signed-in user's password, verifying the current one first.
  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    if (_phone == null || _token == null) return 'No account is signed in.';
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_change_password.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'phone': _phone,
              'token': _token,
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final map = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return (map['error'] as String?) ?? 'Failed to change password.';
      }
      return null;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  // ── Forgot password (phone -> BDApps OTP -> new password) ─────────────────
  //
  // This server has no email/SMS channel of its own to send a reset
  // code/link through, so it reuses the same BDApps carrier OTP
  // (send_otp.php/verify_otp.php) already used for the subscription gate,
  // then trusts the client the same way registration does.

  Future<bool> sendPasswordResetOtp(String phone) async {
    final normalized = _normalizePhone(phone);
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/send_otp.php'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {'user_mobile': normalized},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return false;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final ref =
          (map['referenceNo'] ?? map['reference_no'] ?? '').toString().trim();
      if (ref.isEmpty) return false;

      _resetReferenceByPhone[normalized] = ref;
      _resetPhone = normalized;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyPasswordResetOtp(String code) async {
    final phone = _resetPhone;
    if (phone == null) return false;
    final ref = _resetReferenceByPhone[phone];
    if (ref == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/verify_otp.php'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {'Otp': code, 'referenceNo': ref},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return false;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (map['subscriptionStatus'] ?? map['subscription_status'] ?? '')
          .toString()
          .toUpperCase()
          .replaceAll('_', ' ')
          .trim();
      const accepted = {
        'REGISTERED', 'SUBSCRIBED', 'ACTIVE', 'S1000',
        'INITIAL CHARGING PENDING', 'PENDING INITIAL CHARGING'
      };
      final ok = accepted.contains(status) ||
          (map['statusCode']?.toString().toUpperCase() == 'S1000');

      if (ok) _resetReferenceByPhone.remove(phone);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Completes the reset once the OTP above has been verified, and signs the
  /// user in with the new password.
  Future<String?> resetPassword(String newPassword) async {
    final phone = _resetPhone;
    if (phone == null) return 'Please verify your phone number again.';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_reset_password.php'),
            headers: _kHeaders,
            body: jsonEncode({'phone': phone, 'password': newPassword}),
          )
          .timeout(const Duration(seconds: 30));
      final map = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return (map['error'] as String?) ?? 'Failed to reset password.';
      }

      await _persistSession(
        phone: map['phone'] as String,
        name: map['name'] as String?,
        token: map['token'] as String,
      );
      _resetPhone = null;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  static String _normalizePhone(String phone) {
    final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('880') && d.length > 10) return d.substring(3);
    if (d.startsWith('88') && d.length > 11) return d.substring(2);
    return d;
  }

  static String _sanitize(String raw) {
    final t = raw.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}
