import 'dart:io';

import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const schemaComment = HiveSchema.comment;

const fileExists = true;
const fileDoesNotExist = false;

/// Expect the given input generates the given output
///
/// About [output]
/// - A [String] value will check if the file exists and contains the given
///   content
/// - [fileExists] will check if the file exists
/// - [fileDoesNotExist] will check if the file does not exist
///
/// Passing a value for [throws] will expect the build_runner console output to
/// contain the given string
void expectGeneration({
  required Map<String, String> input,
  Map<String, Object> output = const {},
  String? throws,
}) {
  final projectRoot = createTestProject(input);
  Process.runSync('dart', ['pub', 'get'], workingDirectory: projectRoot);
  final result = Process.runSync(
    'dart',
    ['pub', 'run', 'build_runner', 'build'],
    workingDirectory: projectRoot,
  );

  if (throws != null) {
    expect(result.exitCode, isNot(0));

    final lines = result.stdout.split('\n');
    for (final line in throws.split('\n')) {
      expect(lines, contains(contains(line)));
    }
    return;
  } else {
    expect(result.exitCode, 0);
  }

  for (final MapEntry(:key, :value) in output.entries) {
    final file = File(path.join(projectRoot, key));
    expect(file.existsSync(), value == true || value is String);

    if (value is! String) continue;
    expect(file.readAsStringSync(), value);
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

Map<String, String> pubspec({
  Set<String> dependencies = const {},
  Set<String> devDependencies = const {},
}) {
  final hivePath = path.absolute(path.current, '..', 'hive');
  final hiveGeneratorPath = path.absolute(path.current);

  return {
    'pubspec.yaml': '''
name: hive_ce_generator_test

environment:
  sdk: ^3.0.0

dependencies:
  hive_ce: any
  ${dependencies.join('\n  ')}

dev_dependencies:
  build_runner: any
  hive_ce_generator: any
  ${devDependencies.join('\n  ')}

dependency_overrides:
  hive_ce:
    path: $hivePath
  hive_ce_generator:
    path: $hiveGeneratorPath
''',
  };
}
