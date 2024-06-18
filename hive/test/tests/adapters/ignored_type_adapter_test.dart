import 'package:hive_ce/src/adapters/ignored_type_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('IgnoredTypeAdapter', () {
    test('.read()', () {
      final binaryReader = MockBinaryReader();
      final value = IgnoredTypeAdapter().read(binaryReader);
      verifyNever(binaryReader.read);
      expect(value, null);
    });

    test('.write()', () {
      final binaryWriter = MockBinaryWriter();
      IgnoredTypeAdapter().write(binaryWriter, 42);
      verifyNever(() => binaryWriter.writeInt(42));
    });
  });
}
