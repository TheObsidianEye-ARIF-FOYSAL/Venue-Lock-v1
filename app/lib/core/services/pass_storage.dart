import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a lightweight reference to each seat a student has booked on this
/// device, so the entry pass can be found again after the app is force-closed
/// (booking flow only carries venueId/seatId as in-memory route args, which
/// don't survive a process restart).
class SavedPass {
  final String venueId;
  final String seatId;
  final String venueName;
  final String seatLabel;

  SavedPass({
    required this.venueId,
    required this.seatId,
    required this.venueName,
    required this.seatLabel,
  });

  Map<String, dynamic> toJson() => {
        'venueId': venueId,
        'seatId': seatId,
        'venueName': venueName,
        'seatLabel': seatLabel,
      };

  factory SavedPass.fromJson(Map<String, dynamic> json) => SavedPass(
        venueId: json['venueId'] as String,
        seatId: json['seatId'] as String,
        venueName: json['venueName'] as String? ?? '',
        seatLabel: json['seatLabel'] as String? ?? '',
      );
}

class PassStorage {
  static const _key = 'saved_passes';

  static Future<void> savePass(SavedPass pass) async {
    final prefs = await SharedPreferences.getInstance();
    final passes = await getPasses();
    passes.removeWhere(
        (p) => p.venueId == pass.venueId && p.seatId == pass.seatId);
    passes.add(pass);
    await prefs.setString(
        _key, jsonEncode(passes.map((p) => p.toJson()).toList()));
  }

  static Future<List<SavedPass>> getPasses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SavedPass.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
