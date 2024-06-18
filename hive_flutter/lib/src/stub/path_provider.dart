/// TODO: Document this!
abstract class Directory {
  /// TODO: Document this!
  String get path;
}

/// TODO: Document this!
Future<Directory> getApplicationDocumentsDirectory() {
  throw UnimplementedError(
    '[Hive Error] Tried to use the `path_provider` package from Flutter Web.',
  );
}
