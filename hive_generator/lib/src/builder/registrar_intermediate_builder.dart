import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/registrar_intermediate.dart';
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

    final hiveTypeElements = LibraryReader(library)
        .annotatedWith(TypeChecker.typeNamed(HiveType, inPackage: 'hive_ce'));
    for (final annotatedElement in hiveTypeElements) {
      final annotation = annotatedElement.annotation;
      final element = annotatedElement.element;
      final cls = getClass(element);
      final adapterName =
          readAdapterName(annotation) ?? generateAdapterName(cls.displayName);
      adapters.add(adapterName);
    }

    // If the registrar should be placed next to this file
    final bool registrarLocation;

    final generateAdaptersChecker =
        TypeChecker.typeNamed(GenerateAdapters, inPackage: 'hive_ce');
    final libraryReader = LibraryReader(library);

    final generateAdaptersElements =
        libraryReader.annotatedWith(generateAdaptersChecker);
    final generateAdaptersDirectives =
        libraryReader.libraryDirectivesAnnotatedWith(generateAdaptersChecker);

    final generateAdaptersAnnotationReaders = [
      ...generateAdaptersElements.map((e) => e.annotation),
      ...generateAdaptersDirectives.map((e) => e.annotation),
    ];

    // Read multiple annotations if they exist
    final generateAdaptersAnnotationObjects = [
      ...generateAdaptersElements
          .expand((e) => generateAdaptersChecker.annotationsOf(e.element)),
      ...generateAdaptersDirectives
          .expand((e) => generateAdaptersChecker.annotationsOf(e.directive)),
    ];

    if (generateAdaptersAnnotationObjects.length > 1) {
      throw HiveError(
        'Multiple GenerateAdapters annotations found in file: ${library.uri}',
      );
    } else if (generateAdaptersAnnotationReaders.isNotEmpty) {
      registrarLocation = true;

      final annotation = generateAdaptersAnnotationReaders.single;
      final revived = RevivedGenerateAdapters(annotation);
      for (final spec in revived.specs) {
        adapters.add(generateAdapterName(spec.type.element!.displayName));
      }
    } else {
      registrarLocation = false;
    }

    if (adapters.isEmpty) return;

    await buildStep.writeAsString(
      buildStep.allowedOutputs.first,
      jsonEncode(
        RegistrarIntermediate(
          uri: library.uri,
          adapters: adapters,
          registrarLocation: registrarLocation,
        ),
      ),
    );
  }
}
