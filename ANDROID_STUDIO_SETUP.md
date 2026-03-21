# Android Studio Setup Guide

## Project Configuration

### 1. Flutter SDK Setup
- **Flutter Version**: 3.35.4 (LOCKED - DO NOT UPDATE)
- **Dart Version**: 3.9.2 (LOCKED - DO NOT UPDATE)
- **Android API Level**: 35
- **Java Version**: OpenJDK 17.0.2

### 2. Required Plugins
Install these Android Studio plugins:
- Flutter
- Dart
- Kotlin

### 3. Project Structure
```
android/
├── app/
│   ├── build.gradle.kts
│   ├── google-services.json (create from Google Console)
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── kotlin/com/huntingsignals/audio/
│       └── res/
├── build.gradle.kts
└── settings.gradle
lib/
├── main.dart
├── services/
├── models/
├── screens/
└── widgets/
```

### 4. Google Drive Setup
1. Create project in Google Cloud Console
2. Enable Google Drive API
3. Enable Google Sign-In API
4. Create OAuth 2.0 client ID (Android)
5. Download google-services.json
6. Place in android/app/

### 5. Build Configuration
- **Package Name**: com.huntingsignals.audio
- **Min SDK**: 21
- **Target SDK**: 35
- **Compile SDK**: 35

### 6. Dependencies
Key dependencies already configured in pubspec.yaml:
- google_sign_in: ^6.2.1
- googleapis: ^13.2.0
- shared_preferences: ^2.5.3
- audioplayers: ^6.1.0
- video_player: ^2.9.2

### 7. Build Commands
```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build APK
flutter build apk --release

# Analyze code
flutter analyze

# Format code
dart format .
```

### 8. Troubleshooting

#### Common Issues:
1. **Gradle build fails** - Check internet connection and Google Services JSON
2. **Google Sign-In fails** - Verify SHA-1 fingerprint in Google Console
3. **Audio not playing** - Check file formats (MP3, WAV supported)
4. **Build timeout** - Use release mode: `flutter run --release`

#### Environment Variables:
- `JAVA_HOME`: /usr/lib/jvm/java-17-openjdk-amd64
- `ANDROID_HOME`: /home/user/android-sdk

### 9. Admin Panel
- **Password**: 1488
- **Access**: Through settings menu
- **Features**: Manage signals, categories, users

### 10. Important Notes
- DO NOT update Flutter/Dart versions - locked for stability
- Use provided Firebase package versions only
- Test on real device for audio/video functionality
- Enable unknown sources for APK installation

### 11. Development Workflow
1. Open project in Android Studio
2. Wait for indexing to complete
3. Run `flutter pub get`
4. Configure Google Services if needed
5. Run on emulator or device

### 12. APK Distribution
- Build location: build/app/outputs/flutter-apk/app-release.apk
- Size: ~48MB
- Requires Android 5.0+

For support: Check GitHub issues or contact project maintainer.