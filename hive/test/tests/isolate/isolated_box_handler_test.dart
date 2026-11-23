@TestOn('vm')
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/src/isolate/handler/isolated_box_handler.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('IsolatedBoxHandler', () {
    late MockBox<dynamic> box;
    late IsolateConnection connection;
    late IsolatedBoxHandler handler;

    setUp(() {
      box = MockBox<dynamic>();
      when(() => box.name).thenReturn('test');
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      when(() => box.putAt(any(), any())).thenAnswer((_) async {});
      when(() => box.add(any())).thenAnswer((_) async => 7);
      when(() => box.putAll(any())).thenAnswer((_) async {});
      when(() => box.addAll(any())).thenAnswer((invocation) async {
        final values = invocation.positionalArguments.first as Iterable;
        return List<int>.generate(values.length, (i) => i);
      });

      connection = IsolateConnection(
        receive: const Stream.empty(),
        close: () {},
      );
      addTearDown(connection.close);
      handler = IsolatedBoxHandler(box, connection);
    });

    test('put unwraps raw Uint8List and TransferableTypedData', () async {
      final raw = Uint8List.fromList([1, 2, 3]);
      final large = Uint8List.fromList([4, 5, 6, 7]);

      await handler(
        IsolateMethodCall('box', 'put', {
          'name': 'test',
          'key': 'rawKey',
          'value': raw,
        }),
      );
      await handler(
        IsolateMethodCall('box', 'put', {
          'name': 'test',
          'key': 'ttdKey',
          'value': TransferableTypedData.fromList([large]),
        }),
      );

      final capturedRaw =
          verify(() => box.put('rawKey', captureAny())).captured.single;
      final capturedLarge =
          verify(() => box.put('ttdKey', captureAny())).captured.single;
      expect(capturedRaw, isA<Uint8List>());
      expect(capturedRaw, equals(raw));
      expect(capturedLarge, isA<Uint8List>());
      expect(capturedLarge, equals(large));
    });

    test('putAt unwraps raw Uint8List and TransferableTypedData', () async {
      final raw = Uint8List.fromList([10, 20]);
      final large = Uint8List.fromList([30, 40, 50]);

      await handler(
        IsolateMethodCall('box', 'putAt', {
          'name': 'test',
          'index': 0,
          'value': raw,
        }),
      );
      await handler(
        IsolateMethodCall('box', 'putAt', {
          'name': 'test',
          'index': 1,
          'value': TransferableTypedData.fromList([large]),
        }),
      );

      expect(
        verify(() => box.putAt(0, captureAny())).captured.single,
        equals(raw),
      );
      expect(
        verify(() => box.putAt(1, captureAny())).captured.single,
        equals(large),
      );
    });

    test('add unwraps raw Uint8List and TransferableTypedData', () async {
      final raw = Uint8List.fromList([8, 9]);
      final large = Uint8List.fromList([11, 12, 13]);

      final res1 = await handler(
        IsolateMethodCall('box', 'add', {
          'name': 'test',
          'value': raw,
        }),
      );
      final res2 = await handler(
        IsolateMethodCall('box', 'add', {
          'name': 'test',
          'value': TransferableTypedData.fromList([large]),
        }),
      );

      expect(res1, 7);
      expect(res2, 7);
      final captured = verify(() => box.add(captureAny())).captured;
      expect(captured[0], equals(raw));
      expect(captured[1], equals(large));
    });

    group('putAll', () {
      test('unpacks raw Uint8List batch', () async {
        final bytesA = Uint8List.fromList([1, 2]);
        final bytesB = Uint8List.fromList([3, 4, 5]);
        final packed = Uint8List.fromList([...bytesA, ...bytesB]);

        await handler(
          IsolateMethodCall('box', 'putAll', {
            'name': 'test',
            'keys': ['a', 'b'],
            'packedBytes': packed,
            'lengths': Int32List.fromList([bytesA.length, bytesB.length]),
          }),
        );

        final entries = verify(() => box.putAll(captureAny())).captured.single
            as Map<dynamic, dynamic>;
        expect(entries.keys, ['a', 'b']);
        expect(entries['a'], equals(bytesA));
        expect(entries['b'], equals(bytesB));
      });

      test('unpacks TransferableTypedData batch', () async {
        final bytesA = Uint8List.fromList([10, 20, 30]);
        final bytesB = Uint8List.fromList([40]);
        final packed = Uint8List.fromList([...bytesA, ...bytesB]);

        await handler(
          IsolateMethodCall('box', 'putAll', {
            'name': 'test',
            'keys': [1, 2],
            'packedBytes': TransferableTypedData.fromList([packed]),
            'lengths': Int32List.fromList([bytesA.length, bytesB.length]),
          }),
        );

        final entries = verify(() => box.putAll(captureAny())).captured.single
            as Map<dynamic, dynamic>;
        expect(entries.keys, [1, 2]);
        expect(entries[1], equals(bytesA));
        expect(entries[2], equals(bytesB));
      });

      test('handles empty packed batch', () async {
        await handler(
          IsolateMethodCall('box', 'putAll', {
            'name': 'test',
            'keys': <dynamic>[],
            'packedBytes': Uint8List(0),
            'lengths': Int32List(0),
          }),
        );

        final entries = verify(() => box.putAll(captureAny())).captured.single
            as Map<dynamic, dynamic>;
        expect(entries, isEmpty);
      });

      test('supports legacy entries argument', () async {
        final bytesA = Uint8List.fromList([6, 7]);
        final bytesB = Uint8List.fromList([8, 9]);

        await handler(
          IsolateMethodCall('box', 'putAll', {
            'name': 'test',
            'entries': {'a': bytesA, 'b': bytesB},
          }),
        );

        final entries = verify(() => box.putAll(captureAny())).captured.single
            as Map<dynamic, dynamic>;
        expect(entries['a'], equals(bytesA));
        expect(entries['b'], equals(bytesB));
      });
    });

    group('addAll', () {
      test('unpacks raw Uint8List batch', () async {
        final bytesA = Uint8List.fromList([1, 2]);
        final bytesB = Uint8List.fromList([3, 4, 5]);
        final packed = Uint8List.fromList([...bytesA, ...bytesB]);

        final result = await handler(
          IsolateMethodCall('box', 'addAll', {
            'name': 'test',
            'packedBytes': packed,
            'lengths': Int32List.fromList([bytesA.length, bytesB.length]),
          }),
        );

        expect(result, [0, 1]);
        final values =
            (verify(() => box.addAll(captureAny())).captured.single as Iterable)
                .toList();
        expect(values, [bytesA, bytesB]);
      });

      test('unpacks TransferableTypedData batch', () async {
        final bytesA = Uint8List.fromList([10, 20, 30]);
        final bytesB = Uint8List.fromList([40]);
        final packed = Uint8List.fromList([...bytesA, ...bytesB]);

        final result = await handler(
          IsolateMethodCall('box', 'addAll', {
            'name': 'test',
            'packedBytes': TransferableTypedData.fromList([packed]),
            'lengths': Int32List.fromList([bytesA.length, bytesB.length]),
          }),
        );

        expect(result, [0, 1]);
        final values =
            (verify(() => box.addAll(captureAny())).captured.single as Iterable)
                .toList();
        expect(values, [bytesA, bytesB]);
      });

      test('handles empty packed batch', () async {
        final result = await handler(
          IsolateMethodCall('box', 'addAll', {
            'name': 'test',
            'packedBytes': Uint8List(0),
            'lengths': Int32List(0),
          }),
        );

        expect(result, isEmpty);
        final values =
            (verify(() => box.addAll(captureAny())).captured.single as Iterable)
                .toList();
        expect(values, isEmpty);
      });

      test('supports legacy values argument', () async {
        final bytesA = Uint8List.fromList([6, 7]);
        final bytesB = Uint8List.fromList([8, 9]);

        final result = await handler(
          IsolateMethodCall('box', 'addAll', {
            'name': 'test',
            'values': [bytesA, bytesB],
          }),
        );

        expect(result, [0, 1]);
        final values =
            (verify(() => box.addAll(captureAny())).captured.single as Iterable)
                .toList();
        expect(values, [bytesA, bytesB]);
      });
    });
  });
}
