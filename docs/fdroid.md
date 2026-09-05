# Getting onto F-Droid

Two things live in this repository for F-Droid's sake, and neither of them is read by
the app:

- **`fastlane/metadata/android/`** — the listing. F-Droid pulls the title, the two
  descriptions, the icon, the screenshots and the changelog out of *this* repository, so
  they stay under the maintainer's control and translations arrive without anybody
  editing F-Droid's own data. The layout is the Fastlane/Triple-T one; none of Fastlane
  is needed to produce it.
- **`fdroid/metadata/dev.calyptra.pappus.yml`** — the build recipe, kept here so it can
  be reviewed and versioned alongside the thing it builds. F-Droid does *not* read it
  from here: it has to be copied into a fork of
  [fdroiddata](https://gitlab.com/fdroid/fdroiddata) and offered as a merge request.

## Submitting

1. Fork `gitlab.com/fdroid/fdroiddata`, clone it, branch as `dev.calyptra.pappus`.
2. Copy `fdroid/metadata/dev.calyptra.pappus.yml` to `metadata/` in that clone.
3. Check it with `fdroid readmeta`, `fdroid lint dev.calyptra.pappus`, and — the one that
   matters — a real build, `fdroid build -v -l dev.calyptra.pappus`, ideally in the
   buildserver VM rather than on the host.
4. Open the merge request. Expect review, and expect it to take days rather than hours.

Once it is merged, `checkupdates-bot` watches the **git tags**, not the GitHub releases:
it reads the version out of `pubspec.yaml` through `UpdateCheckData`, writes new build
blocks and opens the merge request itself. Cutting a release the usual way
(`CONTRIBUTING.md`) is all that is needed after that.

## What each release needs

The changelog is `fastlane/metadata/android/*/changelogs/default.txt`, which F-Droid uses
as the fallback for every version. It is *not* per-version here on purpose: with
`--split-per-abi` a release carries three versionCodes (1012, 2012, 4012 for 1.11.0), so
per-version files would mean writing the same text three times every release.

## Things that would break the build, and why they do not

- **Google Play Services.** `third_party/geolocator_android` exists so no proprietary code
  is linked in; see AGENTS.md. F-Droid's scanner rejects both the Gradle coordinate and
  the class references in the dex, and CI checks the release classpath on every pull
  request so this cannot regress quietly.
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
accept the published signature on the locally rebuilt APK.

Three things had to be true for that, and all three are load-bearing rather than incidental:

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

The cost of this arrangement is worth stating: if a release ever fails to reproduce,
F-Droid publishes **nothing** for it rather than falling back to signing its own — and
dropping `binary:` later would change the signature for everyone who installed from
F-Droid, which is the same forced reinstall 1.11.0 imposed once. So the three points above
are not tidiness; they are what has to keep holding.

