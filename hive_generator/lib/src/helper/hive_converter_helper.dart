import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

/// Information about a matched HiveConverter for code generation
@immutable
class HiveConverterMatch {
  /// Expression used to access the converter instance
  final String accessString;

  /// The Dart field type converted from/to (HiveConverter's `T`)
  final DartType fieldType;

  /// The Hive-stored type (HiveConverter's `S`), with type args substituted
  final DartType hiveType;

  /// Whether the converter class is generic and was instantiated with type args
  final bool isGeneric;

  /// Constructor
  const HiveConverterMatch({
    required this.accessString,
    required this.fieldType,
    required this.hiveType,
    required this.isGeneric,
  });
}

const _hiveConverterChecker = TypeChecker.typeNamedLiterally(
  'HiveConverter',
  inPackage: 'hive_ce',
);

/// Resolve a HiveConverter for [targetType] from [GenerateAdapters.converters]
HiveConverterMatch? findHiveConverter({
  required DartType targetType,
  required List<DartObject> converters,
}) {
  final matches = converters
      .map((e) => _compatibleMatch(targetType, e))
      .whereType<_HiveConverterCandidate>()
      .toList();

  if (matches.isEmpty) return null;

  if (matches.length > 1) {
    throw InvalidGenerationSourceError(
      'Found more than one matching converter for '
      '`${targetType.getDisplayString()}`.',
    );
  }

  return _converterFrom(matches.single);
}

HiveConverterMatch _converterFrom(_HiveConverterCandidate match) {
  final reviver = ConstantReader(match.annotation).revive();
  if (reviver.namedArguments.isNotEmpty ||
      reviver.positionalArguments.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'Converters with constructor arguments are not supported.',
    );
  }

  final annotationType = match.annotation.type;
  final annotationTypeElement = annotationType?.element;
  final className = annotationTypeElement?.name;
  if (className == null) {
    throw InvalidGenerationSourceError(
      'Could not resolve converter class name.',
    );
  }
  final accessor = reviver.accessor.isEmpty ? '' : '.${reviver.accessor}';

  if (match.genericTypeArgs != null) {
    return HiveConverterMatch(
      accessString: '$className<${match.genericTypeArgs}>$accessor()',
      fieldType: match.fieldType,
      hiveType: match.hiveType,
      isGeneric: true,
    );
  }

  return HiveConverterMatch(
    accessString: 'const $className$accessor()',
    fieldType: match.fieldType,
    hiveType: match.hiveType,
    isGeneric: false,
  );
}

@immutable
class _HiveConverterCandidate {
  final DartObject annotation;
  final DartType fieldType;
  final DartType hiveType;
  final String? genericTypeArgs;

  const _HiveConverterCandidate(
    this.annotation,
    this.hiveType,
    this.genericTypeArgs,
    this.fieldType,
  );
}

_HiveConverterCandidate? _compatibleMatch(
  DartType targetType,
  DartObject? constantValue,
) {
  if (constantValue == null || constantValue.isNull) return null;

  final converterType = constantValue.type;
  if (converterType is! InterfaceType) return null;

  final converterClassElement = converterType.element;
  if (converterClassElement is! ClassElement) return null;

  final hiveConverterSuper = converterClassElement.allSupertypes
      .where((e) => _hiveConverterChecker.isExactly(e.element))
      .singleOrNull;

  if (hiveConverterSuper == null) return null;

  assert(hiveConverterSuper.typeArguments.length == 2);

  final fieldType = hiveConverterSuper.typeArguments[0];
  final hiveType = hiveConverterSuper.typeArguments[1];
  final nonNullableTarget = _promoteNonNullable(targetType);

  // Exact match (allow T for T?)
  if (fieldType == targetType || fieldType == nonNullableTarget) {
    return _HiveConverterCandidate(
      constantValue,
      hiveType,
      null,
      fieldType,
    );
  }

  // Generic converter where T is a type parameter of the annotated class
  if (fieldType is TypeParameterType && targetType is TypeParameterType) {
    if (converterClassElement.typeParameters.length > 1) {
      throw InvalidGenerationSourceError(
        '`HiveConverter` implementations can have no more than one type '
        'argument. `${converterClassElement.name}` has '
        '${converterClassElement.typeParameters.length}.',
        element: converterClassElement,
      );
    }

    return _HiveConverterCandidate(
      constantValue,
      hiveType,
      '${targetType.element.name}${_nullabilitySuffix(targetType)}',
      fieldType,
    );
  }

  // Generic converter such as `HiveConverter<IList<E>, List>` matching
  // `IList<String>` by unifying type parameters
  final bindings = <TypeParameterElement, DartType>{};
  if (_unify(fieldType, nonNullableTarget, bindings)) {
    final typeArgs = converterClassElement.typeParameters.map((param) {
      final bound = bindings[param];
      if (bound == null) {
        throw InvalidGenerationSourceError(
          'Could not infer type argument `${param.name}` for converter '
          '`${converterClassElement.name}` when matching '
          '`${targetType.getDisplayString()}`.',
          element: converterClassElement,
        );
      }
      return bound.getDisplayString();
    }).join(', ');

    return _HiveConverterCandidate(
      constantValue,
      _substitute(hiveType, bindings),
      typeArgs.isEmpty ? null : typeArgs,
      _substitute(fieldType, bindings),
    );
  }

  return null;
}

bool _unify(
  DartType pattern,
  DartType concrete,
  Map<TypeParameterElement, DartType> bindings,
) {
  if (pattern is TypeParameterType) {
    final element = pattern.element;
    final existing = bindings[element];
    if (existing != null) {
      return existing == concrete ||
          existing == _promoteNonNullable(concrete) ||
          _promoteNonNullable(existing) == _promoteNonNullable(concrete);
    }
    bindings[element] = concrete;
    return true;
  }

  if (pattern is InterfaceType && concrete is InterfaceType) {
    if (pattern.element != concrete.element) return false;
    if (pattern.typeArguments.length != concrete.typeArguments.length) {
      return false;
    }
    for (var i = 0; i < pattern.typeArguments.length; i++) {
      if (!_unify(
        pattern.typeArguments[i],
        concrete.typeArguments[i],
        bindings,
      )) {
        return false;
      }
    }
    return true;
  }

  return pattern == concrete ||
      pattern == _promoteNonNullable(concrete) ||
      _promoteNonNullable(pattern) == _promoteNonNullable(concrete);
}

DartType _substitute(
  DartType type,
  Map<TypeParameterElement, DartType> bindings,
) {
  if (type is TypeParameterType) {
    return bindings[type.element] ?? type;
  }
  if (type is InterfaceType && type.typeArguments.isNotEmpty) {
    final args =
        type.typeArguments.map((arg) => _substitute(arg, bindings)).toList();
    return type.element.instantiate(
      typeArguments: args,
      nullabilitySuffix: type.nullabilitySuffix,
    );
  }
  return type;
}

DartType _promoteNonNullable(DartType type) {
  if (type.nullabilitySuffix == NullabilitySuffix.none) return type;
  if (type is InterfaceType) {
    return type.element.instantiate(
      typeArguments: type.typeArguments,
      nullabilitySuffix: NullabilitySuffix.none,
    );
  }
  return type;
}

String _nullabilitySuffix(DartType type) {
  return type.nullabilitySuffix == NullabilitySuffix.question ? '?' : '';
}
