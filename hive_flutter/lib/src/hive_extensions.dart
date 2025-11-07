import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hive_ce_flutter/src/wrapper/path_provider.dart';
import 'package:hive_ce_flutter/src/wrapper/path.dart' as path_helper;

/// Flutter extensions for Hive.
extension HiveX on HiveInterface {
  /// Initializes Hive with the path from [getApplicationDocumentsDirectory].
  ///
  /// You can provide a [subDir] where the boxes should be stored.
  ///
  /// Also registers the flutter type adapters.
  Future<void> initFlutter([
    String? subDir,
    HiveStorageBackendPreference backendPreference =
        HiveStorageBackendPreference.native,
    int? colorAdapterTypeId,
    int? timeOfDayAdapterTypeId,
    bool obfuscateBoxNames = false,
  ]) async {
    WidgetsFlutterBinding.ensureInitialized();

    String? path;
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      path = path_helper.join(appDir.path, subDir);
    }

    init(
      path,
      backendPreference: backendPreference,
      obfuscateBoxNames: obfuscateBoxNames,
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
