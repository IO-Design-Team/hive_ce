import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/registrar_intermediate.dart';
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

    if (adapters.isEmpty) return;

    await buildStep.writeAsString(
      buildStep.allowedOutputs.first,
      jsonEncode(
        RegistrarIntermediate(
          uri: library.source.uri,
          adapters: adapters,
        ),
      ),
    );
  }
}
