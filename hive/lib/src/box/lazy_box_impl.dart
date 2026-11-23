import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
import 'package:hive_ce/src/object/hive_object.dart';

/// Not part of public API
class LazyBoxImpl<E> extends BoxBaseImpl<E> implements LazyBox<E> {
  /// Not part of public API
  LazyBoxImpl(
    super.hive,
    super.name,
    super.keyComparator,
    super.compactionStrategy,
    super.backend, {
    super.isolated = false,
  });

  @override
  final lazy = true;

  @override
  Future<E?> get(dynamic key, {E? defaultValue}) async {
    checkOpen();

    final frame = keystore.get(key);

    if (frame != null) {
      final value = await backend.readValue(frame, verbatim: isolated);
      if (value is HiveObjectMixin) {
        value.init(key, this);
      }
      return value as E?;
    } else {
      if (defaultValue != null && defaultValue is HiveObjectMixin) {
        defaultValue.init(key, this);
      }
      return defaultValue;
    }
  }

  @override
  Future<E?> getAt(int index) {
    return get(keystore.keyAt(index));
  }

  @override
  Future<void> put(dynamic key, E value) async {
    checkOpen();

    final frame = Frame(key, value);
    if (key is int) {
      keystore.updateAutoIncrement(key);
    }

    await backend.writeFrames([frame], verbatim: isolated);

    if (value is HiveObjectMixin) {
      value.init(key, this);
    }
    keystore.insert(frame, lazy: true);

    await performCompactionIfNeeded();
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> kvPairs) async {
    checkOpen();

    final frames = <Frame>[];
    for (final entry in kvPairs.entries) {
      final key = entry.key;
      frames.add(Frame(key, entry.value));
      if (key is int) {
        keystore.updateAutoIncrement(key);
      }
    }

    if (frames.isEmpty) return;
    await backend.writeFrames(frames, verbatim: isolated);

    for (final frame in frames) {
      if (frame.value is HiveObjectMixin) {
        (frame.value as HiveObjectMixin).init(frame.key, this);
      }
      keystore.insert(frame, lazy: true);
    }

    await performCompactionIfNeeded();
  }

  @override
  Future<void> delete(dynamic key) async {
    checkOpen();

    if (!keystore.containsKey(key)) return;

    final frame = Frame.deleted(key);
    await backend.writeFrames([frame], verbatim: isolated);

    keystore.insert(frame);

    await performCompactionIfNeeded();
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    checkOpen();

    final frames = <Frame>[];
    for (final key in keys) {
      if (keystore.containsKey(key)) {
        frames.add(Frame.deleted(key));
      }
    }

    if (frames.isEmpty) return;
    await backend.writeFrames(frames, verbatim: isolated);

    for (final frame in frames) {
      keystore.insert(frame);
    }

    await performCompactionIfNeeded();
  }

  @override
  Future<void> flush() async {
    await backend.flush();
  }
}
