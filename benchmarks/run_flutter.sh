#!/bin/sh
set -eu

if [ "$#" -ne 0 ] && { [ "$#" -ne 1 ] || [ "$1" != '--no-build' ]; }; then
  echo "Usage: $0 [--no-build]" >&2
  exit 64
fi

cd "$(dirname "$0")"
root=$(pwd -P)
main="$root/hive_ce_flutter"
v4="$root/.hive_v4_flutter"
app=hive_ce_flutter_benchmark

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$work/main" "$work/v4"
ln -s "$root/hive_v4/assets" "$work/v4/assets"

run_app() (
  executable="$1/build/macos/Build/Products/Release/$app.app/Contents/MacOS/$app"
  if [ ! -x "$executable" ]; then
    echo "Release build missing in $1. Run without --no-build first." >&2
    exit 1
  fi
  cd "$work/$2"
  HIVE_BENCH_RESULT_FILE="$work/$2.json" "$executable"
)

build_v4() {
  # Hive v2 and v4 resolve different versions of the same package. Build v4
  # in a separate project using the same macOS runner, with its own pubspec.
  mkdir -p "$v4/macos" "$v4/bin"
  rsync -a --exclude Pods --exclude Podfile --exclude Podfile.lock \
    --exclude ephemeral --exclude GeneratedPluginRegistrant.swift \
    --exclude xcuserdata "$main/macos/" "$v4/macos/"
  cp "$main/pubspec.v4.yaml" "$v4/pubspec.yaml"
  cp "$main/bin/v4.dart" "$v4/bin/v4.dart"
  (cd "$v4/macos" && pod deintegrate)
  (cd "$v4" && flutter build macos --release --target bin/v4.dart)
}

if [ "$#" -eq 0 ]; then
  (cd "$main" && flutter build macos --release)
  build_v4
fi

run_app "$main" main
run_app "$v4" v4
dart --packages="$main/.dart_tool/package_config.json" common/bin/report.dart \
  "$work/main.json" "$work/v4.json"
