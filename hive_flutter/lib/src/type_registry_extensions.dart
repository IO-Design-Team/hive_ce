import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hive_ce_flutter/src/wrapper/path_provider.dart';
import 'package:hive_ce_flutter/src/wrapper/path.dart' as path_helper;

/// Flutter extensions for [TypeRegistry]
extension TypeRegistryX on TypeRegistry {
  /// Common Flutter initialization code
  Future<void> initFlutterCommon({
    String? dir,
    required FutureOr<void> Function(String? path) initHive,
    int? colorAdapterTypeId,
    int? timeOfDayAdapterTypeId,
    bool useMaterialUi = false,
  }) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
    } catch (_) {
      // This will fail if the Flutter engine is not available
    }

    String? path;
    if (!kIsWeb) {
      // Root-relative Windows paths still take the drive from the app directory
      if (dir != null &&
          path_helper.isAbsolute(dir) &&
          !path_helper.isRootRelative(dir)) {
        path = dir;
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        path = path_helper.join(appDir.path, dir);
      }
    }

    await initHive(path);

    _registerAdapter(ColorAdapter(typeId: colorAdapterTypeId));
    if (useMaterialUi) {
      _registerAdapter(
        MaterialUiTimeOfDayAdapter(typeId: timeOfDayAdapterTypeId),
      );
    } else {
      _registerAdapter(TimeOfDayAdapter(typeId: timeOfDayAdapterTypeId));
    }
  }

  void _registerAdapter<T>(TypeAdapter<T> adapter) {
    if (isAdapterRegistered(adapter.typeId)) return;
    registerAdapter(adapter);
  }
}
