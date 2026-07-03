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

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
        id: json['id'] as String,
        name: json['name'] as String,
        eventDate: DateTime.parse(json['eventDate'] as String),
        sections: (json['sections'] as List<dynamic>)
            .map((s) => VenueSection.fromMap(s as Map<String, dynamic>))
            .toList(),
        accessCode: json['accessCode'] as String,
        status: json['status'] as String? ?? 'open',
        bookedCount: (json['bookedCount'] as num?)?.toInt() ?? 0,
        checkedInCount: (json['checkedInCount'] as num?)?.toInt() ?? 0,
        adminId: json['adminId'] as String,
      );
}
