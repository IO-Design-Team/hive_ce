@TestOn('vm')
library;

import 'package:hive_ce/src/io/buffered_file_writer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('BufferedFileWriter', () {
    test('.write()', () async {
      final file = MockRandomAccessFile();
      final writer = BufferedFileWriter(file, 10);

      await writer.write([1, 2, 3, 4, 5, 6]);
      await writer.write([7, 8, 9]);
      verifyZeroInteractions(file);

      when(() => file.writeFrom(any())).thenAnswer((i) => Future.value(file));
      await writer.write([10]);
      verify(() => file.writeFrom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

      reset(file);
      await writer.flush();
      verifyZeroInteractions(file);

      when(() => file.writeFrom(any())).thenAnswer((i) => Future.value(file));
      await writer.write([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
      verify(() => file.writeFrom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]));
    });

    test('flush()', () async {
      final file = MockRandomAccessFile();
      when(() => file.writeFrom(any())).thenAnswer((i) => Future.value(file));
      final writer = BufferedFileWriter(file, 10);

      await writer.flush();
      verifyZeroInteractions(file);

      await writer.write([1, 2, 3]);
      await writer.flush();
      verify(() => file.writeFrom([1, 2, 3]));

      await writer.flush();
      verifyNoMoreInteractions(file);
    });
  });
}
