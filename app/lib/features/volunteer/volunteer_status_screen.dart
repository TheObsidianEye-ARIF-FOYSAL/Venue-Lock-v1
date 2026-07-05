import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/services/volunteer_service.dart';
import '../admin/subscription/widgets/auth_widgets.dart';

/// Polls the server for this volunteer application's approval status.
/// Approved volunteers are routed straight into the scanner; the screen
/// also re-fires on every app relaunch since VolunteerJoinScreen resumes
/// here from the persisted application instead of losing it.
class VolunteerStatusScreen extends StatefulWidget {
  final String venueId;
  final String volunteerId;

  const VolunteerStatusScreen({
    super.key,
    required this.venueId,
    required this.volunteerId,
  });

  @override
  State<VolunteerStatusScreen> createState() => _VolunteerStatusScreenState();
}

class _VolunteerStatusScreenState extends State<VolunteerStatusScreen> {
  final _service = VolunteerService();
  Timer? _timer;
  VolunteerInfo? _info;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    final active = await _service.getActiveApplication();
    if (active == null || active.volunteerId != widget.volunteerId) {
      if (mounted) setState(() => _notFound = true);
      return;
    }
    final info = await _service.getStatus(
      volunteerId: active.volunteerId,
      deviceToken: active.deviceToken,
    );
    if (!mounted) return;
    if (info == null) {
      setState(() => _notFound = true);
      return;
    }
    setState(() {
      _info = info;
      _loading = false;
    });
    if (info.status == 'approved') {
      _timer?.cancel();
      context.go(
          '/volunteer/scanner/${widget.venueId}/${widget.volunteerId}');
    }
  }

  Future<void> _cancelApplication() async {
    _timer?.cancel();
    await _service.clearActiveApplication();
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: authGradient(context),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _notFound
                      ? _StatusCard(
                          icon: Icons.error_outline,
                          iconColor: kError,
                          title: 'Application not found',
                          message:
                              'This volunteer application could no longer be '
                              'found. Please apply again.',
                          onCancel: _cancelApplication,
                          cancelLabel: 'Back to Home',
                        )
                      : _buildStatus(_info!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(VolunteerInfo info) {
    switch (info.status) {
      case 'rejected':
        return _StatusCard(
          icon: Icons.cancel_outlined,
          iconColor: kError,
          title: 'Application Rejected',
          message:
              'The organizer did not approve your volunteer application for '
              'this venue.',
          onCancel: _cancelApplication,
          cancelLabel: 'Back to Home',
        );
      case 'approved':
        // Handled by the redirect in _poll(); shown briefly during transition.
        return const CircularProgressIndicator(color: Colors.white);
      default:
        return _StatusCard(
          icon: Icons.hourglass_top_outlined,
          iconColor: kWarning,
          title: 'Waiting for Approval',
          message:
              'Your application to volunteer as ${info.name} is pending. '
              'The venue organizer needs to approve you before you can '
              'scan entry passes. This screen updates automatically.',
          onCancel: _cancelApplication,
          cancelLabel: 'Cancel Application',
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final VoidCallback onCancel;
  final String cancelLabel;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.onCancel,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 48),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onCancel, child: Text(cancelLabel)),
          ],
        ),
      ),
    );
  }
}
