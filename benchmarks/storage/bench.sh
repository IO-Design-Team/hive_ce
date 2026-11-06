#!/bin/sh
set -e

cd "$(dirname "$0")"

pids=""
for project in hive_ce hive_v2 hive_v4; do
  (
    echo "Running $project"
    cd "$project"
    dart pub get
    dart compile exe bin/bench.dart -o bench
    ./bench
    rm bench
    echo "Results written to $project/results.md"
  ) &
  pids="$pids $!"
done

status=0
for pid in $pids; do
  wait "$pid" || status=1
done
exit "$status"
