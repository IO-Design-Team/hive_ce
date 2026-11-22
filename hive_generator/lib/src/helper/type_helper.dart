import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/helper/source_helper.dart';
import 'package:source_gen/source_gen.dart';

/// TODO: Document this!
const kConstConstructors = true;

/// TODO: Document this!
String constantToString(
  DartObject? object, [
  List<String> typeInformation = const [],
  LibraryElement? library,
]) {
  if (object == null || object.isNull) return 'null';
  final reader = ConstantReader(object);
  return reader.isLiteral
      ? literalToString(object, typeInformation, library)
      : revivableToString(object, typeInformation, library);
}

/// TODO: Document this!
String revivableToString(
  DartObject? object,
  List<String> typeInformation, [
  LibraryElement? library,
]) =>
    reviveToString(
      ConstantReader(object).revive(),
      type: object?.type,
      library: library,
      typeInformation: [...typeInformation, '$object'],
    );

/// Formats a [Revivable] back into Dart source code inside [library].
String reviveToString(
  Revivable revivable, {
  DartType? type,
  LibraryElement? library,
  List<String> typeInformation = const [],
}) {
  if (revivable.source.fragment.isEmpty) {
    if (library != null) {
      final topLevelName = revivable.accessor.split('.').first;
      final prefix = getImportPrefixForUri(
        revivable.source,
        topLevelName,
        library,
      );
      if (prefix != null) return '$prefix.${revivable.accessor}';
    }
    return revivable.accessor;
  }

  final prefix = kConstConstructors ? 'const ' : '';
  final ctor = revivable.accessor.isEmpty ? '' : '.${revivable.accessor}';
  final typeName = library != null && type != null
      ? type.getPrefixedDisplayString(library)
      : revivable.source.fragment;
  final arguments = <String>[
    for (final arg in revivable.positionalArguments)
      constantToString(arg, typeInformation, library),
    for (final kv in revivable.namedArguments.entries)
      '${kv.key}: ${constantToString(kv.value, typeInformation, library)}',
  ];

  return '$prefix$typeName$ctor(${arguments.join(', ')})';
}

// The code below is based on code from https://github.com/google/json_serializable.dart/blob/df60c2a95c4c0054d6ab785849937d7f5ade39fe/json_serializable/lib/src/json_key_utils.dart#L43

/// TODO: Document this!
String literalToString(
  DartObject object,
  List<String> typeInformation, [
  LibraryElement? library,
]) {
  final reader = ConstantReader(object);

  String? badType;
  if (reader.isSymbol) {
    badType = 'Symbol';
  } else if (reader.isType) {
    badType = 'Type';
  } else if (object.type is FunctionType) {
    badType = 'Function';
  } else if (!reader.isLiteral) {
    final element = object.type?.element;
    if (element == null) throwUnsupported('Unable to determine type.');
    badType = element.displayName;
  }

  if (badType != null) {
    badType = typeInformation.followedBy([badType]).join(' > ');
    throwUnsupported('`defaultValue` is `$badType`, it must be a literal.');
  }

  if (reader.isDouble || reader.isInt || reader.isString || reader.isBool) {
    final value = reader.literalValue;

    if (value is String) return escapeDartString(value);

    if (value is double) {
      if (value.isNaN) {
        return 'double.nan';
      }

      if (value.isInfinite) {
        if (value.isNegative) {
          return 'double.negativeInfinity';
        }
        return 'double.infinity';
      }
    }

    if (value is bool || value is num) return value.toString();
  }

  if (reader.isList) {
    final listTypeInformation = [...typeInformation, 'List'];
    final listItems = reader.listValue
        .map((it) => constantToString(it, listTypeInformation, library))
        .join(', ');
    return '[$listItems]';
  }

  if (reader.isSet) {
    final setTypeInformation = [...typeInformation, 'Set'];
    final setItems = reader.setValue
        .map((it) => constantToString(it, setTypeInformation, library))
        .join(', ');
    return '{$setItems}';
  }

  if (reader.isMap) {
    final mapTypeInformation = [...typeInformation, 'Map'];
    final buffer = StringBuffer('{');

    var first = true;

    reader.mapValue.forEach((key, value) {
      if (first) {
        first = false;
      } else {
        buffer.writeln(',');
      }

      buffer
        ..write(constantToString(key, mapTypeInformation, library))
        ..write(': ')
        ..write(constantToString(value, mapTypeInformation, library));
    });

    buffer.write('}');

    return buffer.toString();
  }

  badType = typeInformation.followedBy(['$object']).join(' > ');
  throwUnsupported(
    'The provided value is not supported: $badType. '
    'This may be an error in package:hive_ce_generator. '
    'Please rerun your build with `--verbose` and file an issue.',
  );
}

/// TODO: Document this!
Never throwUnsupported(String message) =>
    throw InvalidGenerationSourceError('Error with `@HiveField`. $message');
