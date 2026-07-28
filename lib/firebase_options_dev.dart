// DEV Firebase project: maintify-dev
// Android app: com.maintify.app.dev
// iOS app:     com.maintify.app.dev
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class FirebaseOptionsDev {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not configured for Dev.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'FirebaseOptionsDev not supported for $defaultTargetPlatform');
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
