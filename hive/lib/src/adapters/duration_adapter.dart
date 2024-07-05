import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';

/// Adapter for Duration
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final typeId = FrameValueType.duration;

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
