import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gate 1 of the two-gate auth flow: a carrier-billing style subscription
/// that must be active before an admin can even reach the login screen.
///
/// This is a stub implementation (no real BdApps/carrier backend wired up
/// yet) — [sendOtp] always succeeds and [verifyOtp] accepts any 6-digit
/// code. Swap the bodies of those two methods (and [unsubscribe]) for real
/// HTTP calls to a billing aggregator when one is available; keep the
/// method signatures the same so nothing else needs to change.
class SubscriptionService extends ChangeNotifier {
  static const _prefsKey = 'venuelock_subscribed_phone';

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

  SubscriptionService();

  /// Awaited once in main() before runApp() so the router's first redirect
  /// decision already knows the real subscription state instead of
  /// flashing the paywall for a previously-subscribed user.
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

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      _phone = phone;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Unable to request OTP. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    if (code.trim().length != 6) {
      _isLoading = false;
      _error = 'Enter the 6-digit code';
      notifyListeners();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _phone!);
    _isSubscribed = true;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> unsubscribe() async {
    if (_phone == null) {
      _error = 'No phone found. Please subscribe again.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    await _clearSession();
    return true;
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _isSubscribed = false;
    _phone = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
