import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Unsupported platforms for this example, but you can add iOS/Android/macOS here.
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDOTuOWu8L_lgsIeejrUufg80PCZuNOj9o',
    appId: '1:318317536493:web:984e2b4b77bebc6465d8e4',
    messagingSenderId: '318317536493',
    projectId: 'finanzapp-web',
    authDomain: 'finanzapp-web.firebaseapp.com',
    storageBucket: 'finanzapp-web.firebasestorage.app',
    measurementId: 'G-PJHS1051QG',
  );
}
