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

  /// The converters
  final List<RevivedHiveConverter> converters;

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
            .toSet(),
        converters = annotation
            .read('converters')
            .listValue
            .map(RevivedHiveConverter.fromObject)
            .toList();
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
    final type = (object.type as ParameterizedType).typeArguments.single;

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

/// A revived hive converter
@immutable
class RevivedHiveConverter {
  /// The name of the class
  final String name;

  /// The number of type parameters

  /// The type of the converter
  final DartType type;

  /// Constructor
  const RevivedHiveConverter({required this.name, required this.type});

  /// Create a [RevivedHiveConverter] from a [DartObject]
  factory RevivedHiveConverter.fromObject(DartObject object) {
    final interfaceType = object.type as InterfaceType;
    final superclass = interfaceType.superclass;
    final name = object.type!.getDisplayString();
    final type = superclass!.typeArguments.first;

    return RevivedHiveConverter(name: name, type: type);
  }
}
