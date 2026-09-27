import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:hive_ce/hive_ce.dart';
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

  /// The revived converters
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

/// A revived HiveConverter
@immutable
class RevivedHiveConverter {
  /// The type of the converter itself
  final InterfaceType converterType;

  /// The type the converter converts from Hive
  final DartType type;

  /// The type stored in Hive
  final DartType hiveType;

  /// Constructor
  const RevivedHiveConverter({
    required this.converterType,
    required this.type,
    required this.hiveType,
  });

  /// Create a [RevivedHiveConverter] from a [DartObject]
  factory RevivedHiveConverter.fromObject(DartObject object) {
    final converterType = object.type as InterfaceType;
    final supertype = converterType.allSupertypes.firstWhere(
      (e) => const TypeChecker.typeNamed(HiveConverter, inPackage: 'hive_ce')
          .isExactly(e.element),
    );

    return RevivedHiveConverter(
      converterType: converterType,
      type: supertype.typeArguments[0],
      hiveType: supertype.typeArguments[1],
    );
  }
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
