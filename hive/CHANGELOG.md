## 2.8.0

- Adds `GenerateAdapters` annotation and relevant documentation

## 2.7.0+1

- Adds a storage benchmark to compare Hive CE with Hive v4

## 2.7.0

- No longer reinitializes `Hive` when opening a `BoxCollection`

## 2.6.0

- Adds `TargetKind.parameter` to `HiveField` to support `freezed`

## 2.5.0+2

- Adds documentation for adding new fields (@vizakenjack)
- Updates README badges

## 2.5.0+1

- Documentation updates for `HiveField` in support of `hive_ce_generator` changes

## 2.5.0

- Adds `Target` annotations to `HiveField` and `HiveType` to prevent invalid usage
- Bumps `analyzer` to `^6.5.0` to deal with deprecations
- Bumps `meta` to `^1.14.0` for `TargetKind.enumValue`

## 2.4.4

- Loosens constraint on `web`

## 2.4.3

- Loosens constraint on `meta`

## 2.4.2

- Only shows the adapter with same type warning if the adapters have different type ids

## 2.4.1

- Upgrades `package:web` to `1.0.0`

## 2.4.0+1

- Adds a guide to migrate from `hive`
- Adds documentation for the new `HiveRegistrar` extension created by `hive_ce_generator`

## 2.4.0

- Adds support for Sets
- Adds a built in `DurationAdapter`
- Adds a warning if attempting to register multiple adapters for the same type

## 2.3.0

- The first release of Hive Community Edition
- Supports Flutter web WASM compilation
- Fixes analysis issues
