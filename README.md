<p align="center">
  <img src="docs/logo.png" alt="Pappus Travel Planner" width="420">
</p>

# Pappus Travel Planner

[![Flutter 3.44+](https://img.shields.io/badge/Flutter-3.44%2B-blue)](https://flutter.dev)
[![Dart 3.12+](https://img.shields.io/badge/Dart-3.12%2B-blue)](https://dart.dev)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![CI](https://github.com/Calyptra-Software/PappusTravelPlanner/actions/workflows/ci.yml/badge.svg)](https://github.com/Calyptra-Software/PappusTravelPlanner/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/Calyptra-Software/PappusTravelPlanner/branch/main/graph/badge.svg)](https://codecov.io/gh/Calyptra-Software/PappusTravelPlanner)

Pappus Travel Planner is a modern, **offline-first** Flutter app for planning trips. Create
trips, build a day-by-day itinerary from places and transport legs, track what each
part of the trip costs, and keep everything in a local SQLite database that you fully
control. The primary target is **Android**, but the same code base also runs on Web,
Linux, Windows, macOS, and iOS.

## Features

- **Trips overview** — create, edit, and delete trips with a destination, date range,
  notes, participants, tags, and an accent colour. Search by text, filter by status
  (upcoming / ongoing / past / undated), tag, participant, originating routine, or date
  range, and sort by date, name, creation, or total expenses. Switch the overview to a
  **month calendar** where each trip is a bar in its accent colour spanning its days.
- **Tags — your filing, not the app's** — the app doesn't decide that a bike ride is a
  lesser kind of trip than a holiday; you invent the labels ("walks", "commute",
  "vacation", "work") and hang them on trips. Tags sit as a chip row directly above the
  overview list rather than two taps deep in a filter sheet, and nothing ever *behaves*
  differently because of a tag — they are renameable and deletable throughout.
- **Routines — a plan you make again** — keep a commute, a training ride, or a regular
  visit as a template with no dates, and stamp it out onto any day.
- **Structured itinerary** — a vertical, day-by-day timeline of **places** and
  **transport legs** (walk, bike, ski, car, taxi, bus, train, tram, subway, ferry,
  flight, …) with times and notes. Reorder and group items within a day; collapse/expand days.
  The transport modes are not a fixed list: add, rename, re-icon, reorder, or remove them
  under **Settings → Transport modes**, and the built-ins are just the starting set.
- **Planned vs. actual times** — every entry carries the times it was *planned* for and,
  once you record them, the times it *actually* started and ended (departed and arrived).
  The timeline keeps showing the plan, with a green or red **+/−** on each end saying how
  early or late it ran, and "you are here" follows what really happened rather than the plan.
- **"You are here"** — on today's plan, the entry currently under way is marked and tinted,
  and between two entries a red line sits where the day has got to.
- **Online connection search & live times** — look up real train and transit journeys from
  an open routing service ([Transitous](https://transitous.org) / MOTIS, built on
  OpenStreetMap and public-transport open data — no account, no API key) and drop a chosen
  one straight into a day. Search *from* / *to* with live station suggestions, set a
  departure or arrival time, and compare the options by time, duration, and number of
  changes — with **live delays** shown where the service has them. Search options (all
  remembered for next time) say which **means of transport** may be used, the **shortest
  change** you want to be planned for, **how fast you walk** (or cycle), whether you have a
  **bike** with you (and whether it comes on board), whether the whole journey must be
  **step-free**, how long you'll spend **getting to and from stops**, and the **most
  changes** to accept — down to *direct connections only* — so a search never books you a
  three-minute sprint across a terminus. A **via stop** can be required as well, with a
  minimum time to stay there.
  Results come back as a time window around what you asked for, with **earlier** and **later**
  loading the departures either side onto the same list. Tapping one **opens** it in full —
  leg by leg, with platforms, the length of each change, and every stop the service calls
  at on the way (a stop the train is *skipping* is struck through rather than given a
  reassuring time) — and a button there commits it.
  Importing writes the journey as that day's transport legs — a multi-leg trip bundled under
  one shared ticket — carrying each leg's line/train number, direction, platform, and stop
  list, and handling overnight legs that arrive the next morning. An imported journey reads
  back exactly the way it did in the search, so the walking transfer between two trains stays
  *the change*. Each imported leg then gets its own **refresh** button that pulls its current
  real-time departure and arrival, updating its stops along with its ends, which surface
  through the planned-vs-actual marks above — and says so plainly when the service has been
  **cancelled**. This is the app's one online feature; everything it imports lives in your
  local database like anything else.
- **A routine's plan can become a real connection** — stamping out a routine that contains
  a searched journey copies the plan first (instant, correct offline on its own) and then
  looks the connection up for the day it now sits on, offering the day's actual departure to
  swap in. Declining it, finding nothing, or having no signal all leave the copied plan
  standing — and "no train" is never reported when it was "no network".
- **Alternatives** — plan competing options for one stretch of a day ("museum or boat
  trip?"). The decision sits in the timeline as a card you **swipe** between options;
  each option holds its own places, legs, and costs.
  Every option's price stays visible side by side so they can be compared, but only the
  **chosen** option counts toward the trip's totals and its expense split — an option you
  considered and dropped never inflates the budget. Afterwards, simply choose the option you
  actually took, or clear the decision away with *keep only this option*.
- **Checklists** — any number of named checklists per trip (packing list, to-dos, …),
  with reorderable, tickable items and collapsible cards.
- **Costs & expense splitting** — attach costs to any place, transport, a whole shared
  ticket, or the trip as a whole, each with an amount, a currency, a category, who paid,
  and who it was for. Categories are your own reusable labels with an icon
  (**Settings → Expense categories**). Per-item subtotals and a per-trip total (grouped by
  currency) are shown automatically, and the overview can be scoped to *my* expenses.
- **Your own currencies, with exchange rates** — the four built-ins (€ / US-$ / £ / CHF)
  are just a starting list: add, rename, re-symbol, reorder, or remove currencies in
  **Settings → Currencies**, mark one as the **base**, and give the others a rate against
  it ("1 USD = 0.92 EUR"). Where a total spans several currencies and every one of them
  has a rate, the base-currency equivalent is shown *beside* the exact figures
  (`€349.90 · US$50.00 ≈ €394.90`) — never in place of them, and never from a partial set
  of rates. Rates start unset, and the app declines to convert rather than guess one.
- **Trip statistics & settle-up** — a per-trip stats screen breaks spending down by
  category and by person (paid vs. fair share) and suggests a minimal set of payments to
  settle up. This is always computed **per currency**, with no conversion: what you owe is
  what was actually spent, not a figure derived from a rate you typed in.
- **Record the money handed back** — a suggested payment can be booked as a **settlement**
  (from → to, no category, no split), straight from the settle-up list or from the trip's
  general expenses. It moves the two balances and nothing else: the trip's total, its
  expense count and its category breakdown stay untouched, so "paid" still means "spent on
  the trip" while the settle-up list shrinks by what has already been repaid.
- **Share a single trip** — export a trip as a self-contained `.tpt` bundle and send it
  to another user of the app (Android share sheet; desktop saves the file). Opening or
  importing a bundle recreates the trip with its itinerary, alternatives, groups, costs,
  checklists, and tags — a **routine** shares just as well as a dated trip. The format is
  independent of the local database's IDs, so sender and recipient don't need matching
  data — a currency or a transport mode the recipient doesn't have is created from the
  bundle, and one they already have keeps their own symbol and rate. A bundle only stamps
  the format version the trip actually needs, so an older copy of the app keeps reading
  what it can.
- **Export as PDF** — turn a trip into a printable PDF for sharing with people who don't
  use the app or for a paper copy: a header with the trip's dates, notes, and participants,
  then whichever of the **itinerary**, the **expense summary** (per-currency total, a
  breakdown, and the settlements) and the **checklists** you tick — each row saying what it
  would print ("5 days · 18 entries"), sections this trip has nothing for greyed out, and
  the choice remembered for next time. Shared via the Android share sheet or saved to a file
  on desktop.
- **Export to calendar** — put a trip into whatever calendar you already use, as a standard
  `.ics` file: one event per place and transport leg, plus an all-day banner for the trip.
  Times are *floating*, so 09:30 stays 09:30 wherever you read it; untimed entries become
  all-day events, and only the **chosen** option of each decision is exported.
- **Portable database** — all data lives in a single SQLite file. On desktop you can
  open/create the database anywhere; on Android you can import/export it. Copy the
  file between devices and platforms and open it as-is.
- **Localization & theme** — English and German, and a light/dark/system theme, both
  switchable in-app. Dates and currencies use locale-correct formatting, and the connection
  search asks the routing service for its results in the app's language too.
- **Android home-screen widget** — shows your current/next trip, a countdown, and
  today's plan with the same planned-time-plus-delay marks as the timeline; tapping it
  opens the trip.
- **Offline-first** — no account and no server; the app works without a network. The one
  exception is the optional connection search above, which fetches journeys and live times
  from the routing service — and even that only enriches the plan, which then stays offline.

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
| Linux | `flutter build linux` | `build/linux/x64/release/bundle/pappus` |
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
    trips/                  # overview, calendar, create/edit, detail, participants, tags, routines
    itinerary/              # timeline, day blocks, alternatives, item form, now marker, modes
    transport_search/       # online connection search (Transitous/MOTIS) + live-times refresh
    costs/                  # cost form, splitting/stats, settlements, reasons, currencies
    checklist/              # per-trip named checklists
    sharing/                # portable trip bundles (.tpt), plus PDF and .ics export
    settings/               # language, theme, categories, currencies, modes, people, database
    home_widget/            # Android widget payload + sync
  l10n/                     # app_en.arb, app_de.arb + generated classes
android/ ios/ linux/ ...    # per-platform host projects
web/                        # web host page + prebuilt sqlite3.wasm / drift_worker.js
tool/                       # dev-only scripts (e.g. a live smoke test for the routing client)
test/                       # unit and widget tests
integration_test/           # flows driven against the real widgets and a real database
```

## Database and portability

Data is stored in a single SQLite file (default: the app documents directory).
Open the in-app **Settings → Database** section to:

- **Desktop:** *Open* an existing `.sqlite` file or create a *New* one at any path;
  the choice is remembered across launches, and *Reset to default* points the app back at
  its own file.
- **Android / Web:** *Import* a `.sqlite` file (replaces the current data) or *Export*
  the current database. On web the data lives in browser storage (OPFS, falling back to
  IndexedDB); import seeds that storage from the picked file and export downloads it.

The file is a standard SQLite database, so you can copy it between devices/platforms
and open it directly. Deleting a trip cascades to its itinerary items and their costs.

To move **one trip** rather than the whole database, use the share button on the trip
screen: it writes a `.tpt` bundle (a portable snapshot of that trip alone) which the
recipient imports from the trips overview. On Android a `.tpt` file shared to — or
opened with — Pappus goes straight into the import flow.

The same button also offers **Export as PDF** (a printable, read-only copy) and **Export to
calendar** (an `.ics` file for a calendar app). Both are one-way views of the plan; only the
`.tpt` bundle can be imported back.

## Data sources and the routing service

The connection search talks to [Transitous](https://transitous.org), a community-run,
donated MOTIS instance serving [public-transport open data](https://transitous.org/sources/)
on top of [OpenStreetMap](https://www.openstreetmap.org/copyright).

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
- Any change to a Drift table or column needs a bumped `AppDatabase.schemaVersion` and
  an `onUpgrade` branch: real databases are migrated in place, never recreated. The same
  goes for the persisted enums (cost display, expense scope, PDF sections, sort order):
  they are stored by index, so append only — never reorder.
- Poke the routing client without the app:
  `dart run tool/motis_smoke.dart "Hamburg Hbf" "Wien Hbf"` (plain Dart, needs network,
  not part of the test suite).
- Web needs two prebuilt assets in `web/`, regenerated whenever `drift`/`sqlite3` are
  upgraded: `sqlite3.wasm` (from the matching
  [sqlite3.dart release](https://github.com/simolus3/sqlite3.dart/releases)) and
  `drift_worker.js` (`dart compile js -O2` of a one-line entrypoint calling
  `WasmDatabase.workerMainForOpen()`, compiled from inside this project).
- The Android toolchain carries one deliberate setting, `android.builtInKotlin=false`, which
  cannot change until Flutter 3.47. It is documented under *Platform build constraints* in
  [AGENTS.md](AGENTS.md), together with the warning that survives a good build and should
  not be chased. The CI job that builds a real APK is the only thing guarding any of it:
  these failures happen while Gradle applies its plugins, where `analyze` and `test` cannot
  see them.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for how the code is arranged
and what to consider before opening a pull request. Contributions are taken under the project's
own license (GPL-3.0-or-later); if a patch carries code you did not write, please name it
and its license in the pull request.

## License

Copyright © 2026-present Joshua Lampert and contributors.

Pappus Travel Planner is free software: you can redistribute it and/or modify it under the terms
of the **GNU General Public License** as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version. It is distributed in the
hope that it will be useful, but **without any warranty**; without even the implied
warranty of merchantability or fitness for a particular purpose. See the
[LICENSE](LICENSE) file, or <https://www.gnu.org/licenses/>, for the full terms.

The bundled fonts carry their own terms, which travel with them and are shown on the app's
license page: Roboto is under Apache-2.0 (`assets/fonts/Roboto-LICENSE.txt`), and the four
transport glyphs come from Apache-2.0 and CC0 sources
(`assets/fonts/TransportGlyphs-ATTRIBUTION.txt`).

## Disclaimer

Large parts of this app were written with the help of AI assistants. The
implementation has been tested and verified manually but comes with no warranty.
