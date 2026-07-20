import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/subscription_service.dart';
import '../../admin/subscription/widgets/auth_widgets.dart';
import 'profile_widgets.dart';

/// Subscribed number, venue stats, and the way into venue management —
/// account-level actions (change password, logout, unsubscribe, delete
/// account) live on the main Profile screen instead, since those apply to
/// the whole account, not specifically to the admin workspace.
class AdminConsoleScreen extends StatelessWidget {
  const AdminConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionService>();
    final venues = context.watch<AppState>().venues;

    final venuesCreated = venues.length;
    final totalCapacity = venues.fold<int>(0, (a, v) => a + v.totalSeats);
    final seatsBooked = venues.fold<int>(0, (a, v) => a + v.bookedCount);
    final checkedIn = venues.fold<int>(0, (a, v) => a + v.checkedInCount);

    return ProfileSubScaffold(
      title: 'Admin Console',
      child: ProfileScrollBody(
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_android_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Subscribed number',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    subscription.phone ?? '—',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MiniStat(value: '$venuesCreated', label: 'Venues'),
                  ),
                  _divider(),
                  Expanded(
                    child: MiniStat(value: '$seatsBooked', label: 'Booked'),
                  ),
                  _divider(),
                  Expanded(
                    child:
                        MiniStat(value: '$checkedIn', label: 'Checked In'),
                  ),
                  _divider(),
                  Expanded(
                    child: MiniStat(
                        value: '$totalCapacity', label: 'Capacity'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AuthPrimaryButton(
                  label: 'Manage Venues',
                  loading: false,
                  onTap: () => context.push('/admin/venues'),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: Colors.white.withValues(alpha: 0.12),
      );
}
