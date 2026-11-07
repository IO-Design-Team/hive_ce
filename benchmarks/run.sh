#!/bin/sh
# Usage: ./run.sh speed|memory
#
# Runs one project at a time so they don't compete for CPU and disk
set -e

benchmark="$1"
case "$benchmark" in
speed | memory) ;;
*)
  echo "Usage: $0 speed|memory" >&2
  exit 64
  ;;
esac

cd "$(dirname "$0")"

for project in hive_ce hive_v2 hive_v4 sqflite drift sembast objectbox; do
  (
    echo "Running $project"
    cd "$project"
    if [ "$project" = objectbox ] && ! ls lib/libobjectbox.* >/dev/null 2>&1; then
      curl -sf https://raw.githubusercontent.com/objectbox/objectbox-dart/v5.3.2/install.sh | bash -s -- --quiet
    fi
    dart pub get
    dart build cli -t "bin/$benchmark.dart" -o "build/$benchmark"
    "build/$benchmark/bundle/bin/$benchmark"
    rm -rf build
    echo "Results written to $project/${benchmark}_results.md"
  )
done
