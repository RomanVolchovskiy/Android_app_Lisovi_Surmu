# 🦌 Hunting Signals - Educational App for Traditional Hunting Music

[![Flutter](https://img.shields.io/badge/Flutter-3.35.4-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green.svg)](https://flutter.dev)
[![Language](https://img.shields.io/badge/Language-Dart%203.9.2-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📱 Опис програми

**Hunting Signals** - це освітня програма для вивчення традиційної мисливської сигнальної музики. Розроблена для збереження культурної спадщини українського мисливського фольклору.

## 🎯 Призначення

Програма створена для:
- 🎓 Викладачів та студентів лісогосподарських коледжів
- 🦌 Мисливців, які вивчають традиційні сигнали
- 🎼 Музикантів, цікавихся фольклорною традицією
- 📚 Всіх, хто цікавиться культурною спадщиною

## ✨ Основні функції

### 📚 Освітні матеріали
- **Інформаційні сигнали** - для передачі повідомлень
- **Організаційні сигнали** - для координації дій
- **Мисливські сигнали** - для полювання
- **Історичний контекст** - походження та значення сигналів

### 🎵 Аудіо бібліотека
- ✅ 25+ автентичних записів мисливських сигналів
- 🎧 Висока якість звуку
- 📱 Офлайн прослуховування
- 🔄 Повторне відтворення для навчання

### 📖 Навчальні функції
- 📝 Теоретичні матеріали
- 🎼 Нотні записи
- 📊 Історичний контекст
- 🎯 Тести для перевірки знань

### 🔧 Технічні особливості
- 📱 Крос-платформеність (Android, iOS, Web)
- 🌐 Офлайн режим
- 💾 Локальне збереження даних
- 🎨 Material Design 3
- 🇺🇦 Українська локалізація

## 🚀 Швидкий старт

### Вимоги
- Flutter 3.35.4
- Dart 3.9.2
- Android Studio / Xcode (опціонально)

### Встановлення

1. **Клонуйте репозиторій:**
```bash
git clone https://github.com/RomanVolchovskiy/Forest-Hunter-Signals.git
cd Forest-Hunter-Signals
```

2. **Встановіть залежності:**
```bash
flutter pub get
```

3. **Запустіть додаток:**
```bash
flutter run
```

### Збірка

**Android APK:**
```bash
flutter build apk --release
```

**Web:**
```bash
flutter build web --release
```

## 📁 Структура проекту

```
lib/
├── main.dart                    # Головний файл додатку
├── models/                      # Моделі даних
│   └── hunting_models.dart      # Моделі мисливських сигналів
├── screens/                     # Екрани додатку
│   ├── main_navigation.dart     # Головна навігація
│   ├── categories_screen.dart   # Екран категорій
│   ├── education_screen.dart    # Екран освітніх матеріалів
│   ├── admin_panel_screen.dart # Адмін панель
│   └── settings_storage_screen.dart # Налаштування сховища
├── services/                    # Сервіси додатку
│   ├── hunting_data_service.dart # Сервіс даних мисливських сигналів
│   ├── audio_service.dart       # Аудіо сервіс
│   ├── local_storage_service.dart # Локальне сховище
│   ├── google_drive_service.dart # Google Drive інтеграція
│   └── storage_manager.dart     # Менеджер сховищ
└── widgets/                     # Віджети
    ├── signal_card.dart         # Картка сигналу
    └── category_header.dart     # Заголовок категорії
```

## 🎨 Дизайн

Програма використовує **Material Design 3** з природною колірною палітрою:
- 🌲 Основний колір: Forest Green (`#2E7D32`)
- 🟠 Акцентний колір: Hunting Orange (`#FF6D00`)
- 📱 Темна/світла тема
- 🎯 Оптимізовано для мобільних пристроїв

## 🔧 Технічні деталі

### Архітектура
- **State Management:** Provider
- **Local Storage:** SharedPreferences + Hive
- **Audio:** Flutter audio players
- **Navigation:** Flutter Navigator 2.0

### Платформи
- ✅ **Android** - Повна підтримка
- ✅ **iOS** - Повна підтримка  
- ✅ **Web** - Повна підтримка

### Залежності
```yaml
# Основні залежності
flutter:
  sdk: flutter

# Стан додатку
provider: ^6.1.5+1

# Локальне сховище
shared_preferences: ^2.5.3
hive: ^2.2.3
hive_flutter: ^1.1.0

# Аудіо
audioplayers: ^6.1.0

# Мережа
http: ^1.5.0

# Інтерфейс
cupertino_icons: ^1.0.8
```

## 🔐 Адміністрування

Додаток має адмін панель для керування контентом:
- **Логін:** Адміністратор
- **Пароль:** `1488` (конфіденційно)

Функції адміністратора:
- ➕ Додавання нових сигналів
- 📚 Додавання освітніх матеріалів
- 🎵 Завантаження аудіо файлів
- ⚙️ Налаштування сховища

## 🌐 Google Drive інтеграція

Програма підтримує інтеграцію з Google Drive для:
- 📁 Резервного копіювання даних
- 🔄 Синхронізації між пристроями
- 📱 Спільного доступу до контенту

## 🚀 Розгортання

### Підготовка до релізу
1. **Оновіть версію** в `pubspec.yaml`
2. **Перевірте код** з `flutter analyze`
3. **Тестуйте** на всіх платформах
4. **Зберіть** релізну версію

### Публікація
- **Google Play Store** - Android APK/AAB
- **Apple App Store** - iOS (вимагає розробника акаунту)
- **Web hosting** - статичні файли з `build/web/`

## 📄 Ліцензія

Цей проект ліцензовано під MIT License - дивіться [LICENSE](LICENSE) файл для деталей.

## 🤝 Внесок у розвиток

Внески вітаються! Будь ласка:
1. Форкніть репозиторій
2. Створіть гілку для ваших змін
3. Зробіть коміт з описом змін
4. Відправте pull request

## 📞 Контакти

**Розробник:** Роман Волчовський  
**Email:** [Ваш email]  
**GitHub:** [@RomanVolchovskiy](https://github.com/RomanVolchovskiy)

---

<p align="center">
  <i>🦌 Збережемо традиції разом! 🎵</i>
</p>

## 🔄 Оновлення

### Останні зміни
- ✅ Повністю видалено Firebase залежності
- 🔧 Додано Google Drive інтеграцію
- 📱 Оптимізовано для офлайн використання
- 🎨 Оновлено дизайн до Material Design 3

### Історія версій
- **v1.0.0** - Перша стабільна версія
- **v1.1.0** - Додано Google Drive інтеграцію
- **v1.2.0** - Оновлено до Flutter 3.35.4