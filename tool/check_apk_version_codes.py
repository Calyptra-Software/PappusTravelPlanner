#!/usr/bin/env python3
"""Checks that each per-ABI APK carries the versionCode this repository gives it.

`android/app/build.gradle.kts` numbers the split APKs `build number × 10 + 1|2|3`
(armeabi-v7a, arm64-v8a, x86_64), and F-Droid's recipe computes the same numbers
from `pubspec.yaml` and refuses a build whose APK disagrees. The override is
easy to lose without anything else noticing: Flutter 3.50 moved its own per-ABI
codes to another Gradle API, the old override then read Flutter's number as its
base, and 1.17.0 was released as 14101–14103 instead of 4101–4103. The build,
the tests and the APKs themselves gave no sign of it.

    tool/check_apk_version_codes.py app-*-release.apk

The build number is read from `pubspec.yaml`, the versionCode and ABI from each
APK with `aapt2 dump badging`. aapt2 is taken from `--aapt2`, else from the
newest build-tools under `ANDROID_HOME` (or `ANDROID_SDK_ROOT`).
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys

ABI_CODES = {"armeabi-v7a": 1, "arm64-v8a": 2, "x86_64": 3}


def find_aapt2() -> str | None:
    for var in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        sdk = os.environ.get(var)
        if not sdk:
            continue
        candidates = sorted(
            pathlib.Path(sdk, "build-tools").glob("*/aapt2"),
            key=lambda p: [int(x) if x.isdigit() else x for x in re.split(r"[.-]", p.parent.name)],
        )
        if candidates:
            return str(candidates[-1])
    return None


def build_number(pubspec: str) -> int:
    match = re.search(r"^version:\s*\S+\+(\d+)\s*$", pathlib.Path(pubspec).read_text(), re.M)
    if not match:
        raise SystemExit(f"::error::No build number in {pubspec}")
    return int(match.group(1))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--pubspec", default="pubspec.yaml")
    parser.add_argument("--aapt2", help="path to aapt2 (default: newest in the Android SDK)")
    parser.add_argument("apks", nargs="+")
    args = parser.parse_args()

    aapt2 = args.aapt2 or find_aapt2()
    if not aapt2:
        print("::error::aapt2 not found; set ANDROID_HOME or pass --aapt2", file=sys.stderr)
        return 1
    build = build_number(args.pubspec)

    failed = False
    for apk in args.apks:
        badging = subprocess.run(
            [aapt2, "dump", "badging", apk], check=True, capture_output=True, text=True
        ).stdout
        version_code = int(re.search(r"versionCode='(\d+)'", badging).group(1))
        abis = re.findall(r"'([^']+)'", (re.search(r"^native-code:(.*)$", badging, re.M) or [""])[0])
        if len(abis) != 1 or abis[0] not in ABI_CODES:
            print(f"::error::{apk}: expected one of {sorted(ABI_CODES)}, found {abis}", file=sys.stderr)
            failed = True
            continue
        expected = build * 10 + ABI_CODES[abis[0]]
        print(f"{version_code:>7}  {abis[0]:<12} {apk}")
        if version_code != expected:
            print(f"::error::{apk}: versionCode {version_code}, expected {expected}"
                  f" (build number {build} × 10 + {ABI_CODES[abis[0]]})", file=sys.stderr)
            failed = True

    if failed:
        return 1
    print(f"All {len(args.apks)} APKs carry build number {build} × 10 + their ABI's code.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
