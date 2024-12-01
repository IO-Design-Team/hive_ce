import 'package:hive_ce/hive.dart';

class HiveInspector {
  HiveInspector._();

  static final _boxes = <BoxBase>{};

  static void inspectBox<T>(BoxBase<T> box) {
    _boxes.add(box);
    box.watch().listen((e) {});
  }
}
