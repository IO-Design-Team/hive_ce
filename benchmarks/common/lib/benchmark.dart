import 'dart:async';
import 'dart:io';

import 'package:storage_benchmark/target.dart';

const recordCount = 1000;
const largeValueCount = 32;
const largeValueBytes = 1024 * 1024;
const benchmarkRuns = 3;

const timeLimit = Duration(minutes: 1);

/// Measures sequentially so samples never compete for resources.
Future<List<T>> collectSamples<T>(Future<T> Function() measure) async => [
  for (var run = 0; run < benchmarkRuns; run++) await measure(),
];

int averageSamples(Iterable<int> samples) =>
    (samples.reduce((sum, sample) => sum + sample) / samples.length).round();

/// Thrown by workloads that can stop partway through a timed operation.
class TimeLimitExceeded implements Exception {}

/// Keeps teardown outside the timed operations and closes a database on failure.
Future<T> withDatabase<D extends BenchmarkDatabase<Object?, Object?>, T>(
  Future<D> Function() open,
  FutureOr<T> Function(D database) action,
) async {
  final db = await open();
  try {
    return await action(db);
  } finally {
    await db.close();
  }
}

void deleteDatabase(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.directory) {
    Directory(path).deleteSync(recursive: true);
  } else if (type != FileSystemEntityType.notFound) {
    File(path).deleteSync();
  }
}

/// Bytes on disk for a database file, or every file in a database directory.
int databaseSize(String path) {
  if (FileSystemEntity.isDirectorySync(path)) {
    return Directory(path)
        .listSync(recursive: true)
        .whereType<File>()
        .fold(0, (size, file) => size + file.lengthSync());
  }
  return File(path).lengthSync();
}

void checkCount(List<Object?> values, int count) {
  if (values.length != count) {
    throw StateError('Read ${values.length} values, expected $count');
  }
}
