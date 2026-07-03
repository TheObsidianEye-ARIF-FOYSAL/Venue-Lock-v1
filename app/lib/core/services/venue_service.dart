import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/venue.dart';
import '../models/venue_section.dart';
import '../models/seat.dart';

const _kDefaultBaseUrl = String.fromEnvironment(
  'SERVER_BASE_URL',
  defaultValue: 'https://ruetandroiddevelopers.com/ARIF(VL)',
);

const _kHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

/// REST client for the venue/seat/booking endpoints in ARIF(VL), replacing
/// the old Cloud Firestore-backed FirestoreService.
class VenueService {
  static final VenueService _instance = VenueService._internal();
  factory VenueService() => _instance;
  VenueService._internal();

  final String _baseUrl = _sanitize(_kDefaultBaseUrl);

  // ── Venues ────────────────────────────────────────────────────────────────

  Future<List<Venue>> getVenues(String phone, String token) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/venuelock_venue_list.php'),
          headers: _kHeaders,
          body: jsonEncode({'phone': phone, 'token': token}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return [];
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['venues'] as List<dynamic>)
        .map((v) => Venue.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<Venue?> getVenueByCode(String code) async {
    final response = await http
        .get(Uri.parse(
            '$_baseUrl/venuelock_venue_by_code.php?code=${Uri.encodeComponent(code)}'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return Venue.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Venue?> getVenueById(String venueId) async {
    final response = await http
        .get(Uri.parse(
            '$_baseUrl/venuelock_venue_get.php?id=${Uri.encodeComponent(venueId)}'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return Venue.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<String> createVenue({
    required String name,
    required DateTime eventDate,
    required List<VenueSection> sections,
    required String adminId,
    required String token,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/venuelock_venue_create.php'),
          headers: _kHeaders,
          body: jsonEncode({
            'phone': adminId,
            'token': token,
            'name': name,
            'eventDate': eventDate.toIso8601String(),
            'sections': sections.map((s) => s.toMap()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(map['error'] ?? 'Failed to create venue');
    }
    return map['id'] as String;
  }

  // ── Seats ─────────────────────────────────────────────────────────────────

  Future<List<Seat>> getSeats(String venueId) async {
    final response = await http
        .get(Uri.parse(
            '$_baseUrl/venuelock_seats_list.php?venueId=${Uri.encodeComponent(venueId)}'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return [];
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['seats'] as List<dynamic>)
        .map((s) => Seat.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<String?> bookSeat({
    required String venueId,
    required String seatId,
    required String studentName,
    required String studentEmail,
    required String rollNumber,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_seat_book.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'venueId': venueId,
              'seatId': seatId,
              'studentName': studentName,
              'studentEmail': studentEmail,
              'rollNumber': rollNumber,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return map['qrToken'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> checkIn({
    required String venueId,
    required String qrToken,
    required String phone,
    required String token,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/venuelock_checkin.php'),
            headers: _kHeaders,
            body: jsonEncode({
              'phone': phone,
              'token': token,
              'venueId': venueId,
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

  static String _sanitize(String raw) {
    final t = raw.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}
