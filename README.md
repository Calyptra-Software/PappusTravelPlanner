# Travel Planner

[![Flutter 3.44+](https://img.shields.io/badge/Flutter-3.44%2B-blue)](https://flutter.dev)
[![Dart 3.12+](https://img.shields.io/badge/Dart-3.12%2B-blue)](https://dart.dev)

Travel Planner is a modern, **offline-first** Flutter app for planning trips. Create
trips, build a day-by-day itinerary from places and transport legs, track what each
part of the trip costs, and keep everything in a local SQLite database that you fully
control. The primary target is **Android**, but the same code base also runs on Web,
Linux, Windows, macOS, and iOS.

## Features

- **Trips overview** — create, edit, and delete trips with a destination, date range,
  notes, and an accent colour.
- **Structured itinerary** — a vertical, day-by-day timeline of **places** and
  **transport legs** (walk, bike, ski, car, taxi, bus, train, tram, subway, ferry,
  flight, …) with times and notes. Reorder items within a day; collapse/expand days.
- **Costs** — attach costs to any place or transport, each with an
  amount, a currency (€ / US-$ / £), and a reason. Previously used reasons are
  remembered and offered in a dropdown. Per-item subtotals and a per-trip total
  (grouped by currency) are shown automatically.
- **Portable database** — all data lives in a single SQLite file. On desktop you can
  open/create the database anywhere; on Android you can import/export it. Copy the
  file between devices and platforms and open it as-is.
- **Localization** — English and German, switchable in-app (or follow the system
  language). Dates and currencies use locale-correct formatting.
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
    database/               # Drift tables, database, DAOs (trips, itinerary, costs)
    repositories/           # thin repository over the DAOs
  features/
    trips/                  # overview, create/edit, detail
    itinerary/              # timeline, item form, transport modes
    costs/                  # cost form and providers
    settings/               # language + database location screen
    home_widget/            # Android widget payload + sync
  l10n/                     # app_en.arb, app_de.arb + generated classes
android/ ios/ linux/ ...    # per-platform host projects
test/                       # unit and widget tests
```

## Database and portability

Data is stored in a single SQLite file (default: the app documents directory).
Open the in-app **Settings → Database** section to:

- **Desktop:** *Open* an existing `.sqlite` file or create a *New* one at any path;
  the choice is remembered across launches.
- **Android:** *Import* a `.sqlite` file (replaces the current data) or *Export* the
  current database to a location you choose (via the system file picker).

The file is a standard SQLite database, so you can copy it between devices/platforms
and open it directly. Deleting a trip cascades to its itinerary items and their costs.

## Localization

- Strings live in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- After editing the ARB files, run `flutter gen-l10n` (or just build the app) to
  regenerate the localized Dart classes.
- Switch the language in-app under **Settings → Language** (System / English / German).

## Developer notes

- Analyze: `flutter analyze`
- Format: `dart format .`
- Test: `flutter test`
- After changing Drift tables/DAOs or Riverpod-annotated code, re-run
  `dart run build_runner build --delete-conflicting-outputs`.

## Disclaimer

Large parts of this app were written with the help of AI assistants. The
implementation has been tested but comes with no warranty — use at your own risk.
