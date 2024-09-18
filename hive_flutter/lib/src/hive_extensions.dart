part of '../hive_flutter.dart';

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
    );

    final colorAdapter = ColorAdapter();
    if (!isAdapterRegistered(colorAdapter.typeId)) {
      registerAdapter(colorAdapter);
    }

    final timeOfDayAdapter = TimeOfDayAdapter();
    if (!isAdapterRegistered(timeOfDayAdapter.typeId)) {
      registerAdapter(timeOfDayAdapter);
    }
  }
}
