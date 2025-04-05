## 2.11.0

- Isolate support through `IsolatedHive`
- Warning messages for potentially unsafe isolate usage
- Updates suggested placement of `GenerateAdapters` annotation
- Fixes custom objects in `BoxCollection`. Custom objects must now be json serializable.
- Adds much more information to the unknown typeId error message

## 2.10.1

- Fixes `HiveObject` disposal in lazy boxes

## 2.10.0

- Raises the maximum type ID from 223 to 65439

## 2.9.0

- Prints a warning when writing `int` or `List<int>` types in a WASM environment
- Only emits print statements when assertions are enabled (aka debug mode)

## 2.8.0+3

- Updates the commit hash for the transitive Hive dependencies workaround

## 2.8.0+2

- Adds workaround for transitive Hive dependencies to README

## 2.8.0+1

- Adds tutorial link to README

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
