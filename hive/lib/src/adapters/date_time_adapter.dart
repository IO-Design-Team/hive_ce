import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:meta/meta.dart';

/// Adapter for DateTime
class DateTimeAdapter<T extends DateTime> extends TypeAdapter<T> {
  @override
  final typeId = FrameValueType.dateTime;

  @override
  T read(BinaryReader reader) {
    final millis = reader.readDouble();
    return DateTimeWithoutTZ.fromMicrosecondsSinceEpoch(
      (millis * 1000).round(),
    ) as T;
  }

  @override
  void write(BinaryWriter writer, DateTime obj) {
    writer.writeDouble(obj.microsecondsSinceEpoch / 1000);
  }
}

/// TODO: Document this!
@immutable
class DateTimeWithoutTZ extends DateTime {
  /// TODO: Document this!
  DateTimeWithoutTZ.fromMillisecondsSinceEpoch(super.millisecondsSinceEpoch)
      : super.fromMillisecondsSinceEpoch();

  /// TODO: Document this!
  DateTimeWithoutTZ.fromMicrosecondsSinceEpoch(super.microsecondsSinceEpoch)
      : super.fromMicrosecondsSinceEpoch();
}

/// Alternative adapter for DateTime with time zone info
class DateTimeWithTimezoneAdapter extends TypeAdapter<DateTime> {
  @override
  final typeId = FrameValueType.dateTimeWithTimezone;

  @override
  DateTime read(BinaryReader reader) {
    final millis = reader.readDouble();
    final isUtc = reader.readBool();
    return DateTime.fromMicrosecondsSinceEpoch(
      (millis * 1000).round(),
      isUtc: isUtc,
    );
  }

  @override
  void write(BinaryWriter writer, DateTime obj) {
    writer.writeDouble(obj.microsecondsSinceEpoch / 1000);
    writer.writeBool(obj.isUtc);
  }
}
