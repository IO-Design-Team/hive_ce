import 'package:hive_ce/hive_ce.dart';

/// Implemetation of [HiveCollection].
mixin HiveCollectionMixin<E extends HiveObjectMixin>
    implements HiveCollection<E> {
  @override
  Iterable<dynamic> get keys sync* {
    for (final value in this) {
      yield value.key;
    }
  }

  @override
  Future<void> deleteAllFromHive() {
    return box.deleteAll(keys);
  }

  @override
  Future<void> deleteFirstFromHive() {
    return first.delete();
  }

  @override
  Future<void> deleteLastFromHive() {
    return last.delete();
  }

  @override
  Future<void> deleteFromHive(int index) {
    return this[index].delete();
  }

  @override
  Map<dynamic, E> toMap() {
    final map = <dynamic, E>{};
    for (final item in this) {
      map[item.key] = item;
    }
    return map;
  }
}
