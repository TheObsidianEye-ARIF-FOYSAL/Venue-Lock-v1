import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/services/volunteer_service.dart';
import '../shared/qr_scan_view.dart';

/// Camera QR scanner used by an approved volunteer to check attendees in,
/// mirroring the admin ScannerScreen but authenticated with the volunteer's
/// device token instead of an admin session.
class VolunteerScannerScreen extends StatefulWidget {
  final String venueId;
  final String volunteerId;

  const VolunteerScannerScreen({
    super.key,
    required this.venueId,
    required this.volunteerId,
  });

  @override
  State<VolunteerScannerScreen> createState() =>
      _VolunteerScannerScreenState();
}

class _VolunteerScannerScreenState extends State<VolunteerScannerScreen> {
  final _service = VolunteerService();
  bool _showGreenFlash = false;
  bool _busy = false;

  Future<void> _onQrDetected(String code) async {
    if (_busy) return;
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

    setState(() => _busy = true);
    final active = await _service.getActiveApplication();
    if (active == null) {
      if (mounted) context.go('/volunteer');
      return;
    }

    final name = await _service.checkIn(
      venueId: widget.venueId,
      volunteerId: widget.volunteerId,
      deviceToken: active.deviceToken,
      qrToken: parts[1],
    );
    if (!mounted) return;
    setState(() => _busy = false);

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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Volunteer Scanner'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
            ),
          ),
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Point the camera at an attendee\'s entry pass QR code to check them in.',
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: QrScanView(onDetect: _onQrDetected),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
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
