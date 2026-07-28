// Legacy default Firebase options — not used by flavored builds.
// main_dev.dart uses firebase_options_dev.dart
// main_prod.dart uses firebase_options_prod.dart
// This file is kept for reference; it mirrors the DEV project configuration.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not configured.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions not supported for $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDzrgp9mt9lj05vusTWNgyARiMOlch8Hmk',
    appId: '1:624223948810:android:989d6e847f4295b3280ff3',
    messagingSenderId: '624223948810',
    projectId: 'maintify-dev',
    storageBucket: 'maintify-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBRKoC60wMbX3yovTis7CMhZGerulJTLBo',
    appId: '1:624223948810:ios:751df77d68f105e8280ff3',
    messagingSenderId: '624223948810',
    projectId: 'maintify-dev',
    storageBucket: 'maintify-dev.firebasestorage.app',
    iosBundleId: 'com.maintify.app.dev',
  );
}
