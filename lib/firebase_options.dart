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
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Android (з google-services.json) ─────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:android:66230f9e244aa45b0f6b16',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
  );

  // ── iOS (placeholder — додати після підключення iOS app у Firebase) ──
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:ios:PLACEHOLDER',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
    iosBundleId: 'com.huntingsignals.app',
  );

  // ── Web (потрібно додати Web App у Firebase Console) ─────────────────
  // Інструкція:
  // 1. Відкрий console.firebase.google.com → проект huntingsignals
  // 2. Project Settings → Add App → Web
  // 3. Скопіюй apiKey, appId, authDomain і встав сюди
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:web:PLACEHOLDER', // <-- замінити після реєстрації
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    authDomain: 'huntingsignals.firebaseapp.com',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
  );
}
