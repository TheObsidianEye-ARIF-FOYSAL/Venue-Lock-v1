import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/theme_service.dart';

/// These auth/profile screens are always rendered as a dark "branded"
/// surface with white text and glass cards, regardless of the app's
/// light/dark mode setting — deriving the gradient from
/// `Theme.of(context).colorScheme.primary` (which changes tone between
/// light/dark ThemeData) previously caused low-contrast white text on some
/// palettes in light mode. Reading the raw palette seed color instead and
/// always darkening it here guarantees readable white text in all 4
/// palettes x both mode combinations.
Color _brandSeed(BuildContext context) =>
    context.watch<ThemeService>().seedColor;

/// A safely dark tone of the current palette, for gradient tops / large
/// flat surfaces where white text must stay readable.
Color brandDark(BuildContext context) =>
    Color.lerp(_brandSeed(context), Colors.black, 0.6)!;

/// A moderately dark accent tone — brighter than [brandDark] but still
/// dark enough for white text/icons on top of it.
Color brandAccent(BuildContext context) =>
    Color.lerp(_brandSeed(context), Colors.black, 0.25)!;

/// Dark-gradient background used across the subscribe/login/profile flow.
BoxDecoration authGradient(BuildContext context) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [brandDark(context), brandAccent(context)],
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

/// BdApps compliance: subscription pricing (incl. VAT+SC+SD) and supported
/// platform must be clearly displayed on both the paywall and the login
/// screen, matching the submitted FAQ.
class PricingNotice extends StatelessWidget {
  final Color? foreground;
  const PricingNotice({super.key, this.foreground});

  @override
  Widget build(BuildContext context) {
    final color = foreground ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                'Subscription price (Incl. VAT+SC+SD)',
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Robi: ৳2.78/day  ·  Airtel: ৳5.56/day',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Robi and Airtel subscribers only. Available on Android.',
            style: TextStyle(color: color.withValues(alpha: 0.65), fontSize: 11),
          ),
        ],
      ),
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
    final seed = _brandSeed(context);
    final dark = brandAccent(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [seed, dark]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: dark.withValues(alpha: 0.5),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
      ),
    );
  }
}
