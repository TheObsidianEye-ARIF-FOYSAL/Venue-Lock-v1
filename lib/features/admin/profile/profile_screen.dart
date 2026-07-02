import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/subscription_service.dart';
import '../subscription/widgets/auth_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
    final auth = context.watch<AuthService>();
    final subscription = context.watch<SubscriptionService>();
    final venues = context.watch<AppState>().venues;
    final user = auth.currentUser;

    final venuesCreated = venues.length;
    final totalCapacity =
        venues.fold<int>(0, (acc, v) => acc + v.totalSeats);
    final seatsBooked =
        venues.fold<int>(0, (acc, v) => acc + v.bookedCount);
    final checkedIn =
        venues.fold<int>(0, (acc, v) => acc + v.checkedInCount);

    return Scaffold(
      body: Container(
        decoration: authGradient,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                      onPressed: () => context.pop(),
                    ),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        children: [
                          _AvatarHeader(
                            photoUrl: user?.photoURL,
                            name: auth.displayName,
                            email: auth.adminEmail,
                          ).animate().fadeIn(duration: 400.ms).slideY(
                              begin: 0.1, duration: 400.ms),
                          const SizedBox(height: 24),
                          _InfoCard(
                            phone: subscription.phone,
                          ).animate().fadeIn(delay: 150.ms),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.dashboard_customize_rounded,
                                  value: '$venuesCreated',
                                  label: 'Venues Created',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.event_seat_rounded,
                                  value: '$seatsBooked',
                                  label: 'Seats Booked',
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 250.ms).slideY(
                              begin: 0.08, delay: 250.ms, duration: 400.ms),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.how_to_reg_rounded,
                                  value: '$checkedIn',
                                  label: 'Checked In',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.chair_alt_rounded,
                                  value: '$totalCapacity',
                                  label: 'Total Capacity',
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 320.ms).slideY(
                              begin: 0.08, delay: 320.ms, duration: 400.ms),
                          const SizedBox(height: 32),
                          _ActionTile(
                            icon: Icons.logout_rounded,
                            label: 'Logout',
                            subtitle: 'Sign out — subscription stays active',
                            onTap: () async {
                              final ok = await _confirm(
                                context,
                                title: 'Logout?',
                                message:
                                    'You will be signed out and redirected '
                                    'to the login screen. Your subscription '
                                    'remains active.',
                                confirmLabel: 'Logout',
                              );
                              if (!ok || !context.mounted) return;
                              await context.read<AuthService>().logout();
                              if (context.mounted) {
                                context.go('/admin/login');
                              }
                            },
                          ).animate().fadeIn(delay: 400.ms),
                          const SizedBox(height: 12),
                          _ActionTile(
                            icon: Icons.unsubscribe_rounded,
                            label: 'Unsubscribe',
                            subtitle: 'Cancel subscription and sign out',
                            destructive: true,
                            onTap: () async {
                              final ok = await _confirm(
                                context,
                                title: 'Unsubscribe?',
                                message:
                                    'Your subscription will be cancelled '
                                    'and you will be signed out. You will '
                                    'need to subscribe again to use the '
                                    'admin console.',
                                confirmLabel: 'Unsubscribe',
                                destructive: true,
                              );
                              if (!ok || !context.mounted) return;
                              final unsubOk = await context
                                  .read<SubscriptionService>()
                                  .unsubscribe();
                              if (!context.mounted) return;
                              if (unsubOk) {
                                // BdApps compliance: unsubscribing must
                                // automatically log the user out and land
                                // them on the login page — no exceptions.
                                await context.read<AuthService>().logout();
                                if (context.mounted) {
                                  context.go('/admin/login');
                                }
                              } else {
                                final err = context
                                    .read<SubscriptionService>()
                                    .error;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(err ?? 'Unsubscribe failed'),
                                    backgroundColor: kError,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ).animate().fadeIn(delay: 460.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final String email;
  const _AvatarHeader(
      {required this.photoUrl, required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [kIndigoLight, kIndigo]),
            boxShadow: [
              BoxShadow(
                color: kIndigoLight.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: photoUrl != null
                ? Image.network(photoUrl!, fit: BoxFit.cover)
                : Container(
                    color: Colors.white.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name.isNotEmpty ? name : 'Admin',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String? phone;
  const _InfoCard({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded,
              color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(
            'Subscribed number',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
          const Spacer(),
          Text(
            phone ?? '—',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatTile(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kIndigoLight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? kError : Colors.white;
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
