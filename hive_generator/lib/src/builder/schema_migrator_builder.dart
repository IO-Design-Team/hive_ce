import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/generator/type_adapter_generator.dart';
import 'dart:async';

import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';
import 'package:meta/meta.dart';

/// Generate a Hive schema from existing HiveType annotations
class SchemaMigratorBuilder implements Builder {
  /// Exception if a field has a default value in the HiveField annotation
  static String hasAnnotationDefaultValue({
    required String className,
    required String fieldName,
  }) =>
      '$className.$fieldName has a default value in the HiveField annotation.'
      ' Convert it to a constructor parameter default before migrating.';

  /// Exception if a field does not have a public setter
  static String hasNoPublicSetter({
    required String className,
    required String fieldName,
  }) =>
      '$className.$fieldName does not have a public setter or corresponding constructor parameter';

  /// Exception if a field does not have a public getter
  static String hasNoPublicGetter({
    required String className,
    required String fieldName,
  }) =>
      '$className.$fieldName does not have a public getter';

  /// Exception if a field will cause a schema mismatch
  static String hasSchemaMismatch({
    required String className,
    required Set<String> accessors,
  }) {
    final accessorsString = accessors.join('\n- ');
    return 'Accessors in $className do not have HiveField annotations'
        ' but are valid accessors for the GenerateAdapters annotation.'
        ' This will result in a schema mismatch.'
        ' Consider moving these accessors to an extension:\n- $accessorsString';
  }

  @override
  final buildExtensions = const {
    r'$lib$': ['hive/hive_adapters.dart', 'hive/hive_adapters.g.yaml'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final hiveTypes = <AnnotatedElement>[];
    await for (final input in buildStep.findAssets(Glob('**/*.dart'))) {
      if (!await buildStep.resolver.isLibrary(input)) continue;
      final library = await buildStep.resolver.libraryFor(input);
      final hiveTypeElements = LibraryReader(library)
          .annotatedWith(TypeChecker.fromRuntime(HiveType));
      hiveTypes.addAll(hiveTypeElements);
    }

    final schemaInfos = <_SchemaInfo>[];
    for (final type in hiveTypes) {
      final cls = getClass(type.element);
      final className = cls.displayName;

      /// TODO: Fix with analyzer 8
      /// ignore: deprecated_member_use
      final library = type.element.library!;
      final typeId = readTypeId(type.annotation);
      final result = TypeAdapterGenerator.getAccessors(
        typeId: typeId,
        cls: cls,
        library: library,
      );

      // Ensure no HiveField default values
      for (final accessor in result.getters + result.setters) {
        final annotationDefault = accessor.annotationDefault;
        if (annotationDefault != null && !annotationDefault.isNull) {
          throw InvalidGenerationSourceError(
            hasAnnotationDefaultValue(
              className: className,
              fieldName: accessor.name,
            ),
            element: accessor.element,
          );
        }
      }

      final uri = library.source.uri;
      final isEnum = cls.thisType.isEnum;
      final constructor = getConstructor(cls);
      final accessors = [
        ...cls.accessors,

        /// TODO: Fix with analyzer 8
        /// ignore: deprecated_member_use
        ...cls.allSupertypes.expand((it) => it.accessors),
      ];
      final info = _SchemaInfo(
        uri: uri,
        className: className,
        isEnum: isEnum,
        constructor: constructor,
        accessors: accessors,
        schema: result.schema,
      );

      // This includes any fields without HiveField annotations that would be
      // included in adapters generated by the GenerateAdapters annotation
      final secondPassResult = TypeAdapterGenerator.getAccessors(
        typeId: typeId,
        cls: cls,
        library: library,
        schema: info.schema,
      );
      final secondPassInfo = _SchemaInfo(
        uri: uri,
        className: className,
        isEnum: isEnum,
        constructor: constructor,
        accessors: accessors,
        schema: secondPassResult.schema,
      );

      final firstPassFields = info.schema.fields.keys.toSet();
      final secondPassFields = secondPassInfo.schema.fields.keys.toSet();
      final accessorsWithoutAnnotations =
          secondPassFields.difference(firstPassFields);

      if (accessorsWithoutAnnotations.isNotEmpty) {
        throw InvalidGenerationSourceError(
          hasSchemaMismatch(
            className: className,
            accessors: accessorsWithoutAnnotations,
          ),
          element: cls,
        );
      }

      schemaInfos.add(info);
    }
    schemaInfos.sort((a, b) => a.schema.typeId.compareTo(b.schema.typeId));
    final nextTypeId =
        schemaInfos.isEmpty ? 0 : schemaInfos.last.schema.typeId + 1;

    final types = {
      for (final type in schemaInfos) type.className: type.schema,
    };

    final imports = schemaInfos
        .map((e) => e.uri)
        .toSet() // Remove duplicates
        .map((e) => "import '$e';")
        .sorted() // Sort alphabetically
        .join('\n');
    final specs =
        schemaInfos.map((e) => 'AdapterSpec<${e.className}>()').join(',\n  ');
    buildStep.forceWriteAsString(
      buildStep.asset('lib/hive/hive_adapters.dart'),
      '''
import 'package:hive_ce/hive.dart';
$imports

@GenerateAdapters([
  $specs,
])
part 'hive_adapters.g.dart';
''',
    );

    buildStep.forceWriteAsString(
      buildStep.asset('lib/hive/hive_adapters.g.yaml'),
      HiveSchema(nextTypeId: nextTypeId, types: types).toString(),
    );
  }
}

@immutable
class _SchemaInfo {
  final Uri uri;
  final String className;
  final HiveSchemaType schema;

