#!/bin/sh
set -e

cd "$(dirname "$0")"

for project in hive_ce hive_v2 hive_v4 sqflite drift sembast objectbox; do
  (
    echo "Running $project"
    cd "$project"
    if [ "$project" = objectbox ] && [ ! -f lib/libobjectbox.dylib ]; then
      curl -sf https://raw.githubusercontent.com/objectbox/objectbox-dart/v5.3.2/install.sh | bash -s -- --quiet
    fi
    dart pub get
    dart build cli -t bin/memory.dart -o build/memory
    build/memory/bundle/bin/memory
    rm -rf build
    echo "Results written to $project/memory_results.md"
  )
done
