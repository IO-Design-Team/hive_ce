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
    super.converters,
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
    final value = _cast(type, variable);

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

  String _cast(DartType type, String variable) {
    final converter = _converterFor(type);
    if (converter != null) {
      final call =
          '${converter.access}.fromHive($variable as ${converter.hiveType})';
      return _nullSafe(type, variable, call);
    }

    final suffix = _suffixFromType(type);
    if (hiveListChecker.isAssignableFromType(type)) {
      return '($variable as HiveList$suffix)$suffix.castHiveList()';
    } else if (setChecker.isAssignableFromType(type)) {
      return '($variable as Set$suffix)${_castIterable(type)}';
    } else if (iterableChecker.isAssignableFromType(type) &&
        !isUint8List(type)) {
      return '($variable as List$suffix)${_castIterable(type)}';
    } else if (mapChecker.isAssignableFromType(type)) {
      return '($variable as Map$suffix)${_castMap(type)}';
    } else if (type.isDartCoreInt) {
      return '($variable as num$suffix)$suffix.toInt()';
    } else if (type.isDartCoreDouble) {
      return '($variable as num$suffix)$suffix.toDouble()';
    } else {
      return '$variable as ${type.getPrefixedDisplayString(cls.library)}';
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

  String _castIterable(DartType type) {
    final paramType = type as ParameterizedType;
    final arg = paramType.typeArguments.first;
    final suffix = _accessorSuffixFromType(type);
    if (isMapOrIterable(arg) && !isUint8List(arg) ||
        _converterFor(arg) != null) {
      var cast = '';
      // Using assignable because Set? is not exactly Set
      if (setChecker.isAssignableFromType(type)) {
        cast = '.toSet()';
        // Using assignable because Iterable? is not exactly Iterable
      } else if (iterableChecker.isAssignableFromType(type)) {
        cast = '.toList()';
      }

      return '$suffix.map((e) => ${_cast(arg, 'e')})$cast';
    } else {
      return '$suffix.cast<${arg.getPrefixedDisplayString(cls.library)}>()';
    }
  }

  String _castMap(DartType type) {
    final paramType = type as ParameterizedType;
    final arg1 = paramType.typeArguments[0];
    final arg2 = paramType.typeArguments[1];
    final suffix = _accessorSuffixFromType(type);
    if (isMapOrIterable(arg1) ||
        isMapOrIterable(arg2) ||
        _converterFor(arg1) != null ||
        _converterFor(arg2) != null) {
      return '$suffix.map((dynamic k, dynamic v)=>'
          'MapEntry(${_cast(arg1, 'k')},${_cast(arg2, 'v')}))';
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
      ..write(${_writeValue(field.type, 'obj.${field.name}')})''');
    }
    code.writeln(';');

    return code.toString();
  }

  String _writeValue(DartType type, String expression) {
    final converter = _converterFor(type);
    if (converter != null) {
      final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
      final value =
          nullable ? '$expression as ${converter.fieldType}' : expression;
      return _nullSafe(
        type,
        expression,
        '${converter.access}.toHive($value)',
      );
    }

    if (setChecker.isAssignableFromType(type) ||
        (iterableChecker.isAssignableFromType(type) && !isUint8List(type))) {
      final arg = (type as ParameterizedType).typeArguments.first;
      final inner = _writeValue(arg, 'e');
      if (inner == 'e') return expression;
      final suffix = _accessorSuffixFromType(type);
      final mapped = '$expression$suffix.map((e) => $inner)';
      return setChecker.isAssignableFromType(type)
          ? '$mapped.toSet()'
          : '$mapped.toList()';
    }

    if (mapChecker.isAssignableFromType(type)) {
      final args = (type as ParameterizedType).typeArguments;
      final key = _writeValue(args[0], 'k');
      final value = _writeValue(args[1], 'v');
      if (key == 'k' && value == 'v') return expression;
      final suffix = _accessorSuffixFromType(type);
      return '$expression$suffix.map((dynamic k, dynamic v) => '
          'MapEntry($key, $value))';
    }

    return expression;
  }

  String _nullSafe(DartType type, String expression, String call) {
    if (type.nullabilitySuffix != NullabilitySuffix.question) return call;
    return '$expression == null ? null : $call';
  }

  HiveConverterMatch? _converterFor(DartType type) =>
      findHiveConverter(type, converters);
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
