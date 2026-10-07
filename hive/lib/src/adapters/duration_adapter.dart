import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';

/// Adapter for Duration
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final typeId = FrameValueType.duration;

  @override
  Duration read(BinaryReader reader) {
    final millis = reader.readDouble();
    return Duration(microseconds: (millis * 1000).round());
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeDouble(obj.inMicroseconds / 1000);
  }
}
