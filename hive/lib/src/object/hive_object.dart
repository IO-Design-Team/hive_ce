import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/object/hive_list_impl.dart';
import 'package:meta/meta.dart';

part 'hive_object_internal.dart';

/// Extend `HiveObject` to add useful methods to the objects you want to store
/// in Hive
mixin HiveObjectMixin {
  BoxBase? _box;

  dynamic _key;

  // HiveLists containing this object
  final _hiveLists = <HiveList, int>{};

  /// Get the box in which this object is stored. Returns `null` if object has
  /// not been added to a box yet.
  BoxBase? get box => _box;

  /// Get the key associated with this object. Returns `null` if object has
  /// not been added to a box yet.
  dynamic get key => _key;

  BoxBase _requireInitialized() {
    final box = _box;
    if (box == null) {
      throw HiveError('This object is currently not in a box.');
    }
    return box;
  }

  /// Persists this object.
  Future<void> save() {
    return _requireInitialized().put(_key, this);
  }

  /// Deletes this object from the box it is stored in.
  Future<void> delete() async {
    final box = _requireInitialized();
    await box.delete(_key);
    if (box.lazy) {
      // Lazy boxes won't automatically dispose their HiveObjects
      dispose();
    }
  }

  /// Returns whether this object is currently stored in a box.
  ///
  /// For lazy boxes this only checks if the key exists in the box and NOT
  /// whether this instance is actually stored in the box.
  bool get isInBox {
    final box = _box;
    if (box != null) {
      if (box.lazy) {
        return box.containsKey(_key);
      } else {
        return true;
      }
    }
    return false;
  }
}

/// TODO: Document this!
abstract class HiveObject with HiveObjectMixin {}
