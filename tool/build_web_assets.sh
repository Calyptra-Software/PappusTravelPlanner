#!/usr/bin/env bash
# Regenerates the two prebuilt files the web build needs in web/, from the
# versions pubspec.lock resolves:
#
#   web/sqlite3.wasm     the release asset of package:sqlite3, unchanged
#   web/drift_worker.js  drift's worker, compiled here at -O4
#
# Run it after `flutter pub get` whenever drift or sqlite3 move. CI runs it too
# and fails if the result differs from what is committed, so a bump that left
# these behind cannot merge green (AGENTS.md, "Web").
#
# The worker is compiled at -O4 because that is the level drift compiles its
# own released worker at, and the one level that keeps drift's null test on
# `navigator.locks`: below it the worker hangs in every insecure context (see
# AGENTS.md). dart2js output depends on the Dart SDK, so a Flutter upgrade can
# change the worker without any package moving; that is a regeneration too.
set -euo pipefail

cd "$(dirname "$0")/.."

[ -f .dart_tool/package_config.json ] || {
  echo "Run 'flutter pub get' first." >&2
  exit 1
}

# The version of a hosted package as resolved in pubspec.lock.
locked_version() {
  awk -v pkg="  $1:" '
    $0 == pkg { found = 1; next }
    found && /^  [^ ]/ { exit }
    found && $1 == "version:" { gsub(/"/, "", $2); print $2; exit }
  ' pubspec.lock
}

sqlite3_version=$(locked_version sqlite3)
drift_version=$(locked_version drift)
[ -n "$sqlite3_version" ] && [ -n "$drift_version" ] || {
  echo "drift or sqlite3 not found in pubspec.lock" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqlite3_version/sqlite3.wasm"

# Compiled from outside lib/ so nothing ships with it, against this project's
# package config so it resolves the drift this app is built with.
printf "import 'package:drift/wasm.dart';\n\nvoid main() => WasmDatabase.workerMainForOpen();\n" \
  >"$tmp/drift_worker.dart"
dart compile js -O4 --no-source-maps \
  --packages=.dart_tool/package_config.json \
  -o "$tmp/drift_worker.js" "$tmp/drift_worker.dart" >/dev/null
cp "$tmp/drift_worker.js" web/drift_worker.js

echo "web/sqlite3.wasm from sqlite3 $sqlite3_version, web/drift_worker.js from drift $drift_version."
