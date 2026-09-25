import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'Dieses Mini-Tool startet vorerst nur auf macOS und Windows.',
        );
    }
  }

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCl6bzYDicx88yqS_eqgEXBtb55NC6BxYE',
    appId: '1:567845942758:ios:7f74e7168ec28bc91bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
    iosClientId:
        '567845942758-ua6oj1re81kanasu3m02umspauvj5fgd.apps.googleusercontent.com',
    iosBundleId: 'com.vibesbox.rbNowPlaying',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
    appId: '1:567845942758:web:8549e7d5abb8b3b81bd227',
    messagingSenderId: '567845942758',
    projectId: 'dj-ollerganove',
    authDomain: 'dj-ollerganove.firebaseapp.com',
    storageBucket: 'dj-ollerganove.firebasestorage.app',
  );
}
