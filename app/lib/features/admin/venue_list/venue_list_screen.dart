import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/responsive.dart';
import '../../../app/theme.dart';
import '../../../core/models/venue.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../subscription/widgets/auth_widgets.dart';

class VenueListScreen extends StatelessWidget {
  const VenueListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final venues = appState.venues;
    final auth = context.watch<AuthService>();
    final name = auth.displayName;

    final totalBooked = venues.fold<int>(0, (a, v) => a + v.bookedCount);
    final totalCapacity = venues.fold<int>(0, (a, v) => a + v.totalSeats);
    final totalCheckedIn = venues.fold<int>(0, (a, v) => a + v.checkedInCount);

    return Scaffold(
      body: Container(
        decoration: authGradient(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                    Expanded(
                      child: Text(
                        name.isNotEmpty
                            ? 'Hi, ${name.split(' ').first}'
                            : 'Your Venues',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: venues.isEmpty
                    ? _EmptyState(
                        onCreateTap: () =>
                            context.push('/admin/venues/create'))
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              Responsive.horizontalPadding(context),
                              4,
                              Responsive.horizontalPadding(context),
                              96,
                            ),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _DashStat(
                                      icon: Icons.dashboard_customize_rounded,
                                      value: '${venues.length}',
                                      label: 'Venues',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DashStat(
                                      icon: Icons.event_seat_rounded,
                                      value: '$totalBooked/$totalCapacity',
                                      label: 'Booked',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DashStat(
                                      icon: Icons.how_to_reg_rounded,
                                      value: '$totalCheckedIn',
                                      label: 'Checked In',
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(duration: 400.ms).slideY(
                                  begin: 0.08, duration: 400.ms),
                              const SizedBox(height: 20),
                              for (var i = 0; i < venues.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _VenueCard(
                                  venue: venues[i],
                                  onTap: () => context
                                      .push('/admin/venue/${venues[i].id}'),
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: (80 * i).ms, duration: 350.ms)
                                    .slideY(
                                        begin: 0.06,
                                        delay: (80 * i).ms,
                                        duration: 350.ms),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/venues/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Venue'),
        backgroundColor: Colors.white,
        foregroundColor: kIndigo,
      ),
    );
  }
}

class _DashStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _DashStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.event_seat_outlined,
                  color: Colors.white, size: 42),
            ).animate().scale(
                duration: 500.ms,
                curve: Curves.easeOutBack,
                begin: const Offset(0.6, 0.6)),
            const SizedBox(height: 22),
            const Text(
              'No venues yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 8),
            Text(
              'Create your first venue to start managing attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: AuthPrimaryButton(
                label: 'Create your first venue',
                loading: false,
                onTap: onCreateTap,
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(
                begin: 0.08, delay: 300.ms, duration: 350.ms),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Venue venue;
  final VoidCallback onTap;

  const _VenueCard({required this.venue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = venue.status == 'open'
        ? kSuccess
        : venue.status == 'locked'
            ? kWarning
            : Colors.white54;

    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      venue.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      venue.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.white.withValues(alpha: 0.55)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM d, yyyy').format(venue.eventDate),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                    ),
                  ),
                  if (venue.sections.length > 1) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.layers_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.55)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        venue.sections.map((s) => s.name).join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: venue.bookingProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  color: Colors.white,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${venue.bookedCount} / ${venue.totalSeats} seats booked',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.4), size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
