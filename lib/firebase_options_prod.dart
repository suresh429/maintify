// PROD Firebase project: maintify-ff8c4
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class FirebaseOptionsProd {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not configured for Prod.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'FirebaseOptionsProd not supported for $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_Tu1xTomM3RYQVLM4Enq-vzDivHtvkLs',
    appId: '1:709385460007:android:1a72c09c63e360619b7102',
    messagingSenderId: '709385460007',
    projectId: 'maintify-ff8c4',
    storageBucket: 'maintify-ff8c4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCYfopySeDFPtSDst6ZDtczokkooS8pJwo',
    appId: '1:709385460007:ios:109f8f3299d4ec669b7102',
    messagingSenderId: '709385460007',
    projectId: 'maintify-ff8c4',
    storageBucket: 'maintify-ff8c4.firebasestorage.app',
    iosClientId:
        '709385460007-ihdsfr5gv36edlplo9ouhveikfprfl6q.apps.googleusercontent.com',
    iosBundleId: 'com.maintify.app',
  );
}
