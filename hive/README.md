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
| 1,000     |   14 ms |   142 ms |   14 ms |        11 ms |
| 10,000    |  162 ms |   1.81 s |  164 ms |       142 ms |
| 100,000   |  1.71 s |  19.94 s |  1.66 s |       1.32 s |
| 1,000,000 | 22.37 s | 339.65 s | 17.21 s |      13.13 s |

### Batch writes

Writing all values with a single `addAll` call:

| Values    | Hive v2 | Hive v4 | Hive CE | IsolatedHive |
| --------- | ------: | ------: | ------: | -----------: |
| 1,000     |    0 ms |    2 ms |    0 ms |         1 ms |
| 10,000    |    9 ms |   26 ms |    9 ms |        15 ms |
| 100,000   |  119 ms |  328 ms |  114 ms |       134 ms |
| 1,000,000 |  3.63 s |  2.94 s |  1.24 s |       1.71 s |

### Opening a box

Opening a box and reading every value:

| Values    | Hive v2 | Hive v4 | Hive CE | IsolatedHive |
| --------- | ------: | ------: | ------: | -----------: |
| 1,000     |    1 ms |    1 ms |    1 ms |         1 ms |
| 10,000    |   13 ms |   14 ms |   11 ms |        14 ms |
| 100,000   |  167 ms |  192 ms |  130 ms |       143 ms |
| 1,000,000 |  4.10 s |  1.66 s |  1.32 s |       1.50 s |

### Encrypted and lazy boxes

Hive v2 compared to Hive CE. Lazy boxes only load keys when opened, so the lazy open time doesn't include reading values.

| Values    | Encrypted batch write | Encrypted open  | Lazy open       |
| --------- | --------------------- | --------------- | --------------- |
| 10,000    | 43 ms → 27 ms         | 31 ms → 21 ms   | 9 ms → 5 ms     |
| 100,000   | 470 ms → 269 ms       | 326 ms → 237 ms | 98 ms → 62 ms   |
| 1,000,000 | 7.00 s → 2.78 s       | 5.98 s → 2.32 s | 3.67 s → 632 ms |

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
