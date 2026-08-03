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
- **A trip is a trip, however long it lasts.** A walk, a commute and a fortnight in
  Rome are the same row with different dates — a one-day trip is simply one whose start
  and end are the same day, so nothing declares "scale" and the timeline drops its day
  headers whenever it draws a single day (derived from the dates, not a flag). The one
  thing dates cannot say is whether a plan is meant to be *used again*, and that is the
  whole of `TripKind`: `trip` or `routine`.
- **Tags are the only axis the overview is organised by** (`Tags` / `TripTags`, modelled
  on `People` / `TripParticipants`). The app does not decide that a bike ride is a lesser
  kind of trip than a holiday — that judgement is the user's, so "walks", "commute",
  "vacation" are theirs to invent. `TripQuery.tagIds` matches **any-of** (like
  `participantIds`), while the facets still compose with AND, and the roster sits in the
  open as a `TagFilterBar` above the list rather than inside the filter sheet: a filter
  two taps deep stops being used, and then the filing that feeds it stops too. Nothing
  may *behave* differently because of a tag — one is renameable and deletable, so logic
  hung off it would break on rename; what the app branches on lives in `Trips.kind`.
- **How the overview is read is a setting; what is being looked for is not.** The whole
  `TripQuery` lives in `tripQueryProvider` (`features/trips/application/trip_query_provider.dart`)
  and every facet of it — statuses, tags, participants, date range, sort — is persisted, so
  "only my walks, newest first" survives a launch; re-picking it each time is the friction
  that stops a filter being used, and then the filing that feeds it. The exception is
  `TripQuery.text`: a search *is* one act, which is why the app bar's close button already
  throws it away — and so the one control that writes nothing per keystroke. Statuses ride
  as a bitmask and the sort as an index, append-only like every persisted enum here. The
  tag/participant ids name rows in *this* database: point the app at another file and a
  stored filter may match nothing, which the filter badge and "clear filters" are the way
  back out of.
- **A routine is a template, and its occurrences are virtual.** Nothing is written for a
  day that simply went as the routine says. `RoutineDao.materializeRoutine` copies the
  plan onto real dates as an ordinary trip, on **any** start date — tomorrow's commute
  planned tonight, yesterday's added after the fact. Routines are never in the trip list
  (`applyTripQuery` drops them) and live on `RoutineListScreen`; the overview's "+" still
  offers *From routine…*, since stamping one out is the common act.
- Having no dates, a routine's items are laid out from `kRoutineAnchorDay`, and its days are
  read as **ranks, not offsets** (`RoutineDao.routineDays`): day one is the earliest day any
  entry sits on, day two the next. The absolute dates are only a sort origin, because a plan
  can legitimately pick up real ones — a connection is searched on a real date — and reading
  the distance from 1970 instead once turned a one-day commute into a trip ending in 2083.
  A day with no entries is not a day of the plan: nothing shows it, so gaps close up, which
  is exactly what the timeline already draws. Days read "Day 1", "Day 2"
  (`ItineraryTimeline.relativeDays`) and a routine has no "today". All day arithmetic goes
  through `core/format/civil_date.dart` (`addDays` / `daysBetween`), never `Duration`: a
  local day is 23 or 25 hours across a daylight-saving change, which is exactly enough to
  pull day two onto day one.
- **A timetable only exists on real dates, so importing a connection into a routine searches
  one and rebases the answer.** `ConnectionSearchSheet.intoRoutine` opens the search on today
  rather than on the plan's anchor (no train runs on 1 January 1970), and the import maps each
  leg back onto the plan with `rebasedLegDay` — keeping the shape, so an overnight leg still
  lands a day further in. What is left behind is everything belonging to that one run: its
  `sourceTripId` and any live times already read off it. A template must not look refreshable,
  and a delay measured on one Tuesday is not part of a plan.
