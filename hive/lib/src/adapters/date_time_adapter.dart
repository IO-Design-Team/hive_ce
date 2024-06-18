import 'package:hive_ce/hive.dart';

/// Adapter for DateTime
class DateTimeAdapter<T extends DateTime> extends TypeAdapter<T> {
  @override
  final typeId = 16;

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

class DateTimeWithoutTZ extends DateTime {
  DateTimeWithoutTZ.fromMillisecondsSinceEpoch(super.millisecondsSinceEpoch)
      : super.fromMillisecondsSinceEpoch();
}

/// Alternative adapter for DateTime with time zone info
class DateTimeWithTimezoneAdapter extends TypeAdapter<DateTime> {
  @override
  final typeId = 18;

  @override
  DateTime read(BinaryReader reader) {
    final millis = reader.readInt();
    final isUtc = reader.readBool();
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc);
  }

  @override
  void write(BinaryWriter writer, DateTime obj) {
    writer.writeInt(obj.millisecondsSinceEpoch);
    writer.writeBool(obj.isUtc);
  }
}
