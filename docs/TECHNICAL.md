# Технічна документація — Мисливські Сигнали

## Загальна інформація

| Параметр | Значення |
|---|---|
| Назва пакету | `hunting_signals` |
| Android package | `com.huntingsignals.audio` |
| Версія | 1.0.0+1 |
| Flutter | 3.41.5 |
| Dart SDK | 3.11.3 |
| Мова інтерфейсу | Українська |

---

## Вимоги до середовища

- **Flutter:** `D:\flutter\bin\flutter`
- **Dart SDK:** `D:\flutter\bin\cache\dart-sdk`
- **Android SDK:** `C:\Users\hp\AppData\Local\Android\Sdk`
- **Java (JAVA_HOME):** `C:\Program Files\Android\Android Studio\jbr`
- **Запуск Flutter з Git Bash:** `bash /d/flutter/bin/flutter <команда>`

### Android-емулятор

```bash
# Запустити емулятор
bash /d/flutter/bin/flutter emulators --launch Pixel_6_API_35

# Запустити додаток
bash /d/flutter/bin/flutter run -d emulator-5554
```

### Запуск на реальному пристрої

```bash
bash /d/flutter/bin/flutter devices
bash /d/flutter/bin/flutter run -d <device-id>
```

---

## Структура проєкту

```
lib/
├── main.dart                        # Точка входу, ініціалізація Firebase, маршрути
├── models/
│   ├── hunting_models.dart          # HuntingSignal, SignalCategory, EducationMaterial
│   └── education_models.dart        # EducationTopic, LearningMaterial, Flashcard, TestQuestion
├── screens/
│   ├── main_navigation.dart         # Нижня навігація (4 вкладки)
│   ├── categories_screen.dart       # Список категорій сигналів
│   ├── education_screen.dart        # Список навчальних тем
│   ├── education_topic_screen.dart  # Матеріали теми (3 вкладки)
│   ├── flashcard_screen.dart        # Флеш-картки
│   ├── test_screen.dart             # Тестування знань
│   ├── favorites_screen.dart        # Обрані сигнали
│   ├── events_screen.dart           # Заходи (placeholder)
│   ├── video_player_screen.dart     # Програвач відео (YouTube + Google Drive)
│   ├── drive_file_viewer_screen.dart # WebView для документів/презентацій
│   ├── add_signal_screen.dart       # Форма додавання сигналу
│   ├── auth_screen.dart             # Вхід / реєстрація користувача (пошта + пароль)
│   ├── verify_email_screen.dart     # Очікування підтвердження пошти
│   ├── access_expired_screen.dart   # Пробний період завершився — введення коду
│   ├── account_screen.dart          # Акаунт: стан доступу, код, вихід
│   ├── admin_access_screen.dart     # Адмін: коди доступу й налаштування
│   ├── admin_login_screen.dart      # Вхід адміністратора
│   ├── admin_panel_screen.dart      # Панель управління
│   ├── admin_education_screen.dart  # Управління навчальним контентом
│   └── settings_storage_screen.dart # Налаштування зберігання
├── services/
│   ├── access_service.dart          # Вхід (Firebase Auth), пробний період, коди доступу
│   ├── admin_service.dart           # Автентифікація адміна, допоміжні методи
│   ├── audio_service.dart           # Відтворення аудіо (audioplayers)
│   ├── firebase_service.dart        # CRUD для Firestore (signals, materials)
│   ├── education_service.dart       # CRUD для навчального контенту
│   ├── hunting_data_service.dart    # Бізнес-логіка; агрегує Firebase + local
│   ├── google_drive_service.dart    # Google Drive OAuth (не активний на Android)
│   ├── media_cache_service.dart     # Кешування аудіо/нотацій, YouTube helpers
│   ├── media_storage_service.dart   # Завантаження медіа у Firebase Storage
│   └── storage_manager.dart         # Вибір типу сховища (local / firebase)
├── widgets/
│   └── signal_card.dart             # Карточка сигналу, нотації, відеоплеєр
└── theme/
    └── hunting_theme.dart           # Кольори, теми, стилі
```

### Статичні ресурси

```
assets/
├── audio/       # Локальні аудіофайли сигналів
├── video/       # Локальні відеофайли
├── images/      # Зображення (іконка застосунку, логотипи)
├── icons/       # SVG/PNG іконки
└── notations/   # Зображення нотацій
```

---

## Маршрутизація

