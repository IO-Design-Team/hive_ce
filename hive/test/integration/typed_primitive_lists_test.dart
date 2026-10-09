import 'dart:typed_data';

import 'package:test/test.dart';

import 'integration.dart';

Future<void> _check<T>(bool lazy, T value) async {
  var (hive, box) = await openBox<T>(lazy, type: TestType.normal);
  await box.put('values', value);

  box = await hive.reopenBox(box);

  final values = await box.get('values');
  expect(values, value);
  expect(values, isA<T>());
  await box.close();
}

void main() {
  for (final lazy in [false, true]) {
    group(lazy ? 'lazy box' : 'normal box', () {
      test('List<int>', () => _check<List<int>>(lazy, [1, 2]));

      test('List<double>', () => _check<List<double>>(lazy, [1.25, 2.5]));

      test('List<bool>', () => _check<List<bool>>(lazy, [true, false]));

      test('List<String>', () => _check<List<String>>(lazy, ['a', 'b']));

      test(
        'List<dynamic>',
        () => _check<List<dynamic>>(lazy, <dynamic>[1, 'a', true]),
      );

      test(
        'Uint8List',
        () => _check<Uint8List>(lazy, Uint8List.fromList([1, 2, 3])),
      );
    });
  }
}
