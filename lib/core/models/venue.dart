import 'package:cloud_firestore/cloud_firestore.dart';
import 'venue_section.dart';

class Venue {
  final String id;
  String name;
  DateTime eventDate;
  final List<VenueSection> sections;
  final String accessCode;
  String status; // open, locked, completed
  int bookedCount;
  int checkedInCount;
  final String adminId;

  Venue({
    required this.id,
    required this.name,
    required this.eventDate,
    required this.sections,
    required this.accessCode,
    this.status = 'open',
    this.bookedCount = 0,
    this.checkedInCount = 0,
    required this.adminId,
  });

  int get totalSeats => sections.fold(0, (acc, s) => acc + s.totalSeats);
  double get bookingProgress =>
      totalSeats > 0 ? bookedCount / totalSeats : 0.0;

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'adminId': adminId,
        'eventDate': Timestamp.fromDate(eventDate),
        'sections': sections.map((s) => s.toMap()).toList(),
        'accessCode': accessCode,
        'status': status,
        'bookedCount': bookedCount,
        'checkedInCount': checkedInCount,
      };

  factory Venue.fromFirestore(String id, Map<String, dynamic> data) => Venue(
        id: id,
        name: data['name'] as String,
        eventDate: (data['eventDate'] as Timestamp).toDate(),
        sections: (data['sections'] as List<dynamic>)
            .map((s) => VenueSection.fromMap(s as Map<String, dynamic>))
            .toList(),
        accessCode: data['accessCode'] as String,
        status: data['status'] as String? ?? 'open',
        bookedCount: (data['bookedCount'] as num?)?.toInt() ?? 0,
        checkedInCount: (data['checkedInCount'] as num?)?.toInt() ?? 0,
        adminId: data['adminId'] as String,
      );
}
