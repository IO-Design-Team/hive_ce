import 'dart:async';

import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/model/revived_generate_adapter.dart';
import 'package:source_gen/source_gen.dart';

/// Builds intermediate data required for the GenerateAdapters builder
class GenerateAdaptersIntermediateBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '.dart': ['.hive_generate_adapters.info'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;

    final library = await buildStep.inputLibrary;
    final generateAdaptersElements = LibraryReader(library)
        .annotatedWith(TypeChecker.fromRuntime(GenerateAdapters));
    if (generateAdaptersElements.isEmpty) return;
    final revived =
        RevivedGenerateAdapters(generateAdaptersElements.single.annotation);

    print(revived.specs.length);

    await buildStep.writeAsString(
      buildStep.allowedOutputs.first,
      revived.specs.map((spec) => spec.type.getDisplayString()).join('\n'),
    );
  }
}
