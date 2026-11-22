import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:collection/collection.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/helper/type_helper.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

const _hiveConverterChecker = TypeChecker.fromUrl(
  'package:hive_ce/src/annotations/hive_converter.dart#HiveConverter',
);

InterfaceType? _hiveConverterSupertype(InterfaceType type) =>
    type.allSupertypes.firstWhereOrNull(
      (e) => _hiveConverterChecker.isExactly(e.element),
    );

/// A revived `HiveConverter` entry from `GenerateAdapters.converters`
@immutable
class RevivedHiveConverter {
  /// The instantiated converter type
  final InterfaceType converterType;

  /// How this converter instance is reconstructed in generated code
  final Revivable revivable;

  /// The `HiveConverter<T, S>` supertype on the uninstantiated converter class
  final InterfaceType rawConverterSupertype;

  /// The `HiveConverter<T, S>` supertype on [converterType]
  final InterfaceType concreteConverterSupertype;

  /// Constructor
  const RevivedHiveConverter({
    required this.converterType,
    required this.revivable,
    required this.rawConverterSupertype,
    required this.concreteConverterSupertype,
  });

  /// Create a [RevivedHiveConverter] from a [DartObject]
  factory RevivedHiveConverter.fromObject(DartObject object) {
    final converterType = object.type;
    if (converterType is! InterfaceType) {
      throw InvalidGenerationSourceError(
        'Converter must be an instance of HiveConverter, got ${object.type}.',
      );
    }

    final concreteSupertype = _hiveConverterSupertype(converterType);
    if (concreteSupertype == null) {
      throw InvalidGenerationSourceError(
        '${converterType.getDisplayString()} must extend or implement HiveConverter.',
        element: converterType.element,
      );
    }

    final revivable = ConstantReader(object).revive();
    if (revivable.source.fragment.isEmpty && revivable.accessor.isEmpty) {
      throw InvalidGenerationSourceError(
        'Could not revive converter ${converterType.getDisplayString()}.',
        element: converterType.element,
      );
    }

    return RevivedHiveConverter(
      converterType: converterType,
      revivable: revivable,
      rawConverterSupertype:
          _hiveConverterSupertype(converterType.element.thisType)!,
      concreteConverterSupertype: concreteSupertype,
    );
  }

  /// Find the highest-priority converter in [converters] matching [targetType].
  static MatchedHiveConverter? matchAny(
    List<RevivedHiveConverter> converters,
    DartType targetType,
    TypeSystem typeSystem,
  ) {
    MatchedHiveConverter? best;
    for (final converter in converters) {
      final candidate = converter.match(targetType, typeSystem);
      if (candidate == null) continue;
      if (best == null || candidate._priority < best._priority) {
        best = candidate;
        if (best._priority == 0) break;
      }
    }
    return best;
  }

  /// Match this converter against [targetType], inferring free type arguments
  /// for unparameterized generic converters when applicable.
  MatchedHiveConverter? match(DartType targetType, TypeSystem typeSystem) {
    final freeParams = _freeTypeParameters(typeSystem);
    final templateT = (freeParams.isEmpty
            ? concreteConverterSupertype
            : rawConverterSupertype)
        .typeArguments[0];
    final handlesNull =
        templateT.nullabilitySuffix == NullabilitySuffix.question;
    final targetIsNullable =
        targetType.nullabilitySuffix == NullabilitySuffix.question;
    if (handlesNull && !targetIsNullable) return null;

    final expectedTarget = handlesNull || !targetIsNullable
        ? targetType
        : typeSystem.promoteToNonNull(targetType);
    final isExactNullability = handlesNull || !targetIsNullable;
    final priority =
        (freeParams.isNotEmpty ? 2 : 0) + (isExactNullability ? 0 : 1);

    if (freeParams.isEmpty) {
      if (templateT != expectedTarget) return null;
      return MatchedHiveConverter(
        revivable: revivable,
        converterType: converterType,
        hiveType: concreteConverterSupertype.typeArguments[1],
        handlesNull: handlesNull,
        priority: priority,
      );
    }

    final typeParams = converterType.element.typeParameters;
    final bindings = <TypeParameterElement, DartType>{
      for (var i = 0; i < typeParams.length; i++)
        if (!freeParams.contains(typeParams[i]))
          typeParams[i]: converterType.typeArguments[i],
    };

    if (!_matchType(
      templateT,
      expectedTarget,
      freeParams,
      bindings,
      typeSystem,
    )) {
      return null;
    }

    for (final param in freeParams) {
      final boundArg = bindings[param];
      if (boundArg == null) return null;
      final declaredBound = param.bound;
      if (declaredBound != null &&
          !typeSystem.isSubtypeOf(
            boundArg,
            _substituteType(declaredBound, bindings),
          )) {
        return null;
      }
    }

    final instantiated = converterType.element.instantiate(
      typeArguments: [for (final p in typeParams) bindings[p]!],
      nullabilitySuffix: NullabilitySuffix.none,
    );
    final resolvedSupertype = _hiveConverterSupertype(instantiated)!;
    if (resolvedSupertype.typeArguments[0] != expectedTarget) return null;

    return MatchedHiveConverter(
      revivable: revivable,
      converterType: instantiated,
      hiveType: resolvedSupertype.typeArguments[1],
      handlesNull: handlesNull,
      priority: priority,
    );
  }

