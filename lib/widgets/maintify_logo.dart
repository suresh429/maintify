import 'package:flutter/material.dart';

/// Official Maintify brand badge.
///
/// Displays [assets/app_logo.png] centered inside a translucent
/// rounded-square container — the canonical brand presentation used on
/// every gradient header, authentication screen, and email template.
///
/// The glass-style container is achieved through transparency alone so it
/// renders correctly on all backgrounds and in every email client.
///
/// Usage:
///   const MaintifyLogo()                         // 64 × 64 — auth headers
///   const MaintifyLogo(size: 96)                 // splash screen
///   MaintifyLogo(size: 64, backgroundOpacity: 0) // no container (edge case)
class MaintifyLogo extends StatelessWidget {
  /// Side length of the outer container in logical pixels. Defaults to 64.
  final double size;

  /// Opacity of the white translucent container background (0.0–1.0).
  /// Defaults to 0.14 — matches the app's glass-card design language.
  final double backgroundOpacity;

  const MaintifyLogo({
    super.key,
    this.size = 64,
    this.backgroundOpacity = 0.14,
  });

  @override
  Widget build(BuildContext context) {
    // Logo fills ~73 % of the container (≈ 47 px inside a 64 px badge).
    final double logoSize = size * (47.0 / 64.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(backgroundOpacity),
        borderRadius: BorderRadius.circular(size * 0.25), // 16 px at size = 64
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
          width: 1,
        ),
      ),
      child: Center(
        child: Image.asset(
          'assets/app_logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