| Маршрут | Екран |
|---|---|
| `/home` (default) | `MainNavigation` |
| `/admin-login` | `AdminLoginScreen` |
| `/admin-panel` | `AdminPanelScreen` |
| `/add-signal` | `AddSignalScreen` |
| `/categories` | `CategoriesScreen` |
| `/education` | `EducationScreen` |
| `/settings` | `SettingsStorageScreen` |

---

## Залежності (pubspec.yaml)

| Пакет | Призначення |
|---|---|
| `audioplayers ^6.1.0` | Відтворення аудіо |
| `video_player ^2.9.2` | Відтворення локального відео |
| `webview_flutter ^4.10.0` | YouTube embed / перегляд документів |
| `cached_network_image ^3.4.1` | Кешоване завантаження зображень |
| `firebase_core ^3.0.0` | Ініціалізація Firebase |
| `cloud_firestore ^5.0.0` | База даних Firestore |
| `firebase_storage ^12.0.0` | Хмарне сховище файлів |
| `firebase_auth ^5.7.0` | Вхід за поштою; доступ до додатку — див. `docs/ACCESS.md` |
| `shared_preferences ^2.5.3` | Локальне зберігання налаштувань |
| `hive ^2.2.3` | Локальна NoSQL база даних |
| `provider ^6.1.5` | Управління станом |
| `http ^1.2.2` | HTTP-запити (завантаження медіа) |
| `path_provider ^2.1.5` | Шляхи до директорій пристрою |
| `url_launcher ^6.3.0` | Відкриття URL у браузері |
| `google_fonts ^6.2.1` | Шрифти Google |
| `image_picker ^1.1.2` | Вибір зображень з галереї |
| `googleapis ^13.2.0` | Google Drive API |
| `google_sign_in ^6.2.1` | Google OAuth |

---

## Firebase Firestore — структура колекцій

### `signals` — мисливські сигнали

```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "category": "string",
  "audioUrl": "string | null",
  "videoUrl": "string | null",
  "videoUrl2": "string | null",
  "notationUrl": "string | null",
  "notationAudioUrl": "string | null",
  "imageUrl": "string | null",
  "galleryImages": ["string"] ,
  "duration": "int",
  "tags": ["string"],
  "historicalInfo": "string | null",
  "usageInstructions": "string | null",
  "isFavorite": "bool",
  "difficulty": "string | null",
  "signalText": "string | null",
  "notationData": [{"pitch": "string", "duration": "double", ...}],
  "notationTempo": "int | null"
}
```

### `materials` — старі навчальні матеріали (legacy)

Використовується `FirebaseService`, але основний навчальний контент перенесено до нових колекцій.

### `edu_topics` — теми навчання

```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "imageUrl": "string | null"
}
```

### `edu_learning_materials` — навчальні матеріали

```json
{
  "id": "string",
  "topicId": "string",
  "type": "multimedia | lecture | practical",
  "name": "string",
  "driveUrl": "string",
  "mediaType": "video | photo | presentation | document | null",
  "thumbnailUrl": "string | null"
}
```

### `edu_flashcards` — флеш-картки

```json
{
  "id": "string",
  "topicId": "string",
  "question": "string",
  "answer": "string"
}
```

### `edu_test_questions` — тестові питання

```json
{
  "id": "string",
  "topicId": "string",
  "question": "string",
  "options": ["string"],
  "correctIndex": "int",
  "explanation": "string | null"
}
```

---

## Сервіс MediaCacheService

Файл: `lib/services/media_cache_service.dart`

Ключові методи:

| Метод | Опис |
|---|---|
| `isYouTubeUrl(url)` | Перевіряє чи URL є YouTube |
| `extractYouTubeId(url)` | Витягує video ID з будь-якого формату YouTube URL |
| `toYouTubeEmbedUrl(url)` | Конвертує в `youtube.com/embed/ID?playsinline=1&rel=0` |
| `extractGoogleDriveId(url)` | Витягує file ID з Google Drive URL |
| `toGoogleDriveThumbnailUrl(url)` | `drive.google.com/thumbnail?id=ID&sz=w480` |
| `toAudioDownloadUrl(url)` | Storage-URL повертає як є; застарілі Drive URL → download-URL Drive |
| `toImageUrl(url)` | те саме для зображень |
| `downloadAudio(url)` | Завантажує аудіо у постійний кеш |
| `downloadNotation(url)` | Завантажує зображення нотації у кеш |
| `preloadSignals(signals)` | Попереднє завантаження всіх аудіо у фоні |
| `getLocalAudioPath(url)` | Повертає локальний шлях, якщо файл кешований |

