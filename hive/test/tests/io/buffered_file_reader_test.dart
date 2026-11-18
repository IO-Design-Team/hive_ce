@TestOn('vm')
library;

import 'package:hive_ce/src/io/buffered_file_reader.dart';
import 'package:test/test.dart';

import '../common.dart';

Future<BufferedFileReader> openReader(
  List<int> bytes, [
  int chunkSize = BufferedFileReader.defaultChunkSize,
]) async {
  final file = await getTempFile(bytes);
  final raf = await file.open();
  return BufferedFileReader(raf, chunkSize);
}

void main() {
  group('BufferedFileReader', () {
    test('constructor creates buffer with correct size', () async {
      var reader = await openReader([]);
      expect(reader.buffer.length, BufferedFileReader.defaultChunkSize);
      await reader.file.close();

      reader = await openReader([], 10);
      expect(reader.buffer.length, 10);
      await reader.file.close();
    });

    group('.skip()', () {
      test('increases offset', () async {
        final reader = await openReader([1, 2, 3, 4, 5]);
        await reader.loadBytes(5);
        expect(reader.remainingInBuffer, 5);
        expect(reader.offset, 0);

        reader.skip(2);
        expect(reader.remainingInBuffer, 3);
        expect(reader.offset, 2);

        reader.skip(3);
        expect(reader.remainingInBuffer, 0);
        expect(reader.offset, 5);

        await reader.file.close();
      });

      test('fails if not enough bytes available', () async {
        final reader = await openReader([1, 2, 3]);
        await reader.loadBytes(5);
        expect(reader.remainingInBuffer, 3);
        expect(reader.offset, 0);

        expect(() => reader.skip(4), throwsA(anything));

        await reader.file.close();
      });
    });

    group('.skipAhead()', () {
      test('discards buffered bytes and skips the rest of the file', () async {
        final reader = await openReader(List.generate(20, (i) => i), 8);
        expect(await reader.loadBytes(4, maxRead: 4), 4);
        expect(reader.file.positionSync(), 4);

        await reader.skipAhead(10);
        expect(reader.offset, 10);
        expect(reader.remainingInBuffer, 0);
        expect(reader.file.positionSync(), 10);

        expect(await reader.loadBytes(4, maxRead: 4), 4);
        expect(reader.viewBytes(4), [10, 11, 12, 13]);
        expect(reader.file.positionSync(), 14);

        await reader.file.close();
      });

      test('stays inside the buffer when it already has the bytes', () async {
        final reader = await openReader(List.generate(10, (i) => i), 8);
        await reader.loadBytes(8);
        expect(reader.file.positionSync(), 8);

        await reader.skipAhead(3);
        expect(reader.offset, 3);
        expect(reader.file.positionSync(), 8);
        expect(reader.viewBytes(2), [3, 4]);

        await reader.file.close();
      });
    });

    group('.viewBytes()', () {
      test('returns a view with the requested size', () async {
        final reader = await openReader([1, 2, 3, 4, 5]);
        await reader.loadBytes(5);
        expect(reader.offset, 0);

        expect(reader.viewBytes(2), [1, 2]);
        expect(reader.offset, 2);

        expect(reader.viewBytes(3), [3, 4, 5]);
        expect(reader.offset, 5);

        await reader.file.close();
      });

      test('fails if not enough bytes available', () async {
        final reader = await openReader([1, 2, 3, 4, 5]);
        await reader.loadBytes(5);

        expect(() => reader.viewBytes(6), throwsA(anything));

        await reader.file.close();
      });
    });

    group('.loadBytes()', () {
      test('returns remaining bytes if enough bytes available', () async {
        final reader = await openReader([1, 2, 3, 4, 5], 3);
        expect(await reader.loadBytes(3), 3);
        expect(await reader.loadBytes(2), 3);

        expect(reader.viewBytes(2), [1, 2]);
        expect(reader.viewBytes(1), [3]);

        await reader.file.close();
      });

      test('increases the buffer if it is too small', () async {
        final reader = await openReader([1, 2, 3, 4, 5], 2);
        await reader.loadBytes(2);
        expect(reader.viewBytes(2), [1, 2]);

        expect(await reader.loadBytes(3), 3);
        expect(reader.viewBytes(3), [3, 4, 5]);

        await reader.file.close();
      });

      test('copies unused bytes', () async {
        final reader = await openReader([1, 2, 3, 4, 5, 6, 7], 3);
        await reader.loadBytes(3);
        expect(reader.viewBytes(1), [1]);

        expect(await reader.loadBytes(1), 2);
        expect(await reader.loadBytes(3), 3);
        expect(reader.viewBytes(2), [2, 3]);
        expect(await reader.loadBytes(5), 4);
        expect(reader.viewBytes(3), [4, 5, 6]);

        await reader.file.close();
      });

      test('maxRead limits how many new bytes are read', () async {
        final reader = await openReader(List.generate(20, (i) => i), 10);
        expect(await reader.loadBytes(4, maxRead: 4), 4);
        expect(reader.file.positionSync(), 4);
        expect(reader.viewBytes(4), [0, 1, 2, 3]);

        expect(await reader.loadBytes(6, maxRead: 2), 2);
        expect(reader.file.positionSync(), 6);
        expect(reader.viewBytes(2), [4, 5]);

        await reader.file.close();
      });
    });
  });
}
