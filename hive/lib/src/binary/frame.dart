import 'package:hive_ce/hive.dart';

/// Not part of public API
class Frame {
  /// The key
  final Object? key;

  /// The value
  final Object? value;

  /// If this frame is deleted
  final bool deleted;

  /// If this frame is lazy
  ///
  /// Lazy frames do not yet have a value
  final bool lazy;

  /// If this frame's value should be writtern to the disk with no transformation
  final bool verbatim;

  /// Not part of public API
  int? length;

  /// Not part of public API
  int offset = -1;

  /// Create a new frame
  Frame(this.key, this.value, {this.length, this.offset = -1})
      : lazy = false,
        deleted = false,
        verbatim = false {
    assert(assertKey(key));
  }

  /// Crate a deleted frame
  Frame.deleted(this.key, {this.length})
      : value = null,
        lazy = false,
        deleted = true,
        verbatim = false,
        offset = -1 {
    assert(assertKey(key));
  }

  /// Create a lazy frame
  Frame.lazy(this.key, {this.length, this.offset = -1})
      : value = null,
        lazy = true,
        verbatim = false,
        deleted = false {
    assert(assertKey(key));
  }

  /// Create a verbatim frame
  Frame.verbatim(this.key, this.value, {this.length, this.offset = -1})
      : lazy = false,
        deleted = false,
        verbatim = true {
    assert(assertKey(key));
  }

  /// Not part of public API
  static bool assertKey(dynamic key) {
    if (key is int) {
      if (key < 0 || key > 0xFFFFFFFF) {
        throw HiveError('Integer keys need to be in the range 0 - 0xFFFFFFFF');
      }
    } else if (key is String) {
      if (key.length > 0xFF) {
        throw HiveError('String keys need to be a max length of 255');
      }
    } else {
      throw HiveError('Keys need to be Strings or integers');
    }

    return true;
  }

  /// Not part of public API
  Frame toLazy() {
    if (deleted) return this;
    return Frame.lazy(
      key,
      length: length,
      offset: offset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is Frame) {
      return key == other.key &&
          value == other.value &&
          length == other.length &&
          deleted == other.deleted;
    } else {
      return false;
    }
  }

  @override
  String toString() {
    if (deleted) {
      return 'Frame.deleted(key: $key, length: $length)';
    } else if (lazy) {
      return 'Frame.lazy(key: $key, length: $length, offset: $offset)';
    } else {
      return 'Frame(key: $key, value: $value, '
          'length: $length, offset: $offset)';
    }
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      key.hashCode ^
      value.hashCode ^
      length.hashCode ^
      deleted.hashCode;
}

/// Possible Key types
final class FrameKeyType {
  FrameKeyType._();

  /// Integer key
  static const uintT = 0;

  /// String key
  static const utf8StringT = 1;
}

/// Possible value types
///
/// ! Only 32 type ids are reserved
final class FrameValueType {
  FrameValueType._();

  /// `null`
  static const nullT = 0;

  /// `int`
  static const intT = 1;

  /// `double`
  static const doubleT = 2;

  /// `bool`
  static const boolT = 3;

  /// `String`
  static const stringT = 4;

  /// `Uint8List`
  static const byteListT = 5;

  /// `List<int>`
  static const intListT = 6;

  /// `List<double>`
  static const doubleListT = 7;

  /// `List<bool>`
  static const boolListT = 8;

  /// `List<String>`
  static const stringListT = 9;

  /// `List<dynamic>`
  static const listT = 10;

  /// `Map<dynamic, dynamic>`
  static const mapT = 11;

  /// `List<HiveObject>`
  static const hiveListT = 12;

  /// `Set<int>`
  static const intSetT = 13;

  /// `Set<double>`
  static const doubleSetT = 14;

  /// `Set<String>`
  static const stringSetT = 15;

  /// `DateTimeAdapter`
  static const dateTime = 16;

  /// `BigIntAdapter`
  static const bigInt = 17;

  /// `DateTimeWithTimezoneAdapter`
  static const dateTimeWithTimezone = 18;

  /// `Set<dynamic>`
  static const setT = 19;

  /// `DurationAdapter`
  static const duration = 20;

  /// Type ID extension
  ///
  /// Informs Hive that the next 2 bytes contain the real type ID
  static const typeIdExtension = 21;
}
