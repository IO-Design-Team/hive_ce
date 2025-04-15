import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:meta/meta.dart';

/// A revived GenerateAdapters annotation
@immutable
class RevivedGenerateAdapters {
  /// The revived adapter specs
  final List<RevivedAdapterSpec> specs;

  /// The first type ID to use
  final int firstTypeId;

  /// Revive a GenerateAdapters annotation
  RevivedGenerateAdapters(ConstantReader annotation)
      : specs = annotation
            .read('specs')
            .listValue
            .map((spec) => spec.type as InterfaceType)
            .map((type) => type.typeArguments.single)
            .map((type) => RevivedAdapterSpec(type: type))
            .toList(),
        firstTypeId = annotation.read('firstTypeId').intValue;
}

/// A revived adapter spec
@immutable
class RevivedAdapterSpec {
  /// The type of the adapter
  final DartType type;

  /// Constructor
  const RevivedAdapterSpec({required this.type});
}
