import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/seat.dart';
import '../../../core/services/app_state.dart';
import '../../shared/qr_scan_view.dart';

class ScannerScreen extends StatefulWidget {
  final String venueId;
  const ScannerScreen({super.key, required this.venueId});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _showGreenFlash = false;

  void _onQrDetected(String code) {
    final parts = code.split('::');
    if (parts.length != 2 || parts[0] != widget.venueId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This QR code is not for this venue'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _checkIn(parts[1]);
  }

  Future<void> _checkIn(String qrToken) async {
    final appState = context.read<AppState>();
    final name = await appState.checkIn(widget.venueId, qrToken);
    if (!mounted) return;

    if (name != null) {
      setState(() => _showGreenFlash = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $name checked in!'),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _showGreenFlash = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already checked in or invalid pass'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final venue = appState.getVenueById(widget.venueId);

    if (venue == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scanner'),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.go('/admin/venue/${widget.venueId}')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scanner'),
                Text(venue.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.go('/admin/venue/${widget.venueId}'),
            ),
          ),
          body: StreamBuilder<List<Seat>>(
            stream: appState.seatsStream(widget.venueId),
            builder: (context, snap) {
              final seats = snap.data ?? [];
              final bookedSeats =
                  seats.where((s) => s.status == 'booked').toList();
              final checkedIn =
                  bookedSeats.where((s) => s.checkedIn).length;
              final total = bookedSeats.length;
              final progress = total > 0 ? checkedIn / total : 0.0;

              return Column(
                children: [
                  // Counter card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), kIndigo],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white24,
                                color: kSuccess,
                                strokeWidth: 6,
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '$checkedIn / $total',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Text('Checked In',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Camera scan window
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 220,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        QrScanView(onDetect: _onQrDetected),
                        Positioned(
                            top: 8,
                            left: 8,
                            child: _CornerBracket(
                                top: true, left: true)),
                        Positioned(
                            top: 8,
                            right: 8,
                            child: _CornerBracket(
                                top: true, left: false)),
                        Positioned(
                            bottom: 8,
                            left: 8,
                            child: _CornerBracket(
                                top: false, left: true)),
                        Positioned(
                            bottom: 8,
                            right: 8,
                            child: _CornerBracket(
                                top: false, left: false)),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Point the camera at an entry pass QR code',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  Expanded(
                    child: bookedSeats.isEmpty
                        ? Center(
                            child: Text(
                              snap.connectionState ==
                                      ConnectionState.waiting
                                  ? 'Loading…'
                                  : 'No booked attendees yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: bookedSeats.length,
                            itemBuilder: (ctx, i) {
                              final seat = bookedSeats[i];
                              return Card(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: seat.checkedIn
                                        ? kSuccess.withValues(alpha: 0.1)
                                        : kIndigo.withValues(alpha: 0.1),
                                    child: Icon(
                                      seat.checkedIn
                                          ? Icons.check
                                          : Icons.person_outline,
                                      color: seat.checkedIn
                                          ? kSuccess
                                          : kIndigo,
                                    ),
                                  ),
                                  title: Text(seat.studentName ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${seat.section} · ${seat.id}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: seat.checkedIn
                                      ? Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6),
                                          decoration: BoxDecoration(
                                            color: kSuccess.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    20),
                                          ),
                                          child: const Text('Checked ✓',
                                              style: TextStyle(
                                                  color: kSuccess,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        )
                                      : FilledButton(
                                          onPressed: () =>
                                              _checkIn(seat.qrToken!),
                                          style: FilledButton.styleFrom(
                                            minimumSize:
                                                const Size(90, 36),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12),
                                            backgroundColor: kIndigo,
                                          ),
                                          child: const Text('Check In',
                                              style:
                                                  TextStyle(fontSize: 13)),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        if (_showGreenFlash)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: kSuccess.withValues(alpha: 0.3))
                  .animate()
                  .fadeIn(duration: 100.ms)
                  .fadeOut(delay: 300.ms, duration: 400.ms),
            ),
          ),
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final bool top;
  final bool left;
  const _CornerBracket({required this.top, required this.left});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: _BracketPainter(top: top, left: left)),
      );
}

class _BracketPainter extends CustomPainter {
  final bool top;
  final bool left;
  _BracketPainter({required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kIndigo
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
