// TODO: Remove with Dart 3.11
// ignore_for_file: unnecessary_ignore, experimental_member_use

import 'dart:typed_data';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_generator/src/adapter_builder/adapter_builder.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/helper/type_helper.dart';
import 'package:hive_ce_generator/src/model/revived_hive_converter.dart';
import 'package:source_gen/source_gen.dart';

/// TODO: Document this!
class ClassAdapterBuilder extends AdapterBuilder {
  /// TODO: Document this!
  const ClassAdapterBuilder(
    super.cls,
    super.getters,
    super.setters, {
    LibraryElement? library,
    this.converters = const [],
  }) : _library = library;

  final LibraryElement? _library;

  /// The library in which the adapter is being generated.
  LibraryElement get library => _library ?? cls.library;

  /// Converters from `GenerateAdapters.converters`.
  final List<RevivedHiveConverter> converters;

  /// [TypeChecker] for [HiveList].
  final hiveListChecker =
      const TypeChecker.typeNamed(HiveList, inPackage: 'hive_ce');

  /// [TypeChecker] for [Map].
  final mapChecker =
      const TypeChecker.typeNamed(Map, inPackage: 'core', inSdk: true);

  /// [TypeChecker] for [Set].
  final setChecker =
      const TypeChecker.typeNamed(Set, inPackage: 'core', inSdk: true);

  /// [TypeChecker] for [Iterable].
  final iterableChecker =
      const TypeChecker.typeNamed(Iterable, inPackage: 'core', inSdk: true);

  /// [TypeChecker] for [Uint8List].
  final uint8ListChecker = const TypeChecker.typeNamed(
    Uint8List,
    inPackage: 'typed_data',
    inSdk: true,
  );

  @override
  String buildRead() {
    final constr = getConstructor(cls);
    final clsName = cls.prefixedName(library);

    // The remaining fields to initialize.
    final fields = setters.toList();

    // Empty classes
    if (constr.formalParameters.isEmpty && fields.isEmpty) {
      return '''
    reader.readByte();
    return $clsName();
    ''';
    }

    final code = StringBuffer();
    code.writeln('''
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return $clsName(
    ''');

    for (final param in constr.formalParameters) {
      var field = fields.firstWhereOrNull((it) => it.name == param.displayName);
      // Final fields
      field ??= getters.firstWhereOrNull((it) => it.name == param.displayName);
      if (field != null) {
        if (param.isNamed) {
          code.write('${param.displayName}: ');
        }
        code.write(_value(param.type, field));
        code.writeln(',');
        fields.remove(field);
      }
    }

    code.writeln(')');

    // There may still be fields to initialize that were not in the constructor
    // as initializing formals. We do so using cascades.
    for (final field in fields) {
      code.write('..${field.name} = ');
      code.writeln(_value(field.type, field));
    }

    code.writeln(';');

    return code.toString();
  }

  String _value(DartType type, AdapterField field) {
    final variable = 'fields[${field.index}]';

    final annotationDefaultIsNull = field.annotationDefault?.isNull ?? true;
    final constructorDefaultIsNull = field.constructorDefault == null;

    final String? defaultValue;
    if (!annotationDefaultIsNull) {
      defaultValue = constantToString(field.annotationDefault);
    } else if (!constructorDefaultIsNull) {
      defaultValue = field.constructorDefault;
    } else {
      defaultValue = null;
    }

    if (defaultValue == null) return _cast(type, variable);

    final value = _cast(type, variable, skipNullCheck: true);
    return '$variable == null ? $defaultValue : $value';
  }

  Set<DartType> _withActive(Set<DartType> activeTypes, DartType type) =>
      {...activeTypes, library.typeSystem.promoteToNonNull(type)};

  MatchedHiveConverter? _matchConverter(
    DartType type,
    Set<DartType> activeTypes,
  ) {
    final nonNullType = library.typeSystem.promoteToNonNull(type);
    if (activeTypes.contains(nonNullType)) return null;
    return RevivedHiveConverter.matchAny(converters, type, library.typeSystem);
  }

  bool _hasConverter(
    DartType type, [
    Set<DartType> activeTypes = const {},
  ]) {
    if (_matchConverter(type, activeTypes) != null) return true;
    if (hiveListChecker.isAssignableFromType(type) ||
        isUint8List(type) ||
        !isMapOrIterable(type) ||
        type is! ParameterizedType ||
        type.typeArguments.isEmpty) {
      return false;
    }
    final nextActive = _withActive(activeTypes, type);
    return type.typeArguments.any((t) => _hasConverter(t, nextActive));
  }

  String _write(
    DartType type,
    String value, {
    Set<DartType> activeTypes = const {},
    bool isLocalVar = false,
  }) {
    final converter = _matchConverter(type, activeTypes);
    if (converter != null) {
      final nextActive = _withActive(activeTypes, type);
      final instance = converter.instanceExpression(library);
      String convert(String expr) => _write(
            converter.hiveType,
            '$instance.toHive($expr)',
            activeTypes: nextActive,
          );

      if (type.nullabilitySuffix == NullabilitySuffix.question &&
          !converter.handlesNull) {
        if (isLocalVar) {
          return '$value == null ? null : ${convert(value)}';
        }
        final varName =
            activeTypes.isEmpty ? 'value' : 'value${activeTypes.length}';
        return 'switch ($value) { final $varName? => ${convert(varName)}, null => null }';
      }
      return convert(value);
    }

    if (!_hasConverter(type, activeTypes)) return value;

    final nextActive = _withActive(activeTypes, type);
    final suffix = _accessorSuffixFromType(type);
    final args = (type as ParameterizedType).typeArguments;
    if (mapChecker.isAssignableFromType(type)) {
      return '$value$suffix.map((k, v) => MapEntry('
          '${_write(args[0], 'k', activeTypes: nextActive, isLocalVar: true)}, '
          '${_write(args[1], 'v', activeTypes: nextActive, isLocalVar: true)}))';
    }
    final collection =
        setChecker.isAssignableFromType(type) ? 'toSet' : 'toList';
    return '$value$suffix.map((e) => '
        '${_write(args[0], 'e', activeTypes: nextActive, isLocalVar: true)}'
        ').$collection()';
  }

