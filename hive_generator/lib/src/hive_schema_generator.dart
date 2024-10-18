import 'dart:convert';

import 'package:glob/glob.dart';
import 'package:build/build.dart';
import 'dart:async';
import 'package:path/path.dart' as p;

/// Copy `.hive_schema.yaml` files from cache to source
class HiveSchemaGenerator implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    r'$lib$': ['hive_registrar.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final uris = <String>[];
    final adapters = <String>[];
    await for (final asset
        in buildStep.findAssets(Glob('**/*.hive_registrar.info'))) {
      final content = await buildStep.readAsString(asset);
      final data = jsonDecode(content) as Map<String, dynamic>;
      uris.add(data['uri'] as String);
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
        p.join('lib', 'hive_registrar.g.dart'),
      ),
      buffer.toString(),
    );
  }
}
