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
      : specs = annotation.read('specs').listValue.map((specObj) {
          final specType = specObj.type as InterfaceType;
          final typeArg = specType.typeArguments.single;
          final reader = ConstantReader(specObj);
          final ignoredFields = reader.peek('ignoredFields')?.listValue.map((v) => v.toStringValue()!).toList() ?? const [];
          return RevivedAdapterSpec(type: typeArg, ignoredFields: ignoredFields);
        }).toList(),
        firstTypeId = annotation.read('firstTypeId').intValue,
        reservedTypeIds = annotation.read('reservedTypeIds').setValue.map((e) => e.toIntValue()).whereType<int>().toSet();
}

/// A revived adapter spec
@immutable
class RevivedAdapterSpec {
  /// The type of the adapter
  final DartType type;

  /// Fields that should be ignored
  final List<String> ignoredFields;

  /// Constructor
  const RevivedAdapterSpec({required this.type, this.ignoredFields = const []});
}
