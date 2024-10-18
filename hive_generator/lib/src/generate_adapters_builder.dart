import 'dart:async';

import 'package:build/build.dart';
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
    r'$lib$': ['hive/hive_adapters.hive.dart', 'hive/hive_schema.yaml'],
  };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final dartAsset = AssetId(
      buildStep.inputId.package,
      'lib/hive/hive_adapters.dart',
    );
    if (!await buildStep.canRead(dartAsset)) return;
    final dartContent = await buildStep.readAsString(dartAsset);

    if (!dartContent.contains(
      RegExp(r"^part 'hive_adapters\.hive\.dart';$", multiLine: true),
    )) {
      throw HiveError(
        'The file $dartAsset has to contain the part statement '
        "'part 'hive_adapters.hive.dart';'",
      );
    }

    final library = await buildStep.resolver.libraryFor(dartAsset);
    final annotations = LibraryReader(library)
        .annotatedWith(TypeChecker.fromRuntime(GenerateAdapters));
    if (annotations.length > 1) {
      throw HiveError(
        'Only one GenerateAdapters annotation is allowed per project',
      );
    }
    if (annotations.isEmpty) return;

    final revived = RevivedGenerateAdapters(annotations.single.annotation);

    final schemaAsset = AssetId(
      buildStep.inputId.package,
      'lib/hive/hive_schema.yaml',
    );
    final HiveSchema? schema;
    if (await buildStep.canRead(schemaAsset)) {
      final schemaContent = await buildStep.readAsString(schemaAsset);
      schema = HiveSchema.fromJson(loadYaml(schemaContent));
      print(schemaContent);
    } else {
      print('AHHHHHH');
      schema = HiveSchema(nextTypeId: revived.firstTypeId, types: {});
    }

    var nextTypeId = schema.nextTypeId;
    final content = StringBuffer("part of 'hive_adapters.dart';");
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
      schemaAsset,
      YamlWriter().write(schema.copyWith(nextTypeId: nextTypeId).toJson()),
    );

    await buildStep.writeAsString(
      AssetId(
        buildStep.inputId.package,
        'lib/hive/hive_adapters.hive.dart',
      ),
      content.toString(),
    );
  }
}
