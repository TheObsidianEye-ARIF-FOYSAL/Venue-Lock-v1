import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/venue.dart';
import '../models/venue_section.dart';
import '../models/seat.dart';
import 'venue_service.dart';

class AppState extends ChangeNotifier {
  final _service = VenueService();

  List<Venue> _venues = [];
  Timer? _venuesTimer;
  String? _phone;
  String? _token;

  // Student flow state
  Venue? studentCurrentVenue;

  List<Venue> get venues => List.unmodifiable(_venues);

  // ── Admin sync ─────────────────────────────────────────────────────────────

  void startSync(String phone, String token) {
    _venuesTimer?.cancel();
    _phone = phone;
    _token = token;
    _venues = [];
    _pollVenues();
    _venuesTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _pollVenues());
  }

  Future<void> _pollVenues() async {
    if (_phone == null || _token == null) return;
    try {
      final list = await _service.getVenues(_phone!, _token!);
      _venues = list;
      notifyListeners();
    } catch (_) {
      // Keep last known list on transient network errors.
    }
  }

  void stopSync() {
    _venuesTimer?.cancel();
    _venuesTimer = null;
    _phone = null;
    _token = null;
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
  }) {
    if (_token == null) throw Exception('Not signed in');
    return _service.createVenue(
      name: name,
      eventDate: eventDate,
      sections: sections.cast<VenueSection>(),
      adminId: adminId,
      token: _token!,
    );
  }

  Venue? getVenueById(String id) {
    try {
      return _venues.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Venue?> getVenueByCode(String code) => _service.getVenueByCode(code);

  /// Fetches a venue directly from the server by id.
  /// Used by student screens that don't have admin sync running.
  Future<Venue?> getVenueByFirestoreId(String venueId) {
    // Check local cache first, fall back to the server.
    final local = getVenueById(venueId);
    if (local != null) return Future.value(local);
    return _service.getVenueById(venueId);
  }

  // ── Seat operations ───────────────────────────────────────────────────────

  /// Polling-backed broadcast stream (the server has no realtime push), so
  /// existing StreamBuilder call sites need no changes.
  Stream<List<Seat>> seatsStream(String venueId) {
    late StreamController<List<Seat>> controller;
    Timer? timer;

    Future<void> poll() async {
      try {
        final seats = await _service.getSeats(venueId);
        if (!controller.isClosed) controller.add(seats);
      } catch (_) {
        // Ignore transient errors; keep polling.
      }
    }

    controller = StreamController<List<Seat>>(
      onListen: () {
        poll();
        timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  Future<List<Seat>> getSeats(String venueId) => _service.getSeats(venueId);

  Future<String?> bookSeat({
    required String venueId,
    required String seatId,
    required String studentName,
    required String studentEmail,
    required String rollNumber,
  }) =>
      _service.bookSeat(
        venueId: venueId,
        seatId: seatId,
        studentName: studentName,
        studentEmail: studentEmail,
        rollNumber: rollNumber,
      );

  Future<String?> checkIn(String venueId, String qrToken) {
    if (_phone == null || _token == null) throw Exception('Not signed in');
    return _service.checkIn(
      venueId: venueId,
      qrToken: qrToken,
      phone: _phone!,
      token: _token!,
    );
  }

  @override
  void dispose() {
    _venuesTimer?.cancel();
    super.dispose();
  }
}