  Set<TypeParameterElement> _freeTypeParameters(TypeSystem typeSystem) {
    final typeParams = converterType.element.typeParameters;
    if (typeParams.isEmpty || revivable.source.fragment.isEmpty) {
      return const {};
    }

    final defaultInstantiated = typeSystem.instantiateInterfaceToBounds(
      element: converterType.element,
      nullabilitySuffix: NullabilitySuffix.none,
    );
    final ctorName = revivable.accessor.isEmpty ? 'new' : revivable.accessor;
    final ctor = converterType.element.constructors
        .firstWhereOrNull((c) => c.name == ctorName);
    final constrainedByArgs = _typeParametersInConstructorArgs(ctor);
    final templateTypeParams =
        _typeParametersOf(rawConverterSupertype.typeArguments[0]);

    return {
      for (var i = 0; i < typeParams.length; i++)
        if (converterType.typeArguments[i] ==
                defaultInstantiated.typeArguments[i] &&
            templateTypeParams.contains(typeParams[i]) &&
            !constrainedByArgs.contains(typeParams[i]))
          typeParams[i],
    };
  }

  Set<TypeParameterElement> _typeParametersInConstructorArgs(
    ConstructorElement? ctor,
  ) {
    if (ctor == null) return const {};

    final referenced = <TypeParameterElement>{};
    var positionalIndex = 0;
    for (final param in ctor.formalParameters) {
      final arg = param.isPositional
          ? (positionalIndex < revivable.positionalArguments.length
              ? revivable.positionalArguments[positionalIndex++]
              : null)
          : revivable.namedArguments[param.name];
      if (arg != null && !arg.isNull) {
        referenced.addAll(_typeParametersOf(param.type));
      }
    }
    return referenced;
  }
}

/// A [RevivedHiveConverter] resolved against a concrete target type
@immutable
class MatchedHiveConverter {
  /// How this converter instance is reconstructed in generated code
  final Revivable revivable;

  /// The concrete instantiated converter type
  final InterfaceType converterType;

  /// The resolved Hive storage type `S`
  final DartType hiveType;

  /// Whether `T` itself is nullable (`fromHive`/`toHive` handle `null`)
  final bool handlesNull;

  final int _priority;

  /// Constructor
  const MatchedHiveConverter({
    required this.revivable,
    required this.converterType,
    required this.hiveType,
    required this.handlesNull,
    required int priority,
  }) : _priority = priority;

  /// Dart expression evaluating to the converter instance inside [library]
  String instanceExpression(LibraryElement library) {
    final hasPrivateSegment = revivable.source.fragment.isEmpty &&
        revivable.accessor.split('.').any((part) => part.startsWith('_'));
    if ((revivable.isPrivate || hasPrivateSegment) &&
        normalizeSourceUri(revivable.source) !=
            normalizeSourceUri(library.uri)) {
      throw InvalidGenerationSourceError(
        'Converter ${converterType.getDisplayString()} is private and cannot '
        'be accessed from ${library.uri}.',
        element: converterType.element,
      );
    }

    return reviveToString(revivable, type: converterType, library: library);
  }
}

