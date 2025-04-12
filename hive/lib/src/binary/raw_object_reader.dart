// This is internal usage
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:hive_ce/src/binary/binary_reader_impl.dart';

/// A binary reader that reads raw objects
class RawObjectReader extends BinaryReaderImpl {
  /// Constructor
  RawObjectReader(super.buffer, super.typeRegistry);

  @override
  dynamic read([int? typeId]) {
    typeId ??= readTypeId();
    if (typeId < 32) {
      // This is a built in type
      return super.read(typeId);
    }

    if (availableBytes == 1) {
      // This is a custom enum
      return RawEnum(typeId, readByte());
    }

    // This is a custom object
    final length = readByte();
    final fields = List<RawField>.filled(length, RawField(-1, null));
    for (var i = 0; i < length; i++) {
      fields[i] = RawField(readByte(), read());
    }
    return RawObject(typeId, fields);
  }
}

/// A raw type read from the buffer
abstract class RawType {
  /// The type ID
  final int typeId;

  /// Constructor
  const RawType(this.typeId);
}

/// A raw enum value read from the buffer
class RawEnum extends RawType {
  /// The index of the enum
  final int index;

  /// Constructor
  const RawEnum(super.typeId, this.index);
}

/// A raw custom object read from the buffer
class RawObject extends RawType {
  /// The fields of the object
  final List<RawField> fields;

  /// Constructor
  const RawObject(super.typeId, this.fields);
}

/// A raw field of a custom object
class RawField {
  /// The index of the field
  final int index;

  /// The value of the field
  final Object? value;

  /// Constructor
  const RawField(this.index, this.value);
}
