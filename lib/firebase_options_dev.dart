// DEV Firebase project: maintify-dev
// Android app: com.maintify.app.dev
// iOS app:     com.maintify.app.dev
// Web app:     Maintify Web Dev (1:624223948810:web:720d627183595178280ff3)
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class FirebaseOptionsDev {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAUTKu_Z-4WWi2Hmd5tvvXwIdL4HFgOAuA',
    appId: '1:624223948810:web:720d627183595178280ff3',
    messagingSenderId: '624223948810',
    projectId: 'maintify-dev',
    authDomain: 'maintify-dev.firebaseapp.com',
    storageBucket: 'maintify-dev.firebasestorage.app',
    measurementId: 'G-5B7683PH51',
  );

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