Set<TypeParameterElement> _typeParametersOf(DartType type) => switch (type) {
      TypeParameterType(:final element) => {element},
      InterfaceType(:final typeArguments) => {
          for (final arg in typeArguments) ..._typeParametersOf(arg),
        },
      RecordType(:final positionalFields, :final namedFields) => {
          for (final f in positionalFields) ..._typeParametersOf(f.type),
          for (final f in namedFields) ..._typeParametersOf(f.type),
        },
      FunctionType(:final returnType, :final formalParameters) => {
          ..._typeParametersOf(returnType),
          for (final p in formalParameters) ..._typeParametersOf(p.type),
        },
      _ => const {},
    };

bool _bindTypeParameter(
  TypeParameterType pattern,
  DartType actual,
  Map<TypeParameterElement, DartType> bindings,
  TypeSystem typeSystem,
) {
  final DartType boundType;
  if (pattern.nullabilitySuffix == NullabilitySuffix.question) {
    if (actual.nullabilitySuffix != NullabilitySuffix.question) return false;
    boundType = typeSystem.promoteToNonNull(actual);
  } else {
    boundType = actual;
  }

  final existing = bindings[pattern.element];
  if (existing != null) return existing == boundType;
  bindings[pattern.element] = boundType;
  return true;
}

bool _matchType(
  DartType pattern,
  DartType actual,
  Set<TypeParameterElement> freeParams,
  Map<TypeParameterElement, DartType> bindings,
  TypeSystem typeSystem,
) {
  switch ((pattern, actual)) {
    case (final TypeParameterType p, _) when freeParams.contains(p.element):
      return _bindTypeParameter(p, actual, bindings, typeSystem);
    case (final InterfaceType p, final InterfaceType a):
      if (p.element != a.element ||
          p.nullabilitySuffix != a.nullabilitySuffix ||
          p.typeArguments.length != a.typeArguments.length) {
        return false;
      }
      for (var i = 0; i < p.typeArguments.length; i++) {
        if (!_matchType(
          p.typeArguments[i],
          a.typeArguments[i],
          freeParams,
          bindings,
          typeSystem,
        )) {
          return false;
        }
      }
      return true;
    case (final RecordType p, final RecordType a):
      if (p.nullabilitySuffix != a.nullabilitySuffix ||
          p.positionalFields.length != a.positionalFields.length ||
          p.namedFields.length != a.namedFields.length) {
        return false;
      }
      for (var i = 0; i < p.positionalFields.length; i++) {
        if (!_matchType(
          p.positionalFields[i].type,
          a.positionalFields[i].type,
          freeParams,
          bindings,
          typeSystem,
        )) {
          return false;
        }
      }
      for (var i = 0; i < p.namedFields.length; i++) {
        if (p.namedFields[i].name != a.namedFields[i].name ||
            !_matchType(
              p.namedFields[i].type,
              a.namedFields[i].type,
              freeParams,
              bindings,
              typeSystem,
            )) {
          return false;
        }
      }
      return true;
    default:
      return pattern == actual;
  }
}

DartType _substituteType(
  DartType type,
  Map<TypeParameterElement, DartType> bindings, {
  NullabilitySuffix? nullabilitySuffix,
}) {
  final suffix = nullabilitySuffix ?? type.nullabilitySuffix;
  return switch (type) {
    TypeParameterType(:final element) => () {
        final bound = bindings[element];
        if (bound == null) {
          return nullabilitySuffix == null
              ? type
              : element.instantiate(nullabilitySuffix: suffix);
        }
        if (suffix == NullabilitySuffix.question &&
            bound.nullabilitySuffix == NullabilitySuffix.none) {
          return _substituteType(
            bound,
            const {},
            nullabilitySuffix: NullabilitySuffix.question,
          );
        }
        return bound;
      }(),
    InterfaceType(:final element, :final typeArguments) => element.instantiate(
        typeArguments: [
          for (final arg in typeArguments) _substituteType(arg, bindings),
        ],
        nullabilitySuffix: suffix,
      ),
    RecordType(:final positionalFields, :final namedFields) => RecordType(
        positional: [
          for (final f in positionalFields) _substituteType(f.type, bindings),
        ],
        named: {
          for (final f in namedFields)
            f.name: _substituteType(f.type, bindings),
        },
        nullabilitySuffix: suffix,
      ),
    _ => type,
  };
}
