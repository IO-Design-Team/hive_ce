@TestOn('vm')
library;

import 'dart:io';

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

    test('flushes existing buffer before writing overflow chunks', () async {
      final file = MockRandomAccessFile();
      final written = <List<int>>[];
      when(() => file.writeFrom(any())).thenAnswer((i) {
        written.add(List<int>.from(i.positionalArguments[0] as List<int>));
        return Future.value(file);
      });
      final writer = BufferedFileWriter(file, 10);

      await writer.write([1, 2, 3, 4, 5, 6]);
      expect(written, isEmpty);

      await writer.write([7, 8, 9, 10, 11]);
      expect(written, [
        [1, 2, 3, 4, 5, 6],
      ]);

      await writer.write([12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]);
      expect(written, [
        [1, 2, 3, 4, 5, 6],
        [7, 8, 9, 10, 11],
        [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
      ]);

      await writer.flush();
      expect(written, hasLength(3));

      await writer.write([23, 24]);
      await writer.write([25, 26, 27, 28, 29, 30, 31, 32]);
      expect(written, hasLength(4));
      expect(written.last, [23, 24, 25, 26, 27, 28, 29, 30, 31, 32]);
    });

    test('writes multi-chunk sequence accurately to real file', () async {
      final file = await getTempFile();
      final raf = await file.open(mode: FileMode.write);
      final writer = BufferedFileWriter(raf, 16);

      final chunks = [
        <int>[],
        List.generate(5, (i) => i),
        List.generate(11, (i) => i + 10),
        List.generate(7, (i) => i + 30),
        List.generate(12, (i) => i + 40),
        List.generate(25, (i) => i + 60),
        List.generate(16, (i) => i + 90),
        List.generate(3, (i) => i + 110),
      ];
      for (final chunk in chunks) {
        await writer.write(chunk);
      }
      await writer.flush();
      await raf.close();

      final expected = chunks.expand((c) => c).toList();
      expect(await file.readAsBytes(), expected);
    });
  });
}
