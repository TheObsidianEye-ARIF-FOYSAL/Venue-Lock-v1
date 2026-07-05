import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kDefaultBaseUrl = String.fromEnvironment(
  'SERVER_BASE_URL',
  defaultValue: 'https://ruetandroiddevelopers.com/ARIF(VL)',
);

const _kHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

class VolunteerApplication {
  final String volunteerId;
  final String deviceToken;
  final String venueId;
  final String venueName;

  VolunteerApplication({
    required this.volunteerId,
    required this.deviceToken,
    required this.venueId,
    required this.venueName,
  });
}

class VolunteerInfo {
  final String id;
  final String venueId;
  final String name;
  final String? phone;
  final String status;

  VolunteerInfo({
    required this.id,
    required this.venueId,
    required this.name,
    required this.phone,
    required this.status,
  });

  factory VolunteerInfo.fromJson(Map<String, dynamic> json) => VolunteerInfo(
        id: json['id'] as String,
        venueId: json['venueId'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        status: json['status'] as String,
      );
}

/// REST client for the volunteer application/approval/check-in endpoints,
/// plus local persistence of the active application so a volunteer's
/// pending/approved status survives an app restart.
class VolunteerService {
  static final VolunteerService _instance = VolunteerService._internal();
  factory VolunteerService() => _instance;
  VolunteerService._internal();

  static const _prefsVenueIdKey = 'volunteer_venue_id';
  static const _prefsVolunteerIdKey = 'volunteer_id';
  static const _prefsDeviceTokenKey = 'volunteer_device_token';
  static const _prefsVenueNameKey = 'volunteer_venue_name';

  final String _baseUrl = _sanitize(_kDefaultBaseUrl);

  Future<VolunteerApplication?> apply({
    required String accessCode,
    required String name,
    required String phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_volunteer_apply.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'accessCode': accessCode,
              'name': name,
              'phone': phone,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final application = VolunteerApplication(
        volunteerId: map['volunteerId'] as String,
        deviceToken: map['deviceToken'] as String,
        venueId: map['venueId'] as String,
        venueName: map['venueName'] as String,
      );
      await _saveActiveApplication(application);
      return application;
    } catch (_) {
      return null;
    }
  }

  Future<VolunteerInfo?> getStatus({
    required String volunteerId,
    required String deviceToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_volunteer_status.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'volunteerId': volunteerId,
              'deviceToken': deviceToken,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return VolunteerInfo.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<VolunteerInfo>> listForVenue({
    required String venueId,
    required String phone,
    required String token,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/venuelock_volunteer_list.php'),
          headers: _kHeaders,
          body: jsonEncode({'phone': phone, 'token': token, 'venueId': venueId}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return [];
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['volunteers'] as List<dynamic>)
        .map((v) => VolunteerInfo.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<bool> review({
    required String venueId,
    required String volunteerId,
    required bool approve,
    required String phone,
    required String token,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_volunteer_review.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'phone': phone,
              'token': token,
              'venueId': venueId,
              'volunteerId': volunteerId,
              'action': approve ? 'approve' : 'reject',
            }),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> checkIn({
    required String venueId,
    required String volunteerId,
    required String deviceToken,
    required String qrToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_volunteer_checkin.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'venueId': venueId,
              'volunteerId': volunteerId,
              'deviceToken': deviceToken,
              'qrToken': qrToken,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return map['studentName'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Local persistence of the active application ────────────────────────

  Future<void> _saveActiveApplication(VolunteerApplication app) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsVenueIdKey, app.venueId);
    await prefs.setString(_prefsVolunteerIdKey, app.volunteerId);
    await prefs.setString(_prefsDeviceTokenKey, app.deviceToken);
    await prefs.setString(_prefsVenueNameKey, app.venueName);
  }

  Future<VolunteerApplication?> getActiveApplication() async {
    final prefs = await SharedPreferences.getInstance();
    final venueId = prefs.getString(_prefsVenueIdKey);
    final volunteerId = prefs.getString(_prefsVolunteerIdKey);
    final deviceToken = prefs.getString(_prefsDeviceTokenKey);
    final venueName = prefs.getString(_prefsVenueNameKey);
    if (venueId == null || volunteerId == null || deviceToken == null) {
      return null;
    }
    return VolunteerApplication(
      volunteerId: volunteerId,
      deviceToken: deviceToken,
      venueId: venueId,
      venueName: venueName ?? '',
    );
  }

  Future<void> clearActiveApplication() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsVenueIdKey);
    await prefs.remove(_prefsVolunteerIdKey);
    await prefs.remove(_prefsDeviceTokenKey);
    await prefs.remove(_prefsVenueNameKey);
  }

  static String _sanitize(String raw) {
    final t = raw.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}
