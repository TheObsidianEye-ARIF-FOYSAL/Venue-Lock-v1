import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/theme_service.dart';
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

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete your account, all data, '
              'and cancel your subscription.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final password = ctrl.text;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting account…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Cancel the subscription first, as a courtesy, so the user isn't
    // still being billed for an account they can no longer log into.
    if (context.mounted) {
      await context.read<SubscriptionService>().unsubscribe();
    }
    final error = context.mounted
        ? await context.read<AuthService>().deleteAccount(password: password)
        : 'No account is signed in.';

    if (context.mounted) Navigator.of(context).pop(); // close loader
    if (!context.mounted) return;

    if (error == null) {
      context.go('/admin/subscribe');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final subscription = context.watch<SubscriptionService>();
    final venues = context.watch<AppState>().venues;

    final venuesCreated = venues.length;
    final totalCapacity =
        venues.fold<int>(0, (acc, v) => acc + v.totalSeats);
    final seatsBooked =
        venues.fold<int>(0, (acc, v) => acc + v.bookedCount);
    final checkedIn =
        venues.fold<int>(0, (acc, v) => acc + v.checkedInCount);

    return Scaffold(
      body: Container(
        decoration: authGradient(context),
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
                            name: auth.displayName,
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
                          const SizedBox(height: 24),
                          const _AppearanceCard()
                              .animate()
                              .fadeIn(delay: 380.ms),
                          const SizedBox(height: 24),
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
                                // Unsubscribing must automatically log the
                                // user out and return them to the start of
                                // the auth flow (Subscribe → OTP → Login).
                                await context.read<AuthService>().logout();
                                if (context.mounted) {
                                  context.go('/admin/subscribe');
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
                          const SizedBox(height: 12),
                          _ActionTile(
                            icon: Icons.delete_forever_rounded,
                            label: 'Delete Account',
                            subtitle:
                                'Permanently delete your account and data',
                            destructive: true,
                            onTap: () => _handleDeleteAccount(context),
                          ).animate().fadeIn(delay: 520.ms),
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
  final String name;
  const _AvatarHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    final seed = context.watch<ThemeService>().seedColor;
    final dark = brandAccent(context);
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [seed, dark]),
            boxShadow: [
              BoxShadow(
                color: dark.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: Container(
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
              color: brandAccent(context).withValues(alpha: 0.6),
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

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Appearance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: appPalettes.map((p) {
              final selected = themeService.palette == p.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => themeService.setPalette(p.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: p.seed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.2),
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  selected: themeService.mode == ThemeMode.light,
                  onTap: () => themeService.setMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  selected: themeService.mode == ThemeMode.dark,
                  onTap: () => themeService.setMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  icon: Icons.brightness_auto_rounded,
                  label: 'System',
                  selected: themeService.mode == ThemeMode.system,
                  onTap: () => themeService.setMode(ThemeMode.system),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.white70, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
