import 'package:hive_ce_flutter/adapters.dart'
    hide IsolatedHive, IsolateNameServer;
import 'package:hive_ce_flutter/src/isolate/isolate_name_server.dart';
import 'package:hive_ce_flutter/src/type_registry_extensions.dart';
import 'package:hive_ce_flutter/src/wrapper/path_provider.dart';

/// Flutter extensions for [IsolatedHiveInterface]
extension IsolatedHiveX on IsolatedHiveInterface {
  /// Initializes [IsolatedHive] with the path from
  /// [getApplicationDocumentsDirectory] and the Flutter [IsolateNameServer]
  ///
  /// You can provide a [subDirectory] where the boxes should be stored.
  /// Relative paths are resolved against [getApplicationDocumentsDirectory].
  /// Absolute paths are used as-is.
  ///
  /// Also registers the flutter type adapters
  ///
  /// If [useMaterialUi] is true, [MaterialUiTimeOfDayAdapter] is registered
  /// instead of [TimeOfDayAdapter]
  Future<void> initFlutter({
    String? subDirectory,
    int? colorAdapterTypeId,
    int? timeOfDayAdapterTypeId,
    bool useMaterialUi = false,
  }) async {
    await initFlutterCommon(
      dir: subDirectory,
      initHive: (path) =>
          init(path, isolateNameServer: const IsolateNameServer()),
      colorAdapterTypeId: colorAdapterTypeId,
      timeOfDayAdapterTypeId: timeOfDayAdapterTypeId,
      useMaterialUi: useMaterialUi,
    );
  }
}
