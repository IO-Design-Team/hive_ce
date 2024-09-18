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
    throw error;
  }
}

/// Returns [element] as [InterfaceElement] if it is a class or enum
InterfaceElement getClass(Element element) {
  check(
    element.kind == ElementKind.CLASS || element.kind == ElementKind.ENUM,
    'Only classes or enums are allowed to be annotated with @HiveType.',
  );

  return element as InterfaceElement;
}

/// Generate a default adapter name from the type name
String generateAdapterName(String typeName) {
  var adapterName =
      '${typeName}Adapter'.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
  if (adapterName.startsWith('_')) {
    adapterName = adapterName.substring(1);
  }
  if (adapterName.startsWith(r'$')) {
    adapterName = adapterName.substring(1);
  }
  return adapterName;
}

/// Get the adapter name from the annotation or generate a default name
String getAdapterName(String typeName, ConstantReader annotation) {
  final annAdapterName = annotation.read('adapterName');
  if (annAdapterName.isNull) {
    return generateAdapterName(typeName);
  } else {
    return annAdapterName.stringValue;
  }
}
