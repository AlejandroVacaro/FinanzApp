import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
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
