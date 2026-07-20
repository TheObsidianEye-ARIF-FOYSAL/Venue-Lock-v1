import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/theme_service.dart';
import '../../admin/subscription/widgets/auth_widgets.dart';
import 'profile_widgets.dart';

/// Theme palette + light/dark/system mode — available to every role, not
/// just admins, since it's a per-device preference.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return ProfileSubScaffold(
      title: 'Appearance',
      child: ProfileScrollBody(
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PALETTE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
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
                              width: 44,
                              height: 44,
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
                                      color: Colors.white, size: 22)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const CardDivider(),
              Text(
                'MODE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
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
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.white70, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 12,
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
