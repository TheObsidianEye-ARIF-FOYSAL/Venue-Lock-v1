import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width * 0.07),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(
                    Icons.lock_outlined,
                    size: 72,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 300.ms),
                const SizedBox(height: 24),
                Text(
                  'VenueLock',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                      ),
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                const SizedBox(height: 8),
                Text(
                  'Lock the headcount. Unlock smooth entry.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
                const Spacer(flex: 2),
                // Role Cards
                Text(
                  'Choose your role',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin',
                        subtitle: 'Manage venues',
                        onTap: () => context.go('/admin/venues'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Student',
                        subtitle: 'Book your seat',
                        onTap: () => context.go('/student'),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(
                      begin: 0.2,
                      delay: 700.ms,
                      duration: 500.ms,
                    ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: kIndigo, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kIndigo,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
