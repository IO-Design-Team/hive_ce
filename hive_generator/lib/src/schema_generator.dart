import 'package:build/build.dart';
import 'dart:async';

import 'package:source_gen/source_gen.dart';

/// Copy `.hive_schema.cache.yaml` files from cache to source
class SchemaGenerator implements Generator {
  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    return buildStep.readAsString(buildStep.inputId);
  }
}
