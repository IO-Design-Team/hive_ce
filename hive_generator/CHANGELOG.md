## 1.6.0

- Adds `.freezed.dart` to `required_inputs` to support `freezed`

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
