import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core/navigation_key.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/apartment_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/user_provider.dart';
import 'providers/complaint_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/meeting_provider.dart';
import 'providers/registration_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/auth/registration_screen.dart';
import 'screens/auth/president_activation_screen.dart';
import 'screens/dashboard_router.dart';
import 'core/services/db_seeder.dart';

/// Top-level background message handler — must be a free function annotated
/// with @pragma('vm:entry-point') so it survives tree-shaking on release builds.
/// Firebase calls this in a separate Dart isolate when the app is in the
/// background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // In-app notifications are driven by the Firestore stream in NotificationProvider,
  // so no additional processing is required here.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive (local session storage) ──────────────────────────────────────────
  await Hive.initFlutter();
  await Hive.openBox<String>('session');

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background/terminated FCM handler before runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Seed Firestore with test data on first launch (no-op if already seeded)
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ApartmentProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ComplaintProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
        ChangeNotifierProvider(create: (_) => RegistrationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Maintify',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            navigatorKey: navigatorKey,
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
