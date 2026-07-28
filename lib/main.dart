import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/auth/registration_screen.dart';
import 'screens/auth/president_activation_screen.dart';
import 'screens/dashboard_router.dart';
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

  AppConfig.init(env);

  // ── Hive (local session storage) ──────────────────────────────────────────
  await Hive.initFlutter();
  await Hive.openBox<String>('session');

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(options: options);

  // ── Seed Firestore with demo data (dev + prod for Play Store review) ────────
  // Guarded by _meta/seeded_v4 — runs once per Firebase project, never again.
  await DbSeeder.seedIfNeeded();

  // ── Device orientation ────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const MaintifyApp());
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
            initialRoute: '/',
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
