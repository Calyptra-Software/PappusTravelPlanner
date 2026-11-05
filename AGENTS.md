# AGENTS.md

This file provides guidance to coding agents (e.g. Claude Code, which reads it via the
`@AGENTS.md` import in `CLAUDE.md`) when working with code in this repository.

Pappus Travel Planner is an offline-first Flutter app for planning trips (trips → day-by-day
itinerary of places and transport legs → costs, plus per-trip checklists and shared-expense
splitting among participants), storing everything in a single portable SQLite file. Primary
target is Android; also runs on Web, Linux, Windows, macOS, iOS.

## Commands

```bash
flutter pub get                                          # fetch dependencies
dart run build_runner build --delete-conflicting-outputs # regenerate Drift/Riverpod code
flutter gen-l10n                                          # regenerate localizations from ARB
flutter analyze                                          # static analysis (flutter_lints)
dart format .
flutter test                                             # all tests
flutter test test/cost_dao_test.dart                     # a single test file
flutter test test/cost_dao_test.dart --plain-name "adds a cost"  # a single test by name
flutter run -d <android|chrome|linux>                    # run; list targets with `flutter devices`

dart run tool/build_country_outlines.dart \
  ne_10m_admin_0_countries.geojson assets/geo/countries.json   # rebuild the country outlines
```

Regenerate code after editing anything under generation:

- **`dart run build_runner build`** after changing any Drift table/DAO (`lib/data/database/`)
  or any `@riverpod`-annotated provider. Generated `*.g.dart` files are committed alongside
  their sources — never edit them by hand.
- **`flutter gen-l10n`** after editing `lib/l10n/app_en.arb` / `app_de.arb` / `app_zh.arb`.
  `app_en.arb` is the template; every key added there must also be added to `app_de.arb`.
  **`app_zh.arb` (Simplified Chinese) is the exception**, because nobody maintaining this
  repository reads Chinese: a new key is left *out* of it rather than translated, so
  `gen-l10n` warns about an untranslated message and the app shows the English text, and
  the pull request mentions @Florlet, who contributed the translation and offered to fill
  the gaps. An English text whose *meaning* changes is the same case, only worse, since
  the Chinese one is then wrong rather than missing — so say so in the pull request too.
  The `zh-CN` store listing under `fastlane/metadata/android/` follows the same rule, and
  has no `changelogs/default.txt` on purpose (`docs/fdroid.md`).

**A change a user can notice gets a `CHANGELOG.md` entry in the same pull request**, under
`## Unreleased` at the top (create the heading if the last release took it). That covers
features, fixed behavior, and what the installed app declares or contacts; not refactors,
tests, CI, or dependency bumps that change nothing visible. One or two short sentences per
entry, saying what changed for the user rather than how: the release step in
`CONTRIBUTING.md` only renames the heading, so an entry that was not written with its
change is not written at all.

**`SECURITY.md` states facts, not intentions**, and a change can make one of them false
without touching it: which hosts are contacted (`api.transitous.org` for a connection
search, `tile.openstreetmap.org` while a map is open, and nothing else), which permissions
the app asks for and which its libraries merge in, that there is no telemetry of any kind,
and the list of foreign files the app parses. A third host, a new permission, an analytics
or crash-reporting dependency, or another format read from outside all turn a sentence
there into a false claim about what the app does with someone's data. Correct it in the
same commit; a security policy that has drifted is worse than none, because people rely
on it.

Both facts have drifted before, and the permission count is read off the **built APK**, never
off `AndroidManifest.xml` (`docs/design/platform-builds.md` says how).

## Design notes: read the one you need

The reasons behind the code live in `docs/design/`, one file per area. They are not loaded
automatically: **before changing an area, read its file** — most rules there exist because
the obvious change was once made and turned out wrong.

