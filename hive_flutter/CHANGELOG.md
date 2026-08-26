## 3.0.0

- BREAKING: Requires Flutter `>=3.44.0`
- BREAKING: `TimeOfDayAdapter` now uses `TimeOfDay` from `package:material_ui`
  - MIGRATION: Import `TimeOfDay` from `package:material_ui/material_ui.dart` instead of `package:flutter/material.dart`
- BREAKING: Removes deprecated `WatchBoxBuilder` and `BoxWidgetBuilder`
  - MIGRATION: Use `StreamBuilder` with `box.watch()`
- BREAKING: Removes `Box.listenable()` and `LazyBox.listenable()`
  - MIGRATION: Use `StreamBuilder` with `box.watch()`
- BREAKING: `Hive.initFlutter` arguments are now named (matches `IsolatedHive.initFlutter`)
  - Drops unused `backendPreference` (`HiveStorageBackendPreference.webWorker` was never implemented)
  - MIGRATION: `Hive.initFlutter(path, preference, colorId, timeId)` → `Hive.initFlutter(subDirectory: path, colorAdapterTypeId: colorId, timeOfDayAdapterTypeId: timeId)`

## 2.3.4

- Adds `hive_ce_flutter.dart` to make the publish action happy

## 2.3.3

- Catch exception when Flutter engine is not available in `IsolatedHive.initFlutter`

## 2.3.2

- Fixes an issue with the `ColorAdapter` reading legacy color data

## 2.3.1

- Fixes web compatibility check

## 2.3.0

- Adds `IsolatedHive.initFlutter`
- Allows changing the type ids of `ColorAdapter` and `TimeOfDayAdapter`

## 2.2.0

- Fixes deprecation of `Color.value`

## 2.1.0

- Does not crash with multiple calls to `initFlutter`

## 2.0.0

- BREAKING: Registers `ColorAdapter` and `TimeOfDayAdapter` in `Hive.initFlutter`
  - MIGRATION: Remove external registration of `ColorAdapter` and `TimeOfDayAdapter`

## 1.2.0

- The first release of hive_ce_flutter
