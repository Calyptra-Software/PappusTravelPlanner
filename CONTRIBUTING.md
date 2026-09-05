# Contributing

Thanks for wanting to help. Bug reports, translations, and patches are all welcome —
open an [issue](https://github.com/Calyptra-Software/PappusTravelPlanner/issues) first if the change
is larger than a fix, so nobody writes a feature twice.

## Licensing your contribution

Pappus Travel Planner is free software under the **GNU General Public License, version 3 or
later** (see [LICENSE](LICENSE)), and contributions are taken under those same terms: what
you send becomes part of the app and is distributed under the GPL along with it. Opening a
pull request means you confirm that you wrote the patch, or are otherwise entitled to
submit it under that license.

**If a patch contains code you did not write, say so in the pull request and name its
license.** That is the one thing worth a sentence of your time, because it is the only part
nobody else can check for you — a snippet lifted from a blog post, another app, or an AI
assistant that reproduced someone's code verbatim. Anything incompatible with the GPL
cannot be merged, however small.

A `Signed-off-by` line (`git commit -s`, certifying the
[Developer Certificate of Origin](https://developercertificate.org/)) is welcome but not
required, and nothing here enforces one. If you use it, note that it is a statement about
provenance, not a transfer of copyright.

There is no CLA either, and the consequence is worth knowing: because the copyright stays
spread across everyone who has contributed, the license can only ever be changed with
everybody's agreement. That is deliberate — the GPL is meant to be the end state here, not
a stage on the way to something else.

## Working with AI assistants

Using an LLM to help write a patch is allowed and needs no apology — large parts of this
app were written that way. What follows is therefore not a
rule against the tool, but a reminder of the responsibility that comes with using it.

**You are the author of the pull request.** You should understand the code you are sending, and be able to explain it to a reviewer. Don't stop thinking just because the assistant has a good answer — it is not a substitute for your own judgment.

**Run it before you send it.** Generated code compiles far more often than it is correct.
At a minimum, the commands in the next section must pass; beyond that, actually exercise
the change in the running app (e.g., `flutter run -d linux` is the quickest). "The tests still
pass" is not the same claim as "I saw this work".

**Say so in the pull request.** One line is enough — which assistant, and roughly what it
did ("wrote the first draft of the DAO method", "translated the ARB strings"). This is not
a judgment and it will not count against a patch. It tells the review where to look
closely, exactly the way "I copied this approach from the Flutter samples" would.

## Before you open a pull request

```bash
flutter pub get
dart format .            # the repository is formatted in tall style
flutter analyze          # must be clean
flutter test
```

CI runs the same three, plus a real `flutter build apk --split-per-abi` — that Android job
is the only thing guarding the Gradle toolchain, since plugin failures happen long before
any Dart is compiled.

Three things generate code or data, and the generated files are committed alongside their
sources:

- **`dart run build_runner build --delete-conflicting-outputs`** after touching any Drift
  table or DAO (`lib/data/database/`) or any `@riverpod`-annotated provider. Never edit a
  `*.g.dart` by hand.
- **`flutter gen-l10n`** after editing `lib/l10n/app_en.arb` (the template) — and every key
  added there must be added to `app_de.arb` too.
- Any change to a Drift table or column needs a bumped `AppDatabase.schemaVersion` **and**
  an `onUpgrade` branch. Real databases are migrated in place, never recreated. The same
  care applies to the persisted enums (cost display, expense scope, PDF sections, sort
  order, trip statuses): they are stored by index, so append only — never reorder.

## Trying your change on a phone

A build from source will not install over a Pappus you already use: the released APK is
signed with the maintainer's key and yours is not, which Android reads as a conflicting
package rather than as an update. Build the side-by-side variant instead:

```bash
ORG_GRADLE_PROJECT_pappusSideBySide=true flutter run
ORG_GRADLE_PROJECT_pappusSideBySide=true flutter build apk --split-per-abi
```

It installs as **Pappus CI**, with its own launcher icon and its own database, beside the
app you use — nothing it does can reach your real trips. The key it is signed with is in
the repository, so this needs nothing you do not already have, and it is the same variant
every pull request's `Build Android APK` artifact contains: your local build and a
downloaded one can replace each other on the device.

To try it against realistic data, use *Export database…* in the real app and *Import
database…* in Pappus CI. Don't uninstall the real app to make room — that takes its
database with it.

## Cutting a release

Maintainers only, and it is a tag rather than a build: nothing is compiled on anybody's
laptop, so what was released can be traced to a machine whose state is written down.

Prepare in an ordinary pull request — rename `## Unreleased` in
[CHANGELOG.md](CHANGELOG.md) to the version and its date, and set `version:` in
`pubspec.yaml`. The build number after the `+` has to *increase*: it becomes the Android
versionCode, and Android refuses to install a lower one over a higher one. Then, on `main`:

```bash
git tag v1.11.0 && git push origin v1.11.0
```

`.github/workflows/release.yml` takes it from there. It refuses outright if the tag and
`pubspec.yaml` disagree, builds the three per-ABI APKs signed with the release key from
the repository secrets, writes `SHA256SUMS.txt`, prints the signing certificate into the
job summary, and opens a **draft** release with notes GitHub generates from the merged
pull requests.

The draft is the point at which a human looks. Check that the fingerprint in the job
summary is the one [SECURITY.md](SECURITY.md) names — a mistyped secret produces perfectly
good APKs signed with the wrong key, and that is not something to discover after
publishing — then press *Publish release*. Nothing is public until you do, so a bad run is
undone by deleting the draft and the tag.

Without the signing secrets the same workflow still runs and warns; it then produces
debug-signed APKs, which are fine for a fork and must not be published. That is also what
*Run workflow* on the Actions tab is for: the same build with no tag and no release, which
is how the signing setup is checked without inventing a version to throw away.

Getting the app onto F-Droid, and what each release needs once it is there, is
described in [docs/fdroid.md](docs/fdroid.md).

## How the code is arranged

[AGENTS.md](AGENTS.md) is the long version — the layering, why a trip and a routine are one
table, why money is stored in minor units, what a group and a decision each mean. It is
written for coding agents but reads perfectly well for people, and it is the fastest way to
find out whether the thing you are about to add already has a place.

Two conventions worth stating here:

- **Tests and documentation are part of the change.** New behavior comes with a test; pure
  logic (`trip_stats.dart`, `day_blocks.dart`, `now_marker.dart`, `time_marks.dart`, the
  sharing bundle) is deliberately free of Flutter and database imports so it can be tested
  directly. Note that drift's `.watch()` streams do not resolve under `flutter_test`'s fake
  clock — override the feature provider with a plain `Stream.value(...)`, or put the test in
  `integration_test/`.
- **Match the surrounding code** rather than importing your own style: the naming, the
  comment density, and the habit of writing down *why* a rule exists where it is enforced.

## The routing service and the tile server

The connection search runs against [Transitous](https://transitous.org), a community-run
instance donated for free and open-source, non-commercial use. Its
[usage policy](https://transitous.org/api/) is a functional requirement of this app, not a
footnote: requests carry a `User-Agent` naming the app, its version, and a contact
(`lib/core/app_info.dart`); the data sources are linked wherever the data is shown
(`lib/core/widgets/attribution.dart`); journeys are searched on an explicit button and
never on a timer; and the staging and `motis-project` hosts are off limits.

The map stands on the same kind of ground: its tiles come from the OpenStreetMap
Foundation's servers, whose
[usage policy](https://operations.osmfoundation.org/policies/tiles/) permits a human panning
around a viewport and **forbids downloading areas in advance** — it names "download region
for offline use" as the prohibited pattern. Requests therefore carry the same identifying
`User-Agent`, caching is left on, and `Basemap.offlineDownload`
(`lib/features/map/basemap.dart`) records per source whether prefetching is allowed at all,
so a future download feature has to ask the source rather than apply to whichever one
happens to be selected.

Please do not add anything that increases request volume — polling, prefetching, a search
that fires while typing — without discussing it in an issue first. The policy asks that
they be contacted before a client starts making many requests, and a patch that quietly
crosses that line is a problem for the whole project, not just for the feature.

To exercise the client against the live service without starting the app:

```bash
dart run tool/motis_smoke.dart "Hamburg Hbf" "Wien Hbf"
```

Plain Dart, needs a network, and deliberately not part of the test suite — the suite must
not depend on somebody else's server being up, and must not add to its load on every run.
