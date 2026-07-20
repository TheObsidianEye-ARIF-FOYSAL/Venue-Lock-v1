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

/// Gate 1 of the two-gate auth flow: a BdApps carrier-billing subscription
/// (Robi/Airtel direct-carrier-billing, verified via SMS OTP) that must be
/// active before an admin can even reach the phone+password login screen.
class SubscriptionService extends ChangeNotifier {
  static const _prefsKey = 'venuelock_subscribed_phone';

  final String _baseUrl;
  final Map<String, String> _referenceByPhone = {};

  bool _isSubscribed = false;
  String? _phone;
  bool _isLoading = false;
  String? _error;
  bool _sessionLoaded = false;

  bool get isSubscribed => _isSubscribed;
  String? get phone => _phone;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get sessionLoaded => _sessionLoaded;

  SubscriptionService({String? baseUrl})
      : _baseUrl = _sanitize(baseUrl ?? _kDefaultBaseUrl);

  /// Awaited once in main() before runApp() so the router's first redirect
  /// decision already knows the real subscription state instead of
  /// flashing the paywall for a previously-subscribed user. This gate is
  /// intentionally *not* re-validated against the server on every launch —
  /// once verified, presence of the locally-stored phone number is trusted
  /// until an explicit unsubscribe.
  Future<void> init() => _loadSession();

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_prefsKey);
    if (phone != null) {
      _isSubscribed = true;
      _phone = phone;
    }
    _sessionLoaded = true;
    notifyListeners();
  }

  /// Checks whether `phone` already has a registered admin login account
  /// (`users` table, via `venuelock_check_phone.php`) — i.e. whether this
  /// person has already been through the subscribe+OTP gate before on some
  /// device and can safely skip straight to phone+password login instead of
  /// repeating the BdApps OTP round-trip. Returns `null` on a network error
  /// so callers can fall back to the normal OTP flow rather than blocking.
  Future<bool?> checkExistingAccount(String phone) async {
    final normalized = _normalize(phone);
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_check_phone.php'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'phone': normalized}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final map = _json(response.body);
      return map['exists'] as bool? ?? false;
    } catch (_) {
      return null;
    }
  }

  /// Marks `phone` as subscribed on this device without an OTP round-trip —
  /// used only when [checkExistingAccount] confirms a login account already
  /// exists for it, meaning the subscribe+OTP gate was already passed once.
  Future<void> markSubscribedLocally(String phone) async {
    final normalized = _normalize(phone);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
    _referenceByPhone.remove(normalized);
    _isSubscribed = true;
    _phone = normalized;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final normalized = _normalize(phone);
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

      if (response.statusCode != 200) {
        throw Exception('OTP request failed (${response.statusCode})');
      }

      final map = _json(response.body);
      final ref =
          (map['referenceNo'] ?? map['reference_no'] ?? '').toString().trim();
      if (ref.isEmpty) {
        final code = (map['statusCode'] ?? 'UNKNOWN').toString();
        final detail =
            (map['statusDetail'] ?? 'Unable to request OTP').toString();
        throw Exception('$detail ($code)');
      }

      _referenceByPhone[normalized] = ref;
      _phone = normalized;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final normalized = _normalize(_phone ?? '');
    final ref = _referenceByPhone[normalized];
    if (ref == null || ref.isEmpty) {
      _isLoading = false;
      _error = 'No OTP request found. Please request OTP again.';
      notifyListeners();
      return false;
    }

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

      if (response.statusCode != 200) {
        throw Exception('OTP verification failed (${response.statusCode})');
      }

      final map = _json(response.body);
      final status = _upperTrim(
          map['subscriptionStatus'] ?? map['subscription_status'] ?? '');
      const accepted = {
        'REGISTERED', 'SUBSCRIBED', 'ACTIVE', 'S1000',
        'INITIAL CHARGING PENDING', 'PENDING INITIAL CHARGING'
      };
      final ok = accepted.contains(status) ||
          _upperTrim(map['statusCode'] ?? '') == 'S1000';

      if (!ok) {
        _isLoading = false;
        _error = 'Invalid OTP';
        notifyListeners();
        return false;
      }

      _referenceByPhone.remove(normalized);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
      _isSubscribed = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> unsubscribe() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) {
      _error = 'No phone found. Please subscribe again.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    final normalized = _normalize(phone);
    // unsubscribe.php wants the full international format (880...), unlike
    // send_otp/verify_otp which want the local 11-digit format.
    final subscriberId = normalized.startsWith('0')
        ? '88$normalized'
        : (normalized.length == 10 && normalized.startsWith('1')
            ? '880$normalized'
            : normalized);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/unsubscribe.php'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'subscriberId': subscriberId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Unsubscribe failed (${response.statusCode})');
      }

      final map = _json(response.body);
      final code = _upperTrim(map['statusCode'] ?? map['status_code'] ?? '');
      final subStatus = _upperTrim(
          map['subscriptionStatus'] ?? map['subscription_status'] ?? '');

      if (code != 'S1000' && subStatus != 'UNREGISTERED') {
        final detail =
            (map['statusDetail'] ?? map['status_detail'] ?? 'Unsubscribe failed')
                .toString()
                .trim();
        throw Exception(detail.isEmpty ? 'Unsubscribe failed' : detail);
      }

      await _clearSession();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _referenceByPhone.clear();
    _isSubscribed = false;
    _phone = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Map<String, dynamic> _json(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) return data;
      throw const FormatException();
    } catch (_) {
      throw Exception('Invalid server response');
    }
  }

  String _normalize(String phone) {
    final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('880') && d.length > 10) return d.substring(3);
    if (d.startsWith('88') && d.length > 11) return d.substring(2);
    return d;
  }

  String _upperTrim(dynamic v) =>
      v.toString().toUpperCase().replaceAll('_', ' ').trim();

  static String _sanitize(String raw) {
    final t = raw.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}