### Кешування

Кешовані файли зберігаються у `<ApplicationDocumentsDirectory>/media_cache/`:
- Аудіо: `<hash>.audio`
- Нотації: `<hash>.notation`

---

## Відтворення відео

**Файли:** `lib/widgets/signal_card.dart`, `lib/screens/video_player_screen.dart`

Логіка визначення типу:
1. Якщо URL містить `youtube.com` або `youtu.be` → відтворення через `WebViewController` з embed URL
2. Інакше → відтворення через `VideoPlayerController` (video_player)

YouTube embed URL формат: `https://www.youtube.com/embed/{ID}?playsinline=1&rel=0`

---

## Нотації сигналів

**Файл:** `lib/widgets/signal_card.dart`

- **Зображення нотації** (`notationUrl`): відображається у 40% висоти екрану; натискання → повноекранний горизонтальний режим
- **Графічні ноти** (`notationData` + `notationTempo`): інтерактивне відображення; натискання → повноекранний горизонтальний режим з елементами управління BPM і програванням
- **Повноекранний режим:** `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])` у `initState`; відновлення portrait у `dispose`

### Формат notationData

```json
[
  {"pitch": "C4", "duration": 1.0},
  {"pitch": "D4", "duration": 0.5},
  {"pitch": "rest", "duration": 0.5}
]
```

---

## Конфігурація Android

**`android/gradle.properties`:**
```properties
kotlin.incremental=false
```
> Потрібно: проєкт на D:, pub cache на C: → крос-дискова помилка Kotlin incremental на Windows.

**`android/app/src/main/AndroidManifest.xml`:**
- Атрибут `package=` видалено (deprecated в AGP 8+)
- Дозволи: INTERNET, READ_EXTERNAL_STORAGE

---

## Відомі обмеження

| Проблема | Статус |
|---|---|
| Екран «Заходи» | Placeholder, не реалізований |
| Playlist у «Вибраних» | Не реалізований |
| Кнопки редагування в адмін-панелі | Частково |
| Google Drive OAuth для web | Потребує OAuth Client ID у `web/index.html` |
| Пароль адміна | Hardcoded у `lib/services/admin_service.dart:7` |

---

## Медіа сигналів: Firebase Storage

Файл: `lib/services/media_storage_service.dart`

Аудіо, відео, ноти, обкладинки та галерея сигналів лежать у Firebase Storage
(`huntingsignals.firebasestorage.app`), у Firestore зберігається їхній
download-URL. Він прямий, працює однаково на Android і у браузері — жодних
проксі чи конвертацій не потрібно.

Чому не Google Drive: у браузері запит до Drive іде з кукі користувача,
на 403 немає CORS-заголовків, тож `<audio>` отримує не аудіо. Раніше це
обходили Vercel-проксі `api/media.js`; після переїзду в Storage його прибрано.

- Шлях у бакеті: `signals/<поле>/<час>_<назва файлу>` (адмін-панель) або
  `signals/<поле>/<docId>.<ext>` (міграція).
- Адмін-панель: кнопка `⬆` у кожному медіа-полі форми сигналу вибирає файл
  і завантажує його у Storage (`putData` з contentType — без нього браузер
  не грає файл).
- Правила бакета: `storage.rules` (деплой `firebase deploy --only storage`).
- Міграція з Drive: `scripts/migrate_media_to_storage.py` (`fetch` → `push`,
  є `rollback`; старі посилання лишаються в полі `driveBackup` документа).
- Аудіо перекодовується у 96 kbps mono — для рога цього достатньо, а файл
  у 3–5 разів менший.

---

## Налаштування Firebase

1. Зареєструйте додаток у [Firebase Console](https://console.firebase.google.com)
2. Завантажте `google-services.json` → `android/app/`
3. Колекції Firestore мають бути публічними для читання (або налаштуйте Rules)

**Рекомендовані Firestore Rules (розробка):**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if false; // запис лише через Firebase Console або адмін-панель
    }
  }
}
```

---

## Запуск і збірка

```bash
# Отримати залежності
bash /d/flutter/bin/flutter pub get

# Статичний аналіз
bash /d/flutter/bin/flutter analyze

# Збірка APK (debug)
bash /d/flutter/bin/flutter build apk --debug

# Збірка APK (release)
bash /d/flutter/bin/flutter build apk --release

# Встановити на підключений пристрій
bash /d/flutter/bin/flutter install
```
