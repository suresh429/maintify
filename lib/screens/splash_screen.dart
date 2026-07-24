import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/version_provider.dart';
import '../models/update_status.dart';
import '../core/constants/app_constants.dart';
import '../widgets/maintify_logo.dart';
import '../widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _taglineFadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.65, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.60, curve: Curves.elasticOut)),
    );
    _taglineFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );

    _controller.forward();
    _navigate();
  }

  /// Startup flow:
  ///   1. Auth restore + Remote Config fetch + 2.4 s branding delay (all parallel).
  ///   2. Force update  → non-dismissible dialog; app stays on splash.
  ///   3. Optional update → dismissible dialog; navigation continues after dismiss.
  ///   4. Up to date    → navigate to dashboard or login.
  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    final version = context.read<VersionProvider>();

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2400)),
      auth.tryRestoreSession(),
      version.checkVersion(),
    ]);

    if (!mounted) return;

    final status = version.status;
    final model = version.model;

    // ── Force update ──────────────────────────────────────────────────────
    // Show non-dismissible dialog and return early — the user must update.
    // If they background the app and return, the dialog is still visible.
    // If the app is killed and relaunched, this flow runs again.
    if (status == UpdateStatus.forceUpdate && model != null) {
      showUpdateDialog(
        context,
        model: model,
        isForce: true,
        onUpdate: version.openStore,
      );
      return;
    }

    // ── Optional update ───────────────────────────────────────────────────
    // Await the dialog so navigation happens only after the user acts.
    if (status == UpdateStatus.optionalUpdate && model != null) {
      await showUpdateDialog(
        context,
        model: model,
        isForce: false,
        onUpdate: version.openStore,
      );
    }

    // ── Continue to app ───────────────────────────────────────────────────
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      auth.isLoggedIn ? '/dashboard' : '/login',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final titleColor =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF2A2D3E);
    final taglineColor =
        isDark ? const Color(0xFFC39A51) : const Color(0xFF684505);
    final indicatorColor = isDark
        ? const Color(0xFF60A5FA).withOpacity(0.5)
        : const Color(0xFF2A2D3E).withOpacity(0.25);
    final versionColor = isDark
        ? const Color(0xFF94A3B8).withOpacity(0.6)
        : const Color(0xFF2A2D3E).withOpacity(0.3);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: const MaintifyLogo(size: 96),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _taglineFadeAnim,
                    child: Text(
                      AppConstants.tagline,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: taglineColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _taglineFadeAnim,
                child: Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(indicatorColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'v${AppConstants.version}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: versionColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
