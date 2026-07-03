import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/seat.dart';
import '../../../core/models/venue.dart';
import '../../../core/models/venue_section.dart';
import '../../../core/services/app_state.dart';

class SeatMapScreen extends StatefulWidget {
  final String venueId;
  const SeatMapScreen({super.key, required this.venueId});

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  String? _selectedSeatId;
  Venue? _venue;
  bool _venueLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenue();
  }

  Future<void> _loadVenue() async {
    final appState = context.read<AppState>();
    // Use cached student venue first, then fetch from Firestore
    final venue = appState.studentCurrentVenue?.id == widget.venueId
        ? appState.studentCurrentVenue
        : await appState.getVenueByFirestoreId(widget.venueId);
    if (!mounted) return;
    setState(() {
      _venue = venue;
      _venueLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (_venueLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seat Map')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_venue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seat Map')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: kError, size: 48),
              const SizedBox(height: 16),
              const Text('Venue not found'),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go Home')),
            ],
          ),
        ),
      );
    }

    final venue = _venue!;

    return Scaffold(
      appBar: AppBar(
        title: Text(venue.name),
        centerTitle: false,
      ),
      body: StreamBuilder<List<Seat>>(
        stream: appState.seatsStream(widget.venueId),
        builder: (context, snap) {
          final seats = snap.data ?? [];
          final selectedSeat =
              seats.where((s) => s.id == _selectedSeatId).firstOrNull;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, yyyy').format(venue.eventDate),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kIndigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        venue.accessCode,
                        style: const TextStyle(
                          color: kIndigo,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Legend
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: const [
                    _LegendItem(
                        color: Color(0xFFE0E7FF), label: 'Available'),
                    _LegendItem(
                        color: Color(0xFFD1D5DB), label: 'Booked'),
                    _LegendItem(color: kIndigo, label: 'Selected'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Seat sections
              Expanded(
                child: snap.connectionState == ConnectionState.waiting &&
                        seats.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(48),
                        minScale: 0.4,
                        maxScale: 3.0,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: venue.sections
                                .map((section) => _SectionGrid(
                                      section: section,
                                      seats: seats
                                          .where((s) =>
                                              s.section == section.name)
                                          .toList(),
                                      selectedSeatId: _selectedSeatId,
                                      onSeatTap: (seatId) => setState(
                                          () => _selectedSeatId =
                                              _selectedSeatId == seatId
                                                  ? null
                                                  : seatId),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
              ),
              // Bottom confirm bar
              if (_selectedSeatId != null && selectedSeat != null)
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${selectedSeat.section} · Row ${selectedSeat.row}, Col ${selectedSeat.col}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                selectedSeat.id,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () => context.push(
                              '/student/book/${widget.venueId}/$_selectedSeatId'),
                          child: const Text('Confirm Seat'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  final VenueSection section;
  final List<Seat> seats;
  final String? selectedSeatId;
  final ValueChanged<String> onSeatTap;

  const _SectionGrid({
    required this.section,
    required this.seats,
    required this.selectedSeatId,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = screenWidth - 62;
    final rawCell = (availableWidth / section.cols) - 4;
    final cellSize = rawCell.clamp(24.0, 42.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: kIndigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              section.name,
              style: const TextStyle(
                color: kIndigo,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        // Column numbers header
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 30),
            ...List.generate(
              section.cols,
              (i) => SizedBox(
                width: cellSize + 4,
                child: Text(
                  '${i + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Seat rows
        ...List.generate(section.rows, (rowIdx) {
          final rowNum = rowIdx + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$rowNum',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 6),
                ...List.generate(section.cols, (colIdx) {
                  final colNum = colIdx + 1;
                  final seat = seats
                      .where(
                          (s) => s.row == rowNum && s.col == colNum)
                      .firstOrNull;

                  if (seat == null) {
                    return SizedBox(
                        width: cellSize + 4, height: cellSize);
                  }

                  final isSelected = seat.id == selectedSeatId;
                  final isBooked = seat.status == 'booked';

                  final Color bgColor;
                  final Color textColor;
                  if (isSelected) {
                    bgColor = kIndigo;
                    textColor = Colors.white;
                  } else if (isBooked) {
                    bgColor = const Color(0xFFD1D5DB);
                    textColor = const Color(0xFF9CA3AF);
                  } else {
                    bgColor = const Color(0xFFE0E7FF);
                    textColor = kIndigo;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: isBooked ? null : () => onSeatTap(seat.id),
                      child: AnimatedScale(
                        scale: isSelected ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '$colNum',
                              style: TextStyle(
                                color: textColor,
                                fontSize:
                                    (cellSize * 0.28).clamp(9.0, 13.0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}
