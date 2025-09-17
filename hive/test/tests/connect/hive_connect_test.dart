import 'package:hive_ce/src/connect/hive_connect.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:test/test.dart';

import '../../integration/isolate_test.dart';
import '../../util/is_browser/is_browser.dart';
import '../common.dart';

void main() {
  group('HiveConnect', () {
    Future<HiveImpl> initHive() async {
      final hive = HiveImpl();
      addTearDown(hive.close);

      final dir = isBrowser ? null : await getTempDir();
      hive.init(dir?.path);
      return hive;
    }

    Future<IsolatedHiveImpl> initIsolatedHive() async {
      final hive = IsolatedHiveImpl();
      addTearDown(hive.close);

      final dir = isBrowser ? null : await getTempDir();
      await hive.init(dir?.path, isolateNameServer: StubIns());
      return hive;
    }

    test('listBoxes', () async {
      expect(HiveConnect.listBoxes(null), []);

      final hive = await initHive();
      await hive.openBox('box');
      await hive.openLazyBox('lazybox');

      final isolatedHive = await initIsolatedHive();
      await isolatedHive.openBox('isolatedbox');
      await isolatedHive.openLazyBox('isolatedlazybox');

      expect(
        HiveConnect.listBoxes(null),
        [
          'box',
          'lazybox',
          'isolatedbox',
          'isolatedlazybox',
        ],
      );
    });

    test('getBoxFrames', () async {
      final hive = await initHive();
      final box = await hive.openBox('box');
      await box.put('key1', 'value1');
      await box.put('key2', 'value2');

      final frames = await HiveConnect.getBoxFrames({'name': 'box'});
      expect(frames, hasLength(2));
    });

    test('loadValue', () async {
      final hive = await initHive();
      final box = await hive.openBox('box');
      await box.put('key1', 'value1');

      final value = await HiveConnect.loadValue({'name': 'box', 'key': 'key1'});
      expect(value, isNotEmpty);
    });
  });
}
