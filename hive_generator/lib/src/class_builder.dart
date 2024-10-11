import 'dart:typed_data';

import 'package:analyzer/dart/element/element.dart';
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

  /// [TypeChecker] for [HiveList].
  final hiveListChecker = const TypeChecker.fromRuntime(HiveList);

  /// [TypeChecker] for [List].
  final listChecker = const TypeChecker.fromRuntime(List);

  /// [TypeChecker] for [Map].
  final mapChecker = const TypeChecker.fromRuntime(Map);

  /// [TypeChecker] for [Set].
  final setChecker = const TypeChecker.fromRuntime(Set);

  /// [TypeChecker] for [Iterable].
  final iterableChecker = const TypeChecker.fromRuntime(Iterable);

  /// [TypeChecker] for [Uint8List].
  final uint8ListChecker = const TypeChecker.fromRuntime(Uint8List);

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
    final suffix = _suffixFromType(type);
    if (hiveListChecker.isAssignableFromType(type)) {
      return '($variable as HiveList$suffix)$suffix.castHiveList()';
    } else if (listChecker.isAssignableFromType(type) && !isUint8List(type)) {
      return '($variable as List$suffix)${_castIterable(type)}';
    } else if (setChecker.isAssignableFromType(type)) {
      return '($variable as Set$suffix)${_castIterable(type)}';
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
    if (isMapOrIterable(arg) && !isUint8List(arg)) {
      var cast = '';
      // Using assignable because List? is not exactly List
      if (listChecker.isAssignableFromType(type)) {
        cast = '.toList()';
        // Using assignable because Set? is not exactly Set
      } else if (setChecker.isAssignableFromType(type)) {
        cast = '.toSet()';
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
    if (isMapOrIterable(arg1) || isMapOrIterable(arg2)) {
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
    code.writeln('..writeByte(${getters.length})');
    for (final field in getters) {
      code.writeln('''
      ..writeByte(${field.index})
      ..write(obj.${field.name})''');
    }
    code.writeln(';');

    return code.toString();
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

    for (final import in currentLibrary.libraryImports) {
      for (final MapEntry(:key, :value)
          in import.namespace.definedNames.entries) {
        if (value == element) {
          return '$key${_suffixFromType(this)}';
        }
      }
    }

    return getDisplayString();
  }
}
