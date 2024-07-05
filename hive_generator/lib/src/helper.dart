import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:hive_ce/hive.dart';
import 'package:source_gen/source_gen.dart';

final _hiveFieldChecker = const TypeChecker.fromRuntime(HiveField);

/// TODO: Document this!
class HiveFieldInfo {
  /// TODO: Document this!
  HiveFieldInfo(this.index, this.defaultValue);

  /// TODO: Document this!
  final int index;

  /// TODO: Document this!
  final DartObject? defaultValue;
}

/// TODO: Document this!
HiveFieldInfo? getHiveFieldAnn(Element? element) {
  if (element == null) return null;
  final obj = _hiveFieldChecker.firstAnnotationOfExact(element);
  if (obj == null) return null;

  return HiveFieldInfo(
    obj.getField('index')!.toIntValue()!,
    obj.getField('defaultValue'),
  );
}

/// TODO: Document this!
void check(bool condition, Object error) {
  if (!condition) {
    // ignore: only_throw_errors
    throw error;
  }
}
