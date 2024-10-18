import 'package:build/build.dart';
import 'dart:async';

/// Copy `.hive_schema.cache.yaml` files from cache to source
class SchemaBuilder implements Builder {
  @override
    @override
  final Map<String, List<String>> buildExtensions = const {
    '.hive_schema.cache.yaml': ['.hive_schema.yaml'],
  };

  @override
  FutureOr<void> build(BuildStep buildStep) {
    final inputId = buildStep.inputId;
    return buildStep.writeAsString(
      AssetId(
        inputId.package,
        inputId.path.replaceFirst('.cache', ''),
      ),
      buildStep.readAsString(inputId),
    );
  }
}
