import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:hive_ce_generator/src/model/revived_generate_adapter.dart';
import 'package:hive_ce_generator/src/type_adapter_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

class GenerateAdaptersBuilder extends Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '.dart': ['.hive.dart', '.hive_schema.yaml'],
    '.yaml': ['.hive_schema.yaml'],
  };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final infoFileId = inputId.changeExtension('.hive_generate_adapters.info');
    if (!await buildStep.canRead(infoFileId)) return;

    // Reading these files tells the generator to notify us of changes
    // But we don't actually need the contents here
    await buildStep.readAsString(infoFileId);

    final library = await buildStep.inputLibrary;
    final annotations = LibraryReader(library)
        .annotatedWith(TypeChecker.fromRuntime(GenerateAdapters));
    if (annotations.isEmpty) return;
    if (annotations.length > 1) {
      throw HiveError(
        'Only one GenerateAdapters annotation is allowed per file',
      );
    }
    final revived = RevivedGenerateAdapters(annotations.single.annotation);

    final schemaFile = inputId.changeExtension('.hive_schema.yaml');
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
      schemaFile,
      YamlWriter().write(schema.copyWith(nextTypeId: nextTypeId).toJson()),
    );

    await buildStep.writeAsString(
      inputId.changeExtension('.hive.dart'),
      content.toString(),
    );
  }
}
