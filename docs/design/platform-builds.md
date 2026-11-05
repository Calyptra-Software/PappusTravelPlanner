# Platform builds, releases and vendored code

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for Gradle/AGP, signing, release and CI builds, side-by-side builds, Linux/Windows packaging, the vendored geolocator and SQLite, the permission count.

## Permissions: count them in the APK

`SECURITY.md` names the hosts the app contacts and the permissions it asks for, and both
facts have already drifted once. The tile server arrived with the map and left a file still saying one host; androidx
`work-runtime` merged five permissions into the manifest and left it saying four, and neither
was noticed here: the second surfaced only when **F-Droid's code-quality report printed the
list off the built APK**, which is what their store page publishes too. So what the manifest
merger produces is on show whether or not this repository mentions it, and the number to
check is the one in the **APK** (`androguard axml`, or the merger's own report under
`build/app/outputs/logs/`). Counting `uses-permission` lines in
`android/app/src/main/AndroidManifest.xml` was never right and is now wrong in both
directions: the file carries `tools:node="remove"` entries that *subtract* from the merged
result.

## Vendored native code

- **The Android half of `geolocator` is a copy in this repository, without Google
  Play Services.** `third_party/geolocator_android` is the published 5.0.3 with four
  edits — the `com.google.android.gms:play-services-location` dependency, `FusedLocationClient`,
  and the branch in `GeolocationManager` that chose between them, plus the foreground
  notification's channel importance (above) — and `dependency_overrides`
  in `pubspec.yaml` puts it in place of the pub.dev package for **every** build, not for a
  variant: there is no Play Store listing to keep GMS for, and one artifact per release is
  what leaves the door open to reproducible builds later. The reason is F-Droid, which
  refuses proprietary code on two independent counts — its source scanner matches the Gradle
  line against a non-free list, and its APK scanner runs `dexdump` and matches
  `com/google/android/gms` against the *whole* output, which is why upstream's documented
  `exclude group:` is not enough: that removes the class definitions and leaves the
  references in the dex. What is given up is the Play Services dialog that switches location
  on without leaving the app, which this app never used — `device_location.dart` answers
  those three states itself — and, below Android 12, the fused provider:
  `LocationManagerClient` prefers `LocationManager.FUSED_PROVIDER` from 12 onwards and falls
  back to GPS. Everything else is upstream's own code, the foreground service included, so
  recording a track needs nothing from Google either. The copy carries no permissions of its
  own; the seven in `SECURITY.md` are the app's own statement, `FOREGROUND_SERVICE_LOCATION`
  included, which upstream deliberately does not declare (5.1.1+1). Keep the edits
  minimal and the version equal to the upstream release they were taken from — the copy is
  meant to stay a diff that can be rebased, forked, or offered upstream, where the
  maintainer has said he would take a Play-Services-free path as long as GMS stays the
  default (Baseflow/flutter-geolocator#841). `third_party/geolocator_android/README.md`
  holds the details; `analysis_options.yaml` excludes the directory, because this project's
  lints are not about somebody else's code.
- **SQLite is compiled from a copy in this repository, not downloaded.**
  `package:sqlite3` resolves its native library through a build hook whose default fetches
  a ready-made `libsqlite3.so` per ABI from the package's GitHub releases, and that binary
  is what used to ship. F-Droid requires native libraries to be built from source, and a
  maintainer confirmed that this applies here (fdroiddata!47901) — while, measured on the
  metadata at the time, 34 of 37 Flutter apps they ship on `package:sqlite3` 3.x still
  download it, so "other apps do it" is not evidence of what a reviewer will accept. Since
  the published APKs are verified against F-Droid's own build, compiling only in the recipe
  would have broken that match; the copy has to live here. So `hooks.user_defines` in
  `pubspec.yaml` points the hook at `third_party/sqlite3/sqlite3.c`, the unmodified
  amalgamation, with the hook's default options left on so the compile-time flags stay the
  ones `package:sqlite3` builds its own binaries with — drift relies on several of them,
  and this changes *how* SQLite is built, not what it can do. Nothing there is patched,
  and nothing should be: the copy's value is that it is byte for byte sqlite.org's.
  The consequence to remember is that **bumping `package:sqlite3` no longer moves the
  SQLite version**: the version is that directory, Dependabot cannot see it, and keeping it
  current is this project's job. `tool/update_sqlite.sh` does the mechanical part — it
  reads the current release and its SHA3-256 off sqlite.org's download page, refuses an
  archive that does not match, and rewrites the provenance block in
  `third_party/sqlite3/README.md`. What it costs, measured: 10–22 KB per ABI, and about a
  minute on a cold release build (198 s against 139 s for three ABIs), since the
  amalgamation is one translation unit and the three compiles run one after another; the
  hook runner caches the result, so incremental builds pay nothing. What it does *not*
  cost, also measured: two cold builds gave byte-identical APKs, and the library carries no
  GNU build ID and no embedded path — the two things that made `libdartjni.so` differ —
  so it needs no `-Wl,--build-id=none`. The `Check SQLite was compiled, not downloaded`
  step in CI fails a build that has gone back to downloading, which otherwise looks
  exactly like one that has not.
  **Which compiler builds it is not Gradle's choice, and that cost a release.** Gradle
  compiles `libdartjni.so` with `ndkVersion = flutter.ndkVersion`, but the hook gets its
  compiler from Flutter, which takes `ANDROID_NDK_HOME` before anything else and only
  then the newest NDK in the SDK. Locally there is one NDK and no variable, so both agree;
  GitHub's runners set the variable to their own default NDK, so 1.13.1 shipped a
  `libsqlite3.so` built with **r27d** beside a `libdartjni.so` built with r28c — and
  fdroidserver sets the same variable to the recipe's `ndk:`, so F-Droid compiled it with
  r28c and could not reproduce the release (1.58 million of 1.75 million bytes differ).
  Two local builds agreeing proved nothing about this, since they share the one thing
  that differed. `tool/pin_ndk.sh` therefore points `ANDROID_NDK_HOME` at
  `flutter.ndkVersion`, read from the Flutter SDK rather than copied, in both workflows
  before the build; `tool/check_apk_ndk.py` then reads the NDK each compiled-here library
  names in its `.note.android.ident` and fails the job unless both carry that version.
  Only those two are checked: `libflutter.so` and AndroidX's
  `libdatastore_shared_counter.so` arrive prebuilt, with whatever NDK their publishers
  used. The recipe's `ndk:` has to name the same release, so a Flutter upgrade that moves
  `flutter.ndkVersion` means a merge request to the recipe in fdroiddata in the same breath
  (`docs/fdroid.md`).

## Releases, signing and packaging

- **A release is a tag, not a build somebody ran.** Pushing `v<version>` to `main` runs
  `.github/workflows/release.yml`: it checks the tag against `pubspec.yaml`, builds the
  three per-ABI APKs signed from repository secrets and the Linux, Windows and web packages beside them, and
  opens a **draft** release for a human to check the signing fingerprint before publishing. So never build and upload a
  release artifact by hand — the point of the workflow is that the environment which
  produced a published APK is knowable, which is also what a later move to F-Droid's
  verified builds would need. `CONTRIBUTING.md` has the steps. The same goal is why
  `android/build.gradle.kts` passes `-Wl,--build-id=none` to `jni`'s CMake: that build ID
  was the only thing making two builds of one tag differ, and the comment there says how
  it was measured.
- **An APK's signing block carries more than signatures, and one of the passengers is
  not ours.** AGP writes the resolved dependency tree into it by default — compressed and
  **encrypted with a Google Play signing key**, so nobody but Google can read it — and
  F-Droid's APK scanner rejects the block on sight (`found extra signing block 'Dependency
  metadata'`, id `0x504B4453`). `dependenciesInfo { includeInApk = false }` in
  `android/app/build.gradle.kts` is what turns it off; there is no Play listing here that
  would ever have consumed it. Two things about how this was found are worth keeping.
  It is invisible to everything else: the app runs, `flutter build` is silent, the APK
  verifies, two builds of one tag are still byte-identical — and `fdroid build` says
  nothing either, because reproducibility is a question about *whether two builds agree*
  and this is a question about *what is inside one*. Only F-Droid's separate `check apk`
  job looks. So a released APK is worth scanning for signing blocks as its own step; the
  scanner is `fdroidserver.scanner.APK_SIGNING_BLOCK_IDS` against
  `common.get_androguard_APK(f)._v2_blocks`, and everything in that dict is a rejection
  while `0x7109871A` (signature scheme v2) and `0x42726577` (verity padding) are the two
  that belong there.
- **The three per-ABI APKs are numbered by this repository, not by Flutter.** `abiCodes`
  in `android/app/build.gradle.kts` overrides each split's `versionCodeOverride` to
  `build number × 10 + 1|2|3` (armeabi-v7a, arm64-v8a, x86_64), which is the scheme F-Droid
  asks Flutter apps for and which `VercodeOperation: 10 * %c + N` in the recipe mirrors.
  Flutter's own scheme is `1|2|4 × 1000 + build number`; ours wins because this block runs
  after the plugin's, which was measured rather than assumed. Two things about it are sharp.
  It **counts smaller** than what it replaced — at build 15 it gives 151/152/153 where the
  released APKs are 1015/2015/4015 — and Android refuses an update whose number is lower, so
  the switch cost a jump of the build number to **402**, the first value leaving all three
  above their predecessors. And a version code is forever: it may only ever grow, so any
  further change of scheme has the same arithmetic to satisfy. Flutter's scheme also had a
  ceiling this one does not — at build 1000 its armeabi code (2000) collides with arm64's at
  build 0.
- **The build CI hands out installs beside a real one, not over it.** Every
  pull request's `Build Android APK` job uploads the arm64-v8a APK as an
  artifact, so a change can be installed rather than only read. It is built with
  `ORG_GRADLE_PROJECT_pappusSideBySide=true` — a Gradle *property*, since
  `flutter build` forwards no `-P`, and a product flavor would make `--flavor`
  mandatory on every command this file documents. The property switches four
  things at once and they are four quarters of one idea: the `applicationId`
  gains `.ci` (Android identifies an app by that, so the same id signed with a
  different key is a *conflicting update*, not a second app), the label becomes
  `Pappus CI`, the icon becomes `ic_launcher_ci`, and **every** build type is
  signed with the `ci` key — `all { }` over the build types, not the release one
  alone, because the id and the label are set in `defaultConfig` and so apply to
  a debug build too: signing only `release` left a locally built debug APK
  calling itself `dev.calyptra.pappus.ci` under the *debug* key, which is a
  second signature for one applicationId and could not be installed over a CI
  artifact or the other way round. Label and icon travel
  through **manifest placeholders** (`${appLabel}`, `${appIcon}`) rather than a
  resource source set, which only a flavor or build type could bring; both icons
  therefore live in `main` and the unused one rides along in a release build.
  The **namespace** deliberately does not follow the id — it is where the Kotlin
  classes and `R` live. That gap is load-bearing: `home_widget` resolves a bare
  provider name as `context.packageName + '.' + name`, and `context.packageName`
  is the applicationId at runtime, so the widget is addressed by its **fully
  qualified** class name (`home_widget_service.dart`) or a `.ci` build would look
  for a class that does not exist and silently stop updating its widget.
- **The CI build's signing key is in the repo on purpose**
  (`android/app/pappus-ci.jks`, the `ci` signingConfig). `debug` is not one key
  but whichever one sits in `~/.android/debug.keystore` — a file AGP *generates*
  when missing, so every CI runner signed with a fresh random key and a tester
  could only install the next pull request's APK by uninstalling the last one.
  A committed key is the same key on every runner and every fork, with no secret
  involved, which is what keeps this working for pull requests from forks. What
  it allows is stated rather than hidden: anyone can build an APK Android accepts
  as an update to `dev.calyptra.pappus.ci`, inheriting that install's data
  directory and already-granted permissions. It cannot touch the released app —
  different id *and* different key, separate sandboxes — and it is selected only
  when `sideBySide` is on, so the key and the suffixed id always arrive together.
  `android/.gitignore` keeps its blanket `**/*.jks` rule and names this one file
  as the exception, so a real signing key still cannot be committed by accident.
- **The released app's key is optional to have and impossible to guess at.**
  `android/key.properties` (never committed; the keystore itself lives outside
  the repository) names the keystore the published APKs are signed with, and
  `build.gradle.kts` declares a `release` signingConfig only when that file is
  there. Its absence is a *supported* state — CI and a fresh clone fall back to
  the debug keys, because a contributor has to be able to build the app without
  holding the key that identifies the published one. The file is read with
  `rootProject.file(...)`: `rootProject` is `android/`, and `file(...)` from the
  app's own script would look in `android/app/` and quietly find nothing, which
  costs nothing visible — the build simply signs with the debug keys instead.
  Neither the resulting APK's fingerprint nor a successful build can tell the
  two apart here, because the release key *is* the old debug key, moved out of
  `~/.android/debug.keystore` into a deliberate location so AGP can no longer
  regenerate the app's identity from under it. `./gradlew :app:signingReport` is
  therefore the only check that answers which key a variant actually uses, and
  the one to run after touching any of this. `sideBySide` still wins over the
  release key: that property suffixes the applicationId in the same breath, so a
  build taking the release key there would be signing something that is not the
  released app.
- **The app says which build it is by looking at its own id.** `isCiBuild`
  (`core/app_info.dart`, pure) reads the `.ci` suffix off `PackageInfo`'s package
  name, resolved once in `main` into `isCiBuildProvider`. Deliberately not a
  `--dart-define` beside the Gradle property: two switches can disagree, and the
  one that would be wrong is the field a bug report quotes. The About screen
  then grows a row naming the build, and the **version string it copies** reads
  `1.7.0+8 · CI` — the marker rides on the text that gets pasted, not merely
  beside it. `appVersionProvider` itself is untouched, because that is what the
  connection search sends as its `User-Agent`, whose shape the router's usage
  policy asks for; which build it is, is a matter for the reader.
- **On Linux the side-by-side build has to isolate more than the id, because the desktop
  shares more.** `PAPPUS_SIDE_BY_SIDE=true` (an environment variable: `flutter build linux`
  forwards no `-D`) suffixes the GTK `APPLICATION_ID` in `linux/CMakeLists.txt` and retitles
  the window. That id is what `path_provider` and `shared_preferences` key
  `~/.local/share/<id>/` by, so the CI build gets preferences of its own, **including the
  saved database path**. Choosing a different file in the CI build's settings is therefore
  not a substitute: the choice is written to the preferences file both builds read, so the
  CI build first opens (and migrates) whatever the released one last used, and the released
  one then opens the test file. The default file needs the same care, since
  `getApplicationDocumentsDirectory` is the user's `~/Documents` on a desktop, not a
  per-app sandbox: `defaultDatabaseFile(ciBuild:)` names it `pappus-ci.sqlite` there and
  leaves Android and iOS alone, where the directory already belongs to the id and renaming
  the file would only hide a tester's data. `isCiBuild` reads the id from GLib
  (`core/application_id.dart`, two FFI calls, the same ones `path_provider_linux` makes),
  because `PackageInfo.packageName` on Linux is the pubspec name `travelplanner`.
  Measured in a throwaway `HOME`: with a released build's preferences pointing elsewhere,
  the CI AppImage created `~/Documents/pappus-ci.sqlite` and left that file alone.
- **`tool/package_linux.sh` is the only place Linux packages are made**, by both workflows
  and by hand, so the AppImage a laptop produces is the one a release publishes. It asserts
  the **glibc floor** (`max_glibc`, 2.35) against the highest `GLIBC_` symbol version the
  bundle references. What counts is that reference and not the glibc of the build machine:
  a build on Ubuntu 24.04 (glibc 2.39) measured GLIBC_2.34, which is why CI builds on
  `ubuntu-latest` and not on an older runner. A new plugin can raise the floor without
  anything else noticing, and raising it on purpose means editing that line and the README.
  appimagetool and its type2 runtime are pinned by version **and** digest. Unpinned, the
  tool fetches the runtime from a rolling release at build time, and that runtime is
  embedded in every AppImage handed out. The runtime is static, so users need no `libfuse2`.
  The packages are unsigned, and `SECURITY.md` says so.
  The bundle also carries `libdartjni.so`, linked against the runner's `libjvm`. It is only
  opened on demand by `package:jni`, which only Android code paths reach, so it is inert
  rather than broken.
  It also **refuses to package a bundle built as the other build** — the id is compiled
  into the executable, so it is read back with `strings` rather than taken on trust from
  the environment. Setting `PAPPUS_SIDE_BY_SIDE` for the build and forgetting it for the
  packaging (or the reverse) is otherwise silent, and produces a CI build wearing the
  released app's name, desktop entry and icon.
- **The tarball carries `install.sh` / `uninstall.sh` (`linux/packaging/`), because a
  desktop entry is the one part of it that cannot work where it is unpacked.** `Exec=` is
  a bare command name and `Icon=` a theme lookup, so both resolve for nobody until the
  entry sits in `~/.local/share/applications`; running `./pappus` in the unpacked folder
  always worked and still does. The installed entry's `Exec=` is rewritten to the
  **absolute** path, since `~/.local/bin` is not on every distribution's PATH and never on
  the session's when it is created after login. The payload goes to `~/.local/opt/<app id>`
  and deliberately *not* to `~/.local/share/<app id>`, which is where `path_provider` keeps
  that build's preferences. The entry is packed as a **template**, `<app id>.desktop.in`,
  and not as a `.desktop` file: shipped ready-made it was the file a file manager offered as
  a launcher, and dragged onto a desktop it failed with "pappus: command not found", since
  the absolute path it needs only exists once the script has chosen it. Everything is
  derived from that single template lying beside the script — the app id, the icon name, and from the `.ci` suffix the command name
  `pappus-ci` — so the CI build installs beside the released app rather than over it, which
  is the same rule the rest of the side-by-side machinery follows. The scripts are POSIX
  `sh`, touch nothing outside `$HOME`, and the uninstall removes its symlink only while it
  still points into its own install.
- **On Windows the same variable renames the product, and the names are the mechanism.**
  `path_provider_windows` keys the app's data directory, and with it `shared_preferences`,
  by `CompanyName\ProductName` from the executable's version resource, and
  `package_info_plus` reports its `InternalName` as the package name. So
  `PAPPUS_SIDE_BY_SIDE=true` becomes a preprocessor **flag** (`windows/CMakeLists.txt`) on
  which `Runner.rc` picks `Pappus CI` / `pappus.ci` and `main.cpp` the window title. That
  is enough on its own: the saved database path lives under the CI build's own
  `%APPDATA%` directory, `isCiBuild` reads the `.ci` off `PackageInfo` with no FFI, and
  `defaultDatabaseFileName` already renames the file on every platform but Android and iOS,
  since `Documents` is shared here too. A flag rather than a string define, because a
  quoted name with a space in it has to survive CMake's quoting into `rc.exe` as well as
  `cl.exe`, and literals chosen in the source do not. Renaming the *released* product
  would move every existing Windows user's settings, so only the CI build's name changes.
  `tool/package_windows.ps1` zips the release folder (or, with `-Folder`, leaves it
  unzipped, which is what the CI artifact uploads: `upload-artifact` zips whatever it is
  handed, and a zip inside that zip had to be unpacked twice) with the **Visual C++ runtime**
  (`msvcp140`, `vcruntime140`, `vcruntime140_1`) copied beside `pappus.exe` from the
  Visual Studio that built it, which Flutter's deployment guide asks for and Microsoft's
  terms allow. Without them a clean machine fails with a missing-DLL error that reads as a
  broken download. It zips with Windows' own `tar.exe`, named by full path, because some
  `Compress-Archive` versions write backslashes into entry names. The zip is unsigned, so
  SmartScreen warns on first start; `SECURITY.md` and the README say so. None of this can
  be built from Linux, since Flutter does not cross-compile Windows, so the `Build Windows
  app` job is the only place the Windows runner is compiled at all.
- The icon is generated, not drawn twice: `tool/build_ci_icon.py` composes the
  app's own mark with an amber `CI` chip and writes all five densities, the
  legacy icon (minSdk is 24; adaptive icons start at 26), and the Windows
  executable's `app_icon_ci.ico` — cropped to what is drawn, since a desktop
  icon has no launcher mask and would otherwise sit small inside the margin
  that mask needs, and carrying every size Windows asks for, because it scales
  whatever it does not find and a blurred 256 is what a 16px taskbar icon then
  looks like. The chip sits inside
  the adaptive icon's **safe circle** — 66 of 108dp — because a round launcher
  mask slices off anything outside it, which reads as a broken icon rather than
  as a badge. That is also why it is not a corner badge or a bottom band.

## Android toolchain (AGP and built-in Kotlin)

The Android toolchain is **AGP 9 on Gradle 9** — the exact versions are the ones in
`android/settings.gradle.kts` and `android/gradle/wrapper/gradle-wrapper.properties`, which
Dependabot moves — and nothing about that combination is pinned any more: the version ceilings that used to live in `.github/dependabot.yml` are
gone, because the `Build Android APK` job in CI now exercises the real
`flutter build apk --split-per-abi`. That job is the whole guard: every failure in this area
happens while Gradle *applies its plugins*, long before a line of Dart or Kotlin is
compiled, so `analyze` and `test` are blind to it and a breaking bump used to merge green.

What is deliberate is `android.builtInKotlin=false` in `android/gradle.properties`. AGP 9
compiles Kotlin itself by default; the Flutter scaffold writes `false` to keep the old
arrangement where the **Kotlin Gradle Plugin** does it. Under Flutter 3.44 that was the only
mode that built at all, and the mechanism is worth keeping written down because it is the
shape such a break takes — it happens in *somebody else's* plugin, over a flag it never
reads. `FlutterPluginUtils.kt` walks the subprojects, and for every one that applies AGP but
does *not* itself apply KGP it called `pluginManager.apply("kotlin-android")` — without
consulting `android.builtInKotlin`. AGP 9 with built-in Kotlin then aborted on exactly those
projects, because KGP was present after all. The irony was that this hit the plugins that had
*already* migrated: `file_selector_android` correctly applies AGP and no KGP, so Flutter
re-applied it and the build died there. Its companion `android.newDsl=true` was no escape
either — Flutter's Gradle plugin threw a `NullPointerException` before it got as far as
Kotlin.

**That ceiling is gone, and `android.builtInKotlin` is now `true`.** Flutter's own
documentation puts built-in Kotlin at **3.47 or later**, and the toolchain here is 3.47.2.
The move was made while it is still optional — Flutter ships both properties as `false` for
the duration of the ecosystem's migration (flutter/flutter#183910) and documents the escape
hatch as going away before AGP 10 — on the grounds that a switch which can be undone by
editing one line is better thrown early than under a deadline, and that the failure mode is
loud: this is the change that used to abort the build outright.

**It is not a per-module setting, which is the thing to know before touching it.** Measured
rather than assumed: with the flag on, KGP is applied to **no** project — not `:app`, not
any of the eleven plugin modules — so every Kotlin source in the build changes compiler in
one step. Two things that could have gone silently wrong did not. The `kotlin { }` block in
`app/build.gradle.kts` is KGP DSL and the app never applies KGP itself (Flutter does), yet
it still resolves and `jvmTarget` still reads `JVM_17` under built-in Kotlin. And
`kotlin-stdlib` resolves to the same 2.4.10 either way, so the compiler changed and the
runtime library did not.

What the build cannot tell you is the half that matters most here: the native Kotlin in this
repository is the **home-screen widget**, and a widget that stopped updating would compile
perfectly. So this is verified on a phone — the widget added, a trip changed, the payload
seen to follow, and a widget tap seen to deep-link into the trip — and not on a green CI run
alone. `newDsl` stays `false`: it is a separate flag with a separate failure, and Flutter's
Gradle plugin threw a `NullPointerException` on it under 3.44.

So the warning that survives a good build — "Your app uses the following plugins that apply
Kotlin Gradle Plugin (KGP): home_widget" — is expected, and should be neither chased nor
silenced. `home_widget` is **already migrated**: 0.9.3 carries "Apply kotlin plugin when
not built in" (ABausG/home_widget#425, closing #421), which is the two-condition check that
consults `android.builtInKotlin` — so with the flag now on it does *not* apply KGP, and it
cannot drop the line either way without breaking AGP 8 users. It is named only
because Flutter matches a **textual** regex against the build script, which cannot see the
`if` guarding it; the other plugins receive KGP just as surely, from Flutter, and go
unmentioned. There is no plugin upgrade to wait for — and, measured on 3.47.2, no
`android.builtInKotlin=true` to wait for either: the warning is printed just the same in
that mode, for exactly the reason above. A regex over a build script cannot know which
branch Gradle took, so nothing about switching the flag will silence it.
