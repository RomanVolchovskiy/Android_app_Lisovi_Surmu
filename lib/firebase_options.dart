import 'dart:io';
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS || Platform.isMacOS) {
      return ios;
    }
    return android;
  }

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
  // УВАГА: appId потрібно замінити після реєстрації iOS-додатку у Firebase Console:
  //   1. Firebase Console → Project Settings → Додати застосунок → iOS
  //   2. Bundle ID: com.huntingsignals.huntingSignals
  //   3. Скачати GoogleService-Info.plist → замінити ios/Runner/GoogleService-Info.plist
  //   4. Скопіювати GOOGLE_APP_ID сюди (формат: 1:718598030499:ios:XXXXXXXXXXXXXXXX)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVSYGp-YOkrkdGwSadfmCuR64xkhlI-pw',
    appId: '1:718598030499:ios:ЗАМІНІТЬ_ЦЕ_ЗНАЧЕННЯ',
    messagingSenderId: '718598030499',
    projectId: 'huntingsignals',
    databaseURL: 'https://huntingsignals-default-rtdb.firebaseio.com',
    storageBucket: 'huntingsignals.firebasestorage.app',
    iosBundleId: 'com.huntingsignals.huntingSignals',
  );
}
