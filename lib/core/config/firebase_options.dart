import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Generated from:
/// - android/app/google-services.json
/// - ios/Runner/GoogleService-Info.plist
/// Project: tripjio-dev
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIxxo3zJD2G-XVHqq15S0ZldhiBoywu58',
    appId: '1:936663940212:web:f2a394c01e4e408f172521',
    messagingSenderId: '936663940212',
    projectId: 'tripjio-dev',
    storageBucket: 'tripjio-dev.firebasestorage.app',
    authDomain: 'tripjio-dev.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIxxo3zJD2G-XVHqq15S0ZldhiBoywu58',
    appId: '1:936663940212:android:f2a394c01e4e408f172521',
    messagingSenderId: '936663940212',
    projectId: 'tripjio-dev',
    storageBucket: 'tripjio-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDGFz1qbsLCDJm9-UkvyHO0Fnw-qE6iowM',
    appId: '1:936663940212:ios:d816a3b3eb95eed7172521',
    messagingSenderId: '936663940212',
    projectId: 'tripjio-dev',
    storageBucket: 'tripjio-dev.firebasestorage.app',
    iosBundleId: 'com.tripjio.app',
  );
}
