import 'package:build/build.dart';
import 'package:hive_ce_generator/src/generate_adapters_builder.dart';
import 'package:hive_ce_generator/src/generate_adapters_intermediate_builder.dart';
import 'package:hive_ce_generator/src/registrar_builder.dart';
import 'package:hive_ce_generator/src/registrar_intermediate_builder.dart';
import 'package:hive_ce_generator/src/type_adapter_generator.dart';
import 'package:source_gen/source_gen.dart';

/// Builds Hive TypeAdapters
Builder getTypeAdapterBuilder(BuilderOptions options) =>
    SharedPartBuilder([TypeAdapterGenerator()], 'hive_generator_type_adapter');

/// Builds intermediate data required for the registrar builder
Builder getRegistrarIntermediateBuilder(BuilderOptions options) =>
    RegistrarIntermediateBuilder();

/// Builds the HiveRegistrar extension
Builder getRegistrarBuilder(BuilderOptions options) => RegistrarBuilder();

/// Builds intermediate data required for the GenerateAdapters builder
Builder getGenerateAdaptersIntermediateBuilder(BuilderOptions options) =>
    GenerateAdaptersIntermediateBuilder();

/// Builds Hive TypeAdapters from the GenerateAdapters annotation
Builder getGenerateAdaptersBuilder(BuilderOptions options) =>
    GenerateAdaptersBuilder();
