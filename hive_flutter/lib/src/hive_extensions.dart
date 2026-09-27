import 'package:hive_ce_flutter/adapters.dart';
import 'package:hive_ce_flutter/src/type_registry_extensions.dart';
import 'package:hive_ce_flutter/src/wrapper/path_provider.dart';

/// Flutter extensions for Hive.
extension HiveX on HiveInterface {
  /// Initializes Hive with the path from [getApplicationDocumentsDirectory].
  ///
  /// You can provide a [dir] where the boxes should be stored. Relative paths
  /// are resolved against [getApplicationDocumentsDirectory]. Absolute paths
  /// are used as-is.
  ///
  /// Also registers the flutter type adapters
  /// - [colorAdapterTypeId] - The type id for the color adapter (default: 200)
  /// - [timeOfDayAdapterTypeId] - The type id for the time of day adapter (default: 201)
  ///
  /// If [useMaterialUi] is true, [MaterialUiTimeOfDayAdapter] is registered
  /// instead of [TimeOfDayAdapter]
  Future<void> initFlutter([
    String? dir,
    HiveStorageBackendPreference backendPreference =
        HiveStorageBackendPreference.native,
    int? colorAdapterTypeId,
    int? timeOfDayAdapterTypeId,
    bool useMaterialUi = false,
  ]) async {
    await initFlutterCommon(
      dir: dir,
      initHive: (path) => init(path, backendPreference: backendPreference),
      colorAdapterTypeId: colorAdapterTypeId,
      timeOfDayAdapterTypeId: timeOfDayAdapterTypeId,
      useMaterialUi: useMaterialUi,
    );
  }
}
