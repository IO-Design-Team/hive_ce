import 'package:hive_ce/hive.dart';
import 'package:hive_ce_inspector_bridge/src/hive_inspector.dart';

extension HiveInspectorExtension on HiveInterface {
  Future<Box<T>> openBoxWithInspection<T>(String name) async {
    final box = await openBox<T>(name);
    HiveInspector.inspectBox(box);
    return box;
  }

  Future<LazyBox<T>> openLazyBoxWithInspection<T>(String name) async {
    final box = await openLazyBox<T>(name);
    HiveInspector.inspectBox(box);
    return box;
  }
}
