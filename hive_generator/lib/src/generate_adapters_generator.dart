import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:hive_ce_generator/src/model/revived_generate_adapter.dart';
import 'package:hive_ce_generator/src/type_adapter_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

class GenerateAdaptersGenerator
    extends GeneratorForAnnotation<GenerateAdapters> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final revived = RevivedGenerateAdapters(annotation);
    final library = await buildStep.inputLibrary;

    final schemaFile = buildStep.inputId.changeExtension('.hive_schema.yaml');
    final HiveSchema? schema;
    if (await buildStep.canRead(schemaFile)) {
      final schemaContent = await buildStep.readAsString(schemaFile);
      schema = HiveSchema.fromJson(loadYaml(schemaContent));
    } else {
      schema = HiveSchema(nextTypeId: revived.firstTypeId, types: {});
    }

    var nextTypeId = schema.nextTypeId;
    final content = StringBuffer();
    for (final spec in revived.specs) {
      final typeKey = spec.type.getDisplayString();
      final schemaType = schema.types[typeKey];
      final typeId = schemaType?.typeId ?? nextTypeId++;
      final result = TypeAdapterGenerator.generateTypeAdapter(
        element: spec.type.element!,
        library: library,
        typeId: typeId,
        schema: schemaType ??
            HiveSchemaType(
              typeId: typeId,
              nextIndex: 0,
              fields: {},
            ),
      );

      content.write(result.content);
      schema.types[typeKey] = result.schema!;
    }

    await buildStep.writeAsString(
      schemaFile.changeExtension('.cache.yaml'),
      YamlWriter().write(schema.copyWith(nextTypeId: nextTypeId).toJson()),
    );

    return content.toString();
  }
}
