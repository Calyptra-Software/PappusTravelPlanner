# AGENTS.md

This file provides guidance to coding agents (e.g. Claude Code, which reads it via the
`@AGENTS.md` import in `CLAUDE.md`) when working with code in this repository.

Travel Planner is an offline-first Flutter app for planning trips (trips → day-by-day
itinerary of places and transport legs → costs), storing everything in a single portable
SQLite file. Primary target is Android; also runs on Web, Linux, Windows, macOS, iOS.

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
```

Regenerate code after editing anything under generation:

- **`dart run build_runner build`** after changing any Drift table/DAO (`lib/data/database/`)
  or any `@riverpod`-annotated provider. Generated `*.g.dart` files are committed alongside
  their sources — never edit them by hand.
- **`flutter gen-l10n`** after editing `lib/l10n/app_en.arb` / `app_de.arb`. `app_en.arb` is
  the template; every key added there must also be added to `app_de.arb`.

## Architecture

Layering is **feature-first** with a shared data core. Data flows upward through Riverpod
providers and downward through a single repository:

```text
UI (features/*/presentation, *widgets)
  → feature providers (features/*/application)   StreamProvider.autoDispose over the repo
    → repositoryProvider → TripRepository          thin passthrough to the DAOs
      → databaseProvider → AppDatabase (Drift)     tripDao / itineraryDao / costDao
```

- **`lib/core/providers.dart`** is the spine. `bootstrapDbPathProvider` is resolved once in
  `main.dart` (from a saved preference or the default path) and **overridden** into the
  `ProviderScope` so it can be read synchronously. `activeDbPathProvider` (a Notifier) holds
  the live path; changing it rebuilds `databaseProvider` — which opens/closes the SQLite file
  — and everything downstream. All data access goes through `repositoryProvider`.
- **`TripRepository`** (`lib/data/repositories/`) is a deliberately thin wrapper over the DAOs
  so a different backend could be swapped in without touching feature code. Prefer adding a
  repository method over reaching into DAOs from features.
- **Single `ItineraryItems` table** holds both places and transport legs, discriminated by
  `ItemKind`; kind-specific columns are nullable. This lets a day read as one ordered timeline
  (place → transport → place). Items are ordered by `date` → `sortOrder` → `startMinutes`.
- Times are stored as **minutes since midnight** (int, 0–1439); money as **minor units**
  (int cents) to avoid float rounding. `Currency` and `TransportMode` enums are persisted by
  **integer index** — only ever append new values at the end, never reorder.
- `Trips → ItineraryItems → Costs` cascade on delete. Cascades rely on
  `PRAGMA foreign_keys = ON`, set in `AppDatabase.migration`'s `beforeOpen`.

### Database portability & schema changes

- Data is one SQLite file. Desktop can open/create a DB at any path; Android imports/exports.
  `DatabaseController` (`lib/features/settings/application/database_providers.dart`) coordinates
  switching/importing/exporting. WAL mode writes `-wal`/`-shm` sidecars; call `checkpoint()`
  before copying and `deleteSidecars()` before replacing a file (see `core/database/database_location.dart`).
- Bump `AppDatabase.schemaVersion` and add an `onUpgrade` branch for **any** table/column
  change — real user databases are migrated in place, not recreated.

### Android home-screen widget

`lib/features/home_widget/` pushes a fully pre-formatted, already-localized `WidgetPayload`
to the native Kotlin `TravelPlannerWidgetProvider` (`android/app/src/main/kotlin/.../`) as
flat key/value pairs via `home_widget`. `HomeWidgetSync` (wrapping the app in `app.dart`)
watches trips/itinerary and re-pushes on change; widget taps deep-link via
`travelplanner://trip?id=N`. `pickFeaturedTrip` decides which trip to show (ongoing → next
upcoming → most recent past). Widget code is Android-only and no-ops elsewhere.

## Testing notes

Drift's `.watch()` streams **do not resolve under `flutter_test`'s fake-async** clock, so
widget tests hang if they depend on the real DB stream. Override the feature provider with a
plain `Stream.value(...)` instead (see `pumpOverview` in `test/trip_flow_test.dart`). For
DAO/logic tests, construct `AppDatabase.forTesting(NativeDatabase.memory())` against an
in-memory database.

## Platform build constraints

Android Gradle Plugin is pinned to **8.x** (AGP 8.11.1 / Gradle 8.13). The Flutter scaffold's
default AGP 9 breaks `file_picker` — do not bump it.

### Web

The database layer is split by platform via conditional imports in
`lib/core/database/database_location.dart`: native (`_io.dart`) opens a `NativeDatabase` over
a file path exactly as before; web (`_web.dart`) ignores the path and opens a
`WasmDatabase` (via `drift_flutter`'s `driftDatabase`) backed by browser storage (OPFS,
falling back to IndexedDB) keyed by a fixed name. `dart:io`/`path_provider` live only in the
`_io.dart` branch. Two prebuilt assets in `web/` are **required** for web and must be
regenerated if `drift`/`sqlite3` are upgraded:

- `web/sqlite3.wasm` — download the tag matching the resolved `sqlite3` version from
  `github.com/simolus3/sqlite3.dart/releases` (e.g. `sqlite3-3.3.4/sqlite3.wasm`).
- `web/drift_worker.js` — `dart compile js -O2 -o web/drift_worker.js <tmp>` where `<tmp>`
  is a one-line entrypoint calling `WasmDatabase.workerMainForOpen()` from
  `package:drift/wasm.dart` (must be compiled from inside this project so `package:drift`
  resolves).

The web has no filesystem, so the settings screen hides the desktop open/create actions
there, but import/export **are** supported: `DatabaseController.exportBytes` /
`importFromBytes` close the live connection and go through `WasmDatabase.probe` (OPFS grants
exclusive single-handle access, so nothing else may be open). Export reads the stored bytes
via `probe.exportDatabase`; import deletes the store, queues the picked file's bytes via
`webSetPendingImport`, and reopens — drift's `initializeDatabase` hook seeds the fresh store.
`file_picker` yields bytes (not a path) on web, so `_import` passes `withData: kIsWeb`.
