import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/adapters.dart'
    hide IsolatedHive, IsolateNameServer;
import 'package:hive_ce_flutter/src/isolate/isolate_name_server.dart';
import 'package:hive_ce_flutter/src/wrapper/path_provider.dart';
import 'package:path/path.dart' as path;

/// Flutter extensions for [IsolatedHiveInterface]
extension IsolatedHiveX on IsolatedHiveInterface {
  /// Initializes [IsolatedHive] with the path from
  /// [getApplicationDocumentsDirectory] and the Flutter [IsolateNameServer]
  ///
  /// You can provide a [subDirectory] where the boxes should be stored
  ///
  /// Also registers the flutter type adapters
  Future<void> initFlutter({
    String? subDirectory,
    int? colorAdapterTypeId,
    int? timeOfDayAdapterTypeId,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final appDir = await getApplicationDocumentsDirectory();
    final hivePath = path.join(appDir.path, subDirectory);

    await init(hivePath, isolateNameServer: const IsolateNameServer());

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
