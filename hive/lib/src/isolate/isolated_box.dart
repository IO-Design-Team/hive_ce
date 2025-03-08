import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/isolate/isolated_box_base.dart';

class IsolatedBox<E> extends IsolatedBoxBase<E> implements Box<E> {
  IsolatedBox(super._channel, super.name);

  @override
  // TODO: implement values
  Iterable<E> get values => throw UnimplementedError();

  @override
  Iterable<E> valuesBetween({startKey, endKey}) {
    // TODO: implement valuesBetween
    throw UnimplementedError();
  }

  @override
  E? get(key, {E? defaultValue}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  E? getAt(int index) {
    // TODO: implement getAt
    throw UnimplementedError();
  }

  @override
  Map<dynamic, E> toMap() {
    // TODO: implement toMap
    throw UnimplementedError();
  }
}
