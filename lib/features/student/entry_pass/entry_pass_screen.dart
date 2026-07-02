import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/theme.dart';
import '../../../core/models/seat.dart';
import '../../../core/models/venue.dart';
import '../../../core/services/app_state.dart';

class EntryPassScreen extends StatefulWidget {
  final String venueId;
  final String seatId;

  const EntryPassScreen({
    super.key,
    required this.venueId,
    required this.seatId,
  });

  @override
  State<EntryPassScreen> createState() => _EntryPassScreenState();
}

class _EntryPassScreenState extends State<EntryPassScreen> {
  Venue? _venue;
  Seat? _seat;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final results = await Future.wait([
      appState.getVenueByFirestoreId(widget.venueId),
      appState.getSeats(widget.venueId),
    ]);
    if (!mounted) return;
    final venue = results[0] as Venue?;
    final seats = results[1] as List<Seat>;
    setState(() {
      _venue = venue;
      _seat = seats.where((s) => s.id == widget.seatId).firstOrNull;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_venue == null || _seat == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: kError, size: 48),
              const SizedBox(height: 16),
              const Text('Pass not found'),
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
    final seat = _seat!;
    final qrData = '${widget.venueId}::${seat.qrToken}';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.go('/'),
                  ),
                  const Spacer(),
                  Text(
                    'Entry Pass',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Boarding pass card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top gradient section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1E1B4B), kIndigo],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lock_outlined,
                                        color: Colors.white54, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'VENUELOCK',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                        fontSize: 11,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  venue.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, MMMM d, yyyy')
                                      .format(venue.eventDate),
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Perforated divider
                          _PerforatedDivider(),
                          // QR Code
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          // Perforated divider
                          _PerforatedDivider(),
                          // Bottom info
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    final narrow =
                                        constraints.maxWidth < 280;
                                    if (narrow) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _InfoBlock(
                                              label: 'SEAT',
                                              value: seat.id),
                                          const SizedBox(height: 12),
                                          _InfoBlock(
                                            label: 'SECTION',
                                            value: seat.section,
                                          ),
                                          const SizedBox(height: 12),
                                          _InfoBlock(
                                            label: 'ATTENDEE',
                                            value: seat.studentName ?? '',
                                          ),
                                          const SizedBox(height: 12),
                                          _InfoBlock(
                                            label: 'ROLL NO.',
                                            value: seat.rollNumber ?? '',
                                          ),
                                          const SizedBox(height: 12),
                                          _InfoBlock(
                                            label: 'EMAIL',
                                            value:
                                                seat.studentEmail ?? '',
                                          ),
                                        ],
                                      );
                                    }
                                    return Column(
                                      children: [
                                        Row(
                                          children: [
                                            _InfoBlock(
                                                label: 'SEAT',
                                                value: seat.id),
                                            const SizedBox(width: 16),
                                            _InfoBlock(
                                              label: 'SECTION',
                                              value: seat.section,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _InfoBlock(
                                              label: 'ATTENDEE',
                                              value:
                                                  seat.studentName ?? '',
                                            ),
                                            const SizedBox(width: 16),
                                            _InfoBlock(
                                              label: 'ROLL NO.',
                                              value:
                                                  seat.rollNumber ?? '',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _InfoBlock(
                                              label: 'EMAIL',
                                              value:
                                                  seat.studentEmail ?? '',
                                            ),
                                            const SizedBox(width: 16),
                                            // filler
                                            const Expanded(child: SizedBox()),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: kSuccess.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: kSuccess
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.verified_outlined,
                                          color: kSuccess, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Valid Entry Pass',
                                        style: TextStyle(
                                          color: kSuccess,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .slideY(
                          begin: 0.3,
                          duration: 600.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Share feature coming soon!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Saved to Photos! (mock)'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Save'),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerforatedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _SemiCircle(flip: false),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                20,
                (_) => Container(
                  width: 3,
                  height: 2,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
          _SemiCircle(flip: true),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SemiCircle extends StatelessWidget {
  final bool flip;
  const _SemiCircle({required this.flip});

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flip,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: 0.5,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFE2E8F0), width: 1),
            ),
          ),
        ),
      ),
    );
  }
}
