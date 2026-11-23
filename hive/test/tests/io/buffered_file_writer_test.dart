@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/src/io/buffered_file_writer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../common.dart';
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

    test('flushes buffered bytes before overflow and oversized writes',
        () async {
      final file = MockRandomAccessFile();
      final written = <List<int>>[];
      when(() => file.writeFrom(any())).thenAnswer((invocation) async {
        final bytes = invocation.positionalArguments.first as List<int>;
        written.add(List<int>.from(bytes));
        return file;
      });
      final writer = BufferedFileWriter(file, 10);

      await writer.write([1, 2, 3, 4, 5, 6]);
      expect(written, isEmpty);

      await writer.write([7, 8, 9, 10, 11]);
      expect(written, [
        [1, 2, 3, 4, 5, 6],
      ]);

      await writer.write([12, 13, 14, 15, 16]);
      expect(written, [
        [1, 2, 3, 4, 5, 6],
        [7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      ]);

      await writer.write([17, 18]);
      expect(written, hasLength(2));

      await writer.write([19, 20, 21, 22, 23, 24, 25, 26, 27, 28]);
      expect(written, [
        [1, 2, 3, 4, 5, 6],
        [7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
        [17, 18],
        [19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
      ]);

      await writer.write([29, 30, 31]);
      expect(written, hasLength(4));

      await writer.write([32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43]);
      expect(written, [
        [1, 2, 3, 4, 5, 6],
        [7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
        [17, 18],
        [19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
        [29, 30, 31],
        [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43],
      ]);

      await writer.flush();
      expect(written, hasLength(6));
    });

    test('writes multi-chunk sequence accurately to a real file', () async {
      final file = await getTempFile();
      try {
        final raf = await file.open(mode: FileMode.write);
        try {
          final writer = BufferedFileWriter(raf, 8);

          await writer.write([]);
          await writer.write([1, 2, 3]);
          await writer.write([]);
          await writer.write([4, 5, 6, 7, 8]);
          await writer.write([9, 10, 11, 12, 13]);
          await writer.write([14, 15, 16, 17]);
          await writer.write([18, 19, 20, 21, 22, 23, 24, 25]);
          await writer.write([26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]);
          await writer.write([37, 38]);
          await writer.write([39, 40, 41, 42, 43, 44, 45, 46, 47, 48]);

          final reusableChunk = Uint8List.fromList([49, 50, 51]);
          await writer.write(reusableChunk);
          reusableChunk.fillRange(0, 3, 0);

          await writer.write([]);
          await writer.flush();
        } finally {
          await raf.close();
        }

        expect(
          await file.readAsBytes(),
          List<int>.generate(51, (i) => i + 1),
        );
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
  });
}
