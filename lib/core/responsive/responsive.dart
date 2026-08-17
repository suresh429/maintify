import 'package:flutter/material.dart';

/// Breakpoint constants and helpers for responsive layout.
class Breakpoints {
  const Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;

  /// Returns true when width < 600 (phone layout).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  /// Returns true when 600 <= width < 1024 (tablet layout).
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  /// Returns true when width >= 1024 (desktop layout).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  /// Returns true when width >= 600 — shows web/wider layout instead of
  /// the mobile-only single-column layout.
  static bool isWebLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobile;
}

/// Shows the appropriate child widget based on screen width.
///
/// [desktop] is required. [tablet] falls back to [desktop] if omitted.
/// [mobile] falls back to [tablet] (or [desktop]) if omitted.
class ResponsiveLayout extends StatelessWidget {
  final Widget desktop;
  final Widget? tablet;
  final Widget? mobile;

  const ResponsiveLayout({
    super.key,
    required this.desktop,
    this.tablet,
    this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= Breakpoints.tablet) return desktop;
    if (width >= Breakpoints.mobile) return tablet ?? desktop;
    return mobile ?? tablet ?? desktop;
  }
}

/// BuildContext extensions for convenience.
extension ResponsiveContext on BuildContext {
  bool get isMobile => Breakpoints.isMobile(this);
  bool get isTablet => Breakpoints.isTablet(this);
  bool get isDesktop => Breakpoints.isDesktop(this);
  bool get isWebLayout => Breakpoints.isWebLayout(this);
}
