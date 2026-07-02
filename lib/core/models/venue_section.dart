class VenueSection {
  final String name;
  final int rows;
  final int cols;

  const VenueSection({
    required this.name,
    required this.rows,
    required this.cols,
  });

  int get totalSeats => rows * cols;

  String get sanitizedId =>
      name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');

  Map<String, dynamic> toMap() => {
        'name': name,
        'rows': rows,
        'cols': cols,
      };

  factory VenueSection.fromMap(Map<String, dynamic> map) => VenueSection(
        name: map['name'] as String,
        rows: (map['rows'] as num).toInt(),
        cols: (map['cols'] as num).toInt(),
      );

  VenueSection copyWith({String? name, int? rows, int? cols}) => VenueSection(
        name: name ?? this.name,
        rows: rows ?? this.rows,
        cols: cols ?? this.cols,
      );
}
