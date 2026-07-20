import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/pass_storage.dart';
import 'profile_widgets.dart';

/// Every seat booked on this device, split into Upcoming (soonest first)
/// and Past (most recent first, dimmed).
class EntryPassesScreen extends StatefulWidget {
  const EntryPassesScreen({super.key});

  @override
  State<EntryPassesScreen> createState() => _EntryPassesScreenState();
}

class _EntryPassesScreenState extends State<EntryPassesScreen> {
  List<SavedPass>? _passes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final passes = await PassStorage.getPasses();
    if (!mounted) return;
    setState(() => _passes = passes);
  }

  @override
  Widget build(BuildContext context) {
    final passes = _passes;
    return ProfileSubScaffold(
      title: 'Entry Passes',
      child: passes == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : ProfileScrollBody(
              child: passes.isEmpty
                  ? const ProfileEmptyState(
                      icon: Icons.confirmation_number_outlined,
                      message: 'No bookings yet — join a venue with its '
                          'code to reserve a seat.',
                    )
                  : _PassesList(passes: passes)
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.05),
            ),
    );
  }
}

class _PassesList extends StatelessWidget {
  final List<SavedPass> passes;
  const _PassesList({required this.passes});

  @override
  Widget build(BuildContext context) {
    final venueCount = passes.map((p) => p.venueId).toSet().length;
    final now = DateTime.now();

    final sorted = [...passes]..sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });
    final upcoming = sorted
        .where((p) =>
            p.eventDate == null ||
            !p.eventDate!.isBefore(DateTime(now.year, now.month, now.day)))
        .toList();
    final past = sorted
        .where((p) =>
            p.eventDate != null &&
            p.eventDate!.isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
        .reversed
        .toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.dashboard_customize_rounded,
                value: '$venueCount',
                label: venueCount == 1 ? 'Venue' : 'Venues Attending',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.confirmation_number_rounded,
                value: '${passes.length}',
                label: passes.length == 1 ? 'Booking' : 'Total Bookings',
              ),
            ),
          ],
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SubLabel(text: 'UPCOMING'),
          const SizedBox(height: 10),
          for (var i = 0; i < upcoming.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            PassTile(
              pass: upcoming[i],
              onTap: () => context.push(
                  '/student/pass/${upcoming[i].venueId}/${upcoming[i].seatId}'),
            ),
          ],
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SubLabel(text: 'PAST'),
          const SizedBox(height: 10),
          for (var i = 0; i < past.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            PassTile(
              pass: past[i],
              dimmed: true,
              onTap: () => context.push(
                  '/student/pass/${past[i].venueId}/${past[i].seatId}'),
            ),
          ],
        ],
      ],
    );
  }
}
