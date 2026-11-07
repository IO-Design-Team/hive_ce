#!/bin/sh
set -e

cd "$(dirname "$0")"

for project in sqflite drift sembast objectbox; do
  (
    echo "Running $project"
    cd "$project"
    if [ "$project" = objectbox ] && [ ! -f lib/libobjectbox.dylib ]; then
      curl -sf https://raw.githubusercontent.com/objectbox/objectbox-dart/v5.3.2/install.sh | bash -s -- --quiet
    fi
    dart pub get
    dart build cli -t bin/speed.dart -o build/speed
    build/speed/bundle/bin/speed
    rm -rf build
    echo "Results written to $project/speed_results.md"
  )
done
