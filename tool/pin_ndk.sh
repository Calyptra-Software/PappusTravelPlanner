#!/usr/bin/env bash
# Makes every native library in an Android build come from the NDK the app
# pins, by pointing ANDROID_NDK_HOME at it.
#
# Two build paths compile native code. Gradle builds libdartjni.so with
# `ndkVersion = flutter.ndkVersion`; the SQLite build hook (see
# third_party/sqlite3) builds libsqlite3.so with whatever NDK Flutter finds
# first, and Flutter looks at ANDROID_NDK_HOME before anything else. GitHub's
# runners set that variable to their own default NDK, which is how 1.13.1
# shipped a libsqlite3.so built with r27d beside a libdartjni.so built with
# r28c — and F-Droid, which sets ANDROID_NDK_HOME to the recipe's NDK, could
# not reproduce it. Pointing the variable at Gradle's NDK makes both paths, on
# every machine, use one compiler.
#
# The version is read from the Flutter SDK, which is where flutter.ndkVersion
# comes from, so it moves with a Flutter upgrade instead of being a third copy
# of the number. The F-Droid recipe's `ndk:` has to name the same release.
#
# On GitHub Actions the variables are written to $GITHUB_ENV for the steps that
# follow. Elsewhere the script prints `export` lines:
#     eval "$(tool/pin_ndk.sh)"
set -euo pipefail

flutter_root=${FLUTTER_ROOT:-$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")}
extension=$(find "$flutter_root/packages/flutter_tools/gradle" -name FlutterExtension.kt | head -n1)
version=$(sed -nE 's/.*val ndkVersion: String = "([0-9.]+)".*/\1/p' "$extension")
if [ -z "$version" ]; then
  echo "Could not read flutter.ndkVersion from $extension" >&2
  exit 1
fi

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
[ -n "$sdk" ] || { echo "ANDROID_HOME is not set" >&2; exit 1; }
ndk="$sdk/ndk/$version"
if [ ! -x "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ]; then
  sdkmanager=$(find "$sdk/cmdline-tools" -path '*/bin/sdkmanager' 2>/dev/null | sort -V | tail -n1)
  [ -n "$sdkmanager" ] || { echo "NDK $version is missing and sdkmanager was not found" >&2; exit 1; }
  echo "Installing NDK $version" >&2
  # `yes` only answers the license prompts, and it always fails: it is still
  # writing when sdkmanager exits, so it dies of a broken pipe — which
  # pipefail would report as the install failing. Its status is not the
  # question; sdkmanager's is, and whether the compiler is there afterwards.
  # This branch went untested until GitHub's runner image stopped shipping
  # this NDK (ubuntu-24.04 20261002), and then failed every Android build.
  { yes || true; } | "$sdkmanager" --install "ndk;$version" >/dev/null
  [ -x "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ] || {
    echo "sdkmanager reported success, but NDK $version has no clang at $ndk" >&2
    exit 1
  }
fi

vars=(
  "ANDROID_NDK_HOME=$ndk"
  "ANDROID_NDK_ROOT=$ndk"
  "ANDROID_NDK=$ndk"
  "PAPPUS_NDK_VERSION=$version"
)
if [ -n "${GITHUB_ENV:-}" ]; then
  printf '%s\n' "${vars[@]}" >> "$GITHUB_ENV"
  echo "Pinned NDK $version for the steps that follow." >&2
else
  printf 'export %s\n' "${vars[@]}"
fi
