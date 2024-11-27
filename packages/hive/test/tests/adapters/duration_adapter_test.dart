import 'package:hive_ce/src/adapters/duration_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('DurationAdapter', () {
    test('.read()', () {
      final duration = Duration(seconds: 30);
      final binaryReader = MockBinaryReader();
      when(binaryReader.readInt).thenReturn(duration.inMilliseconds);

      final duration2 = DurationAdapter().read(binaryReader);
      verify(binaryReader.readInt);
      expect(duration2, duration);
    });

    test('.write()', () {
      final duration = Duration(seconds: 30);
      final binaryWriter = MockBinaryWriter();

      DurationAdapter().write(binaryWriter, duration);
      verify(() => binaryWriter.writeInt(duration.inMilliseconds));
    });
  });
}