- The copy takes the plan **and, for a routine only, the fare**. Everywhere else a copy
  takes no money — a cost records a payment that happened once — but a routine's cost is a
  *price*, "what this ride costs", which is the only reason to put one on a template. So it
  travels, **unpaid** (paying is what an occurrence does, as a copied checklist arrives
  unticked), with its split; a settlement never travels, since a template cannot be owed.
  The corollary is that a routine's own costs count toward **no** total: `allTripsStatsProvider`
  drops routines, or the same fare would be charged both to the plan and to every trip made
  from it. Groups and decisions are cloned into fresh ones. Participants travel,
  and so do the routine's **tags** — a tag the user must re-add every morning is missing by
  Thursday, and auto-filing the trips stamped out of routines is what makes tags carry the
  crowding they were introduced for. `Trips.fromRoutineId` records where a trip came from,
  enough to *ask* before recording the same routine twice on one day, and to filter the
  overview down to what a routine has produced (`TripQuery.routineIds`, any-of like the
  tags; selecting every routine *is* the question "only trips I made from a routine",
  since a trip points at its routine only while that routine exists). `setNull` on delete:
  a trip that happened does not un-happen because its template was thrown away — it simply
  stops being findable that way, because what it came from is then genuinely unknown.
- **An imported leg keeps how the router addresses its ends** — `ItineraryItems.fromPlaceId`
  / `toPlaceId`, the `queryId` the search was issued against (a stop id, or `"lat,lon"` for
  an address). Unlike `sourceTripId`, which names *one dated run of one service* and so is
  never copied, these say only *where*, so they survive a copy and travel in the `.tpt`
  bundle. They sit on the run's **outer** legs, since a journey is searched again as a whole.
  This is what lets a routine's plan become a real connection: `RoutineController` copies the
  plan first (offline-safe, instant, correct on its own), then looks each `PlannedJourney`
  up for the day it now sits on and offers the result in the ordinary `journey_sheet.dart`.
  Accepting it swaps the legs via `RoutineDao.replaceJourneyLegs`, which **keeps the group**
  so the shared ticket hanging off it survives — and rescues a cost sitting on a *leg* onto
  the group (or the replacement's first leg) rather than letting the cascade take it, since a
  single-leg commute has no group to hang its fare on — and puts the replacement back in the *slot*
  the old run occupied rather than on the end of the day — appending once put a stop added
  after the journey in front of it. A wider replacement pushes what followed it down,
  decisions included, since a day's items and its sets share one ordering space.
  The lookup **says nothing when it works**: the connection it took is in the trip the user
  is one tap from opening, so announcing it only queues a message in front of that tap. Declining, finding nothing, or losing the
  network all leave the copied plan standing — and "no train" is never reported when it was
  "no signal". A run whose id has been lost — a leading walk deleted, an end leg replaced — falls
  back to the **coordinates** the leg still carries, since the router takes a coordinate
  anywhere it takes a stop id; the id is preferred only because it starts on the platform
  rather than outside the station. Without that fallback the ids' living on the outer legs
  alone meant any edit to an end silently and permanently un-offered the journey. A leg
  with neither ids nor coordinates (hand-entered) is simply copied as a plan: there is
  nothing to re-issue a query with, and guessing one from a station's name would be a
  different journey wearing the same label.
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
- **Drag reorders *within* a list; move/copy crosses between them.** A day and an option are
  two separate `ReorderableListView`s, and a decision is one index in its day, so no drag can
  express "into that option" — nor should one, since landing in an unchosen option takes an
  entry's money out of the trip's totals, and this app's rule is that gestures browse while
  buttons commit. Crossing a boundary is therefore two explicit steps: the item sheet's
  **Move to… / Copy to…** picks the entry up into `itemClipboardProvider`
  (`features/itinerary/application/item_clipboard.dart` — a `HeldItem`, autoDispose so leaving
  the trip screen drops the hold rather than leaving an invisible pending move); the day's and
  each option's add-row then grows a `PutDownChip`, so the destination names itself by being
  the place you navigated to. The held entry stays visible, dimmed (`TimelineTile.held`), under
  a `_HoldingBar`. `ItineraryDao.moveItem` / `duplicateItem` do the writing, appending to the
  end of the destination (finer placement is the drag's job again). Two rules there: a moved
  entry **leaves its group** (a group is one contiguous run inside one day or option), and a
  **copy takes the plan, not the money** — a cost records a payment that happened once, and
  duplicating it would silently invent money inside the settle-up. The clipboard's `Held` is a
  sealed type: a `HeldItem` *or* a `HeldGroup`, so a whole shared-ticket run rides along too —
  picked up from a grouped entry's sheet, dimmed member-by-member (`isHeldItem`), landing via
  `GroupDao.moveGroup` (members travel together, still grouped, the shared cost riding along
  since it hangs off the surviving group) / `copyGroup` (a fresh bundle, no costs). The copy
  fields live once, in `copyItemPlan` (`data/database/item_copy.dart`), shared by every
  duplicate so a new column reaches them all at once.
- **Duplicating an *option* is in-place, not clipboard** (`AlternativeDao.duplicateAlternative`,
  the decision card's ⋮ menu): the "same as B, but…" third option. It adds an **unchosen** copy
  of the option on screen (the set already has its one chosen), cloning the option's internal
  grouping into fresh groups (a group is part of what the option *is*) but — as everywhere — not
  its costs. Moving a whole decision to another day, or flattening one option's contents out
  elsewhere, are deliberately *not* built.
- **A checklist travels by picker, not by hand** (`ChecklistDao.moveChecklist` / `copyChecklist`,
  offered from the card's overflow menu). Same two-step frame, different second step, because a
  checklist's destinations are just *the trips* — a short flat list that names itself, where an
  itinerary entry's are every day × every option. The rule that governs the money governs the
  ticks: a **copy arrives unticked** (a tick records that this was packed, on that trip), while
  a **move keeps them** — it is the same list, relocated. Copying last trip's packing list into
  the next one is what the feature is for, and a list is only reusable empty.
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
- **The router is somebody else's donated server, and its usage policy is part of the
  feature.** Transitous asks each request to carry a `User-Agent` naming the application,
  the client's **version** and a way of contact; all three live in `core/app_info.dart`
  (`buildUserAgent`, no Flutter import — the smoke tool is plain Dart), fed the real version
  by `appVersionProvider`, which `main` resolves from `PackageInfo` and overrides into the
  scope beside the database path. A browser drops that header (`User-Agent` is forbidden
  there), which the policy answers with the `Referer` — so any public web deployment must
  carry contact information on the page itself; no Dart change can supply it. It also asks
  that the data sources be **linked**, not merely credited: `core/widgets/attribution.dart`
  holds both links, under the search where the data is used and in settings, where they
  outlive the sheet — an imported connection stays in the trip, the PDF and the `.ics` long
  after the search that found it. The rest of the policy is why the client looks the way it
  does: `detailedLegs=false`, a debounced and cached geocode, journeys only on an explicit
  button, live refresh one leg at a time and never on a timer. `staging.api.transitous.org`
  and the `*.motis-project.*` hosts are off limits outright. Being an open-source,
  non-commercial app is a *condition* of using the API, not a coincidence.
- **A journey is read the same way before and after it is imported.** A connection found by
  the search and a run of legs the trip already holds are both mapped onto one
  `JourneyView` (`features/transport_search/journey_view.dart`, pure — plus the DB-side
  adapter in `data/journey_view_items.dart`), which the pure `journey_preview.dart` folds
  into `LegRow`/`ChangeRow` and one `presentation/journey_sheet.dart` draws. So the walking
  transfer the router puts between two trains reads as *the change* on both sides of the
  import, where the timeline can only show it as another leg. The arithmetic that survives
  the fan-in is `ViewPoint.absolute`, a monotone minute count each adapter defines in its own
  terms — UTC minutes from the router, wall-clock minutes from the trip, which has no
  timezones to be exact with. The sheet's unit is the **group**: importing bundles each day's
  legs into one, so a group already *is* a journey and the button sits on the run's label
  (`TimelineTile.onShowJourney`); an imported leg standing alone carries its own. Each leg
  card hosts the leg's own `LiveRefreshButton` — still one tap, one leg.
- **An imported leg keeps the stops it calls at**, encoded in `ItineraryItems.stopovers` by
  `data/database/stopovers.dart` (a JSON list of name + departure minutes + a day offset for
  a night train's small hours). A column, not a table: they belong to exactly one leg, are
  written once by the import and read only when that leg is looked at, so they ride in the
  row they describe and are there offline. Departure only, plus how late the service leaves
  it — or that it **skips** it, which is the one thing a stop list must not get wrong: a
  partially cancelled train goes on reporting the planned departure for the stops it is
  dropping, so reading that as a time tells a traveller their station is served, punctually,
  by a train that will pass straight through. A skipped stop is therefore struck through and
  never timed, and stays in the list rather than vanishing — the timetable still says the
  train comes past at that minute. The live-times refresh rewrites a leg's stops along with
  its ends
  (`refreshedStopovers`, one write via `setLiveTimes`), so one tap leaves the whole leg
  current — and a stop the live trip no longer mentions loses its old figure rather than
  keeping it. The **miss** is stored rather than an actual time, unlike the leg's ends: it is
  what gets printed either way, it comes from the UTC instants and so is exact, and a delay
  past midnight cannot read as a day early. The stops are *plan*, so they travel with a copy
  (`copyItemPlan`) and in the `.tpt` bundle; `sourceTripId` does not, since it names one
  dated run of one service — which is also what says a lone leg has a journey to show
  (`hasStandaloneJourney`), since a service the feed lists no stops for is an imported
  journey all the same.
- Times are stored as **minutes since midnight** (int, 0–1439); money as **minor units**
  (int cents) to avoid float rounding, and amounts may be negative (refunds/income). The
  SharedPreferences-backed `CostReasonDisplay` / `ExpenseScope` enums are persisted by
  **integer index** — only ever append new values at the end, never reorder.
- **Currencies are a user-managed table too**, on the same pattern as the transport modes: a
  cost's `Costs.currency` is a foreign key into `Currencies`, and the `Currency` enum is only
  the *catalogue of built-ins* (EUR/USD/GBP/CHF) the DB is seeded with, in enum order, so a
  fresh row's id is its enum index + 1 — what the v23 migration repoints legacy costs by. A
  row's identity is its unique `code`; unlike a mode, a currency in use **cannot be deleted**
  (`restrict`, plus a check in `CurrencyDao`) — a leg without a mode is still a leg, an amount
  without a currency is nothing. Exactly one row `isBase`, and every other carries an optional
  `rateMicros`: what one of its units is worth in the base, in millionths (`kRateOne`), or null
  for "not set" — the app then declines to convert rather than guessing. `CurrencyDao.setBase`
  re-expresses every rate against the new base (clearing them when the new base has no rate to
  divide by; `rebaseClearsRates` warns first). CRUD is in `CurrencyDao`, the UI in
  `features/costs/presentation/currencies_settings.dart`.
- **The maths stays per-currency; conversion is only ever an extra line.** `core/format/money_format.dart`
  holds the pure `CurrencyInfo` / `CurrencyBook` — a lookup by row id *and* by code, plus the
  base and the display order — that everything printing money reads (`currencyBookProvider`;
  the PDF and `.ics` build one from `TripBundle.currencyBook` instead). Totals are keyed by
  currency **code**, not row id, so one map shape serves both the app and a shared trip.
  `formatTotals` appends "≈ €395.90" when several currencies are involved *and* every one has
  a rate — never replacing the exact per-currency figures, and never on a partial set, which
  would read as a total while leaving money out. `computeTripStats` still converts nothing.
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
  `Trips` carries `kind`/`fromRoutineId` (above), `Tags` / `TripTags` (the user's filing,
  above),
  `CostReasons` (reusable reason labels with an optional icon id), `Currencies` (the
  built-in-plus-custom currencies with their base flag and exchange rates, above),
  `TransportModes` (the built-in-plus-custom transport modes, above), `People` (reusable payer/
  beneficiary names; one flagged `isMe`), `TripParticipants` and `CostBeneficiaries`
  (many-to-many join tables), `Checklists` / `ChecklistItems` (any number of named checklists
  per trip), and `CollapsedDays` (persists which itinerary days are collapsed).
- **Expense splitting** lives in `lib/features/costs/trip_stats.dart` as pure functions
  (`computeTripStats`) so the per-currency category breakdown, per-person paid/share/balance,
  and minimal settle-up transfers are unit-testable without a database. A cost splits among
  its `CostBeneficiaries`, falling back to all trip participants. Nothing here converts between
  currencies — everything is computed per currency code, in the `CurrencyBook`'s order.
- **A settlement is a `Costs` row that isn't spending.** `Costs.isTransfer` marks money handed
  from one person to another to square up: always trip-level, `paidBy` the sender, its single
  beneficiary the receiver, and no `reason` (a repayment is not a category). It moves the two
  balances and nothing else — `computeTripStats` keeps it out of `totalMinor`, the paid/open
  split, the expense `count` and the categories, folding it instead into
  `PersonStat.settledMinor` (sent − received), which `netMinor` adds to `paid − share`. So
  "paid" still means "spent on the trip" and still sums to the trip's total, while the
  settle-up list — unchanged, it just reads `netMinor` — shrinks by what has been paid back.
  Unlike an expense, a settlement with no beneficiary recorded does **not** fall back to the
  participants: it would otherwise quietly spread itself over everyone. The same rule is
  mirrored wherever money is summed: `sumByCurrency` (every "Total" the app prints) and
  `CostDao.watchTotalsByTrip` (overview cards) drop transfers, while
  `watchCountedCostsForTrip` keeps them — they are what settles the balances. Recording one
  goes through `CostController.addTransfer` / `showTransferFormSheet` (a "from → to" form, no
  category, no split), reachable from the trip's general expenses and, prefilled, from each
  suggested payment in the settle-up list.
- Everything hangs off `Trips` and cascades on delete (`ItineraryItems`, `Costs`, checklists,
  participant/beneficiary links). Cascades rely on `PRAGMA foreign_keys = ON`, set in
  `AppDatabase.migration`'s `beforeOpen`.
- **A trip leaves the app in three shapes, all built from one `TripBundle`** (`features/sharing/`,
  all pure so they test without a database): the `.tpt` bundle itself — the only *lossless*,
  round-tripping one, and the only one with an importer — plus two one-way views, `trip_pdf.dart`
  and `trip_ics.dart`. All three read the plan the same way the timeline does: only *live* entries
  (loose ones and the chosen option of each decision), so the road not taken never leaves either.
  The `.ics` export leans on the fact that the app stores **no timezone at all** — a day plus
  minutes since midnight — which is exactly iCalendar's *floating* time (`DTSTART` with neither a
  `Z` nor a `TZID`), so nothing is converted and nothing can be converted wrongly. What a calendar
  cannot hold is dropped rather than faked: an untimed entry becomes an all-day event and thereby
  loses its `sortOrder` (a calendar orders by time or not at all), and groups, checklists,
  participants and actual times have no mapping (costs ride along as description text, readable
  but not counted). Import of `.ics` is deliberately **not** built — a calendar event routinely
  spans days, which an item (one day, strictly) cannot represent.
- **A bundle stamps only the format version the trip actually needs**, so an older app keeps
  reading what it can: v2 for a trip with decisions, v3 for one using a currency the old
  four-value enum never had. That is why a cost's currency is written under the *old enum name*
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
  ("5 days · 18 entries") and a section this trip has nothing for is greyed out rather than
  offered as a switch that yields no pages. `summarizePdfSections` counts through the same
  helpers the builder lays out with (`countedBundleCosts`, `bundleItemIsLive`,
  `printableChecklists`), so the picker's numbers cannot drift from the document's contents.
  A section unavailable on this trip keeps its stored setting for the next one.

### Database portability & schema changes

- Data is one SQLite file. Desktop can open/create a DB at any path; Android imports/exports.
  `DatabaseController` (`lib/features/settings/application/database_providers.dart`) coordinates
  switching/importing/exporting. Where the app can't choose a path — Android (scoped storage
  hands back a `content://` URI, not a file it may hold a WAL handle on) and the web — the DB
  always lives at the fixed default location, so **"new database" can only mean "emptied in
  place"**: `createEmpty` is the import flow with nothing to copy in. "Reset to default" is
  desktop-only for the same reason — only a platform that can be pointed *away* from the
  default path can be sent back to it; elsewhere it would be a no-op wearing a destructive
  label. WAL mode writes `-wal`/`-shm` sidecars; call `checkpoint()`
  before copying and `deleteSidecars()` before replacing a file (see `core/database/database_location.dart`).
- Bump `AppDatabase.schemaVersion` (currently 27) and add an `onUpgrade` branch for **any**
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

The Android toolchain is **AGP 9.3.1 on Gradle 9.6.1**, and nothing about that combination
is pinned any more — the version ceilings that used to live in `.github/dependabot.yml` are
gone, because the `Build Android APK` job in CI now exercises the real
`flutter build apk --split-per-abi`. That job is the whole guard: every failure in this area
happens while Gradle *applies its plugins*, long before a line of Dart or Kotlin is
compiled, so `analyze` and `test` are blind to it and a breaking bump used to merge green.

What is deliberate is `android.builtInKotlin=false` in `android/gradle.properties`. AGP 9
compiles Kotlin itself by default; the Flutter scaffold writes `false` to keep the old
arrangement where the **Kotlin Gradle Plugin** does it, and that is the only mode that
builds. `flutter build apk` prints a `[!] Flutter Fix` box recommending the migration —
**taking that advice breaks the build**, and no plugin upgrade will change that, because
the blocker is Flutter itself. `FlutterPluginUtils.kt` walks the subprojects, and for
every one that applies AGP but does *not* itself apply KGP it calls
`pluginManager.apply("kotlin-android")` — without consulting `android.builtInKotlin`. AGP 9
with built-in Kotlin then aborts on exactly those projects, because KGP is present after
all. The irony is that this hits the plugins that have *already* migrated:
`file_selector_android` correctly applies AGP and no KGP, so Flutter re-applies it and the
build dies there. Its companion `android.newDsl=true` is no escape either — Flutter's Gradle
plugin throws a `NullPointerException` before it gets as far as Kotlin.

None of this is a defect to chase: Flutter's own documentation states that **enabling
built-in Kotlin requires Flutter 3.47 or later**, and the pinned toolchain here is 3.44.
The flag simply is not supported yet, and the call site above is the shape that takes.
Flutter deliberately ships both properties as `false` for the duration of the ecosystem's
migration (flutter/flutter#183910); the escape hatch is documented as going away before
AGP 10.

So the warning that survives a good build — "Your app uses the following plugins that apply
Kotlin Gradle Plugin (KGP): home_widget" — is expected, and should be neither chased nor
silenced. `home_widget` is **already migrated**: 0.9.3 carries "Apply kotlin plugin when
not built in" (ABausG/home_widget#425, closing #421), which is the two-condition check that
consults `android.builtInKotlin` — so it applies KGP here precisely because we asked for
legacy mode, and it cannot drop the line without breaking AGP 8 users. It is named only
because Flutter matches a **textual** regex against the build script, which cannot see the
`if` guarding it; the other plugins receive KGP just as surely, from Flutter, and go
unmentioned. There is no plugin upgrade to wait for. The warning clears when Flutter 3.47
lands and `android.builtInKotlin=true` becomes possible — that upgrade, not a dependency
bump, is the thing to revisit.

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
`file_picker` yields no path on web, so `_import` reads the picked file through
`PlatformFile.readAsBytes()` rather than off `path` (the older `withData:` flag that used to
pre-load them is deprecated).
