## 1.10.1

- Upgrades `analyzer` to `9.0.0`

## 1.10.0

- Adds support for `ignoredFields` parameter in `AdapterSpec` (by [@rezam92](https://github.com/rezam92) in [#229](https://github.com/IO-Design-Team/hive_ce/pull/229))

## 1.9.5

- Supports `analyzer: 8.0.0`
- Supports `build: 4.0.0`
- Supports `source_gen: 4.0.0`

## 1.9.4

- Fixes `TypeChecker.fromRuntime` deprecations

## 1.9.3

- Supports `build: 3.0.0` and `source_gen: 3.0.0`

## 1.9.2

- Ignores analyzer deprecations
- Fixes read method generation for classes with non-constructor fields
- Fixes adapter name generation for generic types

## 1.9.1

- Fixes issue with `hive_registrar.g.dart` getting deleted (by [@Komodo5197](https://github.com/Komodo5197) in [#130](https://github.com/IO-Design-Team/hive_ce/pull/130))

## 1.9.0

- Generates `IsolatedHiveRegistrar` extension for `IsolatedHiveInterface`
- Fixes generated read method for empty classes (by [@esuljic](https://github.com/esuljic) in [#92](https://github.com/IO-Design-Team/hive_ce/pull/92))
- Adds support for `@Default` annotation from `freezed`
- Fixes generation for `Iterable` fields
- Removes type annotation from generated `typeId` field
- Adds support for `reservedTypeIds` in `GenerateAdapters` annotation

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
