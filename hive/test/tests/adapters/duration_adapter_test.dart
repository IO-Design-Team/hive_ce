import 'package:hive_ce/src/adapters/duration_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('DurationAdapter', () {
    test('.read()', () {
      final duration = Duration(seconds: 30, microseconds: 7);
      final binaryReader = MockBinaryReader();
      when(binaryReader.readDouble).thenReturn(duration.inMilliseconds + 0.007);

      final duration2 = DurationAdapter().read(binaryReader);
      verify(binaryReader.readDouble);
      expect(duration2, duration);
    });

    test('.write()', () {
      final duration = Duration(seconds: 30, microseconds: 7);
      final binaryWriter = MockBinaryWriter();

      DurationAdapter().write(binaryWriter, duration);
      verify(() => binaryWriter.writeDouble(duration.inMilliseconds + 0.007));
    });
  });
}
