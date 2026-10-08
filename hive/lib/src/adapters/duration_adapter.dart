import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/adapters/date_time_adapter.dart';
import 'package:hive_ce/src/binary/frame.dart';

/// Adapter for Duration
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final typeId = FrameValueType.duration;

  @override
  Duration read(BinaryReader reader) {
    final value = reader.readDouble();
    final millis = value.truncate();
    return Duration(
      milliseconds: millis,
      microseconds: ((value - millis) * 1000).round(),
    );
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    final millis = obj.inMilliseconds;
    final fraction = millis.abs() < maxMicrosecondPrecisionMillis
        ? obj.inMicroseconds.remainder(1000) / 1000
        : 0.0;
    writer.writeDouble(millis + fraction);
  }
}
