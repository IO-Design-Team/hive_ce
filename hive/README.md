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
  - Faster box opening and writes, especially for large and encrypted boxes (see [benchmarks](#benchmarks))

## Benchmarks

All times are averaged over several runs

### Individual writes

Writing values one at a time with `add`:

| Values    | Hive v2 |  Hive v4 | Hive CE | IsolatedHive |
| --------- | ------: | -------: | ------: | -----------: |
| 1,000     |   19 ms |   129 ms |   17 ms |        36 ms |
| 10,000    |  149 ms |   1.66 s |  156 ms |       343 ms |
| 100,000   |  1.56 s |  18.79 s |  1.52 s |       3.62 s |
| 1,000,000 | 20.61 s | 331.64 s | 15.44 s |      38.56 s |

### Batch writes

Writing all values with a single `addAll` call:

| Values    | Hive v2 | Hive v4 | Hive CE | IsolatedHive |
| --------- | ------: | ------: | ------: | -----------: |
| 1,000     |    0 ms |    3 ms |    0 ms |         1 ms |
| 10,000    |    9 ms |   26 ms |    8 ms |        13 ms |
| 100,000   |  119 ms |  265 ms |   99 ms |       126 ms |
| 1,000,000 |  3.00 s |  3.03 s |  991 ms |       1.44 s |

### Opening a box

Opening a box and reading every value:

| Values    | Hive v2 | Hive v4 | Hive CE | IsolatedHive |
| --------- | ------: | ------: | ------: | -----------: |
| 1,000     |    1 ms |    2 ms |    1 ms |         1 ms |
| 10,000    |   12 ms |   15 ms |   12 ms |        14 ms |
| 100,000   |  160 ms |  165 ms |  125 ms |       143 ms |
| 1,000,000 |  3.98 s |  1.72 s |  1.29 s |       1.46 s |

### Encrypted and lazy boxes

Hive v2 compared to Hive CE. Lazy boxes only load keys when opened, so the lazy open time doesn't include reading values.

| Values    | Encrypted batch write | Encrypted open  | Lazy open       |
| --------- | --------------------- | --------------- | --------------- |
| 10,000    | 34 ms → 24 ms         | 22 ms → 20 ms   | 6 ms → 5 ms     |
| 100,000   | 367 ms → 239 ms       | 252 ms → 216 ms | 84 ms → 52 ms   |
| 1,000,000 | 5.73 s → 2.49 s       | 5.34 s → 2.29 s | 3.35 s → 530 ms |

### Database size

| Values    |   Hive CE |   Hive v4 |
| --------- | --------: | --------: |
| 1,000     |   0.11 MB |   1.00 MB |
| 10,000    |   1.10 MB |   5.00 MB |
| 100,000   |  10.97 MB |  30.00 MB |
| 1,000,000 | 109.67 MB | 290.00 MB |

### Notes

Database size in Hive v4 is directly affected by the length of field names in model classes which is not ideal. Also Hive v4 is much slower than Hive CE for large numbers of individual writes.

IsolatedHive is slower than Hive, but it is much faster than Hive v4 and you still get the benefit of multiple isolate support.

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
