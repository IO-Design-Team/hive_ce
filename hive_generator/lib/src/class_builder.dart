import 'dart:typed_data';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/builder.dart';
import 'package:hive_ce_generator/src/helper.dart';
import 'package:source_gen/source_gen.dart';

import 'package:hive_ce_generator/src/type_helper.dart';

/// TODO: Document this!
class ClassBuilder extends Builder {
  /// TODO: Document this!
  ClassBuilder(
    super.cls,
    super.getters,
    super.setters,
  );

  /// TODO: Document this!
  var hiveListChecker = const TypeChecker.fromRuntime(HiveList);

  /// TODO: Document this!
  var listChecker = const TypeChecker.fromRuntime(List);

  /// TODO: Document this!
  var mapChecker = const TypeChecker.fromRuntime(Map);

  /// TODO: Document this!
  var setChecker = const TypeChecker.fromRuntime(Set);

  /// TODO: Document this!
  var iterableChecker = const TypeChecker.fromRuntime(Iterable);

  /// TODO: Document this!
  var uint8ListChecker = const TypeChecker.fromRuntime(Uint8List);

  @override
  String buildRead() {
    final constr = cls.constructors.firstOrNullWhere((it) => it.name.isEmpty);
    check(constr != null, 'Provide an unnamed constructor.');

    // The remaining fields to initialize.
    final fields = setters.toList();

    // Empty classes
    if (constr!.parameters.isEmpty && fields.isEmpty) {
      return 'return ${cls.name}();';
    }

    final code = StringBuffer();
    code.writeln('''
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return ${cls.name}(
    ''');

    for (final param in constr.parameters) {
      var field = fields.firstOrNullWhere((it) => it.name == param.name);
      // Final fields
      field ??= getters.firstOrNullWhere((it) => it.name == param.name);
      if (field != null) {
        if (param.isNamed) {
          code.write('${param.name}: ');
        }
        code.write(
          _value(
            param.type,
            'fields[${field.index}]',
            field.defaultValue,
          ),
        );
        code.writeln(',');
        fields.remove(field);
      }
    }

    code.writeln(')');

    // There may still be fields to initialize that were not in the constructor
    // as initializing formals. We do so using cascades.
    for (final field in fields) {
      code.write('..${field.name} = ');
      code.writeln(
        _value(
          field.type,
          'fields[${field.index}]',
          field.defaultValue,
        ),
      );
    }

    code.writeln(';');

    return code.toString();
  }

  String _value(DartType type, String variable, DartObject? defaultValue) {
    final value = _cast(type, variable);
    if (defaultValue?.isNull != false) return value;
    return '$variable == null ? ${constantToString(defaultValue!)} : $value';
  }

  String _cast(DartType type, String variable) {
    final suffix = _suffixFromType(type);
    if (hiveListChecker.isAssignableFromType(type)) {
      return '($variable as HiveList$suffix)$suffix.castHiveList()';
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
      return '$variable as ${_displayString(type)}';
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
    if (isMapOrIterable(arg) && !isUint8List(arg)) {
      var cast = '';
      // Using assignable because List? is not exactly List
      if (listChecker.isAssignableFromType(type)) {
        cast = '.toList()';
        // Using assignable because Set? is not exactly Set
      } else if (setChecker.isAssignableFromType(type)) {
        cast = '.toSet()';
      }
      // The suffix is not needed with nnbd on $cast becauuse it short circuits,
      // otherwise it is needed.
      final castWithSuffix = isLibraryNNBD(cls) ? cast : '$suffix$cast';
      return '$suffix.map((dynamic e)=> ${_cast(arg, 'e')})$castWithSuffix';
    } else {
      return '$suffix.cast<${_displayString(arg)}>()';
    }
  }

  String _castMap(DartType type) {
    final paramType = type as ParameterizedType;
    final arg1 = paramType.typeArguments[0];
    final arg2 = paramType.typeArguments[1];
    final suffix = _accessorSuffixFromType(type);
    if (isMapOrIterable(arg1) || isMapOrIterable(arg2)) {
      return '$suffix.map((dynamic k, dynamic v)=>'
          'MapEntry(${_cast(arg1, 'k')},${_cast(arg2, 'v')}))';
    } else {
      return '$suffix.cast<${_displayString(arg1)}, '
          '${_displayString(arg2)}>()';
    }
  }

  @override
  String buildWrite() {
    final code = StringBuffer();
    code.writeln('writer');
    code.writeln('..writeByte(${getters.length})');
    for (final field in getters) {
      final value = _convertIterable(field.type, 'obj.${field.name}');
      code.writeln('''
      ..writeByte(${field.index})
      ..write($value)''');
    }
    code.writeln(';');

    return code.toString();
  }

  String _convertIterable(DartType type, String accessor) {
    if (listChecker.isAssignableFromType(type)) {
      return accessor;
    } else
    // Using assignable because Set? and Iterable? are not exactly Set and
    // Iterable
    if (setChecker.isAssignableFromType(type) ||
        iterableChecker.isAssignableFromType(type)) {
      final suffix = _accessorSuffixFromType(type);
      return '$accessor$suffix.toList()';
    } else {
      return accessor;
    }
  }
}

extension _FirstOrNullWhere<T> on Iterable<T> {
  T? firstOrNullWhere(bool Function(T) predicate) {
    for (final it in this) {
      if (predicate(it)) {
        return it;
      }
    }
    return null;
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
  if (type.nullabilitySuffix == NullabilitySuffix.star) {
    return '';
  }
  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    return '?';
  }
  return '';
}

String _displayString(DartType e) {
  final suffix = _suffixFromType(e);
  // TODO: Update when Flutter supports analyser 6.5.0
  // ignore: deprecated_member_use
  return '${e.getDisplayString(withNullability: false)}$suffix';
}
