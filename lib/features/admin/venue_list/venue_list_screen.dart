import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/venue.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/subscription_service.dart';

class VenueListScreen extends StatelessWidget {
  const VenueListScreen({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: kError)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final venues = appState.venues;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VenueLock'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                final ok = await _confirm(
                  context,
                  title: 'Logout?',
                  message: 'You will be signed out and redirected to the '
                      'login screen. Your subscription remains active.',
                  confirmLabel: 'Logout',
                );
                if (!ok || !context.mounted) return;
                await context.read<AuthService>().logout();
                if (context.mounted) context.go('/admin/login');
              } else if (value == 'unsubscribe') {
                final ok = await _confirm(
                  context,
                  title: 'Unsubscribe?',
                  message: 'Your subscription will be cancelled and you '
                      'will be signed out. You will need to subscribe '
                      'again to use the admin console.',
                  confirmLabel: 'Unsubscribe',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                final unsubOk =
                    await context.read<SubscriptionService>().unsubscribe();
                if (!context.mounted) return;
                if (unsubOk) {
                  await context.read<AuthService>().logout();
                  if (context.mounted) context.go('/admin/subscribe');
                } else {
                  final err = context.read<SubscriptionService>().error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'Unsubscribe failed')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'unsubscribe',
                child: ListTile(
                  leading: Icon(Icons.unsubscribe_outlined),
                  title: Text('Unsubscribe'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: venues.isEmpty
          ? _EmptyState(
              onCreateTap: () => context.push('/admin/venues/create'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: venues.length,
                  itemBuilder: (ctx, i) => _VenueCard(
                    venue: venues[i],
                    onTap: () =>
                        context.push('/admin/venue/${venues[i].id}'),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/venues/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Venue'),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kIndigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.event_seat_outlined,
                  color: kIndigo, size: 40),
            ),
            const SizedBox(height: 20),
            Text('No venues yet',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Create your first venue to start managing attendance.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create your first venue'),
            ),
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
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      venue.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      venue.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, yyyy').format(venue.eventDate),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline),
              ),
              if (venue.sections.length > 1) ...[
                const SizedBox(height: 4),
                Text(
                  venue.sections.map((s) => s.name).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: venue.bookingProgress,
                  backgroundColor:
                      Theme.of(context).colorScheme.outlineVariant,
                  color: kIndigo,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${venue.bookedCount} / ${venue.totalSeats} seats booked',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
