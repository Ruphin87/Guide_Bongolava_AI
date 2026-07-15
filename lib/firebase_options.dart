import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBm64HNwKHk_3Ws4IB7l0l-Dn20tDj-4Ps',
    appId: '1:228455590136:web:af873a871b1269a55ff30d',
    messagingSenderId: '228455590136',
    projectId: 'bongolava-guide-ia-v2',
    authDomain: 'bongolava-guide-ia-v2.firebaseapp.com',
    storageBucket: 'bongolava-guide-ia-v2.firebasestorage.app',
    measurementId: 'G-YRJFZGEZB5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAHnkHQnNOaOkjGMXqQDXZT7cYu6hdmXk0',
    appId: '1:228455590136:android:40a5aff636bcd4c35ff30d',
    messagingSenderId: '228455590136',
    projectId: 'bongolava-guide-ia-v2',
    storageBucket: 'bongolava-guide-ia-v2.firebasestorage.app',
  );
}