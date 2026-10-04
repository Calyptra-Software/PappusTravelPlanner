# SQLite — vendored amalgamation

The SQLite this app is built with: the official
[amalgamation](https://sqlite.org/amalgamation.html), unmodified.
`hooks.user_defines` in `pubspec.yaml` points `package:sqlite3` at `sqlite3.c`
here, so the library is compiled during the build instead of being downloaded.

## Why

`package:sqlite3` resolves its native library through a Dart build hook whose
default downloads a ready-made `libsqlite3.so` per ABI from the package's own
GitHub releases, and that binary is what ends up in the APK. It is built from
upstream sources, but not built here. F-Droid requires every native library in
an app to be built from source; a maintainer confirmed that this applies here
(fdroiddata!47901). Since the published APKs are verified against F-Droid's own
build, this repository's build has to compile SQLite the same way, which is why
the copy lives here and not only in F-Droid's recipe.

## Provenance

<!-- provenance:start -->
SQLite **3.53.4**, from:

    https://sqlite.org/2026/sqlite-amalgamation-3530400.zip
    SHA3-256  628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e   (as published on sqlite.org/download.html)
    sha256    b1dd5d74ec7f29055a6684fa06fb3c2f6821c87dd38f9a458dfd2e8a1db28189   sqlite3.c
    sha256    919e7f2e8ed1d8f56ac17b412b8971c76aa5d1a879752cc6058f75e7d5910e1d   sqlite3.h
<!-- provenance:end -->

`shell.c` and `sqlite3ext.h` from the same archive are not copied: the first is
the `sqlite3` command-line tool and the second is for loadable extensions,
neither of which this app builds. Both files here are byte for byte upstream.
Unlike `third_party/geolocator_android`, nothing is patched, and nothing should
be.

## Compile-time options

None are set here. The hook's default options stay on, so `package:sqlite3`
applies the same list it compiles its own binaries with (FTS5, RTREE, math
functions, `SQLITE_DQS=0`, the session and preupdate hooks, and the rest).
That is deliberate: drift relies on several of them, and this copy is meant to
change *how* SQLite is built, not *what* it can do. 3.53.4 is also the version
`package:sqlite3` 3.7.0 ships prebuilt, so switching changed nothing about
SQLite itself.

## Updating

Upgrading `package:sqlite3` no longer moves the SQLite version with it: the
version is this directory, and keeping it current is this project's job.
SQLite security fixes matter here, since the app opens database files it did
not create.

    tool/update_sqlite.sh            # take the current release from sqlite.org
    tool/update_sqlite.sh 3.53.5     # the same, but refuse anything else

The script reads the current release and its SHA3-256 from sqlite.org's
download page, checks the archive against that hash before unpacking it,
replaces `sqlite3.c` and `sqlite3.h`, and rewrites the provenance block above.
Then run `flutter test` — the schema-migration tests are what exercise SQLite
hardest here — and cut a release: a new SQLite reaches F-Droid only with a new
tag, like any other change to the APK.
