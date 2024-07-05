import 'package:hive_ce/hive.dart';

/// Adapter for DateTime
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final typeId = 16;

  @override
  Duration read(BinaryReader reader) {
    final millis = reader.readInt();
    return Duration(milliseconds: millis);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMilliseconds);
  }
}
