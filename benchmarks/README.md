# Storage benchmarks

Run this from the repository root on macOS with Flutter, Xcode, and CocoaPods
installed.

```sh
./benchmarks/run_flutter.sh
```

The storage comparison averages three runs per measurement across all ten
configurations. The standard workloads use 1,000 values. The launcher builds
the release apps and runs them serially.
The benchmark uses `hive_ce_flutter` and calls `Hive.initFlutter()` and
`IsolatedHive.initFlutter()` to enable zlib for CRC32. Hive v4 builds separately
so it can resolve a different version of Hive.

Use `--no-build` to repeat the same measurements with up-to-date release builds.

The launcher writes `benchmark_results.md`, `benchmark_results.csv`, and SVG
charts under `charts/` in `benchmarks/`.

- `benchmark_results.md` shows speed in milliseconds and memory and database
  size in MiB. The speed table includes two columns for 1 MiB values.
- `benchmark_results.csv` contains one row per result, with raw values in
  microseconds or bytes. A standard speed measurement has an empty value
  and a `timedOut` status if any run reaches one minute.
- `charts/` contains `speed.svg`, `large_values.svg`, and `memory.svg`.

Speed write timings include the final flush where needed. Opening and querying
reuse the database left by the batch write. The speed test for opening a lazy
box reads its keys, and the memory test also measures reading its values. Each
memory measurement runs in a fresh process and measures peak RSS above its
starting RSS. Write measurements include constructing the input values.

All ten configurations batch-write the same 32 values of 1 MiB each, flush
where needed, and reopen the database. The reopen timer stops before reading
the values back for validation. Hive v4 stores base64 strings, and Sembast uses
its Blob type.
