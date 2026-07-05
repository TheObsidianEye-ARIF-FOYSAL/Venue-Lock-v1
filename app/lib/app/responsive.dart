import 'package:flutter/material.dart';

/// Small MediaQuery-driven helpers so screens look proportionally the same
/// on a small phone, a large phone, and a tablet, instead of just stretching
/// fixed pixel paddings/widths.
class Responsive {
  /// Horizontal padding that grows with screen width instead of staying a
  /// fixed 16-24px on every device.
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return width * 0.18;
    if (width >= 600) return width * 0.12;
    return 20;
  }

  /// Caps how wide a form/content column gets on tablets/desktop so text
  /// fields and cards don't stretch edge-to-edge and become hard to read.
  static const double maxContentWidth = 480;

  /// True for phones in landscape or tablets, where a wider layout (e.g. a
  /// two-column form) reads better than a single narrow column.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 700;

  /// Scales a base font size gently for very small or very large screens,
  /// clamped so text never becomes unreadably small or comically large.
  static double fontScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 390).clamp(0.85, 1.2);
  }
}

/// Wraps [child] in a horizontally-padded, width-capped, centered column —
/// the standard content shell used across the app's forms and detail
/// screens so they look consistent from small phones to tablets.
class ResponsiveScaffoldBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? verticalPadding;
  final double maxWidth;

  const ResponsiveScaffoldBody({
    super.key,
    required this.child,
    this.verticalPadding,
    this.maxWidth = Responsive.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad)
              .add(verticalPadding ?? EdgeInsets.zero),
          child: child,
        ),
      ),
    );
  }
}