| File | Read before touching |
| --- | --- |
| [`trips-and-routines.md`](docs/design/trips-and-routines.md) | the overview, `TripQuery`/`RoutineQuery`, tags, the result line, the statistics filter, routines and `materializeRoutine` |
| [`itinerary.md`](docs/design/itinerary.md) | `ItineraryItems`, groups, decisions, day blocks, drag/move/copy, the clipboard, "you are here", planned/actual times, `endDayOffset`, transport modes |
| [`transport-search.md`](docs/design/transport-search.md) | the connection search, import, re-routing (`replaceJourney`), lookups, stopovers, the Transitous usage policy |
| [`costs.md`](docs/design/costs.md) | currencies and rates, totals, `computeTripStats`, settlements, reimbursements, invitations |
| [`sharing.md`](docs/design/sharing.md) | `TripBundle` / `.tpt` versions, PDF, `.ics`, `.gpx` |
| [`map.md`](docs/design/map.md) | both maps, pins and clusters, the point picker, device location, `PositionFeed`, track recording, basemaps |
| [`tracks.md`](docs/design/tracks.md) | `Tracks`, the polyline codec, GPX import and splitting, routed shapes, `TrackDisplay`, chords, entry colors |
| [`countries.md`](docs/design/countries.md) | the countries tab, `assets/geo/countries.json` and its builder, hand marks |
| [`attachments.md`](docs/design/attachments.md) | attachments, EXIF and `ACCESS_MEDIA_LOCATION`, photos on the map, the gallery, cover photos, documents |
| [`database.md`](docs/design/database.md) | the database file: auto-vacuum, the storage tile, switching/importing/exporting, migrations |
| [`ui-conventions.md`](docs/design/ui-conventions.md) | `showAppSheet` |
| [`home-widget.md`](docs/design/home-widget.md) | the Android home-screen widget |
| [`testing.md`](docs/design/testing.md) | a widget test that hangs, leaks a timer, or depends on the time zone |
| [`platform-builds.md`](docs/design/platform-builds.md) | Gradle/AGP/Kotlin, signing, version codes, release and CI builds, side-by-side builds, Linux/Windows packaging, `third_party/` (geolocator, SQLite), the NDK pin |
| [`web.md`](docs/design/web.md) | the web build, `web/sqlite3.wasm` and `web/drift_worker.js`, downloads, fonts, self-hosting |

When a change adds or overturns a design decision, record it in the matching file (or a new
one, listed here), not in this file. Keep this file to what every session needs.

## Architecture

Layering is **feature-first** with a shared data core. Data flows upward through Riverpod
providers and downward through a single repository:

```text
UI (features/*/presentation, *widgets)
  → feature providers (features/*/application)   StreamProvider.autoDispose over the repo
    → repositoryProvider → TripRepository          thin passthrough to the DAOs
      → databaseProvider → AppDatabase (Drift)     tripDao / itineraryDao / costDao / checklistDao
```

- **`lib/core/providers.dart`** is the spine. `bootstrapDbPathProvider` is resolved once in
  `main.dart` (from a saved preference or the default path) and **overridden** into the
  `ProviderScope` so it can be read synchronously. `activeDbPathProvider` (a Notifier) holds
  the live path; changing it rebuilds `databaseProvider` — which opens/closes the SQLite file
  — and everything downstream. All data access goes through `repositoryProvider`.
- **`TripRepository`** (`lib/data/repositories/`) is a deliberately thin wrapper over the DAOs
  so a different backend could be swapped in without touching feature code. Prefer adding a
  repository method over reaching into DAOs from features.

### Rules that cut across areas

Each one is explained in the design note named after it.

- **Live entries only.** An entry counts when it is loose or in the *chosen* option of a
  decision; a cost counts when it hangs on the trip, a live entry, or a group with a live
  member. The rule lives once in SQL (`CostDao._countsTowardTotals`) and once in Dart
  (`live_items.dart`); exports, maps and statistics all read it. (`itinerary.md`)
- **A copy takes the plan, not the money.** Duplicates never copy costs or ticks
  (`copyItemPlan`), except that a routine's fare travels, unpaid. Tracks travel via
  `copyItemTracks`, called explicitly from each copy path, not from `copyItemPlan`.
  (`itinerary.md`, `trips-and-routines.md`, `tracks.md`)
