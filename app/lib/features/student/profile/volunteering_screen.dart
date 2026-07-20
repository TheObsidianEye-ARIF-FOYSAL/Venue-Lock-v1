import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/services/volunteer_service.dart';
import 'profile_widgets.dart';

/// This device's active (or most recent) volunteer application, if any.
class VolunteeringScreen extends StatefulWidget {
  const VolunteeringScreen({super.key});

  @override
  State<VolunteeringScreen> createState() => _VolunteeringScreenState();
}

class _VolunteeringScreenState extends State<VolunteeringScreen> {
  VolunteerApplication? _app;
  VolunteerInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = VolunteerService();
    final app = await service.getActiveApplication();
    VolunteerInfo? info;
    if (app != null) {
      info = await service.getStatus(
        volunteerId: app.volunteerId,
        deviceToken: app.deviceToken,
      );
    }
    if (!mounted) return;
    setState(() {
      _app = app;
      _info = info;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSubScaffold(
      title: 'Volunteering',
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : ProfileScrollBody(
              child: _app == null
                  ? const ProfileEmptyState(
                      icon: Icons.volunteer_activism_outlined,
                      message: 'Not volunteering anywhere yet — apply with '
                          'a venue\'s access code.',
                    )
                  : _VolunteerCard(
                      app: _app!,
                      info: _info,
                      onViewStatus: () => context.push(
                          '/volunteer/status/${_app!.venueId}/${_app!.volunteerId}'),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),
            ),
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  final VolunteerApplication app;
  final VolunteerInfo? info;
  final VoidCallback onViewStatus;

  const _VolunteerCard({
    required this.app,
    required this.info,
    required this.onViewStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = info?.status ?? 'pending';
    final (statusColor, statusLabel, statusIcon) = switch (status) {
      'approved' => (kSuccess, 'Approved', Icons.check_circle_rounded),
      'rejected' => (kError, 'Rejected', Icons.cancel_rounded),
      _ => (kWarning, 'Pending Approval', Icons.hourglass_top_rounded),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kIndigo.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.venueName.isNotEmpty ? app.venueName : 'Venue',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Volunteer application',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewStatus,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View Status'),
            ),
          ),
        ],
      ),
    );
  }
}
