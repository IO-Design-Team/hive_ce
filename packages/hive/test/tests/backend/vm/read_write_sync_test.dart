import 'package:hive_ce/src/backend/vm/read_write_sync.dart';
import 'package:test/test.dart';

Future _asyncRead(
  ReadWriteSync rw,
  int id,
  List<String> history, {
  bool? throwError = false,
}) {
  return rw.syncRead(() async {
    history.add('startread$id');
    await Future.delayed(Duration(milliseconds: 10));
    if (throwError!) {
      throw 'error$id';
    }
    history.add('stopread$id');
  });
}

Future _asyncWrite(
  ReadWriteSync rw,
  int id,
  List<String> history, {
  bool? throwError = false,
}) {
  return rw.syncWrite(() async {
    history.add('startwrite$id');
    await Future.delayed(Duration(milliseconds: 10));
    if (throwError!) {
      throw 'error$id';
    }
    history.add('stopwrite$id');
  });
}

Future _asyncReadWrite(
  ReadWriteSync rw,
  int id,
  List<String> history, {
  bool? throwError = false,
}) {
  return rw.syncReadWrite(() async {
    history.add('startreadwrite$id');
    await Future.delayed(Duration(milliseconds: 10));
    if (throwError!) {
      throw 'error$id';
    }
    history.add('stopreadwrite$id');
  });
}

typedef _Operation = Future Function(
  ReadWriteSync rw,
  int id,
  List<String> history, {
  bool? throwError,
});

Future _asyncOperation(
  ReadWriteSync rw,
  _Operation operation,
  int id,
  List<String> history, {
  bool throwError = false,
}) async {
  history.add('before$id');
  try {
    await operation(rw, id, history, throwError: throwError);
  } catch (e) {
    history.add('$e');
  }
  history.add('after$id');
}

void main() {
  group('ReadWriteSync', () {
    group('.syncRead()', () {
      test('runs in sequence with other read operations', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncRead, 0, history);
        final r2 = _asyncOperation(rw, _asyncRead, 1, history);
        final r3 = _asyncOperation(rw, _asyncRead, 2, history);
        await Future.wait([r1, r2, r3]);

        expect(history, [
          //
          'before0', 'before1', 'before2',
          'startread0', 'stopread0', 'after0',
          'startread1', 'stopread1', 'after1',
          'startread2', 'stopread2', 'after2',
        ]);
      });

      test('runs parallel to write operations', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncRead, 0, history);
        final r2 = _asyncOperation(rw, _asyncWrite, 1, history);
        await Future.wait([r1, r2]);

        expect(history[0], 'before0');
        expect(history[1], 'before1');
        expect(history.indexOf('stopread0') + 1, history.indexOf('after0'));
        expect(history.indexOf('stopwrite1') + 1, history.indexOf('after1'));
      });

      test('handles errors', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncRead, 0, history);
        final r2 =
            _asyncOperation(rw, _asyncRead, 1, history, throwError: true);
        final r3 = _asyncOperation(rw, _asyncRead, 2, history);
        await Future.wait([r1, r2, r3]);

        expect(history, [
          //
          'before0', 'before1', 'before2',
          'startread0', 'stopread0', 'after0',
          'startread1', 'error1', 'after1',
          'startread2', 'stopread2', 'after2',
        ]);
      });
    });

    group('.syncWrite()', () {
      test('runs in sequence with other write operations', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncWrite, 0, history);
        final r2 = _asyncOperation(rw, _asyncWrite, 1, history);
        final r3 = _asyncOperation(rw, _asyncWrite, 2, history);
        await Future.wait([r1, r2, r3]);

        expect(history, [
          //
          'before0', 'before1', 'before2',
          'startwrite0', 'stopwrite0', 'after0',
          'startwrite1', 'stopwrite1', 'after1',
          'startwrite2', 'stopwrite2', 'after2',
        ]);
      });

      test('runs parallel to read operations', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncWrite, 0, history);
        final r2 = _asyncOperation(rw, _asyncRead, 1, history);
        await Future.wait([r1, r2]);

        expect(history[0], 'before0');
        expect(history[1], 'before1');
        expect(history.indexOf('stopwrite0') + 1, history.indexOf('after0'));
        expect(history.indexOf('stopread1') + 1, history.indexOf('after1'));
      });

      test('handles errors', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncWrite, 0, history);
        final r2 =
            _asyncOperation(rw, _asyncWrite, 1, history, throwError: true);
        final r3 = _asyncOperation(rw, _asyncWrite, 2, history);
        await Future.wait([r1, r2, r3]);

        expect(history, [
          //
          'before0', 'before1', 'before2',
          'startwrite0', 'stopwrite0', 'after0',
          'startwrite1', 'error1', 'after1',
          'startwrite2', 'stopwrite2', 'after2',
        ]);
      });
    });

    group('.syncReadWrite()', () {
      test('runs in sequence with read and write operations', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncWrite, 0, history);
        final r2 = _asyncOperation(rw, _asyncRead, 1, history);
        final r3 = _asyncOperation(rw, _asyncReadWrite, 2, history);
        final r4 = _asyncOperation(rw, _asyncWrite, 3, history);
        final r5 = _asyncOperation(rw, _asyncReadWrite, 4, history);
        final r6 = _asyncOperation(rw, _asyncRead, 5, history);
        await Future.wait([r1, r2, r3, r4, r5, r6]);

        int index(String str) => history.indexOf(str);

        expect(index('stopwrite0') < index('startreadwrite2'), true);
        expect(index('after0') < index('startreadwrite2'), true);
        expect(index('stopread1') < index('startreadwrite2'), true);
        expect(index('after1') < index('startreadwrite2'), true);

        expect(index('after2') < index('startwrite3'), true);
        expect(index('after3') < index('startreadwrite4'), true);
        expect(index('after4') < index('startread5'), true);
      });

      test('handles errors', () async {
        final rw = ReadWriteSync();
        final history = <String>[];
        final r1 = _asyncOperation(rw, _asyncReadWrite, 0, history);
        final r2 =
            _asyncOperation(rw, _asyncReadWrite, 1, history, throwError: true);
        final r3 = _asyncOperation(rw, _asyncReadWrite, 2, history);
        await Future.wait([r1, r2, r3]);

        expect(history, [
          //
          'before0', 'before1', 'before2',
          'startreadwrite0', 'stopreadwrite0', 'after0',
          'startreadwrite1', 'error1', 'after1',
          'startreadwrite2', 'stopreadwrite2', 'after2',
        ]);
      });
    });
  });
}