  _SchemaInfo({
    required this.uri,
    required this.className,
    required bool isEnum,

    /// TODO: Fix with analyzer 8
    /// ignore: deprecated_member_use
    required ConstructorElement constructor,

    /// TODO: Fix with analyzer 8
    /// ignore: deprecated_member_use
    required List<PropertyAccessorElement> accessors,
    required HiveSchemaType schema,
  }) : schema = _sanitizeSchema(
          className: className,
          isEnum: isEnum,
          schema: schema,
          constructor: constructor,
          accessors: accessors,
        );

  static HiveSchemaType _sanitizeSchema({
    required String className,
    required bool isEnum,
    required HiveSchemaType schema,

    /// TODO: Fix with analyzer 8
    /// ignore: deprecated_member_use
    required ConstructorElement constructor,

    /// TODO: Fix with analyzer 8
    /// ignore: deprecated_member_use
    required List<PropertyAccessorElement> accessors,
  }) {
    // Enums need no sanitization
    if (isEnum) return schema;

    final sanitizedFields = <String, HiveSchemaField>{};
    for (final MapEntry(key: fieldName, value: schema)
        in schema.fields.entries) {
      final publicFieldName =
          fieldName.startsWith('_') ? fieldName.substring(1) : fieldName;

      final isInConstructor =
          constructor.parameters.any((e) => e.displayName == publicFieldName);
      final publicAccessors =
          accessors.where((e) => e.displayName == publicFieldName).toList();
      final hasPublicSetter = publicAccessors.any((e) => e.isSetter);
      final hasPublicGetter = publicAccessors.any((e) => e.isGetter);

      if (!isInConstructor && !hasPublicSetter) {
        throw InvalidGenerationSourceError(
          SchemaMigratorBuilder.hasNoPublicSetter(
            className: className,
            fieldName: fieldName,
          ),
          element: constructor,
        );
      }

      if (!hasPublicGetter) {
        throw InvalidGenerationSourceError(
          SchemaMigratorBuilder.hasNoPublicGetter(
            className: className,
            fieldName: fieldName,
          ),
          element: constructor,
        );
      }

      sanitizedFields[publicFieldName] = schema;
    }

    return schema.copyWith(fields: sanitizedFields);
  }
}
