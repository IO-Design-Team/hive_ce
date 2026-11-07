import 'dart:async';

import 'package:meta/meta.dart';
import 'package:storage_benchmark/test_model.dart';

/// A database under test
@immutable
class Target {
  final String name;

  /// The database file or directory
  final String path;

  /// Opens the database, creating it when [path] is missing
  final Future<Object?> Function() open;

  /// Writes a single value. Only needed for the individual write benchmark.
  final Future<void> Function(Object? db, TestModel value)? add;

  final Future<void> Function(Object? db, List<TestModel> values) addAll;

  /// Makes pending writes durable. Write timings include it.
  ///
  /// Not needed when every write commits to disk before it returns.
  final Future<void> Function(Object? db)? flush;

  final Future<List<Object?>> Function(Object? db) readAll;
  final Future<void> Function(Object? db) close;

  const Target._({
    required this.name,
    required this.path,
    required this.open,
    required this.add,
    required this.addAll,
    required this.flush,
    required this.readAll,
    required this.close,
  });

  /// Creates a target for a database handle of type [T]
  static Target create<T>({
    required String name,
    required String path,
    required FutureOr<T> Function() open,
    required FutureOr<void> Function(T db, List<TestModel> values) addAll,
    required FutureOr<List<Object?>> Function(T db) readAll,
    required FutureOr<void> Function(T db) close,
    FutureOr<void> Function(T db, TestModel value)? add,
    FutureOr<void> Function(T db)? flush,
  }) => Target._(
    name: name,
    path: path,
    open: () async => await open(),
    add: add == null ? null : (db, value) async => await add(db as T, value),
    addAll: (db, values) async => await addAll(db as T, values),
    flush: flush == null ? null : (db) async => await flush(db as T),
    readAll: (db) async => await readAll(db as T),
    close: (db) async => await close(db as T),
  );
}
