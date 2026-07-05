import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/seat.dart';
import '../../../core/models/venue_section.dart';
import '../../../core/services/app_state.dart';

/// Lets an admin reserve seats for guests (blocking them from public
/// booking) or release a previously-reserved seat back to the public.
class SeatReserveScreen extends StatefulWidget {
  final String venueId;
  const SeatReserveScreen({super.key, required this.venueId});

  @override
  State<SeatReserveScreen> createState() => _SeatReserveScreenState();
}

class _SeatReserveScreenState extends State<SeatReserveScreen> {
  bool _busy = false;

  Future<void> _onSeatTap(Seat seat) async {
    if (seat.status == 'booked' || _busy) return;

    if (seat.status == 'blocked') {
      setState(() => _busy = true);
      final ok = await context.read<AppState>().reserveSeat(
            venueId: widget.venueId,
            seatId: seat.id,
            reserve: false,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) _showError('Could not release seat');
      return;
    }

    final guestName = await _promptGuestName();
    if (guestName == null) return;
    setState(() => _busy = true);
    final ok = await context.read<AppState>().reserveSeat(
          venueId: widget.venueId,
          seatId: seat.id,
          reserve: true,
          guestName: guestName,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _showError('Could not reserve seat');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _promptGuestName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reserve for guest'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Guest / reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim().isEmpty ? 'Guest' : ctrl.text.trim()),
            child: const Text('Reserve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final venue = appState.getVenueById(widget.venueId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reserve Seats'),
        centerTitle: false,
      ),
      body: venue == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Seat>>(
              stream: appState.seatsStream(widget.venueId),
              builder: (context, snap) {
                final seats = snap.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: const [
                          _LegendItem(
                              color: Color(0xFFE0E7FF), label: 'Available'),
                          _LegendItem(
                              color: Color(0xFFD1D5DB), label: 'Booked'),
                          _LegendItem(
                              color: kWarning, label: 'Reserved (tap to release)'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Tap an available seat to reserve it for a guest.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: snap.connectionState ==
                                  ConnectionState.waiting &&
                              seats.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : InteractiveViewer(
                              boundaryMargin: const EdgeInsets.all(48),
                              minScale: 0.4,
                              maxScale: 3.0,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: venue.sections
                                      .map((section) => _AdminSectionGrid(
                                            section: section,
                                            seats: seats
                                                .where((s) =>
                                                    s.section == section.name)
                                                .toList(),
                                            onSeatTap: _onSeatTap,
                                          ))
                                      .toList(),
                                ),
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

class _AdminSectionGrid extends StatelessWidget {
  final VenueSection section;
  final List<Seat> seats;
  final ValueChanged<Seat> onSeatTap;

  const _AdminSectionGrid({
    required this.section,
    required this.seats,
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
                      .where((s) => s.row == rowNum && s.col == colNum)
                      .firstOrNull;

                  if (seat == null) {
                    return SizedBox(
                        width: cellSize + 4, height: cellSize);
                  }

                  final Color bgColor;
                  final Color textColor;
                  if (seat.status == 'booked') {
                    bgColor = const Color(0xFFD1D5DB);
                    textColor = const Color(0xFF9CA3AF);
                  } else if (seat.status == 'blocked') {
                    bgColor = kWarning;
                    textColor = Colors.white;
                  } else {
                    bgColor = const Color(0xFFE0E7FF);
                    textColor = kIndigo;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: seat.status == 'booked'
                          ? null
                          : () => onSeatTap(seat),
                      child: Container(
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
                              fontSize: (cellSize * 0.28).clamp(9.0, 13.0),
                              fontWeight: FontWeight.w600,
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
