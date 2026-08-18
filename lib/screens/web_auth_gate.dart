import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/version_provider.dart';

/// Web-only: handles session restoration when a protected route is accessed
/// directly via browser URL (e.g., typing /dashboard in the address bar).
///
/// Shows a blank screen while restoring the Firebase Auth session,
/// then navigates to /dashboard (if logged in) or /login (if not).
///
/// This widget is NEVER shown on Android/iOS — mobile uses SplashScreen.
/// This widget is NOT a named route — it only appears as the initial route
/// via onGenerateInitialRoutes in main.dart.
class WebAuthGate extends StatefulWidget {
  const WebAuthGate({super.key});

  @override
  State<WebAuthGate> createState() => _WebAuthGateState();
}

class _WebAuthGateState extends State<WebAuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final version = context.read<VersionProvider>();

    await Future.wait([
      auth.tryRestoreSession(),
      version.checkVersion(),
    ]);

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      auth.isLoggedIn ? '/dashboard' : '/login',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
    );
  }
}
