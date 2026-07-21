# AGENTS.md

This file provides guidance to coding agents (e.g. Claude Code, which reads it via the
`@AGENTS.md` import in `CLAUDE.md`) when working with code in this repository.

Travel Planner is an offline-first Flutter app for planning trips (trips → day-by-day
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
- **Single `ItineraryItems` table** holds both places and transport legs, discriminated by
  `ItemKind`; kind-specific columns are nullable. This lets a day read as one ordered timeline
  (place → transport → place). Items are ordered by `date` → `sortOrder` → `startMinutes`.
- **Item groups** (`ItemGroups`, with `ItineraryItems.groupId`) bundle adjacent items — e.g.
  a train journey of several legs sharing one ticket — so a single cost covers them all. A
  `Cost` attaches to exactly one of an item (`itemId`), a group (`groupId`), or the trip
  (`tripId`); the stats engine only sees one row per cost, so grouping never affects the maths.
  `groupId` on items is `setNull` on group delete (dissolving a group keeps its items); a
  group's costs are re-pointed onto its first member before the group is deleted so the expense
  survives. Grouping ops live in `GroupDao`.
- **Alternatives** (`AlternativeSets` / `Alternatives`, with `ItineraryItems.alternativeId`) are
  a second, orthogonal axis of bundling: a set is one decision on one day ("what do we do on
  Saturday afternoon?"), holding two or more branches — competing versions of that stretch of
  the day — of which exactly one is `chosen`. There is deliberately no "actually happened" flag
  beside it: the chosen branch is what the trip counts, so settling a decision after the fact is
  just choosing what you did (v18 dropped the `decided` column that tried to say more).
  A group means "these share a ticket", a branch means
  "these are one option"; a group never straddles two branches (`GroupDao.groupItems` throws).
  An item is either *loose* (`alternativeId` null — the ordinary case) or in exactly one branch.
  A set occupies **one slot** in its day: `AlternativeSets.date`/`sortOrder` share an ordering
  space with the day's loose items, while a branch item's `sortOrder` orders it within its
  branch. Deleting a branch **deletes its items** (cascade — unlike dissolving a group, which
  frees them), and a set left with one branch is flattened back into the day. Ops live in
  `AlternativeDao`.
- The timeline renders a day as a list of **blocks** (`features/itinerary/day_blocks.dart`,
  pure): an `ItemBlock` (a loose item) or a `DecisionBlock` (a whole set). A decision draws as
  an `AlternativeCard` — a `PageView` **swiped** between options, which only *browses*;
  choosing is the explicit button, so looking at an option never moves the trip's money. The
  indicator row under it carries every option's price (the comparison a pager otherwise hides).
  Dragging in a day reorders blocks (writing `ItineraryItems.sortOrder` *and*
  `AlternativeSets.sortOrder`); dragging inside a card reorders that option's items.
- **"You are here"**: a day is an ordered *list*, not a time-scaled axis (times are optional),
  so there is no offset to place a now-line at — only a slot. `features/itinerary/now_marker.dart`
  (pure) answers, for today's blocks and the current minute, either *this block is under way*
  (marked with a `NowBadge`, a red rail node and a tinted tile) or *the line goes here* (a
  `NowLine` between two blocks, after the last block that is behind us). The same rule runs a
  second time *inside* a decision that is under way (`nowMarkerForItems` over its chosen
  option): a decision spans its option whole, so when now falls between two of that option's
  entries the day draws no line — the boundary is inside the card, and so is the line.
  Untimed entries stay
  *ahead* of the line unless something timed after them is already past — we cannot know when
  they happen, and claiming they are done is the guess that would make the mark lie. A decision
  is timed by its **chosen** option only. The mark is drawn *inside* the tile/card, never as an
  extra list child: the day is a `ReorderableListView` indexed by its blocks. `core/clock.dart`'s
  `nowProvider` ticks it on the minute; today's day header carries `Today · HH:mm` so a collapsed
  day still says where we are, and `TripDetailScreen` scrolls today into view on open.
- **Costs of unchosen branches are shown but never counted.** An item is *live* when it is
  loose or in the chosen branch; a cost counts when it is trip-level, on a live item, or on a
  group with a live member. The rule lives once, as a SQL predicate in `CostDao`
  (`_countsTowardTotals`), and is applied by `watchCountedCostsForTrip` (trip header + stats)
  and `watchTotalsByTrip` (overview cards); `watchCostsForTrip` stays unfiltered so the
  timeline can price every branch. Its Dart mirror for items is `features/itinerary/live_items.dart`
  (`liveItems` / `chosenBranchIds`), used by the timeline and the home widget. `computeTripStats`
  is deliberately left untouched by all this — it still sees one row per counted cost.
- **Planned vs. actual times.** An item carries two pairs: `startMinutes`/`endMinutes` are
  what was *planned* (a leg's departure/arrival), `actualStartMinutes`/`actualEndMinutes`
  what really happened. Both are optional and each end is compared with its own counterpart,
  so a leg that left late but has not landed yet runs from its actual departure to its
  planned arrival. What is *shown* is decided once, in the pure
  `features/itinerary/time_marks.dart` (`timeMarks`): the **planned** range, each end
  carrying its miss as a signed `(+15)` / `(−5)` (`formatSignedMinutes`; red late, green
  early or on time). The actual time itself is never printed — plan plus delta already says
  it, and the plan is what the day is judged against. Two renderers paint that one rule:
  `widgets/item_times.dart` (coloured spans) and the home widget (see below). An actual time
  outranks its planned one in `now_marker.dart`, though: "you are here" is a claim about the
  day as it is going.
- Times are stored as **minutes since midnight** (int, 0–1439); money as **minor units**
  (int cents) to avoid float rounding, and amounts may be negative (refunds/income). The
  `Currency` enum (in `tables.dart`) and the SharedPreferences-backed
  `CostReasonDisplay` / `ExpenseScope` enums are all persisted by **integer index** — only
  ever append new values at the end, never reorder.
- **Transport modes are a user-managed table**, not a fixed enum: a leg's `ItineraryItems.mode`
  is a foreign key into `TransportModes` (setNull on delete). The `TransportMode` enum (in
  `tables.dart`) is only the *catalogue of built-ins* the DB is seeded with — each value's
  `name` is the `builtinKey` stored on its seed row, giving it a localized label and a default
  icon (`transport_mode.dart`). A row's label is its `name` when set, else its `builtinKey`'s
  localized label; icons come from the curated `kTransportModeIcons` set. Built-ins seed in
  enum order so a fresh row's id is its enum index + 1 — the fact the v20 migration relies on
  to repoint legacy legs. CRUD lives in `TransportModeDao`; the sharing bundle denormalizes a
  leg's mode to its portable key (built-in key or custom name), carrying custom icons in
  `TripBundle.modeIcons`.
- Tables (all in `lib/data/database/tables.dart`): `Trips`, `ItemGroups`, `AlternativeSets`,
  `Alternatives`, `ItineraryItems`, `Costs`,
  `CostReasons` (reusable reason labels with an optional icon id), `TransportModes` (the
  built-in-plus-custom transport modes, above), `People` (reusable payer/
  beneficiary names; one flagged `isMe`), `TripParticipants` and `CostBeneficiaries`
  (many-to-many join tables), `Checklists` / `ChecklistItems` (any number of named checklists
  per trip), and `CollapsedDays` (persists which itinerary days are collapsed).
- **Expense splitting** lives in `lib/features/costs/trip_stats.dart` as pure functions
  (`computeTripStats`) so the per-currency category breakdown, per-person paid/share/balance,
  and minimal settle-up transfers are unit-testable without a database. A cost splits among
  its `CostBeneficiaries`, falling back to all trip participants. The app never converts
  between currencies — everything is computed per `Currency`.
- Everything hangs off `Trips` and cascades on delete (`ItineraryItems`, `Costs`, checklists,
  participant/beneficiary links). Cascades rely on `PRAGMA foreign_keys = ON`, set in
  `AppDatabase.migration`'s `beforeOpen`.

### Database portability & schema changes

- Data is one SQLite file. Desktop can open/create a DB at any path; Android imports/exports.
  `DatabaseController` (`lib/features/settings/application/database_providers.dart`) coordinates
  switching/importing/exporting. WAL mode writes `-wal`/`-shm` sidecars; call `checkpoint()`
  before copying and `deleteSidecars()` before replacing a file (see `core/database/database_location.dart`).
- Bump `AppDatabase.schemaVersion` (currently 21) and add an `onUpgrade` branch for **any**
  table/column change — real user databases are migrated in place, not recreated.

### Android home-screen widget

`lib/features/home_widget/` pushes a fully pre-formatted, already-localized `WidgetPayload`
to the native Kotlin `TravelPlannerWidgetProvider` (`android/app/src/main/kotlin/.../`) as
flat key/value pairs via `home_widget`. `HomeWidgetSync` (wrapping the app in `app.dart`)
watches trips/itinerary and re-pushes on change; widget taps deep-link via
`travelplanner://trip?id=N`. `pickFeaturedTrip` decides which trip to show (ongoing → next
upcoming → most recent past). Widget code is Android-only and no-ops elsewhere.

A row's time (`widgetTime`) is the one place the payload is not plain text: it carries the
same planned-time-plus-miss line as the timeline, and a `RemoteViews` text can only be
coloured in part through HTML, so the `(+15)` is wrapped in a `<font color>` that
`TodayItemsRemoteViewsService` parses back into spans with `Html.fromHtml`. The colours are
the widget's own (a lighter red/green — it paints on its own dark background, not the app's
theme), and a row with nothing recorded still sends plain "09:00 – 10:30".

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
