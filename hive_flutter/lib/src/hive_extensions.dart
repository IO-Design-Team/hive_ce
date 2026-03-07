import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hive_ce_flutter/src/wrapper/path_provider.dart';
import 'package:hive_ce_flutter/src/wrapper/path.dart' as path_helper;

/// Flutter extensions for Hive.
extension HiveX on HiveInterface {
  /// Initializes Hive with the path from [getApplicationDocumentsDirectory], or as an absolute path.
  ///
  /// You can provide a [dir] where the boxes should be stored.
  ///
  /// Also registers the flutter type adapters
  /// - [colorAdapterTypeId] - The type id for the color adapter (default: 200)
  /// - [timeOfDayAdapterTypeId] - The type id for the time of day adapter (default: 201)
  Future<void> initFlutter([
    String? dir,
    HiveStorageBackendPreference backendPreference =
        HiveStorageBackendPreference.native,
    int? colorAdapterTypeId,
    int? timeOfDayAdapterTypeId,
  ]) async {
    WidgetsFlutterBinding.ensureInitialized();

    String? path;
    if (!kIsWeb) {
      // join accepts the latter arguments as nullable so it is safe
      // to consider it "relative" even in that case. If the user wants an
      // absolute path pointing to the base of a well-defined
      // path (including one with built-in dart support),
      // different from getApplicationDocumentsDirectory,
      // then they should pass that directory in.
      if (dir == null || path_helper.isRelative(dir)) {
        final appDir = await getApplicationDocumentsDirectory();
        path = path_helper.join(appDir.path, dir);
      } else {
        path = dir;
      }
    }

    init(
      path,
      backendPreference: backendPreference,
    );

    final colorAdapter = ColorAdapter(typeId: colorAdapterTypeId);
    if (!isAdapterRegistered(colorAdapter.typeId)) {
      registerAdapter(colorAdapter);
    }

    final timeOfDayAdapter = TimeOfDayAdapter(typeId: timeOfDayAdapterTypeId);
    if (!isAdapterRegistered(timeOfDayAdapter.typeId)) {
      registerAdapter(timeOfDayAdapter);
    }
  }
}
