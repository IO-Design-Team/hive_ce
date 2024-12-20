import 'package:build/build.dart';
import 'package:hive_ce_generator/src/builder/schema_migrator_builder.dart';
import 'package:hive_ce_generator/src/generator/adapters_generator.dart';
import 'package:hive_ce_generator/src/builder/registrar_builder.dart';
import 'package:hive_ce_generator/src/builder/registrar_intermediate_builder.dart';
import 'package:hive_ce_generator/src/generator/type_adapter_generator.dart';
import 'package:source_gen/source_gen.dart';

/// Builds Hive TypeAdapters
Builder getTypeAdapterBuilder(BuilderOptions options) =>
    SharedPartBuilder([TypeAdapterGenerator()], 'hive_type_adapter_generator');

/// Builds intermediate data required for the registrar builder
Builder getRegistrarIntermediateBuilder(BuilderOptions options) =>
    RegistrarIntermediateBuilder();

/// Builds the HiveRegistrar extension
Builder getRegistrarBuilder(BuilderOptions options) => RegistrarBuilder();

/// Builds Hive TypeAdapters from the GenerateAdapters annotation
Builder getAdaptersBuilder(BuilderOptions options) =>
    SharedPartBuilder([AdaptersGenerator()], 'hive_adapters_generator');

/// Builds a Hive schema from existing HiveType annotations
Builder getSchemaMigratorBuilder(BuilderOptions options) =>
    SchemaMigratorBuilder();
