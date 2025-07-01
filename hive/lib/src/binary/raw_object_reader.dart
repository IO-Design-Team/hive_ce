// This is internal usage
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:typed_data';

import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/hive_error.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/schema/hive_schema.dart';

/// A binary reader that reads raw objects
class RawObjectReader extends BinaryReaderImpl {
  final HiveSchema _schema;

  /// Constructor
  RawObjectReader(this._schema, Uint8List buffer)
      : super(buffer, TypeRegistryImpl());

  @override
  dynamic read([int? typeId]) {
    typeId ??= readTypeId();
    if (typeId < 32) {
      // This is a built in type
      return super.read(typeId);
    }

    final type = _schema.types.entries
        .where((e) =>
            TypeRegistryImpl.calculateTypeId(e.value.typeId, internal: false) ==
            typeId)
        .firstOrNull;
    if (type == null) {
      throw HiveError('Unknown type ID: $typeId');
    }

    MapEntry<String, HiveSchemaField>? getField(int index) {
      return type.value.fields.entries
          .where((e) => e.value.index == index)
          .firstOrNull;
    }

    switch (type.value.kind) {
      case TypeKind.objectKind:
        final length = readByte();
        final fields = List<RawField>.filled(length, RawField('', null));
        for (var i = 0; i < length; i++) {
          // Consume the field index
          final index = readByte();
          final field = getField(index);

          if (field == null) {
            throw HiveError('Unknown field index: ${type.key}[$index]');
          }
          fields[i] = RawField(field.key, read());
        }
        return RawObject(type.key, fields);
      case TypeKind.enumKind:
        final index = readByte();
        final field = getField(index);

        if (field == null) {
          throw HiveError('Unknown enum index: ${type.key}[$index]');
        }
        return RawEnum(type.key, field.key);
      case TypeKind.unknownKind:
        throw HiveError('Unknown type kind: ${type.key}');
    }
  }
}

/// A raw type read from the buffer
abstract class RawType {
  /// The type name
  final String name;

  /// Constructor
  const RawType(this.name);
}

/// A raw enum value read from the buffer
class RawEnum extends RawType {
  /// The enum value
  final String value;

  /// Constructor
  const RawEnum(super.name, this.value);

  @override
  String toString() => '$name.$value';
}

/// A raw custom object read from the buffer
class RawObject extends RawType {
  /// The fields of the object
  final List<RawField> fields;

  /// Constructor
  const RawObject(super.name, this.fields);

  @override
  String toString() => '$name($fields)';
}

/// A raw field of a custom object
class RawField {
  /// THe name of the field
  final String name;

  /// The value of the field
  final Object? value;

  /// Constructor
  const RawField(this.name, this.value);

  @override
  String toString() => '$name: $value';
}
