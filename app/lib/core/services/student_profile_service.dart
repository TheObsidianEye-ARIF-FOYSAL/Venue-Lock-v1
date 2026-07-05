import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only profile for the Audience/Volunteer roles (no server account
/// exists for them). Lets a returning attendee skip re-typing their name,
/// email, and roll number on every booking, and lets them edit it afterward
/// from the profile screen reachable off the role picker.
class StudentProfileService extends ChangeNotifier {
  static const _nameKey = 'student_profile_name';
  static const _emailKey = 'student_profile_email';
  static const _rollKey = 'student_profile_roll';

  String name = '';
  String email = '';
  String roll = '';
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString(_nameKey) ?? '';
    email = prefs.getString(_emailKey) ?? '';
    roll = prefs.getString(_rollKey) ?? '';
    _loaded = true;
    notifyListeners();
  }

  Future<void> save({
    required String name,
    required String email,
    required String roll,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_rollKey, roll);
    this.name = name;
    this.email = email;
    this.roll = roll;
    notifyListeners();
  }
}
