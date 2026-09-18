import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Медіа сигналів у Firebase Storage.
///
/// Файли лежать як `signals/<тека>/<час>_<назва>`; тека — це поле сигналу
/// (audioUrl, imageUrl, ...), щоб у консолі було видно, що звідки.
/// Повертається постійний download-URL — саме він зберігається у Firestore
/// і працює однаково на Android та у браузері.
class MediaStorageService {
  static final _storage = FirebaseStorage.instance;

  /// Типи файлів, які приймає кожне поле форми.
  static const audioExtensions = ['mp3', 'm4a', 'aac', 'ogg', 'wav'];
  static const imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif'];
  static const videoExtensions = ['mp4', 'webm', 'mov'];

  /// Відкриває вибір файлів і завантажує обрані. Повертає download-URL
  /// кожного у порядку вибору; порожній список — користувач нічого не обрав.
  ///
  /// Береться `withData`, а не шлях: на вебі шляху до файлу немає,
  /// а putData працює на всіх платформах.
  static Future<List<String>> pickAndUpload({
    required String folder,
    required List<String> allowedExtensions,
    bool allowMultiple = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: true,
    );
    if (result == null) return const [];

    final urls = <String>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      urls.add(await upload(folder: folder, bytes: bytes, fileName: file.name));
    }
    return urls;
  }

  static Future<String> upload({
    required String folder,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path =
        'signals/$folder/${DateTime.now().millisecondsSinceEpoch}_${_safeName(fileName)}';
    final ref = _storage.ref(path);
    // Без contentType Storage віддає application/octet-stream, і <audio>
    // у браузері відмовляється такий файл грати.
    await ref.putData(bytes, SettableMetadata(contentType: _contentType(fileName)));
    final url = await ref.getDownloadURL();
    debugPrint('MediaStorage: uploaded $path (${bytes.length} bytes)');
    return url;
  }

  static String _safeName(String name) {
    final safe = name.trim().replaceAll(RegExp(r'[^\w.\-]+', unicode: true), '_');
    return safe.isEmpty ? 'file' : safe;
  }

  static String _contentType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'mp3' => 'audio/mpeg',
      'm4a' || 'aac' => 'audio/mp4',
      'ogg' => 'audio/ogg',
      'wav' => 'audio/wav',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }
}
