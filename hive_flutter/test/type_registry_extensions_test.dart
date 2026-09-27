import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce_flutter/src/type_registry_extensions.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:test/test.dart';

final _documentsPath = p.absolute('documents');

class _FakePathProviderPlatform extends PathProviderPlatform {
  var documentsPathCalls = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    documentsPathCalls++;
    return _documentsPath;
  }
}

void main() {
  late _FakePathProviderPlatform pathProvider;

  setUp(() {
    pathProvider = _FakePathProviderPlatform();
    PathProviderPlatform.instance = pathProvider;
  });

  Future<String?> initPath(String? dir) async {
    String? initPath;
    await TypeRegistryImpl().initFlutterCommon(
      dir: dir,
      initHive: (path) => initPath = path,
    );
    return initPath;
  }

  group('TypeRegistryX.initFlutterCommon()', () {
    test('uses the documents directory when dir is null', () async {
      expect(await initPath(null), _documentsPath);
      expect(pathProvider.documentsPathCalls, 1);
    });

    test('resolves a relative dir against the documents directory', () async {
      expect(await initPath('boxes'), p.join(_documentsPath, 'boxes'));
      expect(pathProvider.documentsPathCalls, 1);
    });

    test('uses an absolute dir as-is', () async {
      final dir = p.absolute('boxes');
      expect(await initPath(dir), dir);
      expect(pathProvider.documentsPathCalls, 0);
    });
  });
}
