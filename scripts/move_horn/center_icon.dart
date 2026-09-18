import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final srcPath = r'D:\flutter_app\assets\icons\icon1.png';
  final src = img.decodePng(File(srcPath).readAsBytesSync())!;
  final w = src.width; final h = src.height;

  // Знаходимо bounding box непрозорих пікселів
  int minX = w, minY = h, maxX = 0, maxY = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (src.getPixel(x, y).a.toInt() > 10) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  print('Content bounds: ($minX,$minY) → ($maxX,$maxY)');

  // Вирізаємо лише реальний вміст
  final cropped = img.copyCrop(src,
      x: minX, y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1);

  // Масштабуємо до 1024x1024 — без рамки, щит заповнює все
  final result = img.copyResize(cropped,
      width: 1024, height: 1024,
      interpolation: img.Interpolation.cubic);

  File(srcPath).writeAsBytesSync(img.encodePng(result));
  print('✓ icon1.png відновлено (без рамки, 1024x1024)');

  // Генеруємо всі розміри
  final base = r'D:\flutter_app\android\app\src\main\res';
  final sizes = {
    '$base\\mipmap-mdpi\\ic_launcher.png': 48,
    '$base\\mipmap-hdpi\\ic_launcher.png': 72,
    '$base\\mipmap-xhdpi\\ic_launcher.png': 96,
    '$base\\mipmap-xxhdpi\\ic_launcher.png': 144,
    '$base\\mipmap-xxxhdpi\\ic_launcher.png': 192,
    '$base\\drawable\\ic_launcher_foreground.png': 432,
    '$base\\drawable\\adaptive_foreground.png': 432,
    '$base\\drawable-mdpi\\ic_launcher_foreground.png': 108,
    '$base\\drawable-hdpi\\ic_launcher_foreground.png': 162,
    '$base\\drawable-xhdpi\\ic_launcher_foreground.png': 216,
    '$base\\drawable-xxhdpi\\ic_launcher_foreground.png': 324,
    '$base\\drawable-xxxhdpi\\ic_launcher_foreground.png': 432,
  };

  for (final entry in sizes.entries) {
    final resized = img.copyResize(result,
        width: entry.value, height: entry.value,
        interpolation: img.Interpolation.cubic);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
    final folder = entry.key.split(r'\')[entry.key.split(r'\').length - 2];
    print('✓ ${entry.value}px → $folder');
  }
  print('\nГотово!');
}
