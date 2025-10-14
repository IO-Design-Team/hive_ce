import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

/// A revived GenerateAdapters annotation
@immutable
class RevivedGenerateAdapters {
  /// The revived adapter specs
  final List<RevivedAdapterSpec> specs;

  /// The first type ID to use
  final int firstTypeId;

  /// The reserved type ids
  final Set<int> reservedTypeIds;

  /// Revive a GenerateAdapters annotation
  RevivedGenerateAdapters(ConstantReader annotation)
      : specs = annotation
            .read('specs')
            .listValue
            .map(RevivedAdapterSpec.fromObject)
            .toList(),
        firstTypeId = annotation.read('firstTypeId').intValue,
        reservedTypeIds = annotation
            .read('reservedTypeIds')
            .setValue
            .map((e) => e.toIntValue())
            .whereType<int>()
            .toSet();
}

/// A revived adapter spec
@immutable
class RevivedAdapterSpec {
  /// The type of the adapter
  final DartType type;

  /// Fields that should be ignored
  final Set<String> ignoredFields;

  /// Constructor
  const RevivedAdapterSpec({required this.type, required this.ignoredFields});

  /// Create a [RevivedAdapterSpec] from a [DartObject]
  factory RevivedAdapterSpec.fromObject(DartObject object) {
    final type = (object.type as InterfaceType).typeArguments.single;

    final reader = ConstantReader(object);
    final ignoredFields = reader
        .read('ignoredFields')
        .setValue
        .map((v) => v.toStringValue())
        .whereType<String>()
        .toSet();

    return RevivedAdapterSpec(type: type, ignoredFields: ignoredFields);
  }
}
