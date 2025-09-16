import 'package:dtd/dtd.dart';

extension DtdExtension on DartToolingDaemon {
  Stream<Uri> listDirectoryContentsRecursive(Uri uri) async* {
    try {
      final contents = await listDirectoryContents(uri);
      for (final uri in contents.uris ?? <Uri>[]) {
        yield uri;
        yield* listDirectoryContentsRecursive(uri);
      }
    } catch (_) {
      // This is not a directory
    }
  }
}
