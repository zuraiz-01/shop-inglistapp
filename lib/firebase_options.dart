// File generated from Firebase project configuration.
// Re-run FlutterFire CLI when adding iOS, web, macOS, Windows, or Linux apps.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase options have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase options have not been configured for iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase options have not been configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Firebase options have not been configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase options have not been configured for Linux.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options have not been configured for Fuchsia.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCtW5quaRIKl-VhPwS_TlTD44oeFk3fwBQ',
    appId: '1:475011192625:android:2f9f15987bc425d2f54210',
    messagingSenderId: '475011192625',
    projectId: 'shopping-list-app-e412a',
    storageBucket: 'shopping-list-app-e412a.firebasestorage.app',
  );
}
