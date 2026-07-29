import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:hive_ce_generator/src/adapter_builder/adapter_builder.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

/// Information about a matched HiveConverter for code generation
@immutable
class HiveConverterMatch {
  /// Expression used to access the converter instance
  final String accessString;

  /// The Dart field type converted from/to ([HiveConverter]'s [T])
  final DartType fieldType;

  /// The Hive-stored type ([HiveConverter]'s [S]), with type args substituted
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

/// Resolve a [HiveConverter] for [targetType] from field/class annotations and
/// configured converter lists
///
/// Matching priority (same as json_serializable's [JsonConverter]):
/// 1. Annotations on the field getter
/// 2. Annotations on the field
/// 3. Annotations on the class
/// 4. [specConverters] (from [AdapterSpec.converters])
/// 5. [globalConverters] (from [GenerateAdapters.converters])
HiveConverterMatch? findHiveConverter({
  required DartType targetType,
  required AdapterFieldContext field,
  List<DartObject> specConverters = const [],
  List<DartObject> globalConverters = const [],
}) {
  List<_HiveConverterCandidate> converterMatches(
    List<ElementAnnotation> items,
  ) =>
      items
          .map(
            (annotation) => _compatibleMatch(
              targetType,
              annotation,
              annotation.computeConstantValue(),
            ),
          )
          .whereType<_HiveConverterCandidate>()
          .toList();

  var matchingAnnotations = converterMatches(
    field.getterAnnotations,
  );

  if (matchingAnnotations.isEmpty) {
    matchingAnnotations = converterMatches(field.fieldAnnotations);
  }

  if (matchingAnnotations.isEmpty) {
    matchingAnnotations = converterMatches(field.classAnnotations);
  }

  if (matchingAnnotations.isEmpty) {
    matchingAnnotations = specConverters
        .map((e) => _compatibleMatch(targetType, null, e))
        .whereType<_HiveConverterCandidate>()
        .toList();
  }

  if (matchingAnnotations.isEmpty) {
    matchingAnnotations = globalConverters
        .map((e) => _compatibleMatch(targetType, null, e))
        .whereType<_HiveConverterCandidate>()
        .toList();
  }

  return _converterFrom(matchingAnnotations, targetType);
}

/// Field context needed to look up converter annotations
@immutable
class AdapterFieldContext {
  /// Annotations on the getter
  final List<ElementAnnotation> getterAnnotations;

  /// Annotations on the field/variable
  final List<ElementAnnotation> fieldAnnotations;

  /// Annotations on the enclosing class
  final List<ElementAnnotation> classAnnotations;

  /// Constructor
  const AdapterFieldContext({
    required this.getterAnnotations,
    required this.fieldAnnotations,
    required this.classAnnotations,
  });

  /// Create from an [AdapterField] and its enclosing class
  factory AdapterFieldContext.from({
    required AdapterField field,
    required InterfaceElement cls,
  }) {
    final variable = field.element.variable;
    return AdapterFieldContext(
      getterAnnotations: variable.getter?.metadata.annotations ?? const [],
      fieldAnnotations: variable.metadata.annotations,
      classAnnotations: cls.metadata.annotations,
    );
  }
}

HiveConverterMatch? _converterFrom(
  List<_HiveConverterCandidate> matchingAnnotations,
  DartType targetType,
) {
  if (matchingAnnotations.isEmpty) return null;

  if (matchingAnnotations.length > 1) {
    throw InvalidGenerationSourceError(
      'Found more than one matching converter for '
      '`${targetType.getDisplayString()}`.',
      element: matchingAnnotations[1].elementAnnotation?.element,
    );
  }

  final match = matchingAnnotations.single;
  final annotationElement = match.elementAnnotation?.element;
  if (annotationElement is PropertyAccessorElement) {
    final enclosing = annotationElement.enclosingElement;

    final accessorName = annotationElement.name;
    if (accessorName == null) {
      throw InvalidGenerationSourceError(
        'Could not resolve converter accessor name.',
        element: annotationElement,
      );
    }
    final accessString = enclosing is ClassElement
        ? '${enclosing.name}.$accessorName'
        : accessorName;

    return HiveConverterMatch(
      accessString: accessString,
      fieldType: match.fieldType,
      hiveType: match.hiveType,
      isGeneric: false,
    );
  }

  final reviver = ConstantReader(match.annotation).revive();
  if (reviver.namedArguments.isNotEmpty ||
      reviver.positionalArguments.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'Converters with constructor arguments are not supported.',
      element: match.elementAnnotation?.element,
    );
  }

  final annotationType = match.annotation.type;
  final annotationTypeElement = annotationType?.element;
  final className = annotationTypeElement?.name;
  if (className == null) {
    throw InvalidGenerationSourceError(
      'Could not resolve converter class name.',
      element: match.elementAnnotation?.element,
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
  final ElementAnnotation? elementAnnotation;
  final String? genericTypeArgs;

  const _HiveConverterCandidate(
    this.elementAnnotation,
    this.annotation,
    this.hiveType,
    this.genericTypeArgs,
    this.fieldType,
  );
}

_HiveConverterCandidate? _compatibleMatch(
  DartType targetType,
  ElementAnnotation? annotation,
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
      annotation,
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
      annotation,
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
      annotation,
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
