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
