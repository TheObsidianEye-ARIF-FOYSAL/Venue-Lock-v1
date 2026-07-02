import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/venue.dart';
import '../models/seat.dart';
import 'firestore_service.dart';

class AppState extends ChangeNotifier {
  final _db = FirestoreService();

  List<Venue> _venues = [];
  StreamSubscription<List<Venue>>? _venuesSub;

  // Student flow state
  Venue? studentCurrentVenue;

  List<Venue> get venues => List.unmodifiable(_venues);

  // ── Admin sync ─────────────────────────────────────────────────────────────

  void startSync(String adminId) {
    _venuesSub?.cancel();
    _venues = [];
    _venuesSub = _db.venuesStream(adminId).listen((list) {
      _venues = list;
      notifyListeners();
    });
  }

  void stopSync() {
    _venuesSub?.cancel();
    _venuesSub = null;
    _venues = [];
    studentCurrentVenue = null;
    notifyListeners();
  }

  // ── Venue operations ──────────────────────────────────────────────────────

  Future<String> createVenue({
    required String name,
    required DateTime eventDate,
    required List<dynamic> sections, // List<VenueSection>
    required String adminId,
  }) => _db.createVenue(
        name: name,
        eventDate: eventDate,
        sections: sections.cast(),
        adminId: adminId,
      );

  Venue? getVenueById(String id) {
    try {
      return _venues.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Venue?> getVenueByCode(String code) =>
      _db.getVenueByCode(code);

  /// Fetches a venue directly from Firestore by document ID.
  /// Used by student screens that don't have admin sync running.
  Future<Venue?> getVenueByFirestoreId(String venueId) {
    // Check local cache first, fall back to Firestore
    final local = getVenueById(venueId);
    if (local != null) return Future.value(local);
    return _db.getVenueById(venueId);
  }

  // ── Seat operations ───────────────────────────────────────────────────────

  Stream<List<Seat>> seatsStream(String venueId) =>
      _db.seatsStream(venueId);

  Future<List<Seat>> getSeats(String venueId) =>
      _db.getSeats(venueId);

  Future<String?> bookSeat({
    required String venueId,
    required String seatId,
    required String studentName,
    required String studentEmail,
    required String rollNumber,
  }) =>
      _db.bookSeat(
        venueId: venueId,
        seatId: seatId,
        studentName: studentName,
        studentEmail: studentEmail,
        rollNumber: rollNumber,
      );

  Future<String?> checkIn(String venueId, String qrToken) =>
      _db.checkIn(venueId, qrToken);

  @override
  void dispose() {
    _venuesSub?.cancel();
    super.dispose();
  }
}
