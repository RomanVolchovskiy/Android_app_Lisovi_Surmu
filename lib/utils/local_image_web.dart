import 'package:flutter/material.dart';

/// У браузері доступу до файлової системи немає, тому локальний шлях
/// показати неможливо — повертаємо порожнє місце замість падіння.
Widget localImage(String path) => const SizedBox.shrink();
