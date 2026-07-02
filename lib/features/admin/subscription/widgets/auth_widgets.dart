import 'package:flutter/material.dart';

/// Dark-gradient background used across the subscribe/login/profile flow,
/// derived from the currently selected palette so all 4 themes carry
/// through consistently in both light and dark mode.
BoxDecoration authGradient(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  final deep = Color.lerp(primary, Colors.black, 0.6)!;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [deep, primary],
    ),
  );
}

class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const AuthBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const AuthPrimaryButton(
      {super.key,
      required this.label,
      required this.loading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final light = Color.lerp(primary, Colors.white, 0.25)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [light, primary]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
