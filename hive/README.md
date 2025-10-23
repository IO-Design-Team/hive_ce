<p align="center">
  <img src="https://raw.githubusercontent.com/IO-Design-Team/hive_ce/master/.github/logo_transparent.svg?sanitize=true" width="350px">
</p>
<h2 align="center">Fast, Enjoyable & Secure NoSQL Database</h2>

<p align="center">
  <a href="https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml"><img src="https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml/badge.svg" alt="Dart CI"></a>
  <a href="https://codecov.io/gh/IO-Design-Team/hive_ce"><img src="https://codecov.io/gh/IO-Design-Team/hive_ce/graph/badge.svg?token=ODO2JA4286" alt="codecov"></a>
  <a href="https://pub.dev/packages/hive_ce"><img src="https://img.shields.io/pub/v/hive_ce?label=pub.dev&labelColor=333940&logo=dart" alt="Pub Version"></a>
  <a href="https://github.com/IO-Design-Team/hive_ce/blob/master/LICENSE"><img src="https://img.shields.io/badge/License-BSD_3--Clause-007A88.svg?logo=bsd" alt="License"></a>
</p>

<p align="center">
  <a href="https://pubstats.dev/packages/hive_ce"><img src="https://pubstats.dev/badges/packages/hive_ce/popularity.svg" alt="PubStats Popularity"></a>
  <a href="https://pubstats.dev/packages/hive_ce"><img src="https://pubstats.dev/badges/packages/hive_ce/rank.svg" alt="PubStats Rank"></a>
  <a href="https://pubstats.dev/packages/hive_ce"><img src="https://pubstats.dev/badges/packages/hive_ce/dependents.svg" alt="PubStats Dependents"></a>
</p>

Hive is a lightweight and blazing fast key-value database written in pure Dart. Inspired by [Bitcask](https://en.wikipedia.org/wiki/Bitcask).

### [Documentation & Samples](https://docs.hive.isar.community) 📖

## Features

- 🚀 Cross platform: mobile, desktop, browser
- ⚡ Great performance (see [benchmark](#benchmark))
- ❤️ Simple, powerful, & intuitive API
- 🔒 Strong encryption built in
- 🎈 **NO** native dependencies
- 🔋 Batteries included

## New features in Hive CE

Hive CE is a spiritual continuation of Hive v2 with the following new features:

- Hive CE Inspector DevTools extension
  - Quickly and easily inspect the content of Hive boxes
- Isolate support through `IsolatedHive`
- Flutter web WASM support
- Automatic type adapter generation using the `GenerateAdapters` annotation
  - No more manually adding annotations to every type and field
  - Generate adapters for classes outside the current package
- A `HiveRegistrar` extension that lets you register all your generated adapters in one call
- Extends the maximum type ID from `223` to `65439`
- Support for constructor parameter defaults
- Support for Sets
- A built in Duration adapter
- Freezed support
- Support for generating adapters with classes that use named imports

## Benchmark

This is a comparison of the time to complete a given number of write operations and the resulting database file size:

| Operations | Hive CE Time | IsolatedHive Time | Hive CE Size | Hive v4 Time | Hive v4 Size |
| ---------- | ------------ | ----------------- | ------------ | ------------ | ------------ |
| 10         | 0.00 s       | 0.00 s            | 0.00 MB      | 0.00 s       | 1.00 MB      |
| 100        | 0.00 s       | 0.01 s            | 0.01 MB      | 0.01 s       | 1.00 MB      |
| 1000       | 0.02 s       | 0.03 s            | 0.11 MB      | 0.06 s       | 1.00 MB      |
| 10000      | 0.13 s       | 0.25 s            | 1.10 MB      | 0.64 s       | 5.00 MB      |
| 100000     | 1.40 s       | 2.64 s            | 10.97 MB     | 7.26 s       | 30.00 MB     |
| 1000000    | 19.94 s      | 41.50 s           | 109.67 MB    | 84.87 s      | 290.00 MB    |

Database size in Hive v4 is directly affected by the length of field names in model classes which is not ideal. Also Hive v4 is much slower than Hive CE for large numbers of operations.

IsolatedHive is slower than Hive, but it is much faster than Hive v4 and you still get the benefit of multiple isolate support.

The benchmark was performed on an M3 Max MacBook Pro. You can [see the benchmark code here](https://github.com/IO-Design-Team/hive_ce/blob/main/benchmarks/storage/bin/bench.dart).

## Migration guides

- [Hive v2 to Hive CE](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#v2-to-ce)
- [Transitive Hive dependencies](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#transitive-hive-dependencies)
- [Migrating to `GenerateAdapters`](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#generate-adapters)
- [Add fields to objects](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#add-fields)

## Getting Started

Hive CE requires Dart 3. Ensure that you have the following in your `pubspec.yaml` file:

```yaml
environment:
  sdk: ^3.0.0
```

## Usage

You can use Hive just like a map. It is not necessary to await `Futures`.

<!-- embedme readme/usage.dart -->

```dart
import 'package:hive_ce/hive.dart';

void example() {
  final box = Hive.box('myBox');
  box.put('name', 'David');
  final name = box.get('name');
  print('Name: $name');
}

```
