// Firebase client configuration for the StudySis project.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is not configured for this platform. Run flutterfire configure.',
        );
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyByLEXhBaAALc8_J4o7qZF5Ht9x7yBfWwk',
    appId: '1:51379727375:web:114b4557d90ef0c438877a',
    messagingSenderId: '51379727375',
    projectId: 'studysis-d2151',
    authDomain: 'studysis-d2151.firebaseapp.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAUM6n5zNlW_0Ao-CQC0qdt8AORLVFOpUI',
    appId: '1:51379727375:android:b5f8b94da3b9670138877a',
    messagingSenderId: '51379727375',
    projectId: 'studysis-d2151',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyB-1JYFj12lyfevleMG18bmlVvMI8vPD0o',
    appId: '1:51379727375:ios:c974fb2bdd29c31038877a',
    messagingSenderId: '51379727375',
    projectId: 'studysis-d2151',
    iosBundleId: 'com.studysis.studysis',
  );
}
