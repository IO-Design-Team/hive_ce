import 'dart:collection';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/object/hive_collection_mixin.dart';
import 'package:hive_ce/src/object/hive_object.dart';
import 'package:hive_ce/src/util/delegating_list_view_mixin.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class HiveListImpl<E extends HiveObjectMixin>
    with HiveCollectionMixin<E>, ListMixin<E>, DelegatingListViewMixin<E>
    implements HiveList<E> {
  /// Not part of public API
  final String boxName;

  final List<dynamic>? _keys;

  HiveInterface _hive = Hive;

  List<E>? _delegate;

  Box? _box;

  var _invalidated = false;

  var _disposed = false;

  /// Not part of public API
  HiveListImpl(Box box, {List<E>? objects})
      : boxName = box.name,
        _keys = null,
        _delegate = [],
        _box = box {
    if (objects != null) {
      addAll(objects);
    }
  }

  /// Not part of public API
  HiveListImpl.lazy(this.boxName, List<dynamic>? keys) : _keys = keys;

  /// The keys backing a lazy list
  ///
  /// Only null if a delegate backed list has been disposed
  List<dynamic> get _lazyKeys {
    final keys = _keys;
    if (keys == null) {
      throw HiveError('HiveList has neither delegate nor keys.');
    }
    return keys;
  }

  @override
  Iterable<dynamic> get keys => _delegate == null ? _lazyKeys : super.keys;

  @override
  Box get box {
    final box = _box;
    if (box != null) return box;

    final opened = (_hive as HiveImpl).getBoxWithoutCheckInternal(boxName);
    if (opened == null) {
      throw HiveError(
        'To use this list, you have to open the box "$boxName" first.',
      );
    } else if (opened is! Box) {
      throw HiveError('The box "$boxName" is a lazy box. '
          'You can only use HiveLists with normal boxes.');
    }
    return _box = opened;
  }

  @override
  List<E> get delegate {
    if (_disposed) {
      throw HiveError('HiveList has already been disposed.');
    }

    final delegate = _delegate;
    if (delegate == null) {
      final list = <E>[];
      for (final key in _lazyKeys) {
        if (box.containsKey(key)) {
          final obj = box.get(key) as E;
          obj.linkHiveList(this);
          list.add(obj);
        }
      }
      return _delegate = list;
    }

    if (_invalidated) {
      final retained = <E>[];
      for (final obj in delegate) {
        if (obj.isInHiveList(this)) {
          retained.add(obj);
        }
      }
      _invalidated = false;
      return _delegate = retained;
    }

    return delegate;
  }

  @override
  void dispose() {
    final delegate = _delegate;
    if (delegate != null) {
      for (final element in delegate) {
        element.unlinkHiveList(this);
      }
      _delegate = null;
    }

    _disposed = true;
  }

  /// Not part of public API
  void invalidate() {
    if (_delegate != null) {
      _invalidated = true;
    }
  }

  void _checkElementIsValid(E obj) {
    if (obj.box != box) {
      throw HiveError('HiveObjects needs to be in the box "$boxName".');
    }
  }

  @override
  set length(int newLength) {
    if (newLength < delegate.length) {
      for (var i = newLength; i < delegate.length; i++) {
        delegate[i].unlinkHiveList(this);
      }
    }
    delegate.length = newLength;
  }

  @override
  void operator []=(int index, E value) {
    _checkElementIsValid(value);
    value.linkHiveList(this);

    final oldValue = delegate[index];
    delegate[index] = value;

    oldValue.unlinkHiveList(this);
  }

  @override
  void add(E element) {
    _checkElementIsValid(element);
    element.linkHiveList(this);
    delegate.add(element);
  }

  @override
  void addAll(Iterable<E> iterable) {
    for (final element in iterable) {
      _checkElementIsValid(element);
      element.linkHiveList(this);
    }
    delegate.addAll(iterable);
  }

  @override
  HiveList<T> castHiveList<T extends HiveObjectMixin>() {
    final delegate = _delegate;
    if (delegate != null) {
      return HiveListImpl(box, objects: delegate.cast());
    } else {
      return HiveListImpl.lazy(boxName, _keys);
    }
  }

  /// Not part of public API
  @visibleForTesting
  set debugHive(HiveInterface hive) => _hive = hive;
}
