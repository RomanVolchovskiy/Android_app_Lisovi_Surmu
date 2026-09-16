import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(
    File(r'D:\flutter_app\assets\icons\icon1.png').readAsBytesSync())!;

  final base = r'D:\flutter_app\android\app\src\main\res';

  // Launcher icons (mipmap)
  final mipmaps = {
    '$base\\mipmap-mdpi\\ic_launcher.png': 48,
    '$base\\mipmap-hdpi\\ic_launcher.png': 72,
    '$base\\mipmap-xhdpi\\ic_launcher.png': 96,
    '$base\\mipmap-xxhdpi\\ic_launcher.png': 144,
    '$base\\mipmap-xxxhdpi\\ic_launcher.png': 192,
  };

  // Adaptive icon foreground (drawable-*dpi) — 108dp standard size
  final foregrounds = {
    '$base\\drawable\\ic_launcher_foreground.png': 432,
    '$base\\drawable\\adaptive_foreground.png': 432,
    '$base\\drawable-mdpi\\ic_launcher_foreground.png': 108,
    '$base\\drawable-hdpi\\ic_launcher_foreground.png': 162,
    '$base\\drawable-xhdpi\\ic_launcher_foreground.png': 216,
    '$base\\drawable-xxhdpi\\ic_launcher_foreground.png': 324,
    '$base\\drawable-xxxhdpi\\ic_launcher_foreground.png': 432,
  };

  for (final entry in {...mipmaps, ...foregrounds}.entries) {
    final size = entry.value;
    final resized = img.copyResize(src, width: size, height: size,
        interpolation: img.Interpolation.cubic);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
    print('✓ ${entry.key.split(r'\').last} (${size}px) → ${entry.key.split(r'\')[entry.key.split(r'\').length - 2]}');
  }
  print('\nDone! All icons updated.');
}
