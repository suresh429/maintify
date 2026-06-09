// File generated from GoogleService-Info.plist and google-services.json
// Do NOT commit to public repos — contains API keys.
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
    apiKey: 'AIzaSyAr9BzFyOvBSUX1GDlsJ7_7SqCHlGfs3OY',
    appId: '1:54805482872:android:9ae61e1e77905946a7cc8d',
    messagingSenderId: '54805482872',
    projectId: 'tivastraapp',
    storageBucket: 'tivastraapp.firebasestorage.app',
    databaseURL: 'https://tivastraapp-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCJEypTjWDjcmN4_RvDiKMlNSfXe2LCB7M',
    appId: '1:54805482872:ios:7ec9b0aeb981b295a7cc8d',
    messagingSenderId: '54805482872',
    projectId: 'tivastraapp',
    storageBucket: 'tivastraapp.firebasestorage.app',
    iosClientId:
        '54805482872-b7afvcib6g76cprk1qg7hr35c1ak4al6.apps.googleusercontent.com',
    iosBundleId: 'com.maintify.app',
    databaseURL: 'https://tivastraapp-default-rtdb.firebaseio.com',
  );
}
