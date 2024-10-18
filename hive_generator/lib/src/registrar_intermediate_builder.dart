import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/revived_generate_adapter.dart';
import 'package:source_gen/source_gen.dart';

/// Builds intermediate data required for the registrar builder
class RegistrarIntermediateBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.hive_registrar.info'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;

    final library = await buildStep.inputLibrary;
    final adapters = <String>[];

    final hiveTypeElements =
        LibraryReader(library).annotatedWith(TypeChecker.fromRuntime(HiveType));
    for (final annotatedElement in hiveTypeElements) {
      final annotation = annotatedElement.annotation;
      final element = annotatedElement.element;
      final cls = getClass(element);
      final adapterName =
          readAdapterName(annotation) ?? generateAdapterName(cls.name);
      adapters.add(adapterName);
    }

    final generateAdaptersElements = LibraryReader(library)
        .annotatedWith(TypeChecker.fromRuntime(GenerateAdapters));
    for (final annotatedElement in generateAdaptersElements) {
      final annotation = annotatedElement.annotation;
      final revived = RevivedGenerateAdapters(annotation);
      for (final spec in revived.specs) {
        adapters.add(generateAdapterName(spec.type.getDisplayString()));
      }
    }

    await buildStep.writeAsString(
      buildStep.allowedOutputs.first,
      jsonEncode({
        'uris': [
          if (hiveTypeElements.isNotEmpty) library.source.uri.toString(),
          if (generateAdaptersElements.isNotEmpty)
            'package:${buildStep.inputId.package}/hive/hive_adapters.dart',
        ],
        'adapters': adapters,
      }),
    );
  }
}
