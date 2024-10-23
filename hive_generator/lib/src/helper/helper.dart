import 'dart:io';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:hive_ce/hive.dart';
import 'package:source_gen/source_gen.dart';
import 'package:path/path.dart' as path;

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

/// Get a classes default constructor or throw
ConstructorElement getConstructor(InterfaceElement cls) {
  final constr = cls.constructors.firstWhereOrNull((it) => it.name.isEmpty);
  if (constr == null) {
    throw 'Provide an unnamed constructor.';
  }
  return constr;
}

/// Returns [element] as [InterfaceElement] if it is a class or enum
InterfaceElement getClass(Element element) {
  if (element.kind != ElementKind.CLASS && element.kind != ElementKind.ENUM) {
    throw 'Only classes or enums are allowed to be annotated with @HiveType.';
  }

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

/// Read the adapter name from the annotation
String? readAdapterName(ConstantReader annotation) {
  final adapterNameField = annotation.read('adapterName');
  return adapterNameField.isNull ? null : adapterNameField.stringValue;
}

/// Read the typeId from the annotation
int readTypeId(ConstantReader annotation) {
  if (annotation.read('typeId').isNull) {
    throw 'You have to provide a non-null typeId.';
  }

  return annotation.read('typeId').intValue;
}

/// Convenience extension for [BuildStep]
extension BuildStepExtension on BuildStep {
  /// Create an [AssetId] for the given [path] relative to the input package
  AssetId asset(String path) => AssetId(inputId.package, path);

  /// Write [content] to asset [id] ignoring output restrictions
  ///
  /// This exists to bypass the following restrictions:
  /// - `$lib$` inputs can only have fixed output locations
  /// - Any files output through `buildStep.writeAsString` will be deleted
  ///   before the build starts
  void forceWriteAsString(AssetId id, String content) {
    File(path.joinAll(id.pathSegments)).writeAsStringSync(content);
  }
}
