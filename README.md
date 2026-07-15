# Travel Planner

[![Flutter 3.44+](https://img.shields.io/badge/Flutter-3.44%2B-blue)](https://flutter.dev)
[![Dart 3.12+](https://img.shields.io/badge/Dart-3.12%2B-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Travel Planner is a modern, **offline-first** Flutter app for planning trips. Create
trips, build a day-by-day itinerary from places and transport legs, track what each
part of the trip costs, and keep everything in a local SQLite database that you fully
control. The primary target is **Android**, but the same code base also runs on Web,
Linux, Windows, macOS, and iOS.

## Features

- **Trips overview** — create, edit, and delete trips with a destination, date range,
  notes, participants, and an accent colour. Search by text, filter by status
  (upcoming / ongoing / past / undated), participant, or date range, and sort by date,
  name, creation, or total expenses. Switch the overview to a **month calendar** where
  each trip is a bar in its accent colour spanning its days.
- **Structured itinerary** — a vertical, day-by-day timeline of **places** and
  **transport legs** (walk, bike, ski, car, taxi, bus, train, tram, subway, ferry,
  flight, …) with times and notes. Reorder and group items within a day; collapse/expand days.
- **Planned vs. actual times** — every entry carries the times it was *planned* for and,
  once you record them, the times it *actually* started and ended (departed and arrived).
  The timeline keeps showing the plan, with a green or red **+/−** on each end saying how
  early or late it ran, and "you are here" follows what really happened rather than the plan.
- **Alternatives** — plan competing options for one stretch of a day ("museum or boat
  trip?"). The decision sits in the timeline as a card you **swipe** between options; each option holds its own places, legs, and costs.
  Every option's price stays visible side by side so they can be compared, but only the
  **chosen** option counts toward the trip's totals and its expense split — an option you
  considered and dropped never inflates the budget. Afterwards, simply choose the option you
  actually took, or clear the decision away with *keep only this option*.
- **Checklists** — any number of named checklists per trip (packing list, to-dos, …),
  with reorderable, tickable items and collapsible cards.
- **Costs & expense splitting** — attach costs to any place, transport, or the trip as a
  whole, each with an amount, a currency (€ / US-$ / £ /
  CHF), a category, who paid, and who it was for. Per-item subtotals and a per-trip total (grouped by currency) are
  shown automatically, and the overview can be scoped to *my* expenses.
- **Trip statistics & settle-up** — a per-trip stats screen breaks spending down by
  category and by person (paid vs. fair share) and suggests a minimal set of payments to
  settle up, computed per currency (no conversion between currencies).
- **Share a single trip** — export a trip as a self-contained `.tpt` bundle and send it
  to another user of the app (Android share sheet; desktop saves the file). Opening or
  importing a bundle recreates the trip with its itinerary, alternatives, groups, costs,
  and checklists. The format is independent of the local database's IDs, so sender and
  recipient don't need matching data.
- **Export as PDF** — turn a trip into a printable PDF for sharing with people who don't
  use the app or for a paper copy: a cover with the trip's dates, notes, and participants,
  the day-by-day itinerary, an expense summary (per-currency total and a breakdown), and
  the checklists. Shared via the Android share sheet or saved to a file on desktop.
- **Portable database** — all data lives in a single SQLite file. On desktop you can
  open/create the database anywhere; on Android you can import/export it. Copy the
  file between devices and platforms and open it as-is.
- **Localization & theme** — English and German, and a light/dark/system theme, both
  switchable in-app. Dates and currencies use locale-correct formatting.
- **Android home-screen widget** — shows your current/next trip, a countdown, and
  today's plan; tapping it opens the trip.
- **Offline-first** — no account, no server; everything works without a network.

## Quick facts

- Framework: Flutter (Dart)
- Main entry: `lib/main.dart`
- State management: [Riverpod](https://riverpod.dev)
- Navigation: [go_router](https://pub.dev/packages/go_router)
- Local storage: [Drift](https://drift.simonbinder.eu) (SQLite)
- Localizations: ARB files in `lib/l10n`
- Generated code: Drift/Riverpod (`build_runner`) and localizations (`gen-l10n`)

## Prerequisites

- Flutter SDK (stable channel, 3.44 or newer) on your `PATH` — check with
  `flutter doctor`.
- A supported target to run on (Android device/emulator, Chrome, or a desktop OS).
- For Android builds: Android SDK (installed via Android Studio).

## Setup

1. Fetch dependencies:

    ```bash
    flutter pub get
    ```

2. Generate code (Drift database, Riverpod, and localizations). The localizations are
   also generated automatically as part of `flutter run`/`flutter build`, but you can
   run both generators explicitly:

    ```bash
    dart run build_runner build --delete-conflicting-outputs
    flutter gen-l10n
    ```

   Re-run `build_runner` after changing any Drift table/DAO, and `gen-l10n` after
   editing the ARB files in `lib/l10n`.

## Run the app

Pick a device with `-d`. List what's available with `flutter devices`.

- Android (device or running emulator):

    ```bash
    flutter run -d android
    ```

- Web (Chrome):

    ```bash
    flutter run -d chrome
    ```

- Web (headless server, open the printed URL in any browser):

    ```bash
    flutter run -d web-server --web-port 8080
    ```

- Linux desktop:

    ```bash
    flutter run -d linux
    ```

- On an Android emulator — first launch it, then run:

    ```bash
    flutter emulators                                  # list emulator IDs
    flutter emulators --launch Medium_Phone_API_36.1   # example ID
    flutter run
    ```

## Build

`flutter build` produces a release build by default; add `--debug` for a debug build.

| Platform | Command | Output |
|---|---|---|
| Android (APK) | `flutter build apk` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android (Play) | `flutter build appbundle` | `build/app/outputs/bundle/release/app-release.aab` |
| Web | `flutter build web` | `build/web/` |
| Linux | `flutter build linux` | `build/linux/x64/release/bundle/travelplanner` |
| Windows | `flutter build windows` | `build/windows/x64/runner/Release/` |
| macOS | `flutter build macos` | `build/macos/Build/Products/Release/` |
| iOS | `flutter build ios` | open `Runner.xcworkspace` in Xcode to sign/deploy |

Install a built APK on a connected device/emulator:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

> **Tip:** the debug APK bundles every CPU architecture and is large. For a quick
> emulator install, build a single-architecture release, e.g.
> `flutter build apk --release --target-platform android-x64`.

## Project structure

```text
lib/
  main.dart                 # entry point (ProviderScope + startup wiring)
  app.dart                  # MaterialApp.router, theme, localization
  core/                     # theme, router, providers, settings, formatting helpers
  data/
    database/               # Drift tables, database, DAOs (trips, itinerary, costs, checklists)
    repositories/           # thin repository over the DAOs
  features/
    trips/                  # overview, create/edit, detail, participants
    itinerary/              # timeline, day blocks, alternatives card, item form, transport modes
    costs/                  # cost form, splitting/stats, reasons & people settings
    checklist/              # per-trip named checklists
    sharing/                # portable trip bundles (export/import a single trip) + PDF export
    settings/               # language, cost reasons, people + database location screen
    home_widget/            # Android widget payload + sync
  l10n/                     # app_en.arb, app_de.arb + generated classes
android/ ios/ linux/ ...    # per-platform host projects
test/                       # unit and widget tests
integration_test/           # flows driven against the real widgets and a real database
```

## Database and portability

Data is stored in a single SQLite file (default: the app documents directory).
Open the in-app **Settings → Database** section to:

- **Desktop:** *Open* an existing `.sqlite` file or create a *New* one at any path;
  the choice is remembered across launches.
- **Android / Web:** *Import* a `.sqlite` file (replaces the current data) or *Export*
  the current database. On web the data lives in browser storage (OPFS, falling back to
  IndexedDB); import seeds that storage from the picked file and export downloads it.

The file is a standard SQLite database, so you can copy it between devices/platforms
and open it directly. Deleting a trip cascades to its itinerary items and their costs.

To move **one trip** rather than the whole database, use the share button on the trip
screen: it writes a `.tpt` bundle (a portable snapshot of that trip alone) which the
recipient imports from the trips overview. On Android a `.tpt` file shared to — or
opened with — Travel Planner goes straight into the import flow. The same button also
offers **Export as PDF** — a printable, read-only copy of the trip for anyone, whether or
not they use the app.

## Localization

- Strings live in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- After editing the ARB files, run `flutter gen-l10n` (or just build the app) to
  regenerate the localized Dart classes.
- Switch the language in-app under **Settings → Language** (System / English / German),
  and the theme under **Settings → Theme** (System / Light / Dark).

## Developer notes

- Analyze: `flutter analyze`
- Format: `dart format .`
- Test: `flutter test`
- Integration tests (real widgets against a real database, on a real device — drift's
  `.watch()` streams don't resolve under `flutter_test`'s fake clock, so flows that depend
  on live data live here): `flutter test -d linux integration_test/`
- After changing Drift tables/DAOs or Riverpod-annotated code, re-run
  `dart run build_runner build --delete-conflicting-outputs`.
- Any change to a Drift table or column needs a bumped `AppDatabase.schemaVersion` and an
  `onUpgrade` branch: real databases are migrated in place, never recreated.

## Disclaimer

Large parts of this app were written with the help of AI assistants. The
implementation has been tested but comes with no warranty — use at your own risk.
