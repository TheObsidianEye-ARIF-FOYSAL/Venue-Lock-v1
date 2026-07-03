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

  factory Seat.fromJson(Map<String, dynamic> json) => Seat(
        id: json['id'] as String,
        row: (json['row'] as num).toInt(),
        col: (json['col'] as num).toInt(),
        section: json['section'] as String? ?? '',
        status: json['status'] as String? ?? 'available',
        studentName: json['studentName'] as String?,
        studentEmail: json['studentEmail'] as String?,
        rollNumber: json['rollNumber'] as String?,
        qrToken: json['qrToken'] as String?,
        checkedIn: json['checkedIn'] as bool? ?? false,
        checkedInAt: json['checkedInAt'] != null
            ? DateTime.parse(json['checkedInAt'] as String)
            : null,
        bookedAt: json['bookedAt'] != null
            ? DateTime.parse(json['bookedAt'] as String)
            : null,
      );
}
