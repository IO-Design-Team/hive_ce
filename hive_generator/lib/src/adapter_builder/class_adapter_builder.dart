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
import 'package:source_gen/source_gen.dart';

import 'package:hive_ce_generator/src/helper/hive_converter_helper.dart';
import 'package:hive_ce_generator/src/helper/type_helper.dart';

/// TODO: Document this!
class ClassAdapterBuilder extends AdapterBuilder {
  /// TODO: Document this!
  const ClassAdapterBuilder(
    super.cls,
    super.getters, {
    super.setters,
    super.specConverters,
    super.globalConverters,
  });

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

    // The remaining fields to initialize.
    final fields = setters.toList();

    // Empty classes
    if (constr.formalParameters.isEmpty && fields.isEmpty) {
      return '''
    reader.readByte();
    return ${cls.displayName}();
    ''';
    }

    final code = StringBuffer();
    code.writeln('''
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return ${cls.displayName}(
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
    final value = _cast(type, variable, field);

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

    if (defaultValue == null) return value;

    return '$variable == null ? $defaultValue : $value';
  }

  String _cast(DartType type, String variable, AdapterField field) {
    final converter = _converterFor(type, field);
    if (converter != null) {
      return _fromHive(converter, type, variable);
    }

    final suffix = _suffixFromType(type);
    if (hiveListChecker.isAssignableFromType(type)) {
      return '($variable as HiveList$suffix)$suffix.castHiveList()';
    } else if (setChecker.isAssignableFromType(type)) {
      return '($variable as Set$suffix)${_castIterable(type, field)}';
    } else if (iterableChecker.isAssignableFromType(type) &&
        !isUint8List(type)) {
      return '($variable as List$suffix)${_castIterable(type, field)}';
    } else if (mapChecker.isAssignableFromType(type)) {
      return '($variable as Map$suffix)${_castMap(type, field)}';
    } else if (type.isDartCoreInt) {
      return '($variable as num$suffix)$suffix.toInt()';
    } else if (type.isDartCoreDouble) {
      return '($variable as num$suffix)$suffix.toDouble()';
    } else {
      return '$variable as ${type.getPrefixedDisplayString(cls.library)}';
    }
  }

  String _fromHive(
    HiveConverterMatch converter,
    DartType targetType,
    String variable,
  ) {
    final hiveType = converter.hiveType.getDisplayString();
    final access = converter.accessString;

    final targetIsNullable =
        targetType.nullabilitySuffix == NullabilitySuffix.question;
    final hiveIsNullable =
        converter.hiveType.nullabilitySuffix == NullabilitySuffix.question;

    if (targetIsNullable && !hiveIsNullable) {
      return '$variable == null ? null : $access.fromHive($variable as $hiveType)';
    }

    return '$access.fromHive($variable as $hiveType)';
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

  String _castIterable(DartType type, AdapterField field) {
    final paramType = type as ParameterizedType;
    final arg = paramType.typeArguments.first;
    final suffix = _accessorSuffixFromType(type);
    if (isMapOrIterable(arg) && !isUint8List(arg) ||
        _converterFor(arg, field) != null) {
      var cast = '';
      // Using assignable because Set? is not exactly Set
      if (setChecker.isAssignableFromType(type)) {
        cast = '.toSet()';
        // Using assignable because Iterable? is not exactly Iterable
      } else if (iterableChecker.isAssignableFromType(type)) {
        cast = '.toList()';
      }

      return '$suffix.map((e) => ${_cast(arg, 'e', field)})$cast';
    } else {
      return '$suffix.cast<${arg.getPrefixedDisplayString(cls.library)}>()';
    }
  }

  String _castMap(DartType type, AdapterField field) {
    final paramType = type as ParameterizedType;
    final arg1 = paramType.typeArguments[0];
    final arg2 = paramType.typeArguments[1];
    final suffix = _accessorSuffixFromType(type);
    if (isMapOrIterable(arg1) ||
        isMapOrIterable(arg2) ||
        _converterFor(arg1, field) != null ||
        _converterFor(arg2, field) != null) {
      return '$suffix.map((dynamic k, dynamic v)=>'
          'MapEntry(${_cast(arg1, 'k', field)},${_cast(arg2, 'v', field)}))';
    } else {
      return '$suffix.cast<${arg1.getPrefixedDisplayString(cls.library)}, '
          '${arg2.getPrefixedDisplayString(cls.library)}>()';
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
      ..write(${_writeValue(field.type, 'obj.${field.name}', field)})''');
    }
    code.writeln(';');

    return code.toString();
  }

  String _writeValue(DartType type, String expression, AdapterField field) {
    final converter = _converterFor(type, field);
    if (converter != null) {
      return _toHive(converter, type, expression);
    }

    if (setChecker.isAssignableFromType(type) ||
        (iterableChecker.isAssignableFromType(type) && !isUint8List(type))) {
      final paramType = type as ParameterizedType;
      final arg = paramType.typeArguments.first;
      final inner = _writeValue(arg, 'e', field);
      if (inner != 'e') {
        final suffix = _accessorSuffixFromType(type);
        if (setChecker.isAssignableFromType(type)) {
          return '$expression$suffix.map((e) => $inner).toSet()';
        }
        return '$expression$suffix.map((e) => $inner).toList()';
      }
    } else if (mapChecker.isAssignableFromType(type)) {
      final paramType = type as ParameterizedType;
      final arg1 = paramType.typeArguments[0];
      final arg2 = paramType.typeArguments[1];
      final key = _writeValue(arg1, 'k', field);
      final value = _writeValue(arg2, 'v', field);
      if (key != 'k' || value != 'v') {
        final suffix = _accessorSuffixFromType(type);
        return '$expression$suffix.map((dynamic k, dynamic v) => '
            'MapEntry($key, $value))';
      }
    }

    return expression;
  }

  String _toHive(
    HiveConverterMatch converter,
    DartType targetType,
    String expression,
  ) {
    final access = converter.accessString;
    final targetIsNullable =
        targetType.nullabilitySuffix == NullabilitySuffix.question;
    final fieldIsNullable =
        converter.fieldType.nullabilitySuffix == NullabilitySuffix.question;

    if (targetIsNullable && !fieldIsNullable) {
      final nonNullType = converter.fieldType.getDisplayString();
      return '$expression == null '
          '? null '
          ': $access.toHive($expression as $nonNullType)';
    }

    return '$access.toHive($expression)';
  }

  HiveConverterMatch? _converterFor(DartType type, AdapterField field) {
    return findHiveConverter(
      targetType: type,
      field: AdapterFieldContext.from(
        field: field,
        cls: cls,
      ),
      specConverters: specConverters,
      globalConverters: globalConverters,
    );
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

extension on DartType {
  String getPrefixedDisplayString(LibraryElement currentLibrary) {
    final element = this.element;
    if (element == null) return getDisplayString();

    final definingLibrary = element.library;
    if (definingLibrary == currentLibrary) return getDisplayString();

    final prefix = currentLibrary.fragments
        .expand((e) => e.libraryImports)
        .firstWhereOrNull(
          (e) => e.namespace.definedNames2.values.contains(element),
        )
        ?.prefix
        ?.element
        .displayName;

    if (prefix != null) {
      return '$prefix.${getDisplayString()}';
    }

    return getDisplayString();
  }
}
