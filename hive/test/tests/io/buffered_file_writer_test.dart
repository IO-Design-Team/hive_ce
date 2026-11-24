@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:hive_ce/src/io/buffered_file_writer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('BufferedFileWriter', () {
    test('.write()', () async {
      final file = MockRandomAccessFile();
      final writer = BufferedFileWriter(file, 10);

      await writer.write([]);
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

    test('flushes on overflow and copies buffered input', () async {
      final file = MockRandomAccessFile();
      final written = <List<int>>[];
      when(() => file.writeFrom(any())).thenAnswer((i) async {
        written.add(List<int>.from(i.positionalArguments.first as List<int>));
        return file;
      });
      final writer = BufferedFileWriter(file, 10);

      await writer.write([1, 2, 3, 4, 5, 6]);
      await writer.write([7, 8, 9, 10, 11]);
      await writer.write([12, 13, 14, 15, 16]);
      await writer.write([17, 18]);
      await writer.write([19, 20, 21, 22, 23, 24, 25, 26, 27, 28]);

      final input = Uint8List.fromList([29, 30, 31]);
      await writer.write(input);
      input.fillRange(0, 3, 0);
      await writer.flush();

      expect(
        written,
        [
          [1, 2, 3, 4, 5, 6],
          [7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
          [17, 18],
          [19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
          [29, 30, 31],
        ],
      );
    });
  });
}
