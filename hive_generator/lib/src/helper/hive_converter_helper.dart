import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';

/// A [HiveConverter] matched to a field type for code generation
class HiveConverterMatch {
  /// Converter instance expression, e.g. `const UriConverter()`
  final String access;

  /// Stored Hive type display string, e.g. `String`
  final String hiveType;

  /// Field type display string, e.g. `Uri`
  final String fieldType;

  /// Constructor
  const HiveConverterMatch({
    required this.access,
    required this.hiveType,
    required this.fieldType,
  });
}

const _checker = TypeChecker.typeNamedLiterally(
  'HiveConverter',
  inPackage: 'hive_ce',
);

/// Find a converter for [type] in [converters] from [GenerateAdapters]
HiveConverterMatch? findHiveConverter(
  DartType type,
  List<DartObject> converters,
) {
  HiveConverterMatch? result;
  for (final converter in converters) {
    final match = _match(type, converter);
    if (match == null) continue;
    if (result != null) {
      throw InvalidGenerationSourceError(
        'Found more than one matching converter for '
        '`${type.getDisplayString()}`.',
      );
    }
    result = match;
  }
  return result;
}

HiveConverterMatch? _match(DartType target, DartObject object) {
  final objectType = object.type;
  if (objectType is! InterfaceType) return null;

  final element = objectType.element;
  if (element is! ClassElement) return null;

  final hiveConverter = element.allSupertypes
      .where((t) => _checker.isExactly(t.element))
      .singleOrNull;
  if (hiveConverter == null) return null;

  final converted = hiveConverter.typeArguments[0];
  final stored = hiveConverter.typeArguments[1];
  final nonNullTarget = _nonNull(target);
  final name = element.name;
  if (name == null) return null;

  if (converted == nonNullTarget) {
    return HiveConverterMatch(
      access: 'const $name()',
      hiveType: stored.getDisplayString(),
      fieldType: converted.getDisplayString(),
    );
  }

  // e.g. `IListConverter<T>` for `IList<String>`
  if (converted is! InterfaceType ||
      nonNullTarget is! InterfaceType ||
      converted.element != nonNullTarget.element ||
      element.typeParameters.isEmpty ||
      converted.typeArguments.length != element.typeParameters.length) {
    return null;
  }

  for (var i = 0; i < element.typeParameters.length; i++) {
    final arg = converted.typeArguments[i];
    if (arg is! TypeParameterType || arg.element != element.typeParameters[i]) {
      return null;
    }
  }

  final args =
      nonNullTarget.typeArguments.map((t) => t.getDisplayString()).join(', ');
  final bindings = {
    for (var i = 0; i < element.typeParameters.length; i++)
      element.typeParameters[i]: nonNullTarget.typeArguments[i],
  };

  return HiveConverterMatch(
    access: '$name<$args>()',
    hiveType: _substitute(stored, bindings).getDisplayString(),
    fieldType: nonNullTarget.getDisplayString(),
  );
}

DartType _nonNull(DartType type) {
  if (type.nullabilitySuffix == NullabilitySuffix.none) return type;
  if (type is InterfaceType) {
    return type.element.instantiate(
      typeArguments: type.typeArguments,
      nullabilitySuffix: NullabilitySuffix.none,
    );
  }
  return type;
}

DartType _substitute(
  DartType type,
  Map<TypeParameterElement, DartType> bindings,
) {
  if (type is TypeParameterType) return bindings[type.element] ?? type;
  if (type is InterfaceType && type.typeArguments.isNotEmpty) {
    return type.element.instantiate(
      typeArguments: [
        for (final arg in type.typeArguments) _substitute(arg, bindings),
      ],
      nullabilitySuffix: type.nullabilitySuffix,
    );
  }
  return type;
}
