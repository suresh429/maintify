import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../maintify_logo.dart';

/// Split-screen auth layout for web (>= 600px).
/// On mobile it simply returns [child] unchanged.
class AuthWebLayout extends StatelessWidget {
  /// The form content shown on the right panel (or full screen on mobile).
  final Widget child;

  /// Optional subtitle displayed under the app name on the left panel.
  final String? pageTitle;

  const AuthWebLayout({
    super.key,
    required this.child,
    this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isWebLayout(context)) {
      return child;
    }

    return Row(
      children: [
        // ── Left panel (38%) ─────────────────────────────────────────────
        Expanded(
          flex: 38,
          child: _LeftPanel(pageTitle: pageTitle),
        ),

        // ── Right panel (62%) ─────────────────────────────────────────────
        Expanded(
          flex: 62,
          child: _RightPanel(child: child),
        ),
      ],
    );
  }
}

class _LeftPanel extends StatelessWidget {
  final String? pageTitle;
  const _LeftPanel({this.pageTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0F1C), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Main centered content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MaintifyLogo(size: 72, backgroundOpacity: 0.18),
                  const SizedBox(height: 32),
                  const Text(
                    'Maintify',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pageTitle ?? 'Smart Apartment Management',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.2),
                    thickness: 1,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Modern management\nfor connected communities.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Copyright at bottom
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Text(
              '© 2026 Maintify',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  final Widget child;
  const _RightPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: child,
          ),
        ),
      ),
    );
  }
}