- **Gestures browse, buttons commit**, and an act is offered on the unit it applies to (a
  run's acts on the run's label, a decision's on its card). (`itinerary.md`)
- **Tags never change behavior**; what the app branches on is `Trips.kind`.
  (`trips-and-routines.md`)
- **Day arithmetic goes through `core/format/civil_date.dart`**, never `Duration`, and every
  reader places an entry's times through `features/itinerary/entry_times.dart`.
  (`itinerary.md`, `testing.md`)
- **A position is pointed at, never derived**: no geocoding of a name into a place, no
  reverse geocoding. (`map.md`)
- **Red is reserved for "happening"**; no user color may hide it. (`map.md`)
- **Persisted enums are stored by index: append only, never reorder.** (In a `.tpt`,
  `TrackSource` and `TrackDisplay` travel by name.)
- **A `.tpt` stamps only the format version the trip needs**; a new field an older app can
  ignore bumps nothing. (`sharing.md`)
- **Never put two Drift tables in a reference cycle**: drift silently drops foreign keys
  elsewhere. (`attachments.md`)
- **The router is a donated server**: its usage policy is part of the feature, every
  provider that calls the network carries `retry: noAutomaticRetry`, and
  `staging.api.transitous.org` and `*.motis-project.*` are off limits.
  (`transport-search.md`)
- **Bitwise ops are 32-bit on the web**: codec arithmetic uses `*` and `~/`. (`tracks.md`)
- **Every modal sheet is opened by `showAppSheet`**, and a snackbar raised from inside a
  sheet is drawn *behind* it. (`ui-conventions.md`, `map.md`)
- **`third_party/` is vendored on purpose** (Play-Services-free `geolocator_android`,
  SQLite from source): keep edits minimal; bumping `package:sqlite3` does not move the
  SQLite version (`tool/update_sqlite.sh` does). (`platform-builds.md`)
- **A release is a tag**, built by `.github/workflows/release.yml`; never build and upload
  a release artifact by hand. (`platform-builds.md`)

### Data model essentials

- Times are stored as **minutes since midnight** (int, 0–1439); money as **minor units**
  (int cents) to avoid float rounding, and amounts may be negative (refunds/income). The
  SharedPreferences-backed `CostReasonDisplay` / `ExpenseScope` enums are persisted by
  **integer index** — only ever append new values at the end, never reorder.
- Tables (all in `lib/data/database/tables.dart`): `Trips` (with `kind`/`fromRoutineId`,
  `trips-and-routines.md`), `ItemGroups`, `AlternativeSets`, `Alternatives`,
  `ItineraryItems`, `Costs`, `Tags` / `TripTags` (the user's filing), `CostReasons`
  (reusable reason labels with an optional icon id), `Currencies` (built-in plus custom,
  with the base flag and exchange rates, `costs.md`), `TransportModes` (built-in plus
  custom, `itinerary.md`), `People` (reusable payer/beneficiary names; one flagged `isMe`),
  `TripParticipants` and `CostBeneficiaries` (many-to-many join tables), `Checklists` /
  `ChecklistItems` (any number of named checklists per trip), `CollapsedDays` (which
  itinerary days are collapsed), `Tracks` (`tracks.md`), `Attachments` /
  `AttachmentBlobs` (`attachments.md`), `VisitedCountries` (`countries.md`), and
  `Recordings` / `RecordingFixes` (a track the app is recording, kept fix by fix until the
  import files it as `Tracks` rows — a buffer outside every trip, see the table docs).
- Everything hangs off `Trips` and cascades on delete (`ItineraryItems`, `Costs`, checklists,
  participant/beneficiary links). Cascades rely on `PRAGMA foreign_keys = ON`, set in
  `AppDatabase.migration`'s `beforeOpen`.
- Bump `AppDatabase.schemaVersion` (currently 41) and add an `onUpgrade` branch for **any**
  table/column change — real user databases are migrated in place, not recreated.

## Testing essentials

Full notes in [`docs/design/testing.md`](docs/design/testing.md).

- Drift's `.watch()` streams **do not resolve under `flutter_test`'s fake-async** clock:
  override the feature provider with a plain stream (see `pumpOverview` in
  `test/trip_flow_test.dart`). DAO/logic tests use
  `AppDatabase.forTesting(NativeDatabase.memory())`.
- Every widget that watches a DB-backed provider must be stubbed in every test that pumps
  it, or a pending drift timer fails the test after its assertions
  (`test/support/attachment_overrides.dart`).
- CI runs under `TZ=Europe/Berlin`; DST-dependent tests use `skip: skipWithoutEuropeanDst`
  (`test/support/dst.dart`). Run them locally with `TZ=Europe/Berlin flutter test …`.
