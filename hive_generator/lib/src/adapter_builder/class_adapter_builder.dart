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
import 'package:source_gen/source_gen.dart';

/// TODO: Document this!
class ClassAdapterBuilder extends AdapterBuilder {
  /// TODO: Document this!
  const ClassAdapterBuilder(
    super.cls,
    super.getters,
    super.setters,
  );

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

  /// [TypeChecker] for [ImmutableCollection].
  static final iCollectionChecker = const TypeChecker.typeNamedLiterally(
    'ImmutableCollection',
    inPackage: 'fast_immutable_collections',
  );

  /// [TypeChecker] for [IList].
  static final iListChecker = const TypeChecker.typeNamedLiterally(
    'IList',
    inPackage: 'fast_immutable_collections',
  );

  /// [TypeChecker] for [ISet].
  static final iSetChecker = const TypeChecker.typeNamedLiterally(
    'ISet',
    inPackage: 'fast_immutable_collections',
  );

  /// [TypeChecker] for [IMap].
  static final iMapChecker = const TypeChecker.typeNamedLiterally(
    'IMap',
    inPackage: 'fast_immutable_collections',
  );

  /// [TypeChecker] for [BuiltList], [BuiltSet], [BuiltMap].
  static final builtCollectionChecker =
      TypeChecker.any([builtListChecker, builtSetChecker, builtMapChecker]);

  /// [TypeChecker] for [BuiltList].
  static final builtListChecker = const TypeChecker.typeNamedLiterally(
    'BuiltList',
    inPackage: 'built_collection',
  );

  /// [TypeChecker] for [BuiltSet].
  static final builtSetChecker = const TypeChecker.typeNamedLiterally(
    'BuiltSet',
    inPackage: 'built_collection',
  );

  /// [TypeChecker] for [BuiltMap].
  static final builtMapChecker = const TypeChecker.typeNamedLiterally(
    'BuiltMap',
    inPackage: 'built_collection',
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
    final suffix = _suffixFromType(type);
    if (hiveListChecker.isAssignableFromType(type)) {
      return '($variable as HiveList$suffix)$suffix.castHiveList()';
    } else if (setChecker.isAssignableFromType(type) ||
        iSetChecker.isAssignableFromType(type) ||
        builtSetChecker.isAssignableFromType(type)) {
      return '($variable as Set$suffix)${_castIterable(type)}${_lockCollection(type)}';
    } else if (iterableChecker.isAssignableFromType(type) &&
        !isUint8List(type)) {
      return '($variable as List$suffix)${_castIterable(type)}${_lockCollection(type)}';
    } else if (mapChecker.isAssignableFromType(type) ||
        iMapChecker.isAssignableFromType(type) ||
        builtMapChecker.isAssignableFromType(type)) {
      return '($variable as Map$suffix)${_castMap(type)}${_lockCollection(type)}';
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
        mapChecker.isAssignableFromType(type) ||
        iMapChecker.isAssignableFromType(type) ||
        builtMapChecker.isAssignableFromType(type);
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
    if (isMapOrIterable(arg1) || isMapOrIterable(arg2)) {
      return '$suffix.map((dynamic k, dynamic v)=>'
          'MapEntry(${_cast(arg1, 'k')},${_cast(arg2, 'v')}))';
    } else {
      return '$suffix.cast<${arg1.getPrefixedDisplayString(cls.library)}, '
          '${arg2.getPrefixedDisplayString(cls.library)}>()';
    }
  }

  String _lockCollection(DartType type) {
    if (iCollectionChecker.isAssignableFromType(type)) {
      return '.lockUnsafe';
    } else if (builtCollectionChecker.isAssignableFromType(type)) {
      return '.build()';
    } else {
      return '';
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
      ..write(obj.${field.name}${_unlockNestedCollection(field.type)})''');
    }
    code.writeln(';');

    return code.toString();
  }

  String _unlockCollection(DartType type) {
    if (iCollectionChecker.isAssignableFromType(type)) {
      return '.unlockView';
    } else if (builtSetChecker.isAssignableFromType(type)) {
      return '.asSet()';
    } else if (builtListChecker.isAssignableFromType(type)) {
      return '.asList()';
    } else if (builtMapChecker.isAssignableFromType(type)) {
      return '.asMap()';
    } else {
      return '';
    }
  }

  String _unlockNestedCollection(DartType type) {
    if (iSetChecker.isAssignableFromType(type) ||
        iListChecker.isAssignableFromType(type) ||
        builtSetChecker.isAssignableFromType(type) ||
        builtListChecker.isAssignableFromType(type)) {
      final paramType = type as ParameterizedType;
      final arg = paramType.typeArguments[0];
      if (iSetChecker.isAssignableFromType(arg) ||
          builtSetChecker.isAssignableFromType(arg)) {
        return '.map((e) => e${_unlockNestedCollection(arg)}).toSet()';
      } else if (iListChecker.isAssignableFromType(arg) ||
          builtListChecker.isAssignableFromType(arg)) {
        return '.map((e) => e${_unlockNestedCollection(arg)}).toList()';
      } else {
        return _unlockCollection(type);
      }
    } else if (iMapChecker.isAssignableFromType(type) ||
        builtMapChecker.isAssignableFromType(type)) {
      final paramType = type as ParameterizedType;
      final arg1 = paramType.typeArguments[0];
      final arg2 = paramType.typeArguments[1];
      if (iCollectionChecker.isAssignableFromType(arg1) ||
          iCollectionChecker.isAssignableFromType(arg2) ||
          builtCollectionChecker.isAssignableFromType(arg1) ||
          builtCollectionChecker.isAssignableFromType(arg2)) {
        return '.map((k, v) => MapEntry(k${_unlockNestedCollection(arg1)}, v${_unlockNestedCollection(arg2)}))${_unlockCollection(type)}';
      } else {
        return _unlockCollection(type);
      }
    } else {
      return '';
    }
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
