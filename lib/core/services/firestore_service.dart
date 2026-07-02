import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/venue.dart';
import '../models/venue_section.dart';
import '../models/seat.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  // ── Venues ────────────────────────────────────────────────────────────────

  Stream<List<Venue>> venuesStream(String adminId) => _db
      .collection('venues')
      .where('adminId', isEqualTo: adminId)
      .orderBy('eventDate', descending: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Venue.fromFirestore(d.id, d.data()))
          .toList());

  Future<Venue?> getVenueByCode(String code) async {
    final snap = await _db
        .collection('venues')
        .where('accessCode', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Venue.fromFirestore(d.id, d.data());
  }

  Future<Venue?> getVenueById(String venueId) async {
    final doc = await _db.collection('venues').doc(venueId).get();
    if (!doc.exists) return null;
    return Venue.fromFirestore(doc.id, doc.data()!);
  }

  Future<String> createVenue({
    required String name,
    required DateTime eventDate,
    required List<VenueSection> sections,
    required String adminId,
  }) async {
    final id = _uuid.v4();
    final accessCode = _generateCode();

    final venue = Venue(
      id: id,
      name: name,
      eventDate: eventDate,
      sections: sections,
      accessCode: accessCode,
      adminId: adminId,
    );

    final batch = _db.batch();
    batch.set(_db.collection('venues').doc(id), venue.toFirestore());

    // Generate all seat documents
    for (final section in sections) {
      for (int r = 1; r <= section.rows; r++) {
        for (int c = 1; c <= section.cols; c++) {
          final seatId = '${section.sanitizedId}_R${r}C$c';
          final seat = Seat(
            id: seatId,
            row: r,
            col: c,
            section: section.name,
          );
          batch.set(
            _db.collection('venues').doc(id).collection('seats').doc(seatId),
            seat.toFirestore(),
          );
        }
      }
    }

    await batch.commit();
    return id;
  }

  // ── Seats ─────────────────────────────────────────────────────────────────

  Stream<List<Seat>> seatsStream(String venueId) => _db
      .collection('venues')
      .doc(venueId)
      .collection('seats')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Seat.fromFirestore(d.id, d.data())).toList());

  Future<List<Seat>> getSeats(String venueId) async {
    final snap = await _db
        .collection('venues')
        .doc(venueId)
        .collection('seats')
        .get();
    return snap.docs.map((d) => Seat.fromFirestore(d.id, d.data())).toList();
  }

  // Book a seat — uses a transaction to prevent double-booking
  Future<String?> bookSeat({
    required String venueId,
    required String seatId,
    required String studentName,
    required String studentEmail,
    required String rollNumber,
  }) async {
    final seatRef =
        _db.collection('venues').doc(venueId).collection('seats').doc(seatId);
    final venueRef = _db.collection('venues').doc(venueId);
    final qrToken = _uuid.v4();

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(seatRef);
        if (!snap.exists) throw Exception('Seat not found');
        if ((snap.data()!['status'] as String?) != 'available') {
          throw Exception('Seat already booked');
        }
        tx.update(seatRef, {
          'status': 'booked',
          'studentName': studentName,
          'studentEmail': studentEmail,
          'rollNumber': rollNumber,
          'qrToken': qrToken,
          'bookedAt': FieldValue.serverTimestamp(),
        });
        tx.update(venueRef, {'bookedCount': FieldValue.increment(1)});
      });
      return qrToken;
    } catch (_) {
      return null;
    }
  }

  // Check in — uses a transaction to prevent duplicate scans
  Future<String?> checkIn(String venueId, String qrToken) async {
    final seatsRef =
        _db.collection('venues').doc(venueId).collection('seats');

    final snap =
        await seatsRef.where('qrToken', isEqualTo: qrToken).limit(1).get();
    if (snap.docs.isEmpty) return null;

    final seatDoc = snap.docs.first;
    String? studentName;

    try {
      await _db.runTransaction((tx) async {
        final fresh = await tx.get(seatDoc.reference);
        if (fresh.data()!['checkedIn'] == true) throw Exception('Already checked in');
        studentName = fresh.data()!['studentName'] as String?;
        tx.update(seatDoc.reference, {
          'checkedIn': true,
          'checkedInAt': FieldValue.serverTimestamp(),
        });
        tx.update(_db.collection('venues').doc(venueId),
            {'checkedInCount': FieldValue.increment(1)});
      });
      return studentName;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
