import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/app_config.dart';
import 'core/navigation_key.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/apartment_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/user_provider.dart';
import 'providers/complaint_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/meeting_provider.dart';
import 'providers/registration_provider.dart';
import 'providers/version_provider.dart';
import 'providers/ads_provider.dart';
import 'core/services/admob_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/auth/registration_screen.dart';
import 'screens/auth/president_activation_screen.dart';
import 'screens/dashboard_router.dart';
import 'screens/web_auth_gate.dart';
import 'core/services/db_seeder.dart';
import 'widgets/global_connectivity_overlay.dart';

/// Shared bootstrap called by both main_dev.dart and main_prod.dart.
/// [options] — environment-specific FirebaseOptions.
/// [env]     — set before any widget/provider reads AppConfig.
Future<void> bootstrap(
  FirebaseOptions options,
  AppEnvironment env,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Web: use path-based URLs (no # hash fragments) ───────────────────────
  // Must be called before runApp. Firebase Hosting rewrites handle server-side
  // routing so browser refresh on any path returns index.html correctly.
  if (kIsWeb) usePathUrlStrategy();

  AppConfig.init(env);

  // ── Hive (local session storage) ──────────────────────────────────────────
  await Hive.initFlutter();
  await Hive.openBox<String>('session');

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(options: options);

  // ── AdMob (mobile only) ────────────────────────────────────────────────
  await AdMobService.initialize();

  // ── Seed Firestore with demo data (dev + prod for Play Store review) ────────
  // Guarded by _meta/seeded_v4 — runs once per Firebase project, never again.
  await DbSeeder.seedIfNeeded();

  // ── Device orientation (mobile only) ─────────────────────────────────────
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
  }

  runApp(const MaintifyApp());
}

/// Overrides Flutter's default "split path segments into multiple routes"
/// behavior for the initial route.
///
/// Flutter's default: initialRoute '/login' → stack [Route('/'), Route('/login')]
/// This creates SplashScreen at the bottom → browser back shows Splash.
///
/// With onGenerateInitialRoutes: We return exactly ONE route in the stack,
/// which eliminates SplashScreen from browser history entirely.
///
/// On mobile: always returns [SplashScreen] (routeName is always '/').
/// On web: maps the browser URL path to the correct single-entry stack.
List<Route<dynamic>> _generateInitialRoutes(String routeName) {
  if (!kIsWeb) {
    return [
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const SplashScreen(),
      ),
    ];
  }
  // Web: routeName IS the browser URL path (because usePathUrlStrategy is active).
  return [_buildWebRoute(routeName)];
}

Route<dynamic> _buildWebRoute(String path) {
  switch (path) {
    case '/login':
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => const LoginScreen(),
      );
    case '/signup':
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/signup'),
        builder: (_) => const RegistrationScreen(),
      );
    case '/activate':
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/activate'),
        builder: (_) => const PresidentActivationScreen(),
      );
    default:
      // Protected routes (/dashboard, /*, etc.) and unknown paths:
      // WebAuthGate restores session then redirects to /dashboard or /login.
      return MaterialPageRoute<void>(
        settings: RouteSettings(name: path),
        builder: (_) => const WebAuthGate(),
      );
  }
}

class MaintifyApp extends StatelessWidget {
  const MaintifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // ConnectivityProvider is registered early so GlobalConnectivityOverlay
        // (injected via MaterialApp.builder) can access it immediately.
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ApartmentProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ComplaintProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
        ChangeNotifierProvider(create: (_) => RegistrationProvider()),
        ChangeNotifierProvider(create: (_) => VersionProvider()),
        ChangeNotifierProvider(create: (_) => AdsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: AppConfig.isDevelopment,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            navigatorKey: navigatorKey,
            // GlobalConnectivityOverlay wraps the entire Navigator so every
            // route, dialog, and bottom sheet automatically inherits the banner.
            builder: (context, child) => GlobalConnectivityOverlay(
              child: child ?? const SizedBox(),
            ),
            // onGenerateInitialRoutes overrides Flutter's default behaviour of
            // splitting the path into multiple stack entries (e.g. '/login' →
            // [SplashScreen('/'), LoginScreen('/login')]). By returning exactly
            // one route we prevent SplashScreen from appearing in browser history
            // and eliminate the "login shows twice" and "back shows splash" bugs.
            onGenerateInitialRoutes: _generateInitialRoutes,
            routes: {
              '/': (_) => const SplashScreen(),
              '/login': (_) => const LoginScreen(),
              '/signup': (_) => const RegistrationScreen(),
              '/activate': (_) => const PresidentActivationScreen(),
              '/dashboard': (_) => const DashboardRouter(),
            },
          );
        },
      ),
    );
  }
}
