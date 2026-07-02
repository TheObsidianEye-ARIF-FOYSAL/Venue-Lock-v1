import 'package:cloud_firestore/cloud_firestore.dart';

class Seat {
  final String id; // e.g. "GIRLS_R1C1"
  final int row;
  final int col;
  final String section; // section name this seat belongs to
  String status; // available, booked
  String? studentName;
  String? studentEmail;
  String? rollNumber;
  String? qrToken;
  bool checkedIn;
  DateTime? checkedInAt;
  DateTime? bookedAt;

  Seat({
    required this.id,
    required this.row,
    required this.col,
    required this.section,
    this.status = 'available',
    this.studentName,
    this.studentEmail,
    this.rollNumber,
    this.qrToken,
    this.checkedIn = false,
    this.checkedInAt,
    this.bookedAt,
  });

  bool get isAvailable => status == 'available';
  bool get isDisabled => false;

  Map<String, dynamic> toFirestore() => {
        'row': row,
        'col': col,
        'section': section,
        'status': status,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'rollNumber': rollNumber,
        'qrToken': qrToken,
        'checkedIn': checkedIn,
        'checkedInAt':
            checkedInAt != null ? Timestamp.fromDate(checkedInAt!) : null,
        'bookedAt': bookedAt != null ? Timestamp.fromDate(bookedAt!) : null,
      };

  factory Seat.fromFirestore(String id, Map<String, dynamic> data) => Seat(
        id: id,
        row: (data['row'] as num).toInt(),
        col: (data['col'] as num).toInt(),
        section: data['section'] as String? ?? '',
        status: data['status'] as String? ?? 'available',
        studentName: data['studentName'] as String?,
        studentEmail: data['studentEmail'] as String?,
        rollNumber: data['rollNumber'] as String?,
        qrToken: data['qrToken'] as String?,
        checkedIn: data['checkedIn'] as bool? ?? false,
        checkedInAt: data['checkedInAt'] != null
            ? (data['checkedInAt'] as Timestamp).toDate()
            : null,
        bookedAt: data['bookedAt'] != null
            ? (data['bookedAt'] as Timestamp).toDate()
            : null,
      );
}
