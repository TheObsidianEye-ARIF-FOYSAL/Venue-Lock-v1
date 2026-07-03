import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'widgets/auth_widgets.dart';

/// Gate 1 paywall — shown before the admin can reach login/register.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Container(
        decoration: authGradient(context),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.event_seat_rounded,
                          color: Colors.white, size: 42),
                    ).animate().scale(
                        duration: 500.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 24),
                    const Text(
                      'VenueLock Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
                    const SizedBox(height: 10),
                    Text(
                      'Subscribe to unlock the admin console — create '
                      'venues, manage seat maps and scan entry passes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 32),
                    GlassCard(
                      child: Column(
                        children: const [
                          _Feature(
                              icon: Icons.dashboard_customize_rounded,
                              label: 'Create and manage unlimited venues'),
                          SizedBox(height: 16),
                          _Feature(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'Scan entry passes at the door'),
                          SizedBox(height: 16),
                          _Feature(
                              icon: Icons.event_seat_rounded,
                              label: 'Live seat availability tracking'),
                          SizedBox(height: 16),
                          _Feature(
                              icon: Icons.insights_rounded,
                              label: 'Track bookings & attendance stats'),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(
                        begin: 0.1, delay: 400.ms, duration: 400.ms),
                    const SizedBox(height: 20),
                    const PricingNotice()
                        .animate()
                        .fadeIn(delay: 480.ms),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Subscribe with Mobile',
                      loading: false,
                      onTap: () => context.push('/admin/subscribe/phone'),
                    ).animate().fadeIn(delay: 550.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