  String _cast(
    DartType type,
    String variable, {
    Set<DartType> activeTypes = const {},
    bool skipNullCheck = false,
  }) {
    final converter = _matchConverter(type, activeTypes);
    if (converter != null) {
      final nextActive = _withActive(activeTypes, type);
      final innerCast =
          _cast(converter.hiveType, variable, activeTypes: nextActive);
      final converted =
          '${converter.instanceExpression(library)}.fromHive($innerCast)';
      if (type.nullabilitySuffix == NullabilitySuffix.question &&
          !converter.handlesNull &&
          !skipNullCheck) {
        return '$variable == null ? null : $converted';
      }
      return converted;
    }

    if (type is DynamicType) return variable;

    final suffix = _suffixFromType(type);
    if (hiveListChecker.isAssignableFromType(type)) {
      return '($variable as HiveList$suffix)$suffix.castHiveList()';
    } else if (setChecker.isAssignableFromType(type)) {
      return '($variable as Set$suffix)${_castIterable(type, activeTypes)}';
    } else if (iterableChecker.isAssignableFromType(type) &&
        !isUint8List(type)) {
      return '($variable as List$suffix)${_castIterable(type, activeTypes)}';
    } else if (mapChecker.isAssignableFromType(type)) {
      return '($variable as Map$suffix)${_castMap(type, activeTypes)}';
    } else if (type.isDartCoreInt) {
      return '($variable as num$suffix)$suffix.toInt()';
    } else if (type.isDartCoreDouble) {
      return '($variable as num$suffix)$suffix.toDouble()';
    } else {
      return '$variable as ${type.getPrefixedDisplayString(library)}';
    }
  }

  /// TODO: Document this!
  bool isMapOrIterable(DartType type) {
    return iterableChecker.isAssignableFromType(type) ||
        mapChecker.isAssignableFromType(type);
  }

  /// TODO: Document this!
  bool isUint8List(DartType type) {
    return uint8ListChecker.isExactlyType(type);
  }

  String _castIterable(DartType type, Set<DartType> activeTypes) {
    final paramType = type as ParameterizedType;
    final arg = paramType.typeArguments.first;
    final suffix = _accessorSuffixFromType(type);
    final nextActive = _withActive(activeTypes, type);
    if ((isMapOrIterable(arg) && !isUint8List(arg)) ||
        _hasConverter(arg, nextActive)) {
      var cast = '';
      // Using assignable because Set? is not exactly Set
      if (setChecker.isAssignableFromType(type)) {
        cast = '.toSet()';
        // Using assignable because Iterable? is not exactly Iterable
      } else if (iterableChecker.isAssignableFromType(type)) {
        cast = '.toList()';
      }

      return '$suffix.map((e) => ${_cast(arg, 'e', activeTypes: nextActive)})$cast';
    } else {
      return '$suffix.cast<${arg.getPrefixedDisplayString(library)}>()';
    }
  }

  String _castMap(DartType type, Set<DartType> activeTypes) {
    final paramType = type as ParameterizedType;
    final arg1 = paramType.typeArguments[0];
    final arg2 = paramType.typeArguments[1];
    final suffix = _accessorSuffixFromType(type);
    final nextActive = _withActive(activeTypes, type);
    if (isMapOrIterable(arg1) ||
        isMapOrIterable(arg2) ||
        _hasConverter(arg1, nextActive) ||
        _hasConverter(arg2, nextActive)) {
      return '$suffix.map((dynamic k, dynamic v)=>'
          'MapEntry(${_cast(arg1, 'k', activeTypes: nextActive)},'
          '${_cast(arg2, 'v', activeTypes: nextActive)}))';
    } else {
      return '$suffix.cast<${arg1.getPrefixedDisplayString(library)}, '
          '${arg2.getPrefixedDisplayString(library)}>()';
    }
  }

  @override
  String buildWrite() {
    final code = StringBuffer();
    code.writeln('writer');
    // Only cascade when there are getters
    if (getters.isNotEmpty) code.write('.');
    code.writeln('.writeByte(${getters.length})');
    for (final field in getters) {
      code.writeln('''
      ..writeByte(${field.index})
      ..write(${_write(field.type, 'obj.${field.name}')})''');
    }
    code.writeln(';');

    return code.toString();
  }
}

/// Suffix to use when accessing a field in [type].
/// $variable$suffix.field
String _accessorSuffixFromType(DartType type) {
  if (type.nullabilitySuffix == NullabilitySuffix.star) {
    return '?';
  }
  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    return '?';
  }
  return '';
}

/// Suffix to use when casting a value to [type].
/// $variable as $type$suffix
String _suffixFromType(DartType type) {
  return switch (type.nullabilitySuffix) {
    NullabilitySuffix.question => '?',
    _ => '',
  };
}
