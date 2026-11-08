import 'dart:io';

import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

/// The number of values used in each benchmark
const operations = [1000, 10000, 100000, 1000000];

/// Writes [values] to a new database and closes it
Future<void> createDatabase(Target target, List<TestModel> values) async {
  deleteDatabase(target.path);
  final db = await target.open();
  await target.addAll(db, values);
  await target.flush?.call(db);
  await target.close(db);
}

void deleteDatabase(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.directory) {
    Directory(path).deleteSync(recursive: true);
  } else if (type != FileSystemEntityType.notFound) {
    File(path).deleteSync();
  }
}

/// Bytes on disk for a database file, or every file in a database directory
int databaseSize(String path) {
  if (FileSystemEntity.isDirectorySync(path)) {
    var size = 0;
    for (final entity in Directory(path).listSync(recursive: true)) {
      if (entity is File) size += entity.lengthSync();
    }
    return size;
  }
  return File(path).lengthSync();
}

void checkCount(List<Object?> values, int count) {
  if (values.length != count) {
    throw StateError('Read ${values.length} values, expected $count');
  }
}

/// Writes markdown [sections] of `title: table` to [file]
void writeResults(String file, Map<String, String> sections) {
  final markdown = [
    for (final MapEntry(:key, :value) in sections.entries) '### $key\n\n$value',
  ].join('\n\n');
  File(file).writeAsStringSync('$markdown\n');
}

/// Formats a markdown table with a row for each target and a column for each
/// value count
String formatTable<T>(
  List<Target> targets,
  List<List<T>> results,
  String Function(T result) format,
) {
  final headers = [
    'Database',
    for (var i = 0; i < results.length; i++) _formatCount(operations[i]),
  ];
  final rows = [
    for (var j = 0; j < targets.length; j++)
      [targets[j].name, for (final result in results) format(result[j])],
  ];
  final widths = [
    for (var i = 0; i < headers.length; i++)
      [
        headers[i],
        for (final row in rows) row[i],
      ].map((cell) => cell.length).reduce((a, b) => a > b ? a : b),
  ];

  String formatRow(List<String> cells) {
    final padded = [
      for (var i = 0; i < cells.length; i++)
        i == 0 ? cells[i].padRight(widths[i]) : cells[i].padLeft(widths[i]),
    ];
    return '| ${padded.join(' | ')} |';
  }

  final divider = [
    for (var i = 0; i < widths.length; i++)
      i == 0 ? '-' * widths[i] : '${'-' * (widths[i] - 1)}:',
  ];
  return [
    formatRow(headers),
    '| ${divider.join(' | ')} |',
    ...rows.map(formatRow),
  ].join('\n');
}

String formatMegabytes(int bytes, {int digits = 2}) =>
    '${(bytes / 1024 / 1024).toStringAsFixed(digits)} MB';

String _formatCount(int count) => count.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
