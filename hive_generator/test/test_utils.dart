import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const fileExists = '';

/// Expect the given input generates the given output
///
/// About [output]
/// - An empty content string will result in checking for file existence only
void expectGeneration({
  required Map<String, String> input,
  required Map<String, String> output,
}) {
  final projectRoot = createTestProject(input);
  final result1 =
      Process.runSync('dart', ['pub', 'get'], workingDirectory: projectRoot);
  final result2 = Process.runSync(
    'dart',
    ['pub', 'run', 'build_runner', 'build'],
    workingDirectory: projectRoot,
  );

  for (final MapEntry(:key, :value) in output.entries) {
    final file = File(path.join(projectRoot, key));
    expect(file.existsSync(), true);

    // Do not check content if value is empty
    if (value.isNotEmpty) {
      final content = file.readAsStringSync();
      expect(content, value);
    }
  }
}

String createTestProject(Map<String, String> project) {
  final directory =
      Directory.systemTemp.createTempSync('hive_ce_generator_test');

  for (final MapEntry(:key, :value) in project.entries) {
    File(path.join(directory.path, key))
      ..createSync(recursive: true)
      ..writeAsStringSync(value);
  }
  return directory.path;
}

String get pubspec {
  final hivePath = path.absolute(path.current, '..', 'hive');
  final hiveGeneratorPath = path.absolute(path.current);

  return '''
name: hive_ce_generator_test

environment:
  sdk: ^3.0.0

dependencies:
  hive_ce: any

dev_dependencies:
  build_runner: any
  hive_ce_generator: any

dependency_overrides:
  hive_ce:
    path: $hivePath
  hive_ce_generator:
    path: $hiveGeneratorPath
''';
}
