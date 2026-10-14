@TestOn('vm')
library;

import 'dart:io';

import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

void main() {
  test('unawaited put is lost on exit unless Hive.flush completes', () async {
    expect(await _valueAfterExit('lose'), isNull);
    expect(await _valueAfterExit('flush'), 'David');
  });
}

Future<String?> _valueAfterExit(String mode) async {
  final directory = await Directory.systemTemp.createTemp('hive_flush_');
  try {
    final result = await Process.run(Platform.resolvedExecutable, [
      'test/integration/flush_before_exit.dart',
      directory.path,
      mode,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final hive = HiveImpl();
    hive.init(directory.path);
    final box = await hive.openBox<String>('box');
    final value = box.get('name');
    await hive.close();
    return value;
  } finally {
    await directory.delete(recursive: true);
  }
}
