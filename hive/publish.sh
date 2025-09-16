set -e

cd ../hive_ce_inspector
dart pub get
dart run devtools_extensions build_and_copy --source=. --dest=../hive/extension/devtools
dart run devtools_extensions validate --package=../hive

cd ../hive
dart pub publish