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

## Benchmarks

All times are averaged over several runs

### Individual writes

Writing values one at a time with `add`:

| Values    | Hive v2 | Hive v4  | Hive CE | IsolatedHive |
| --------- | ------: | -------: | ------: | -----------: |
| 1,000     |   15 ms |   198 ms |   15 ms |        11 ms |
| 10,000    |  271 ms |   2.13 s |  271 ms |       130 ms |
| 100,000   |  1.80 s |  21.52 s |  1.90 s |       1.66 s |
| 1,000,000 | 23.36 s | 371.17 s | 17.36 s |      13.07 s |

### Batch writes

Writing all values with a single `addAll` call:

| Values    | Hive v2 | Hive v4 | Hive CE | IsolatedHive |
| --------- | ------: | ------: | ------: | -----------: |
| 1,000     |    0 ms |    2 ms |    0 ms |         1 ms |
| 10,000    |    8 ms |   27 ms |    9 ms |        13 ms |
| 100,000   |  121 ms |  313 ms |  118 ms |       157 ms |
| 1,000,000 |  3.66 s |  3.00 s |  1.28 s |       1.86 s |

### Opening a box

Opening a box and reading every value:

| Values    | Hive v2 | Hive v4 | Hive CE | IsolatedHive |
| --------- | ------: | ------: | ------: | -----------: |
| 1,000     |    1 ms |    1 ms |    1 ms |         1 ms |
| 10,000    |   13 ms |   14 ms |   10 ms |        14 ms |
| 100,000   |  178 ms |  189 ms |  125 ms |       146 ms |
| 1,000,000 |  4.34 s |  1.65 s |  1.32 s |       1.59 s |

### Encrypted and lazy boxes

Hive v2 compared to Hive CE. Lazy boxes only load keys when opened, so the lazy open time doesn't include reading values.

| Values    | Encrypted batch write | Encrypted open  | Lazy open       |
| --------- | --------------------- | --------------- | --------------- |
| 10,000    | 41 ms → 30 ms         | 31 ms → 27 ms   | 7 ms → 5 ms     |
| 100,000   | 481 ms → 330 ms       | 339 ms → 291 ms | 99 ms → 59 ms   |
| 1,000,000 | 7.21 s → 3.35 s       | 6.14 s → 2.99 s | 3.79 s → 640 ms |

### Database size

| Values    |   Hive CE |   Hive v4 |
| --------- | --------: | --------: |
| 1,000     |   0.11 MB |   1.00 MB |
| 10,000    |   1.10 MB |   5.00 MB |
| 100,000   |  10.97 MB |  30.00 MB |
| 1,000,000 | 109.67 MB | 290.00 MB |

### Notes

Database size in Hive v4 is directly affected by the length of field names in model classes which is not ideal. Also Hive v4 is much slower than Hive CE for large numbers of individual writes.

The benchmark was performed on an M3 Max MacBook Pro. You can [see the benchmark code here](https://github.com/IO-Design-Team/hive_ce/tree/main/benchmarks/storage).

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
