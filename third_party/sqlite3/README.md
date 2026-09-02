# SQLite — vendored amalgamation

The SQLite source this app is built with: the official
[amalgamation](https://sqlite.org/amalgamation.html), version **3.53.4**,
unmodified. `pubspec.yaml`'s `hooks.user_defines` points `package:sqlite3` at
`sqlite3.c` here, so the library is compiled during the build instead of being
downloaded.

## Why

`package:sqlite3` resolves its native library through a Dart build hook whose
default is `PrecompiledFromGithubAssets`: it downloads a ready-made
`libsqlite3.so` per ABI from the package's own GitHub releases, and that binary
is what ends up in the APK. Nothing about it is proprietary — SQLite is public
domain and those binaries are built from upstream sources in GitHub Actions
with pinned hashes — but F-Droid builds everything it ships from source, and a
binary fetched during the build is not that. It also makes every build depend
on GitHub being reachable, and it is the one thing standing between this
project and reproducible builds.

## Provenance

    https://sqlite.org/2026/sqlite-amalgamation-3530400.zip
    SHA3-256  628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e   (as published on sqlite.org/download.html)
    sha256    b1dd5d74ec7f29055a6684fa06fb3c2f6821c87dd38f9a458dfd2e8a1db28189   sqlite3.c
    sha256    919e7f2e8ed1d8f56ac17b412b8971c76aa5d1a879752cc6058f75e7d5910e1d   sqlite3.h

`shell.c` and `sqlite3ext.h` from the same archive are not copied: the first is
the `sqlite3` command-line tool and the second is for loadable extensions,
neither of which this app builds. Both files here are byte-for-byte upstream —
unlike `third_party/geolocator_android`, nothing is patched, and nothing should
be.

## Compile-time options

None are set here. `default_options` in `pubspec.yaml` is left on, so
`package:sqlite3` applies the same list it compiles its own binaries with
(FTS5, RTREE, math functions, `SQLITE_DQS=0`, session and preupdate hooks, and
the rest). That is deliberate: drift relies on several of them, and this change
is meant to alter *how* SQLite is built, not *what* it can do. 3.53.4 is the
version the downloaded binaries were at when this was written, so the same
commit changes nothing about SQLite itself.

## Updating

Download the new amalgamation from sqlite.org, check its SHA3-256 against the
download page, replace both files, and update the hashes above. Then run the
tests — the schema-migration tests are what exercise SQLite hardest here. Note
that upgrading `package:sqlite3` no longer moves the SQLite version with it:
the version is this directory, and keeping it current is now this project's
job rather than upstream's.

## What it costs

Measured on an arm64 release build: the self-compiled library is about 19 KB
larger than the downloaded one (1 851 376 against 1 831 352 bytes unstripped),
which is 0.07 % of the APK. A cold build spends about 35 seconds per ABI
compiling it — the amalgamation is one translation unit and cannot be
parallelised. Incremental builds reuse the hook runner's cache.
