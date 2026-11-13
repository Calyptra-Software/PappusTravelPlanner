# Exports: .tpt, PDF, .ics, .gpx

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the trip bundle and the three one-way exports.

- **A trip leaves the app in four shapes, all built from one `TripBundle`** (`features/sharing/`,
  all pure so they test without a database): the `.tpt` bundle itself — the only *lossless*,
  round-tripping one, and the only one with an importer — plus three one-way views,
  `trip_pdf.dart`, `trip_ics.dart` and `trip_gpx.dart`. All four read the plan the same way the
  timeline does: only *live* entries
  (loose ones and the chosen option of each decision), so the road not taken never leaves either.
  The `.ics` export leans on the fact that the app stores **no timezone at all** — a day plus
  minutes since midnight — which is exactly iCalendar's *floating* time (`DTSTART` with neither a
  `Z` nor a `TZID`), so nothing is converted and nothing can be converted wrongly. What a calendar
  cannot hold is dropped rather than faked: an untimed entry becomes an all-day event and thereby
  loses its `sortOrder` (a calendar orders by time or not at all), and groups, checklists,
  participants, and actual times have no mapping (costs ride along as description text, readable
  but not counted). Import of `.ics` is deliberately **not** built — a calendar event routinely
  spans days, which an item (one day, strictly) cannot represent.
- **The `.gpx` export exists because half the lines have no original anywhere else.** Importing
  one recording across several entries *cuts* it, and those pieces live only here, as do the
  routes the connection search computed; the packed column was chosen so that a line could
  leave this app "without a decoder being written first", which was true only for somebody
  willing to write the decoder. `buildTripGpx` returns **null** rather than an empty document
  when a trip holds no line, and the caller says so — the menu entry cannot know in advance
  without decoding every point of the trip, which is the one expensive thing a track does.
  Three decisions in it are worth keeping: a recording is a **`<trk>`** and a routed shape an
  **`<rte>`**, which is the distinction GPX itself draws (where something went, against how it
  could go) and the one the map dashes — and the routes are written **before** the tracks
  because the schema fixes that order, not because the plan does. A line the map is **not**
  drawing is exported all the same: `TrackDisplay` is a statement about the picture and a GPX
  is the record, so an eye must not quietly change what a file contains. And nothing is
  invented to fill the format's other fields — no `<ele>`, no per-point `<time>` (the import
  dropped both on purpose), coordinates at the five decimals the column actually holds, and on
  a **routine** not even the day, since its entries sit on `kRoutineAnchorDay`, which is a sort
  origin and not a date anybody travelled. That is also why a routine *is* offered this export
  while paper and the calendar are not: a line needs no dates to be a line. So the file is not
  the file that was imported, and `docs/features.md` says so where a user might otherwise
  delete the original.
- **A bundle stamps only the format version the trip actually needs**, so an older app keeps
  reading what it can: v2 for a trip with decisions, v3 for one using a currency the old
  four-value enum never had, v7 for one with an entry ending two or more days after it starts
  (a one-night entry also writes the `spansNextDay` an older app reads correctly, so it forces
  nothing). That is why a cost's currency is written under the *old enum name*
  (`eur`) when its code is one of those four and as the plain code (`JPY`) otherwise —
  `bundleCurrencyToken` / `bundleCurrencyCode` in `trip_bundle.dart`, whose legacy table is
  frozen and must not follow the enum if it grows. The currency definitions ride along in
  `TripBundle.currencies` (used codes plus the sender's base). On import a currency is matched
  by code and created only when missing; an existing one keeps the importer's own symbol and
  rate, and an incoming rate is adopted **only when both databases share a base code** — a rate
  against someone else's base would silently misprice everything.
- **The PDF is the one export the user composes** (`trip_pdf_sections.dart`, pure): a `PdfSection`
  — itinerary, expenses, checklists — is ticked in `presentation/pdf_sections_sheet.dart` before
  the document is built, and the choice is remembered across launches as a bitmask
  (`pdfSectionsProvider`, append-only like every persisted enum here). Only the *paper* view is
  choosable: `.tpt` must stay lossless and `.ics` holds what a calendar holds. Settlements are not
  a section of their own — they ride with the expenses, since a repayment only reads beside the
  balances it settles — and the header (title, dates, participants) is not one either: it is the
  document's identity, so it is always printed and "nothing ticked" is simply not an export.
  The trip bundle is read *before* the sheet opens so every row can say what it would print
  ("5 days · 18 entries") and a section this trip has nothing for is grayed out rather than
  offered as a switch that yields no pages. `summarizePdfSections` counts through the same
  helpers the builder lays out with (`countedBundleCosts`, `bundleItemIsLive`,
  `printableChecklists`), so the picker's numbers cannot drift from the document's contents.
  A section unavailable on this trip keeps its stored setting for the next one.
- **The PDF draws a day the way the timeline does**: a rail, a place as a dot in the trip's
  accent, a leg as its mode's icon in a disc. The rail runs from a day's first node to its
  last, each row drawing its own piece, and a decision's accent bar is drawn per row in the
  text column so that it neither breaks the rail nor is broken by it. The icon is the one
  *this* database gives the mode (`modeIcons`, from `transportModeIconsByKey`), since a
  bundle carries a custom mode's icon but not one chosen for a built-in;
  `pdfTransportModeIcon` falls back to the bundle's, then to the built-in's own.
  **The icons need a font of their own, and two traps decided what it is.** Flutter's
  Material Icons font is CFF-based (`OTTO`), and package:pdf parses TrueType outlines only —
  it falls back to its Latin-1 standard font and throws on the code point — so
  `assets/fonts/build_pdf_icons.py` converts exactly the `Icons.*` that `transport_mode.dart`
  names out of the SDK's own font into `MaterialIconsPdf.ttf` (same glyphs, same code
  points, CC BY 4.0, ~8 KB). Run it again when an icon joins `kTransportModeIcons`;
  `trip_pdf_test.dart` fails until then. The second trap is the **left side bearing**: a
  TrueType renderer puts a glyph's origin at `xMin − lsb`, so an `hmtx` that says 0 draws
  every glyph shifted left by its own `xMin`. The CFF font's `hmtx` says 0, and so did
  `build_transport_glyphs.py` — which means the app itself drew the horse and the three
  lifts up to 15% of their size left of center, in Flutter as much as in a PDF viewer, until
  both scripts were made to write `lsb = xMin`. A test asserts it for both fonts.
- **A `.tpt` the app is opened with crosses into Dart as a path, never as bytes.**
  `MainActivity.kt` streams the intent's URI into `cache/received/` on a background thread and
  hands over the copy's path; `takeReceivedTrip` (`received_trip_file.dart`) reads it and deletes
  it. The bytes used to cross the method channel as one Base64 string, which costs about five
  times the file on the Java heap (the bytes, their Base64, and that as a UTF-16 string): a trip
  carrying tens of megabytes of photos killed the app on launch with an `OutOfMemoryError`,
  uncaught since it is not an `Exception`, while the import from inside the app, which never
  touches Java, went through. The handoff waits for a frame and asks for one
  (`ensureVisualUpdate`): a post-frame callback alone waits for whatever redraws next, and after
  a copy that takes a second the screen may have nothing to redraw. A file that cannot be read
  shows `importTripFailed` rather than nothing.
