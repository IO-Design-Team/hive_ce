import 'package:hive_ce/src/box/box_base.dart';

/// [LazyBox]es don't keep the values in memory like normal boxes. Opening a
/// lazy box reads its keys and does not checksum values. Large values are
/// skipped on disk. A value is read and checksummed the first time it is
/// accessed.
abstract class LazyBox<E> extends BoxBase<E> {
  /// Returns the value associated with the given [key]. If the key does not
  /// exist, `null` is returned.
  ///
  /// If [defaultValue] is specified, it is returned in case the key does not
  /// exist.
  Future<E?> get(dynamic key, {E? defaultValue});

  /// Returns the value associated with the n-th key.
  Future<E?> getAt(int index);
}
