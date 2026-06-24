import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (Platform.isIOS || Platform.isMacOS) return ios;
    return android;
  }

  // Веб конфігурація
  // УВАГА: appId потрібно замінити після реєстрації веб-додатку у Firebase Console:
  //   Firebase Console → Project Settings → Додати застосунок → Web
  //   Скопіювати firebaseConfig.appId сюди
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:web:ЗАМІНІТЬ_ПІСЛЯ_РЕЄСТРАЦІЇ',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    authDomain: 'huntingsignals.firebaseapp.com',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
  );

  // Android конфігурація (повна — з google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:android:66230f9e244aa45b0f6b16',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
  );

  // iOS конфігурація
  // УВАГА: appId потрібно замінити після реєстрації iOS-додатку у Firebase Console
  //   Bundle ID: com.huntingsignals.huntingSignals
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:ios:ЗАМІНІТЬ_ПІСЛЯ_РЕЄСТРАЦІЇ',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
    iosBundleId: 'com.huntingsignals.huntingSignals',
  );
}
