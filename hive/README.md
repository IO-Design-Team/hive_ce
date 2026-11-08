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

The benchmarks were run on an M3 Max MacBook Pro. You can [see the benchmark code here](https://github.com/IO-Design-Team/hive_ce/tree/main/benchmarks).

### Speed

All times are averaged over several runs.

#### Individual writes

Writing values one at a time, then flushing once. Hive v4, sqflite, drift, and ObjectBox commit each write. Runs that took longer than 5 minutes were stopped.

| Database     |  1,000 |  10,000 | 100,000 | 1,000,000 |
| ------------ | -----: | ------: | ------: | --------: |
| Hive CE      |  14 ms |  144 ms |  1.45 s |   14.92 s |
| IsolatedHive |  11 ms |  119 ms |  1.20 s |   12.65 s |
| Hive v2      |  15 ms |  144 ms |  1.50 s |   20.23 s |
| Hive v4      | 129 ms |  1.60 s | 17.82 s |  228.49 s |
| sqflite      | 1.70 s | 14.26 s | 94.92 s |   > 5 min |
| drift        | 266 ms |  3.63 s | 44.00 s |   > 5 min |
| sembast      |  62 ms |  642 ms |  7.45 s |   72.72 s |
| ObjectBox    | 4.11 s | 41.97 s | > 5 min |   > 5 min |

#### Batch writes

Writing all values with a single `addAll`, then flushing once:

| Database     | 1,000 | 10,000 | 100,000 | 1,000,000 |
| ------------ | ----: | -----: | ------: | --------: |
| Hive CE      |  0 ms |   9 ms |  101 ms |    1.10 s |
| IsolatedHive |  1 ms |  10 ms |  126 ms |    1.47 s |
| Hive v2      |  0 ms |   8 ms |  111 ms |    3.10 s |
| Hive v4      |  2 ms |  26 ms |  257 ms |    2.88 s |
| sqflite      |  7 ms |  56 ms |  581 ms |    6.48 s |
| drift        |  5 ms |  40 ms |  443 ms |    4.56 s |
| sembast      | 17 ms | 169 ms |  1.71 s |   17.43 s |
| ObjectBox    |  4 ms |   6 ms |   29 ms |    269 ms |

#### Opening a database

Opening a database and reading every value:

| Database     | 1,000 | 10,000 | 100,000 | 1,000,000 |
| ------------ | ----: | -----: | ------: | --------: |
| Hive CE      |  1 ms |   9 ms |  114 ms |    1.25 s |
| IsolatedHive |  1 ms |  13 ms |  134 ms |    1.41 s |
| Hive v2      |  1 ms |  11 ms |  145 ms |    3.68 s |
| Hive v4      |  1 ms |  12 ms |  154 ms |    1.61 s |
| sqflite      |  0 ms |   7 ms |   95 ms |    1.04 s |
| drift        |  1 ms |  13 ms |  166 ms |    1.86 s |
| sembast      |  2 ms |  31 ms |  343 ms |    3.87 s |
| ObjectBox    |  0 ms |   1 ms |    9 ms |    103 ms |

#### Encrypted and lazy boxes

Hive v2 compared to Hive CE. Lazy boxes only load keys when opened, so the lazy open time doesn't include reading values.

| Values    | Encrypted batch write |  Encrypted open |       Lazy open |
| --------- | --------------------: | --------------: | --------------: |
| 10,000    |         40 ms → 23 ms |   27 ms → 20 ms |     6 ms → 5 ms |
| 100,000   |       413 ms → 256 ms | 304 ms → 211 ms |   84 ms → 59 ms |
| 1,000,000 |       6.06 s → 2.53 s | 5.51 s → 2.17 s | 3.30 s → 634 ms |

### Database size

| Database  |   1,000 |  10,000 |  100,000 | 1,000,000 |
| --------- | ------: | ------: | -------: | --------: |
| Hive CE   | 0.11 MB | 1.10 MB | 10.97 MB | 109.67 MB |
| Hive v4   | 1.00 MB | 5.00 MB | 30.00 MB | 290.00 MB |
| sqflite   | 0.04 MB | 0.25 MB |  2.49 MB |  24.94 MB |
| drift     | 0.03 MB | 0.24 MB |  2.40 MB |  24.02 MB |
| sembast   | 0.24 MB | 2.41 MB | 24.21 MB | 243.08 MB |
| ObjectBox | 0.24 MB | 1.51 MB | 14.16 MB | 141.02 MB |

Database size in Hive v4 is directly affected by the length of field names in model classes.

### Memory usage

Peak memory usage with 1,000,000 values, including native memory, averaged over three runs. Each run is a new process. Hive CE and Hive v2 keep every value of a regular box in memory while it is open. Lazy boxes only keep keys in memory and read values with `getAt`.

| Database       | Batch write |     Open | Open and read |
| -------------- | ----------: | -------: | ------------: |
| Hive CE        |      595 MB |   471 MB |        486 MB |
| Hive CE (lazy) |      501 MB |   241 MB |        369 MB |
| Hive v2        |      595 MB |   469 MB |        485 MB |
| Hive v4        |      481 MB |     1 MB |      1,396 MB |
| sqflite        |    1,673 MB |     1 MB |        558 MB |
| drift          |      644 MB |     1 MB |        784 MB |
| sembast        |    1,790 MB | 1,128 MB |      1,400 MB |
| ObjectBox      |      292 MB |     1 MB |        272 MB |
