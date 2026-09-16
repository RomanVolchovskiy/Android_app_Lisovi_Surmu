// Stub for dart:io on web platform.
// These classes match the interface used in the project but do nothing on web.
// Real dart:io is used on mobile via conditional import.

class File {
  final String path;
  const File(this.path);
  Future<bool> exists() async => false;
  Future<int> length() async => 0;
  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) async => this;
  Future<File> writeAsString(String contents) async => this;
  // encoding приймається лише для сумісності сигнатури з dart:io —
  // на вебі цією гілкою код не йде (файл читається з bytes).
  Future<String> readAsString({Object? encoding}) async => '';
}

class Directory {
  final String path;
  const Directory(this.path);
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}
