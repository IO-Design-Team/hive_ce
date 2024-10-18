import 'dart:convert';

import 'package:glob/glob.dart';
import 'package:build/build.dart';
import 'dart:async';

/// Generate the HiveRegistrar for the entire project
class RegistrarBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    r'$lib$': ['hive/hive_registrar.hive.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final uris = <String>[];
    final adapters = <String>[];
    await for (final input
        in buildStep.findAssets(Glob('**/*.hive_registrar.info'))) {
      final content = await buildStep.readAsString(input);
      final data = jsonDecode(content) as Map<String, dynamic>;
      uris.addAll((data['uris'] as List).cast<String>());
      adapters.addAll((data['adapters'] as List).cast<String>());
    }

    // Do not create the registrar if there are no adapters
    if (adapters.isEmpty) return;

    adapters.sort();
    uris.sort();

    final buffer = StringBuffer("import 'package:hive_ce/hive.dart';\n");

    for (final uri in uris) {
      buffer.writeln("import '$uri';");
    }

    buffer.write('''

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
''');

    for (final adapter in adapters) {
      buffer.writeln('    registerAdapter($adapter());');
    }

    buffer.write('''
  }
}
''');

    await buildStep.writeAsString(
      AssetId(
        buildStep.inputId.package,
        'lib/hive/hive_registrar.hive.dart',
      ),
      buffer.toString(),
    );
  }
}
