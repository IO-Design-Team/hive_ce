import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:storage_benchmark/test_model.dart';

/// Operations bound to one open database. Each adapter keeps its native handle.
@immutable
class BenchmarkDatabase<Value, Row> {
  final FutureOr<void> Function(List<Value> values) _addAll;
  final FutureOr<void> Function()? _flush;
  final FutureOr<List<Row>> Function() readAll;
  final FutureOr<void> Function() close;

  const BenchmarkDatabase({
    required FutureOr<void> Function(List<Value> values) addAll,
    FutureOr<void> Function()? flush,
    required this.readAll,
    required this.close,
  }) : _addAll = addAll,
       _flush = flush;

  Future<void> writeBatch(List<Value> values) async {
    await _addAll(values);
    await flush();
  }

  FutureOr<void> flush() => _flush?.call();
}

@immutable
class StandardDatabase extends BenchmarkDatabase<TestModel, Object?> {
  final FutureOr<void> Function(TestModel value) add;

  /// Reads keys for lazy boxes and values for other databases.
  final FutureOr<List<Object?>> Function() readAfterOpen;
  final FutureOr<List<Object?>> Function(int min, int max) query;

  const StandardDatabase({
    required this.add,
    required this.readAfterOpen,
    required this.query,
    required super.addAll,
    super.flush,
    required super.readAll,
    required super.close,
  });
}

typedef OpenLargeDatabase =
    Future<BenchmarkDatabase<Uint8List, Uint8List>> Function(String directory);

/// Defines how to open a binary fixture in the supplied directory.
OpenLargeDatabase largeDatabase<Handle>({
  required FutureOr<Handle> Function(String directory) open,
  required FutureOr<void> Function(Handle db, List<Uint8List> values) addAll,
  FutureOr<void> Function(Handle db)? flush,
  required FutureOr<List<Uint8List>> Function(Handle db) readAll,
  required FutureOr<void> Function(Handle db) close,
}) => (directory) async {
  final db = await open(directory);
  return BenchmarkDatabase(
    addAll: (values) => addAll(db, values),
    flush: flush == null ? null : () => flush(db),
    readAll: () => readAll(db),
    close: () => close(db),
  );
};

@immutable
class Target {
  final String name;

  /// File or directory for the standard fixture and its on-disk size.
  final String path;

  final FutureOr<void> Function()? initialize;
  final FutureOr<void> Function()? close;
  final Future<StandardDatabase> Function() open;
  final OpenLargeDatabase openLarge;

  const Target._(
    this.name,
    this.path,
    this.open,
    this.openLarge, {
    this.initialize,
    this.close,
  });

  Target withLifecycle({
    FutureOr<void> Function()? initialize,
    FutureOr<void> Function()? close,
  }) => Target._(
    name,
    path,
    open,
    openLarge,
    initialize: initialize ?? this.initialize,
    close: close ?? this.close,
  );

  static Target create<Handle>({
    required String name,
    required String path,
    required OpenLargeDatabase openLarge,
    FutureOr<void> Function()? initialize,
    FutureOr<void> Function()? closeEngine,
    required FutureOr<Handle> Function() open,
    required FutureOr<void> Function(Handle db, TestModel value) add,
    required FutureOr<void> Function(Handle db, List<TestModel> values) addAll,
    FutureOr<void> Function(Handle db)? flush,
    required FutureOr<List<Object?>> Function(Handle db) readAll,
    FutureOr<List<Object?>> Function(Handle db)? readKeys,
    required FutureOr<List<Object?>> Function(Handle db, int min, int max)
    query,
    required FutureOr<void> Function(Handle db) close,
  }) => Target._(
    name,
    path,
    () async {
      final db = await open();
      return StandardDatabase(
        add: (value) => add(db, value),
        addAll: (values) => addAll(db, values),
        flush: flush == null ? null : () => flush(db),
        readAll: () => readAll(db),
        readAfterOpen: () => (readKeys ?? readAll)(db),
        query: (min, max) => query(db, min, max),
        close: () => close(db),
      );
    },
    openLarge,
    initialize: initialize,
    close: closeEngine,
  );
}
