import 'package:build/build.dart';
import 'package:hive_ce_generator/src/registrar_generator.dart';
import 'package:hive_ce_generator/src/registrar_intermediate_generator.dart';
import 'package:hive_ce_generator/src/type_adapter_generator.dart';
import 'package:source_gen/source_gen.dart';

/// The [SharedPartBuilder] for hive_generator
Builder getTypeAdapterBuilder(BuilderOptions options) =>
    SharedPartBuilder([TypeAdapterGenerator()], 'hive_generator');

/// Builds intermediate data required for the registrar builder
Builder getRegistrarIntermediateBuilder(BuilderOptions options) =>
    RegistrarIntermediateBuilder();

/// The registrar builder for hive_generator
Builder getRegistrarBuilder(BuilderOptions options) => RegistrarBuilder();
