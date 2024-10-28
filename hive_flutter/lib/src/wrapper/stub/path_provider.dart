/// Stub directory
abstract class Directory {
  /// Stub path
  String get path;
}

/// Stub call
Future<Directory> getApplicationDocumentsDirectory() {
  throw UnimplementedError(
    '[Hive Error] Tried to use the `path_provider` package from Flutter Web.',
  );
}
