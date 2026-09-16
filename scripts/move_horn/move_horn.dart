import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const srcPath = r'D:\flutter_app\assets\images\pictugram_cropped.png';
  const dstPath = r'D:\flutter_app\assets\images\pictugram_cropped_new.png';

  print('Loading image...');
  final src = img.decodePng(File(srcPath).readAsBytesSync())!;
  final w = src.width;
  final h = src.height;

  const shiftY = 220;

  // ── Horn pixel detection (wide range: gold, cream highlights, dark outlines adjacent) ──
  bool isGoldenCore(int r, int g, int b, int a) {
    if (a <= 120) return false;
    // Golden / bronze main body
    if (r > 100 && r < 255 && g > 55 && g < 215 && b > 10 && b < 165 && r > g && g > b && (r - b) > 50) {
      return true;
    }
    // Warm cream highlights (bright gleam on horn surface, B>=100 distinguishes from yellow quadrant)
    if (r > 190 && g > 155 && b >= 100 && b < 210 && (r - b) > 28 && (r - g) < 68) {
      return true;
    }
    return false;
  }

  print('Detecting horn pixels...');
  final hornSet = <int>{};
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      if (isGoldenCore(p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt())) {
        hornSet.add(y * w + x);
      }
    }
  }
  print('  Core horn pixels: ${hornSet.length}');

  // 1 pass: expand into adjacent dark outline pixels
  final ndx8 = [-1, 1, 0, 0, -1, -1, 1, 1];
  final ndy8 = [0, 0, -1, 1, -1, 1, -1, 1];
  final outline = <int>{};
  for (final idx in hornSet) {
    final x = idx % w; final y = idx ~/ w;
    for (int d = 0; d < 8; d++) {
      final nx = x + ndx8[d]; final ny = y + ndy8[d];
      if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
      final nidx = ny * w + nx;
      if (hornSet.contains(nidx)) continue;
      final p = src.getPixel(nx, ny);
      final r = p.r.toInt(); final g = p.g.toInt(); final b = p.b.toInt();
      if (r < 55 && g < 55 && b < 55 && p.a.toInt() > 100) outline.add(nidx);
    }
  }
  hornSet.addAll(outline);
  print('  After outline expansion: ${hornSet.length}');

  // ── Build background using heavily blurred original ──────────────────────
  print('Creating blurred background (radius=45)...');
  final blurred = img.gaussianBlur(src, radius: 45);

  // Inpainting seeds: non-horn pixels keep exact color; horn pixels use blurred version
  final bgR = List<int>.filled(w * h, 255);
  final bgG = List<int>.filled(w * h, 255);
  final bgB = List<int>.filled(w * h, 255);
  final filled = List<bool>.filled(w * h, false);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final idx = y * w + x;
      if (!hornSet.contains(idx)) {
        final p = src.getPixel(x, y);
        bgR[idx] = p.r.toInt(); bgG[idx] = p.g.toInt(); bgB[idx] = p.b.toInt();
        filled[idx] = true;
      } else {
        // Pre-fill horn area with blurred background estimate
        final bp = blurred.getPixel(x, y);
        bgR[idx] = bp.r.toInt(); bgG[idx] = bp.g.toInt(); bgB[idx] = bp.b.toInt();
        filled[idx] = true; // treat as "filled" for compositing
      }
    }
  }

  // ── Composite ─────────────────────────────────────────────────────────────
  print('Compositing...');
  final result = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final idx = y * w + x;
      result.setPixel(x, y, img.ColorRgba8(bgR[idx], bgG[idx], bgB[idx], 255));
    }
  }
  // Overlay horn at shifted position
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (hornSet.contains(y * w + x)) {
        final ny = y + shiftY;
        if (ny < h) {
          final p = src.getPixel(x, y);
          result.setPixel(x, ny, img.ColorRgba8(p.r.toInt(), p.g.toInt(), p.b.toInt(), 255));
        }
      }
    }
  }

  print('Saving...');
  File(dstPath).writeAsBytesSync(img.encodePng(result));
  print('Done! → $dstPath');
}
