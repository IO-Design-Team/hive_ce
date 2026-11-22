// TODO: Remove with Dart 3.11
// ignore_for_file: unnecessary_ignore, experimental_member_use

import 'dart:io';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';
import 'package:yaml_writer/yaml_writer.dart';

/// Root of the package being built, defaulting to the working directory
///
/// Tests point this at a temporary project because the working directory is
/// shared by every test isolate.
String? buildPackageRoot;

final _hiveFieldChecker =
    const TypeChecker.typeNamed(HiveField, inPackage: 'hive_ce');
final _freezedDefaultChecker = const TypeChecker.fromUrl(
  'package:freezed_annotation/freezed_annotation.dart#Default',
);

/// TODO: Document this!
@immutable
class HiveFieldInfo {
  /// TODO: Document this!
  const HiveFieldInfo(this.index, this.defaultValue);

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

  final index = obj.getField('index')?.toIntValue();
  if (index == null) throw 'HiveField index is null.';

  return HiveFieldInfo(
    index,
    obj.getField('defaultValue'),
  );
}

/// Get the string representation of the freezed default value
DartObject? getFreezedDefault(Element? element) {
  if (element == null) return null;
  final obj = _freezedDefaultChecker.firstAnnotationOfExact(element);
  if (obj == null) return null;

  // Get the source code of the default value
  return obj.getField('defaultValue');
}

/// Get a classes default constructor or throw
ConstructorElement getConstructor(InterfaceElement cls) {
  final constr = cls.constructors.firstWhereOrNull((it) => it.name == 'new');
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

String? _findImportPrefix(
  LibraryElement library,
  bool Function(LibraryImport import) matches,
) {
  final imports =
      library.fragments.expand((f) => f.libraryImports).where(matches).toList();
  if (imports.any((e) => e.prefix == null)) return null;
  return imports.firstOrNull?.prefix?.element.displayName;
}

/// Normalizes `asset:` URIs under `lib/` to `package:` URIs and drops any
/// fragment so URIs from `source_gen` and `analyzer` can be compared directly.
Uri normalizeSourceUri(Uri uri) {
  final clean = uri.removeFragment();
  if (clean.scheme == 'asset' &&
      clean.pathSegments.length >= 2 &&
      clean.pathSegments[1] == 'lib') {
    return clean.replace(
      scheme: 'package',
      pathSegments: [clean.pathSegments.first, ...clean.pathSegments.skip(2)],
    );
  }
  return clean;
}

/// Returns the import prefix used in [currentLibrary] for a symbol named
/// [topLevelName] declared in [sourceUri], if any.
String? getImportPrefixForUri(
  Uri sourceUri,
  String topLevelName,
  LibraryElement currentLibrary,
) {
  final normalizedSource = normalizeSourceUri(sourceUri);
  if (normalizedSource == normalizeSourceUri(currentLibrary.uri)) return null;

  return _findImportPrefix(currentLibrary, (import) {
    final importedElement = import.namespace.definedNames2[topLevelName];
    if (importedElement == null) return false;
    final importedLibraryUri = import.importedLibrary?.uri;
    final elementLibraryUri = importedElement.library?.uri;
    return (importedLibraryUri != null &&
            normalizeSourceUri(importedLibraryUri) == normalizedSource) ||
        (elementLibraryUri != null &&
            normalizeSourceUri(elementLibraryUri) == normalizedSource);
  });
}

/// Import-prefix helpers for [Element].
extension ElementPrefixExtension on Element {
  /// Returns [displayName] prefixed with its import prefix in
  /// [currentLibrary], if any.
  String prefixedName(LibraryElement currentLibrary) {
    if (library == null || library == currentLibrary) return displayName;
    final prefix = _findImportPrefix(
      currentLibrary,
      (e) => e.namespace.definedNames2.values.contains(this),
    );
    return prefix != null ? '$prefix.$displayName' : displayName;
  }
}

/// Prefixed type formatting for [DartType].
extension PrefixedDartTypeExtension on DartType {
  /// Formats this type for emission inside [currentLibrary], preserving any
  /// import prefixes on the outer type and its type arguments.
  String getPrefixedDisplayString(LibraryElement currentLibrary) {
    final suffix = nullabilitySuffix == NullabilitySuffix.question ? '?' : '';
    return switch (this) {
      final InterfaceType type => () {
          final name = type.element.prefixedName(currentLibrary);
          final args = type.typeArguments.isEmpty
              ? ''
              : '<${type.typeArguments.map((t) => t.getPrefixedDisplayString(currentLibrary)).join(', ')}>';
          return '$name$args$suffix';
        }(),
      final RecordType type => () {
          final positional = type.positionalFields
              .map((f) => f.type.getPrefixedDisplayString(currentLibrary))
              .toList();
          final named = type.namedFields
              .map(
                (f) =>
                    '${f.type.getPrefixedDisplayString(currentLibrary)} ${f.name}',
              )
              .toList();
          final parts = <String>[
            ...positional,
            if (named.isNotEmpty) '{${named.join(', ')}}',
          ];
          final trailingComma =
              positional.length == 1 && named.isEmpty ? ',' : '';
          return '(${parts.join(', ')}$trailingComma)$suffix';
        }(),
      _ => getDisplayString(),
    };
  }
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
    File(path.joinAll([buildPackageRoot ?? '', ...id.pathSegments]))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
}

/// Write a [HiveSchema] to a string
String writeSchema(HiveSchema schema) {
  final yaml = YamlWriter().write(schema.toJson());
  return '''
${HiveSchema.comment}
$yaml''';
}
