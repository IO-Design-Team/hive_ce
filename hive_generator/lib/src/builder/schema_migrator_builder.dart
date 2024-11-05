import 'package:glob/glob.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/generator/type_adapter_generator.dart';
import 'dart:async';

import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:source_gen/source_gen.dart';

/// Generate a Hive schema from existing HiveType annotations
class SchemaMigratorBuilder implements Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['hive_schema.g.yaml'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final hiveTypes = <AnnotatedElement>[];
    await for (final input in buildStep.findAssets(Glob('**/*.dart'))) {
      final library = await buildStep.resolver.libraryFor(input);
      final hiveTypeElements = LibraryReader(library)
          .annotatedWith(TypeChecker.fromRuntime(HiveType));
      hiveTypes.addAll(hiveTypeElements);
    }

    final schemaTypes = <(String, HiveSchemaType)>[];
    for (final type in hiveTypes) {
      final cls = getClass(type.element);
      final result = TypeAdapterGenerator.getAccessors(
        typeId: readTypeId(type.annotation),
        cls: cls,
        library: type.element.library!,
      );

      schemaTypes.add((cls.getDisplayString(), result.schema));
    }

    schemaTypes.sort((a, b) => a.$2.typeId.compareTo(b.$2.typeId));
    final nextTypeId = schemaTypes.isEmpty ? 0 : schemaTypes.last.$2.typeId + 1;
    final types = {for (final type in schemaTypes) type.$1: type.$2};

    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.g.yaml'),
      HiveSchema(nextTypeId: nextTypeId, types: types).toString(),
    );
  }
}
