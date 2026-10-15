import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:hive_ce_generator/hive_generator.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const schemaComment = HiveSchema.comment;

const fileExists = true;
const fileDoesNotExist = false;

const _testPackage = 'hive_ce_generator_test';
final _packageRef = RegExp('package:(\\w+)/');

/// Expect the given input generates the given output
///
/// About [output]
/// - A [String] value will check if the file exists and contains the given
///   content
/// - [fileExists] will check if the file exists
/// - [fileDoesNotExist] will check if the file does not exist
///
/// Passing a value for [throws] will expect the build errors or migrate output
/// to contain the given string
///
/// Setting [migrate] runs `hive_ce_generator:migrate` instead of the builders
Future<void> expectGeneration({
  required Map<String, String> input,
  Map<String, Object> output = const {},
  String? throws,
  bool migrate = false,
  bool debug = false,
}) async {
  final project = _prepare(input);
  if (migrate) {
    final result = Process.runSync(
      'dart',
      ['run', 'hive_ce_generator:migrate'],
      workingDirectory: project.path,
    );
    if (debug) print(result.stdout);
    _expect(
      project,
      output,
      throws,
      failed: result.exitCode != 0,
      messages: '${result.stdout}${result.stderr}',
    );
    return;
  }

  final readerWriter = TestReaderWriter(rootPackage: _testPackage);
  for (final MapEntry(:key, :value) in (await _dependencySources()).entries) {
    readerWriter.testing.writeString(makeAssetId(key), value);
  }

  final registrar = getRegistrarBuilder(const BuilderOptions({}));
  buildPackageRoot = project.path;
  TestBuilderResult? result;
  Object? error;
  try {
    result = await testBuilders(
      [
        getTypeAdapterBuilder(const BuilderOptions({})),
        getAdaptersBuilder(const BuilderOptions({})),
        getRegistrarIntermediateBuilder(const BuilderOptions({})),
        registrar,
      ],
      {
        for (final MapEntry(:key, :value) in input.entries)
          if (key != 'pubspec.yaml') '$_testPackage|$key': value,
      },
      rootPackage: _testPackage,
      packageConfig: await _packageConfig(),
      readerWriter: readerWriter,
      visibleOutputBuilders: {registrar},
    );
  } catch (e) {
    error = e;
  }

  final messages = [
    ...?result?.errors,
    if (error != null) '$error',
  ].join('\n');
  if (debug) print(messages);
  _expect(
    project,
    output,
    throws,
    failed: result?.succeeded != true,
    messages: messages,
    result: result,
  );
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

Directory? _project;
String? _pubspec;
PackageConfig? _config;
Map<String, String>? _sources;

Directory _prepare(Map<String, String> input) {
  final spec = input['pubspec.yaml'];
  if (spec == null) {
    throw ArgumentError('input must include pubspec.yaml');
  }

  var project = _project;
  if (project == null || _pubspec != spec) {
    project = Directory.systemTemp.createTempSync('hive_ce_generator_test_');
    File(path.join(project.path, 'pubspec.yaml')).writeAsStringSync(spec);
    final result = Process.runSync(
      'dart',
      ['pub', 'get'],
      workingDirectory: project.path,
    );
    if (result.exitCode != 0) {
      fail('${result.stdout}\n${result.stderr}');
    }
    _project = project;
    _pubspec = spec;
    _config = null;
    _sources = null;
  }

  for (final entity in project.listSync()) {
    final name = path.basename(entity.path);
    if (name == 'pubspec.yaml' ||
        name == 'pubspec.lock' ||
        name == '.dart_tool') {
      continue;
    }
    entity.deleteSync(recursive: true);
  }
  for (final MapEntry(:key, :value) in input.entries) {
    if (key == 'pubspec.yaml') continue;
    File(path.join(project.path, key))
      ..createSync(recursive: true)
      ..writeAsStringSync(value);
  }
  return project;
}

Future<PackageConfig> _packageConfig() async {
  final cached = _config;
  if (cached != null) return cached;
  final project = _project;
  if (project == null) fail('No test project');
  return _config = await loadPackageConfigUri(
    Uri.file(path.join(project.path, '.dart_tool', 'package_config.json')),
  );
}

Future<Map<String, String>> _dependencySources() async {
  final cached = _sources;
  if (cached != null) return cached;

  final config = await _packageConfig();
  final assets = <String, String>{};
  final pending = ['hive_ce'];
  final seen = <String>{_testPackage};
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!seen.add(name)) continue;
    final root = config[name]?.packageUriRoot;
    if (root == null) continue;
    final lib = Directory.fromUri(root);
    if (!lib.existsSync()) continue;
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative =
          path.relative(entity.path, from: lib.path).replaceAll(r'\', '/');
      final source = entity.readAsStringSync();
      assets['$name|lib/$relative'] = source;
      for (final match in _packageRef.allMatches(source)) {
        final imported = match.group(1);
        if (imported != null) pending.add(imported);
      }
    }
  }
  return _sources = assets;
}

void _expect(
  Directory project,
  Map<String, Object> output,
  String? throws, {
  required bool failed,
  required String messages,
  TestBuilderResult? result,
}) {
  if (throws != null) {
    expect(failed, isTrue);
    final lines = messages.split('\n');
    for (final line in throws.split('\n')) {
      expect(lines, contains(contains(line)));
    }
    return;
  }

  if (failed) fail(messages);
  for (final MapEntry(:key, :value) in output.entries) {
    final content = _read(project, key, result);
    expect(content != null, value == true || value is String, reason: key);
    if (value is! String) continue;
    expect(content, value);
  }
}

String? _read(Directory project, String key, TestBuilderResult? result) {
  final file = File(path.join(project.path, key));
  if (file.existsSync()) return file.readAsStringSync();
  if (result == null) return null;
  final asset = AssetId(_testPackage, key);
  if (!result.outputs.contains(asset)) return null;
  return result.readerWriter.testing.readString(asset);
}
