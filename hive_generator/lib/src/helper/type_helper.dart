import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

/// TODO: Document this!
const kConstConstructors = true;

/// TODO: Document this!
String constantToString(
  DartObject? object, [
  List<String> typeInformation = const [],
]) {
  if (object == null || object.isNull) return 'null';
  final reader = ConstantReader(object);
  return reader.isLiteral
      ? literalToString(object, typeInformation)
      : revivableToString(object, typeInformation);
}

/// TODO: Document this!
String revivableToString(DartObject? object, List<String> typeInformation) {
  final reader = ConstantReader(object);
  final revivable = reader.revive();

  if (revivable.source.fragment.isEmpty) {
    // Enums
    return revivable.accessor;
  } else {
    // Classes
    final nextTypeInformation = [...typeInformation, '$object'];
    final prefix = kConstConstructors ? 'const ' : '';
    final ctor = revivable.accessor.isEmpty ? '' : '.${revivable.accessor}';
    final arguments = <String>[
      for (final arg in revivable.positionalArguments)
        constantToString(arg, nextTypeInformation),
      for (final kv in revivable.namedArguments.entries)
        '${kv.key}: ${constantToString(kv.value, nextTypeInformation)}',
    ];

    return '$prefix${revivable.source.fragment}$ctor(${arguments.join(', ')})';
  }
}

// The code below is based on code from https://github.com/google/json_serializable.dart/blob/df60c2a95c4c0054d6ab785849937d7f5ade39fe/json_serializable/lib/src/json_key_utils.dart#L43

/// TODO: Document this!
String literalToString(DartObject object, List<String> typeInformation) {
  final reader = ConstantReader(object);

  String? badType;
  if (reader.isSymbol) {
    badType = 'Symbol';
  } else if (reader.isType) {
    badType = 'Type';
  } else if (object.type is FunctionType) {
    badType = 'Function';
  } else if (!reader.isLiteral) {
    badType = object.type!.element!.displayName;
  }

  if (badType != null) {
    badType = typeInformation.followedBy([badType]).join(' > ');
    throwUnsupported('`defaultValue` is `$badType`, it must be a literal.');
  }

  if (reader.isDouble || reader.isInt || reader.isString || reader.isBool) {
    final value = reader.literalValue;

    if (value is String) return _escapeDartString(value);

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
        .map((it) => constantToString(it, listTypeInformation))
        .join(', ');
    return '[$listItems]';
  }

  if (reader.isSet) {
    final setTypeInformation = [...typeInformation, 'Set'];
    final setItems = reader.setValue
        .map((it) => constantToString(it, setTypeInformation))
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
        ..write(constantToString(key, mapTypeInformation))
        ..write(': ')
        ..write(constantToString(value, mapTypeInformation));
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

/// Returns a quoted String literal for [value] that can be used in generated
/// Dart code.
String _escapeDartString(String value) {
  final escaped = StringBuffer("'");
  for (final unit in value.runes) {
    switch (unit) {
      case 0x27: // '
        escaped.write(r"\'");
      case 0x5C: // \
        escaped.write(r'\\');
      case 0x24: // $
        escaped.write(r'\$');
      case 0x08: // \b
        escaped.write(r'\b');
      case 0x09: // \t
        escaped.write(r'\t');
      case 0x0A: // \n
        escaped.write(r'\n');
      case 0x0B: // \v
        escaped.write(r'\v');
      case 0x0C: // \f
        escaped.write(r'\f');
      case 0x0D: // \r
        escaped.write(r'\r');
      default:
        if (unit < 0x20 || unit == 0x7F) {
          escaped.write(
            '\\x${unit.toRadixString(16).toUpperCase().padLeft(2, '0')}',
          );
        } else {
          escaped.writeCharCode(unit);
        }
    }
  }
  escaped.write("'");
  return escaped.toString();
}
