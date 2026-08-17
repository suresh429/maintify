import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'core/config/app_config.dart';
import 'firebase_options_dev.dart';
import 'main.dart';

/// Background FCM handler for the DEV flavor.
/// Must be a free function — runs in a separate Dart isolate.
/// Not registered on web: FCM background handling requires a service worker on web.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
      options: FirebaseOptionsDev.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  await bootstrap(FirebaseOptionsDev.currentPlatform, AppEnvironment.dev);
}
