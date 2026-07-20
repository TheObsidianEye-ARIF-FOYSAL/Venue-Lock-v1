import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../admin/subscription/widgets/auth_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: authGradient(context),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width * 0.07),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.person_outline,
                        color: Colors.white),
                    tooltip: 'My Profile',
                    onPressed: () => context.push('/student/profile'),
                  ),
                ),
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
                const SizedBox(height: 18),
                _RoleTile(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin',
                  subtitle: 'Create and manage venues',
                  colors: const [Color(0xFF6366F1), Color(0xFF4338CA)],
                  onTap: () => context.push('/admin/venues'),
                )
                    .animate()
                    .fadeIn(delay: 650.ms, duration: 450.ms)
                    .slideX(begin: -0.15, delay: 650.ms, duration: 450.ms),
                const SizedBox(height: 14),
                _RoleTile(
                  icon: Icons.confirmation_number_rounded,
                  label: 'Audience',
                  subtitle: 'Book your seat with a code',
                  colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  onTap: () => context.push('/student'),
                )
                    .animate()
                    .fadeIn(delay: 780.ms, duration: 450.ms)
                    .slideX(begin: -0.15, delay: 780.ms, duration: 450.ms),
                const SizedBox(height: 14),
                _RoleTile(
                  icon: Icons.volunteer_activism_rounded,
                  label: 'Volunteer',
                  subtitle: 'Help scan entries at the gate',
                  colors: const [Color(0xFF10B981), Color(0xFF059669)],
                  onTap: () => context.push('/volunteer'),
                )
                    .animate()
                    .fadeIn(delay: 910.ms, duration: 450.ms)
                    .slideX(begin: -0.15, delay: 910.ms, duration: 450.ms),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends State<_RoleTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.colors.first;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.colors,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
