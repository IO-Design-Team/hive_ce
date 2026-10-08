import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:meta/meta.dart';

/// Beyond 2^43 milliseconds a double cannot hold microsecond precision
const maxMicrosecondPrecisionMillis = 8796093022208;

/// Adapter for DateTime
class DateTimeAdapter<T extends DateTime> extends TypeAdapter<T> {
  @override
  final typeId = FrameValueType.dateTime;

  @override
  T read(BinaryReader reader) {
    final millis = reader.readInt();
    return DateTimeWithoutTZ.fromMillisecondsSinceEpoch(millis) as T;
  }

  @override
  void write(BinaryWriter writer, DateTime obj) {
    writer.writeInt(obj.millisecondsSinceEpoch);
  }
}

/// TODO: Document this!
@immutable
class DateTimeWithoutTZ extends DateTime {
  /// TODO: Document this!
  DateTimeWithoutTZ.fromMillisecondsSinceEpoch(super.millisecondsSinceEpoch)
      : super.fromMillisecondsSinceEpoch();
}

/// Alternative adapter for DateTime with time zone info
class DateTimeWithTimezoneAdapter extends TypeAdapter<DateTime> {
  @override
  final typeId = FrameValueType.dateTimeWithTimezone;

  @override
  DateTime read(BinaryReader reader) {
    final value = reader.readDouble();
    final isUtc = reader.readBool();
    final millis = value.truncate();
    final micros = ((value - millis).abs() * 1000).round();
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc)
        .add(Duration(microseconds: micros));
  }

  @override
  void write(BinaryWriter writer, DateTime obj) {
    final millis = obj.millisecondsSinceEpoch;
    final fraction = millis.abs() < maxMicrosecondPrecisionMillis
        ? obj.microsecond / 1000
        : 0.0;
    // Away from zero so readers that truncate get millisecondsSinceEpoch
    writer.writeDouble(millis < 0 ? millis - fraction : millis + fraction);
    writer.writeBool(obj.isUtc);
  }
}
