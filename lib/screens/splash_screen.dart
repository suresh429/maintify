import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';
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

    // Logo fades + scales in first
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

    // Tagline fades in slightly after logo
    _taglineFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );

    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    // Run splash delay and session restore in parallel so there's no extra wait
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2400)),
      auth.tryRestoreSession(),
    ]);
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF141E30), // dark navy — top
              Color(0xFF243B55), // deep blue — bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Centre content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Logo ───────────────────────────────────────────────
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Image.asset(
                          'assets/app_logo.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── App name ───────────────────────────────────────────
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Tagline ────────────────────────────────────────────
                    FadeTransition(
                      opacity: _taglineFadeAnim,
                      child: const Text(
                        AppConstants.tagline,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFFECB6E), // gold
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Loading indicator — pinned to bottom ───────────────────
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'v${AppConstants.version}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.25),
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
      ),
    );
  }
}
