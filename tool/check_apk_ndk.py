#!/usr/bin/env python3
"""Checks that the native libraries compiled during this build share one NDK.

Every library the NDK links carries a `.note.android.ident` ELF note naming the
NDK release and build number it came from. A release APK holds libraries from
two different build paths: Gradle compiles `libdartjni.so` with the NDK the app
pins (`flutter.ndkVersion`), while the SQLite build hook compiles
`libsqlite3.so` with whatever NDK Flutter finds first, and Flutter looks at
`ANDROID_NDK_HOME` before anything else. GitHub's runners set that variable to
their own default NDK, so the two paths drifted apart unnoticed — and F-Droid,
which sets it to the recipe's NDK, then built a different `libsqlite3.so` than
the release it was meant to reproduce. tool/pin_ndk.sh fixes the variable;
this checks that it worked, on the APKs themselves.

Only the libraries compiled *here* are checked. An APK also carries native
code that arrives prebuilt — `libflutter.so` from the Flutter engine, and
libraries inside AndroidX AARs such as `libdatastore_shared_counter.so` — each
built with whatever NDK its publisher used, so "one NDK for everything" is not
a property any APK has.

    tool/check_apk_ndk.py [--expect 28.2.13676358] app-*.apk

With `--expect`, the libraries must also carry that version's build number.
Each name in `--libs` must be found, so a renamed library fails loudly rather
than quietly leaving nothing to check. The note is read straight out of the
ELF file, so no NDK tools are needed.
"""

import argparse
import struct
import sys
import zipfile


def android_ident(elf: bytes):
    """Returns (ndk release, build number) from `.note.android.ident`, or None."""
    if elf[:4] != b"\x7fELF":
        return None
    is64 = elf[4] == 2
    endian = "<" if elf[5] == 1 else ">"
    if is64:
        shoff, = struct.unpack_from(endian + "Q", elf, 0x28)
        shentsize, shnum, shstrndx = struct.unpack_from(endian + "HHH", elf, 0x3A)
    else:
        shoff, = struct.unpack_from(endian + "I", elf, 0x20)
        shentsize, shnum, shstrndx = struct.unpack_from(endian + "HHH", elf, 0x2E)

    def section(i):
        base = shoff + i * shentsize
        if is64:
            name, _, _, _, offset, size = struct.unpack_from(endian + "IIQQQQ", elf, base)
        else:
            name, _, _, _, offset, size = struct.unpack_from(endian + "IIIIII", elf, base)
        return name, offset, size

    _, str_off, str_size = section(shstrndx)
    names = elf[str_off:str_off + str_size]
    for i in range(shnum):
        name_idx, offset, size = section(i)
        name = names[name_idx:names.index(b"\0", name_idx)]
        if name != b".note.android.ident":
            continue
        namesz, descsz, _ = struct.unpack_from(endian + "III", elf, offset)
        desc = offset + 12 + ((namesz + 3) & ~3)
        data = elf[desc:desc + descsz]
        # api level (4 bytes), NDK release (64 bytes), NDK build number (64 bytes)
        release = data[4:68].split(b"\0")[0].decode()
        build = data[68:132].split(b"\0")[0].decode()
        return release, build
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--expect", help="NDK version the libraries must come from, e.g. 28.2.13676358")
    parser.add_argument("--libs", default="libsqlite3.so,libdartjni.so",
                        help="comma-separated libraries compiled during this build")
    parser.add_argument("apks", nargs="+")
    args = parser.parse_args()
    expected_build = args.expect.split(".")[-1] if args.expect else None
    wanted = set(args.libs.split(","))

    seen = {}
    for apk in args.apks:
        with zipfile.ZipFile(apk) as z:
            for entry in sorted(z.namelist()):
                if not entry.startswith("lib/") or entry.rsplit("/", 1)[-1] not in wanted:
                    continue
                ident = android_ident(z.read(entry))
                if ident is None:
                    continue  # a library not linked by the NDK says nothing either way
                seen[f"{apk}!{entry}"] = ident

    missing = wanted - {where.rsplit("/", 1)[-1] for where in seen}
    if missing:
        print(f"::error::Not found in any APK: {sorted(missing)}", file=sys.stderr)
        return 1
    for where, (release, build) in seen.items():
        print(f"{release:>6} {build:>10}  {where}")

    builds = {build for _, build in seen.values()}
    if len(builds) > 1:
        print(f"::error::The libraries compiled here come from {len(builds)} NDKs: {sorted(builds)}"
              " — see tool/pin_ndk.sh", file=sys.stderr)
        return 1
    if expected_build and builds != {expected_build}:
        print(f"::error::The libraries compiled here were built with NDK build {builds.pop()},"
              f" expected {args.expect}", file=sys.stderr)
        return 1
    print(f"All {len(seen)} libraries compiled here were built with one NDK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
