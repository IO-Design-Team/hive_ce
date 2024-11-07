import 'package:analyzer/dart/element/element.dart';
import 'package:glob/glob.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/generator/type_adapter_generator.dart';
import 'dart:async';

import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';

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
  static String hasNoSetter({
    required String className,
    required String fieldName,
  }) =>
      '$className.$fieldName does not have a public setter or corresponding constructor parameter';

  /// Exception if a field does not have a public getter
  static String hasNoGetter({
    required String className,
    required String fieldName,
  }) =>
      '$className.$fieldName does not have a public getter';

  @override
  final buildExtensions = const {
    r'$lib$': ['hive_schema.g.yaml'],
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
      final result = TypeAdapterGenerator.getAccessors(
        typeId: readTypeId(type.annotation),
        cls: cls,
        library: type.element.library!,
      );

      final className = cls.name;
      for (final accessor in result.getters + result.setters) {
        final annotationDefault = accessor.annotationDefault;
        if (annotationDefault != null && !annotationDefault.isNull) {
          throw InvalidGenerationSource(
            hasAnnotationDefaultValue(
              className: className,
              fieldName: accessor.name,
            ),
          );
        }
      }

      schemaInfos.add(
        _SchemaInfo(
          className: className,
          isEnum: cls.thisType.isEnum,
          constructor: getConstructor(cls),
          accessors: cls.accessors,
          schema: result.schema,
        ),
      );
    }
    schemaInfos.sort((a, b) => a.schema.typeId.compareTo(b.schema.typeId));
    final nextTypeId =
        schemaInfos.isEmpty ? 0 : schemaInfos.last.schema.typeId + 1;

    final sanitizedSchemaInfos = <_SchemaInfo>[];
    for (final info in schemaInfos) {
      if (info.isEnum) {
        // Enums need no sanitization
        sanitizedSchemaInfos.add(info);
        continue;
      }

      final sanitizedFields = <String, HiveSchemaField>{};
      for (final MapEntry(key: fieldName, value: schema)
          in info.schema.fields.entries) {
        final publicFieldName =
            fieldName.startsWith('_') ? fieldName.substring(1) : fieldName;

        final isInConstructor =
            info.constructor.parameters.any((e) => e.name == publicFieldName);
        final accessors =
            info.accessors.where((e) => e.name == publicFieldName).toList();
        final hasSetter = accessors.any((e) => e.isSetter);
        final hasGetter = accessors.any((e) => e.isGetter);

        if (!isInConstructor && !hasSetter) {
          throw InvalidGenerationSourceError(
            hasNoSetter(className: info.className, fieldName: fieldName),
            element: info.constructor,
          );
        }

        if (!hasGetter) {
          throw InvalidGenerationSourceError(
            hasNoGetter(className: info.className, fieldName: fieldName),
            element: info.constructor,
          );
        }

        sanitizedFields[publicFieldName] = schema;
      }
      sanitizedSchemaInfos.add(
        info.copyWith(schema: info.schema.copyWith(fields: sanitizedFields)),
      );
    }

    final types = {
      for (final type in sanitizedSchemaInfos) type.className: type.schema,
    };
    await buildStep.writeAsString(
      buildStep.asset('lib/hive_schema.g.yaml'),
      HiveSchema(nextTypeId: nextTypeId, types: types).toString(),
    );
  }
}

class _SchemaInfo {
  final String className;
  final bool isEnum;
  final ConstructorElement constructor;
  final List<PropertyAccessorElement> accessors;
  final HiveSchemaType schema;

  _SchemaInfo({
    required this.className,
    required this.isEnum,
    required this.constructor,
    required this.accessors,
    required this.schema,
  });

  _SchemaInfo copyWith({
    String? className,
    bool? isEnum,
    ConstructorElement? constructor,
    List<PropertyAccessorElement>? accessors,
    HiveSchemaType? schema,
  }) {
    return _SchemaInfo(
      className: className ?? this.className,
      isEnum: isEnum ?? this.isEnum,
      constructor: constructor ?? this.constructor,
      accessors: accessors ?? this.accessors,
      schema: schema ?? this.schema,
    );
  }
}
