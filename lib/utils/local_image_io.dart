import 'dart:io';
import 'package:flutter/material.dart';

/// Зображення з локальної файлової системи (мобільні платформи).
Widget localImage(String path) => Image.file(File(path), fit: BoxFit.contain);
