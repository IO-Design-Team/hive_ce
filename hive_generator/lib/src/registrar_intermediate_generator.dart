import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/helper.dart';
import 'package:source_gen/source_gen.dart';

/// Builds intermediate data required for the registrar builder
class RegistrarIntermediateBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '.dart': ['.hive_registrar.info'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final library = await buildStep.inputLibrary;
    final annotatedElements =
        LibraryReader(library).annotatedWith(TypeChecker.fromRuntime(HiveType));

    final adapters = <String>[];
    for (final annotatedElement in annotatedElements) {
      final annotation = annotatedElement.annotation;
      final element = annotatedElement.element;
      final cls = getClass(element);
      final adapterName = getAdapterName(cls.name, annotation);
      adapters.add(adapterName);
    }

    await buildStep.writeAsString(
      AssetId.resolve(library.source.uri),
      jsonEncode({
        'uri': library.source.uri.toString(),
        'adapters': adapters,
      }),
    );
  }
}
