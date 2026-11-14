# UI conventions

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for opening a modal sheet, and for where Material comes from.

- **Every modal sheet is opened by `showAppSheet`** (`core/widgets/app_sheet.dart`),
  which is where four settings that belong together now live. A sheet is `useSafeArea`
  and capped at the screen less the status bar less one touch target, so it stops below
  the status bar and always leaves a strip of scrim above itself. Both halves are the
  same bug: `showModalBottomSheet` defaults `useSafeArea` to false, which does more than
  omit a `SafeArea` — Flutter then applies `MediaQuery.removePadding(removeTop: true)`,
  so a `SafeArea` *inside* the sheet cannot make up for it either — and with
  `isScrollControlled` a tall sheet then reaches y = 0, putting its drag handle in the
  strip Android pulls the notification shade down from. The gesture that should shrink
  the sheet opens the system's panel instead, and with no scrim left to tap, the back
  button is the only way out. The cap is a **height** and not a fraction, measured below
  the status bar, because what it has to be is a touch target — a tenth of a short screen
  is not one. The width is restated (`kSheetMaxWidth`) because naming `constraints`
  *replaces* the theme's rather than adding to them, and the M3 default that would be
  lost is exactly `maxWidth: 640`. A sheet wanting less height still constrains its own
  body, as several do; the stricter constraint governs. Nine of twenty-one call sites
  passed `useSafeArea` before this and twelve did not, which is the shape of rule that
  has to live in one function rather than in a convention.
- **Material comes from `package:material_ui`, never from `package:flutter/material.dart`**,
  and Cupertino's localizations from `package:cupertino_ui`. Flutter 3.50 deprecated the
  SDK's copies, and the two are not interchangeable: `material_ui` declares its own
  `MaterialApp`, `ThemeData` and `MaterialLocalizations`, so a widget built from one
  does not see the other's theme or strings. go_router 18 already looks for
  `material_ui`'s `MaterialApp`; while this app still built the SDK's, from 1.10.0 on,
  go_router took it for a plain `WidgetsApp` and gave every route a `NoTransitionPage`,
  which is why screens stopped animating. `flutter_localizations` is still imported, but
  only `show GlobalWidgetsLocalizations`. `lib/l10n/app_localizations.dart` is excluded
  from analysis because `gen-l10n` still lists the deprecated delegates in
  `AppLocalizations.localizationsDelegates`, so that list is not to be used: name
  `material_ui`'s `GlobalMaterialLocalizations.delegates` instead.
