import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/seat.dart';
import '../../../core/services/app_state.dart';

class VenueDetailScreen extends StatelessWidget {
  final String venueId;
  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final venue = appState.getVenueById(venueId);

    if (venue == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Venue'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin/venues'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final statusColor = venue.status == 'open'
        ? kSuccess
        : venue.status == 'locked'
            ? kWarning
            : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: Text(venue.name),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/venues'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/admin/venue/$venueId/scanner'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Open Scanner'),
        backgroundColor: kIndigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Seat>>(
        stream: appState.seatsStream(venueId),
        builder: (context, snap) {
          final seats = snap.data ?? [];
          final bookedSeats =
              seats.where((s) => s.status == 'booked').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status + date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      venue.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      DateFormat('MMM d, yyyy').format(venue.eventDate),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.event_seat,
                      label: 'Booked',
                      value: '${venue.bookedCount}',
                      total: '${venue.totalSeats}',
                      color: kIndigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Checked In',
                      value: '${venue.checkedInCount}',
                      total: '${venue.bookedCount}',
                      color: kSuccess,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Sections overview
              if (venue.sections.length > 1) ...[
                Text('Sections',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: venue.sections
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kIndigo.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${s.name}  ${s.totalSeats} seats',
                              style: const TextStyle(
                                  color: kIndigo,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
              // Access code
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.key_outlined,
                              color: kIndigo, size: 18),
                          const SizedBox(width: 8),
                          Text('Access Code',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: kIndigo)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                venue.accessCode,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: venue.accessCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Code copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Text(
                        'Share this code with attendees',
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
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/admin/venue/$venueId/reserve'),
                icon: const Icon(Icons.event_seat_outlined),
                label: const Text('Reserve Seats for Guests'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/admin/venue/$venueId/volunteers'),
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: const Text('Volunteer Applications'),
              ),
              const SizedBox(height: 20),
              // Attendees
              Text(
                'Attendees (${bookedSeats.length} booked)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (bookedSeats.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No bookings yet',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline),
                      ),
                    ),
                  ),
                )
              else
                ...bookedSeats.map((seat) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              kIndigo.withValues(alpha: 0.1),
                          child: Text(
                            seat.studentName
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                '?',
                            style: const TextStyle(
                                color: kIndigo,
                                fontWeight: FontWeight.bold),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      kSuccess.withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Text('Checked In',
                                    style: TextStyle(
                                        color: kSuccess,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.grey.withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Text('Pending',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                      ),
                    )),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String total;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' / $total',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
