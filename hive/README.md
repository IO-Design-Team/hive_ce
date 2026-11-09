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
- ⚡ Great performance (see [benchmarks](#benchmarks))
- ❤️ Simple, powerful, & intuitive API
- 🔒 Strong encryption built in
- 🎈 **NO** native dependencies
- 🔋 Batteries included

## New features in Hive CE

Hive CE is a spiritual continuation of Hive v2 with the following new features:

- **Tooling**
  - Hive CE Inspector DevTools extension to browse and search the contents of your boxes
- **Platforms**
  - Isolate support through `IsolatedHive`
  - Flutter web WASM support
- **Code generation**
  - Generate adapters with the `GenerateAdapters` annotation instead of annotating every type and field
  - Generate adapters for classes outside the current package
  - Register every generated adapter in one call with the `HiveRegistrar` extension
  - Support for Freezed, constructor parameter defaults, and named imports
- **Types**
  - Built-in support for `Set` and `Duration`
  - `DateTime` and `Duration` keep microsecond precision
  - Type IDs up to `65439` instead of `223`
- **Performance**
  - Faster batch writes and opening of large boxes, including encrypted boxes
  - Lazy boxes open several times faster
  - `IsolatedHive` individual writes are faster than Hive CE
  - See the [benchmarks](#benchmarks)

## Getting Started

Hive CE requires Dart 3. Ensure that you have the following in your `pubspec.yaml` file:

```yaml
environment:
  sdk: ^3.0.0
```

## Usage

You can use Hive just like a map. Writes are readable immediately, but a write can be lost if the process is killed before its future completes. On the VM, `flush()` waits for pending writes and flushes them to disk.

<!-- embedme readme/usage.dart -->

```dart
import 'package:hive_ce/hive_ce.dart';

void example() {
  final box = Hive.box('myBox');
  box.put('name', 'David');
  final name = box.get('name');
  print('Name: $name');
}

```

## Benchmarks

Run on an M3 Max MacBook Pro with values of a class with ten `int` fields. See the [benchmark code](https://github.com/IO-Design-Team/hive_ce/tree/main/benchmarks).

### Speed

Times are averaged over several runs. Runs that took longer than 1 minute were stopped.

#### Individual writes

Writing values one at a time, then flushing once. Hive v4, sqflite, drift, and ObjectBox commit every write.

| Database     |  1,000 |  10,000 | 100,000 | 1,000,000 |
| ------------ | -----: | ------: | ------: | --------: |
| Hive CE      |  16 ms |  167 ms |  1.57 s |   14.89 s |
| IsolatedHive |  13 ms |  132 ms |  1.25 s |   12.52 s |
| Hive v2      |  14 ms |  148 ms |  1.51 s |   19.35 s |
| Hive v4      | 140 ms |  1.62 s | 19.67 s |   > 1 min |
| sqflite      | 402 ms |  4.04 s | 43.85 s |   > 1 min |
| drift        | 286 ms |  4.22 s | 44.67 s |   > 1 min |
| sembast      |  64 ms |  729 ms |  7.77 s |   > 1 min |
| ObjectBox    | 4.21 s | 43.79 s | > 1 min |   > 1 min |

#### Batch writes

Writing every value with a single `addAll`, then flushing.

| Database     |  1,000 | 10,000 | 100,000 | 1,000,000 |
| ------------ | -----: | -----: | ------: | --------: |
| Hive CE      | 750 µs |   8 ms |  107 ms |    1.10 s |
| IsolatedHive |   1 ms |  12 ms |  138 ms |    1.46 s |
| Hive v2      | 867 µs |   9 ms |  105 ms |    3.08 s |
| Hive v4      |   2 ms |  26 ms |  267 ms |    2.94 s |
| sqflite      |   5 ms |  59 ms |  623 ms |    6.86 s |
| drift        |   4 ms |  44 ms |  466 ms |    4.97 s |
| sembast      |  16 ms | 172 ms |  1.73 s |   17.79 s |
| ObjectBox    |   5 ms |  10 ms |   47 ms |    461 ms |

#### Opening and reading

Opening a database and reading every value.

| Database     |  1,000 | 10,000 | 100,000 | 1,000,000 |
| ------------ | -----: | -----: | ------: | --------: |
| Hive CE      |   1 ms |  10 ms |  135 ms |    1.22 s |
| IsolatedHive |   1 ms |  11 ms |  154 ms |    1.40 s |
| Hive v2      |   1 ms |  12 ms |  142 ms |    3.71 s |
| Hive v4      |   1 ms |  14 ms |  159 ms |    1.65 s |
| sqflite      | 811 µs |   7 ms |   94 ms |    1.06 s |
| drift        |   1 ms |  13 ms |  174 ms |    1.86 s |
| sembast      |   2 ms |  29 ms |  347 ms |    3.84 s |
| ObjectBox    | 326 µs | 882 µs |    9 ms |    108 ms |

#### Queries

Finding the tenth of the values within a range of an integer field, right after opening. sqflite, drift, and ObjectBox index the field. Hive has no query API, so Hive boxes filter their values in Dart, and Hive v4 reads them from disk first.

| Database     |  1,000 | 10,000 | 100,000 | 1,000,000 |
| ------------ | -----: | -----: | ------: | --------: |
| Hive CE      |  38 µs |   1 ms |    3 ms |     29 ms |
| IsolatedHive | 760 µs |   7 ms |   60 ms |    637 ms |
| Hive v2      |  21 µs | 573 µs |    2 ms |     26 ms |
| Hive v4      |   1 ms |  13 ms |  158 ms |    1.65 s |
| sqflite      | 147 µs | 746 µs |    7 ms |     91 ms |
| drift        | 216 µs |   1 ms |   15 ms |    167 ms |
| sembast      | 273 µs |   3 ms |   47 ms |    501 ms |
| ObjectBox    | 272 µs | 341 µs |    4 ms |     42 ms |

#### Encrypted and lazy boxes

Hive v2 → Hive CE. Lazy boxes only load keys when opened.

| Values    | Encrypted batch write |  Encrypted open |       Lazy open |
| --------- | --------------------: | --------------: | --------------: |
| 10,000    |         41 ms → 33 ms |   28 ms → 20 ms |     6 ms → 5 ms |
| 100,000   |       412 ms → 266 ms | 308 ms → 205 ms |   84 ms → 56 ms |
| 1,000,000 |       6.08 s → 2.59 s | 5.58 s → 2.19 s | 3.06 s → 624 ms |

### Database size

| Database  |   1,000 |  10,000 |  100,000 | 1,000,000 |
| --------- | ------: | ------: | -------: | --------: |
| Hive CE   | 0.11 MB | 1.10 MB | 10.97 MB | 109.67 MB |
| Hive v2   | 0.11 MB | 1.10 MB | 10.97 MB | 109.67 MB |
| Hive v4   | 1.00 MB | 5.00 MB | 30.00 MB | 295.00 MB |
| sqflite   | 0.05 MB | 0.38 MB |  4.00 MB |  40.98 MB |
| drift     | 0.05 MB | 0.37 MB |  3.89 MB |  39.84 MB |
| sembast   | 0.24 MB | 2.44 MB | 24.58 MB | 247.74 MB |
| ObjectBox | 0.32 MB | 2.45 MB | 23.74 MB | 236.66 MB |

Hive v4 sizes grow with the length of model field names. sqflite, drift, and ObjectBox sizes include the query index.

### Memory usage

Peak memory with 1,000,000 values, including native memory, averaged over three runs. Regular Hive boxes keep every value in memory while open. Lazy boxes keep only keys and read values with `getAt`.

| Database       | Batch write |     Open | Open and read |
| -------------- | ----------: | -------: | ------------: |
| Hive CE        |      579 MB |   476 MB |        492 MB |
| Hive CE (lazy) |      475 MB |   240 MB |        367 MB |
| Hive v2        |      577 MB |   470 MB |        485 MB |
| Hive v4        |      470 MB |     1 MB |      1,400 MB |
| sqflite        |    1,545 MB |     1 MB |        558 MB |
| drift          |      534 MB |     1 MB |        789 MB |
| sembast        |    1,687 MB | 1,128 MB |      1,443 MB |
| ObjectBox      |      367 MB |     1 MB |        342 MB |
