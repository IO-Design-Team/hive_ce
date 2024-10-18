import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

class RevivedGenerateAdapters {
  final List<RevivedAdapterSpec> specs;
  final int firstTypeId;

  /// Constructor
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

class RevivedAdapterSpec {
  final DartType type;

  const RevivedAdapterSpec({required this.type});
}
