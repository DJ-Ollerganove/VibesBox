// Firebase-Konfiguration je Plattform (iOS-Werte aus ios/Runner/GoogleService-Info.plist).

// ignore_for_file: constant_identifier_names

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web-Konfiguration für dj-ollerganove
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
    appId: '1:567845942758:web:8549e7d5abb8b3b81bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    authDomain: 'dj-ollerganove.firebaseapp.com',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
    appId: '1:567845942758:android:b6af2b4d3e9c4a0e1bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCl6bzYDicx88yqS_eqgEXBtb55NC6BxYE',
    appId: '1:567845942758:ios:3c50a027e0a4697e1bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
    iosClientId:
        '567845942758-jj8j5j2e6vjiafaitnts8bunklh10ddr.apps.googleusercontent.com',
    iosBundleId: 'com.vibesbox.dj',
  );

  /// Gleiches Firebase-Projekt wie iOS (eigene macOS-App in der Console optional).
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCl6bzYDicx88yqS_eqgEXBtb55NC6BxYE',
    appId: '1:567845942758:ios:3c50a027e0a4697e1bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
    iosClientId:
        '567845942758-jj8j5j2e6vjiafaitnts8bunklh10ddr.apps.googleusercontent.com',
    iosBundleId: 'com.vibesbox.dj',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
    appId: '1:567845942758:web:8549e7d5abb8b3b81bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    authDomain: 'dj-ollerganove.firebaseapp.com',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
    appId: '1:567845942758:web:8549e7d5abb8b3b81bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    authDomain: 'dj-ollerganove.firebaseapp.com',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
  );
}

