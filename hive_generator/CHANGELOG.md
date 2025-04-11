## 1.9.0

- Generates `IsolatedHiveRegistrar` extension for `IsolatedHiveInterface`
- Fixes generated read method for empty classes (by [@esuljic](https://github.com/esuljic) in [#92](https://github.com/IO-Design-Team/hive_ce/pull/92))
- Adds support for `@Default` annotation from `freezed`

## 1.8.2

- Supports analyzer 7

## 1.8.1

- Fixes a bug in the migrator affecting `freezed` classes

## 1.8.0

- Adds support for the `GenerateAdapters` annotation. See the [hive_ce documentation](https://pub.dev/packages/hive_ce) for more information.

## 1.7.0

- Supports named imports

## 1.6.0

- Adds `.freezed.dart` to `required_inputs` to support `freezed`
- Sorts adapters and uris in `HiveRegistrar`

## 1.5.0

- Supports constructor parameter default values
- No longer generates the `HiveRegistrar` if there are no adapters
- Removes unnecessary print statement in `HiveRegistrar` generator
- Bumps `analyzer` to `^6.5.0` to deal with deprecations

## 1.4.0

- Adds a generator to create a `HiveRegistrar` extension that allows registration of all generated `TypeAdapters` in one call

## 1.3.0

- Adds support for Sets

## 1.2.1

- Fix `analyzer` dependency conflicts with Flutter

## 1.2.0

- The first release of hive_ce_generator
