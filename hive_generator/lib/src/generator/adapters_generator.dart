import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:hive_ce_generator/src/model/revived_generate_adapter.dart';
import 'package:hive_ce_generator/src/generator/type_adapter_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';
import 'package:yaml/yaml.dart';

/// Builder that generates Hive adapters from a GenerateAdapters annotation
class AdaptersGenerator extends GeneratorForAnnotation<GenerateAdapters> {
  @override
  Future<String> generateForAnnotatedDirective(
    ElementDirective directive,
    ConstantReader annotation,
    BuildStep buildStep,
  ) =>
      _generate(annotation, buildStep);

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) =>
      _generate(annotation, buildStep);

  Future<String> _generate(
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final library = await buildStep.inputLibrary;
    final revived = RevivedGenerateAdapters(annotation);

    final schemaAsset = buildStep.inputId.changeExtension('.g.yaml');
    final HiveSchema schema;
    if (await buildStep.canRead(schemaAsset)) {
      final schemaContent = await buildStep.readAsString(schemaAsset);
      schema =
          HiveSchema.fromJson(jsonDecode(jsonEncode(loadYaml(schemaContent))));
    } else {
      schema = HiveSchema(nextTypeId: revived.firstTypeId, types: {});
    }
    _validateSchema(schema);

    // Sort existing types by type ID
    final existingSpecs = revived.specs
        .where((spec) => schema.types.containsKey(spec.type.getDisplayString()))
        .toList()
      ..sort((a, b) {
        final aTypeId = schema.types[a.type.getDisplayString()]!.typeId;
        final bTypeId = schema.types[b.type.getDisplayString()]!.typeId;
        return aTypeId.compareTo(bTypeId);
      });

    // Maintain order of new types
    final newSpecs = revived.specs
        .where(
          (spec) => !schema.types.containsKey(spec.type.getDisplayString()),
        )
        .toList();

    var typeId = schema.nextTypeId - 1;
    int generateTypeId() {
      do {
        typeId++;
      } while (revived.reservedTypeIds.contains(typeId));
      return typeId;
    }

    final newTypes = <String, HiveSchemaType>{};
    final content = StringBuffer();
    for (final spec in existingSpecs + newSpecs) {
      final typeKey = spec.type.element!.displayName;

      final schemaType = schema.types[typeKey] ??
          HiveSchemaType(
            typeId: generateTypeId(),
            kind: spec.type.isEnum ? TypeKind.enumKind : TypeKind.objectKind,
            nextIndex: 0,
            fields: {},
          );
      final result = TypeAdapterGenerator.generateTypeAdapter(
        element: spec.type.element!,
        library: library,
        typeId: schemaType.typeId,
        schema: schemaType,
      );

      content.write(result.content);
      newTypes[typeKey] = result.schema;
    }

    // Do not output the schema file through the buildStep since conflicting
    // output handling will delete it before this generator runs
    // Not the safest thing to do, but there doesn't seem to be a better way
    buildStep.forceWriteAsString(
      schemaAsset,
      writeSchema(HiveSchema(nextTypeId: typeId + 1, types: newTypes)),
    );

    return content.toString();
  }

  void _validateSchema(HiveSchema schema) {
    void invalidSchema(String message) {
      throw HiveError('Invalid schema: $message');
    }

    final typeIds = <int>{};
    for (final type in schema.types.values) {
      final typeId = type.typeId;
      if (typeIds.contains(typeId)) {
        invalidSchema('Duplicate type ID $typeId');
      }
      typeIds.add(typeId);

      final fieldIndices = <int>{};
      for (final field in type.fields.values) {
        final index = field.index;
        if (fieldIndices.contains(index)) {
          invalidSchema('Duplicate field index $index for type ID $typeId');
        }
        fieldIndices.add(index);
      }

      final sortedIndices = fieldIndices.toList()..sort();
      final lastIndex = sortedIndices.lastOrNull ?? -1;
      if (lastIndex >= type.nextIndex) {
        invalidSchema('Next index is invalid for type ID $typeId');
      }
    }

    final sortedTypeIds = typeIds.toList()..sort();
    final lastTypeId = sortedTypeIds.lastOrNull ?? -1;
    if (lastTypeId >= schema.nextTypeId) {
      invalidSchema('Next type ID is invalid');
    }
  }
}
