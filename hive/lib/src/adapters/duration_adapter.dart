import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';

/// Beyond 2^43 milliseconds a double cannot hold microsecond precision
///
/// Unlike DateTime this must be enforced since on web the remainder of
/// [Duration.inMicroseconds] becomes rounding noise for long durations
const _maxMicrosecondPrecisionMillis = 8796093022208;

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
    final fraction = millis.abs() < _maxMicrosecondPrecisionMillis
        ? obj.inMicroseconds.remainder(1000) / 1000
        : 0.0;
    writer.writeDouble(millis + fraction);
  }
}
