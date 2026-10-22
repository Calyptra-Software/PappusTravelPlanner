# F-Droid

Pappus is on F-Droid as [dev.calyptra.pappus](https://f-droid.org/packages/dev.calyptra.pappus/),
since 1.13.2. Two things decide what appears there, and only one of them lives in this
repository:

- **`fastlane/metadata/android/`** — the listing. F-Droid pulls the title, the two
  descriptions, the icon, the screenshots and the changelog out of *this* repository, so
  they stay under the maintainer's control and translations arrive without anybody
  editing F-Droid's own data. The layout is the Fastlane/Triple-T one; none of Fastlane
  is needed to produce it.
- **`metadata/dev.calyptra.pappus.yml` in [fdroiddata](https://gitlab.com/fdroid/fdroiddata)**
  — the build recipe. It is F-Droid's file, not this project's: a copy used to be kept
  here, but the bot below rewrites the real one on every release, so a copy could only
  drift from it.

## Releases reach F-Droid by themselves

`checkupdates-bot` watches the **git tags**, not the GitHub releases: for a new `v*` tag
it reads the version out of `pubspec.yaml` (`UpdateCheckData`), copies the last build
blocks with the new commit and versionCodes, and opens the merge request in fdroiddata
itself. F-Droid's build server then rebuilds the release, compares it with the APKs on the
releases page, and publishes them some days later. Cutting a release the usual way
(`CONTRIBUTING.md`) is all that is needed.

The recipe has to be edited by hand only when what the bot copies stops being true: when
a Flutter upgrade moves `flutter.ndkVersion` (the recipe's `ndk:` must follow, see below),
or when the build steps change — the version of Flutter is read out of
`.github/workflows/release.yml`, so moving that line breaks the recipe too. That is a
merge request against fdroiddata from a fork. Check it with `fdroid lint
dev.calyptra.pappus` and a real `fdroid build -v dev.calyptra.pappus:<versionCode>`, which
compares the result with the published APK just as F-Droid's server will.

## What each release needs

The changelog is `fastlane/metadata/android/*/changelogs/default.txt`, which F-Droid uses
as the fallback for every version. It is *not* per-version here on purpose: with
`--split-per-abi` a release carries three versionCodes (4061, 4062, 4063 for 1.13.2), so
per-version files would mean writing the same text three times every release.

Only `en-US` and `de-DE` have one, and `zh-CN` deliberately does not. Because
`default.txt` applies to every version, a Chinese one that was not rewritten at a release
would go on showing the notes of whichever release it was last written for, and nobody
here can write it. Without the file, F-Droid has no Chinese changelog to offer, and the
client shows another language's.

## Things that would break the build, and why they do not

- **Google Play Services.** `third_party/geolocator_android` exists so no proprietary code
  is linked in; see AGENTS.md. F-Droid's scanner rejects both the Gradle coordinate and
  the class references in the dex, and CI checks the release classpath on every pull
  request so this cannot regress quietly.
- **Prebuilt native libraries.** `package:sqlite3` downloads a ready-made `libsqlite3.so`
  unless told otherwise, and F-Droid requires it built from source. `pubspec.yaml` points
  its hook at the amalgamation in `third_party/sqlite3`, which the release build compiles
  too, so the verified builds still match; CI fails a build that downloads it.
- **Binaries in the tree.** `web/sqlite3.wasm` is one, which is why the recipe's `rm:`
  drops `web/` along with the other platforms it does not build.
- **Generated sources.** The `*.g.dart` files and the localizations are committed, so the
  build needs no `build_runner` step.
- **A lockfile.** `pubspec.lock` is committed, which is what lets the recipe use
  `flutter pub get --enforce-lockfile`.

## Signing: verified builds

The recipe carries `binary:` and `AllowedAPKSigningKeys`, so F-Droid rebuilds each release
from source, compares it against the APK published here, and — only on a match — ships the
one **this project signed**. Nothing F-Droid signs is published for this app. The point is
continuity: somebody who installed a GitHub APK can switch to F-Droid without uninstalling,
because it is the same file.

That was measured before it was promised. Against the published 1.11.1, all three ABIs:
409 of 409 entries identical, none missing or extra, and `apksigcopier` plus
`apksigner verify` — which is exactly what `common.verify_apks` does inside `fdroid build` —
accept the published signature on the locally rebuilt APK. The first version F-Droid
published, 1.13.2, is byte for byte the same three files as the GitHub release.

Four things have to be true for that, and all four are load-bearing rather than incidental:

- **No GNU build ID in `libdartjni.so`.** `android/build.gradle.kts` passes
  `-Wl,--build-id=none` to `jni`'s CMake. Without it the two builds differ in exactly 20
  bytes, which a v2 signature covers as surely as a megabyte.
- **The same build command as the release workflow**, `flutter build apk --release
  --split-per-abi` with **no** `--target-platform`. That flag changes
  `assets/flutter_assets/NativeAssetsManifest.json`, which lists the ABIs the native-asset
  hooks built for. Each build block therefore builds all three ABIs and keeps one, which
  costs F-Droid three times the work and is the price of matching.
- **The same build path.** `libapp.so` — the AOT-compiled Dart, 13 MB of the APK — embeds
  the directory it was built in, and 29 % of its bytes change with it. Measured three ways:
  two builds at one path are byte-identical, three builds at three paths differ pairwise,
  and a build at the CI's own path matches the CI. Hence the `mv` to
  `/home/runner/work/PappusTravelPlanner/PappusTravelPlanner`, which is where
  `actions/checkout` puts the repository in `.github/workflows/release.yml`.
- **The same NDK for the SQLite build hook.** The hook compiles `libsqlite3.so` with the NDK
  in `ANDROID_NDK_HOME`, which fdroidserver sets to the recipe's `ndk:` and GitHub's runners
  to their own default. 1.13.1 was built with r27d there and could not be reproduced with
  r28c. Both workflows now run `tool/pin_ndk.sh` before building, which sets it to
  `flutter.ndkVersion`, and `tool/check_apk_ndk.py` fails the job if a library compiled here
  names a different NDK. The recipe's `ndk:` must name that same release.

The cost of this arrangement is worth stating: if a release ever fails to reproduce,
F-Droid publishes **nothing** for it rather than falling back to signing its own — and
dropping `binary:` later would change the signature for everyone who installed from
F-Droid, which is the same forced reinstall 1.11.0 imposed once. So the four points above
are not tidiness; they are what has to keep holding.

