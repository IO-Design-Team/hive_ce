import 'package:hive_ce/src/util/logger.dart';
import 'package:test/test.dart';

import 'print_utils.dart';

void main() {
  setUp(() {
    Logger.level = LoggerLevel.verbose;
  });

  test('verbose', () async {
    final output1 = await captureOutput(() => Logger.v('verbose')).first;
    expect(output1, contains('verbose'));

    Logger.level = LoggerLevel.debug;
    final output2 = await captureOutput(() => Logger.v('verbose')).toList();
    expect(output2, isEmpty);
  });

  test('debug', () async {
    final output1 = await captureOutput(() => Logger.d('debug')).first;
    expect(output1, contains('debug'));

    Logger.level = LoggerLevel.info;
    final output2 = await captureOutput(() => Logger.d('debug')).toList();
    expect(output2, isEmpty);
  });

  test('info', () async {
    final output1 = await captureOutput(() => Logger.i('info')).first;
    expect(output1, contains('info'));

    Logger.level = LoggerLevel.warn;
    final output2 = await captureOutput(() => Logger.i('info')).toList();
    expect(output2, isEmpty);
  });

  test('warn', () async {
    final output1 = await captureOutput(() => Logger.w('warn')).first;
    expect(output1, contains('warn'));

    Logger.level = LoggerLevel.error;
    final output2 = await captureOutput(() => Logger.w('warn')).toList();
    expect(output2, isEmpty);
  });

  test('error', () async {
    final output1 = await captureOutput(() => Logger.e('error')).first;
    expect(output1, contains('error'));
  });

  test('wtf', () async {
    final output1 = await captureOutput(() => Logger.wtf('wtf')).first;
    expect(output1, contains('wtf'));
  });
}
