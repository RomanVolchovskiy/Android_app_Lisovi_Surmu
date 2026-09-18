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
      case TargetPlatform.macOS:
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

  // ── iOS ───────────────────────────────────────────────────────────────
  // УВАГА: appId потрібно замінити після реєстрації iOS-додатку у Firebase
  // Console (Bundle ID: com.huntingsignals.huntingSignals); те саме — у
  // ios/Runner/GoogleService-Info.plist.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:ios:ЗАМІНІТЬ_ПІСЛЯ_РЕЄСТРАЦІЇ',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
    iosBundleId: 'com.huntingsignals.huntingSignals',
  );

  // ── Web (Web App зареєстровано у Firebase Console) ───────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAhVTO38rw3oN0zxgH5_kXGl8Ex6mWPoPE',
    appId: '1:718598030499:web:de6181196b200ae40f6b16',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    authDomain: 'huntingsignals.firebaseapp.com',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
    measurementId: 'G-3DZLGD1WCL',
  );
}
