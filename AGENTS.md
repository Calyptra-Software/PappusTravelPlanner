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
  ne_50m_admin_0_countries.geojson assets/geo/countries.json   # rebuild the country outlines
```

Regenerate code after editing anything under generation:

- **`dart run build_runner build`** after changing any Drift table/DAO (`lib/data/database/`)
  or any `@riverpod`-annotated provider. Generated `*.g.dart` files are committed alongside
  their sources — never edit them by hand.
- **`flutter gen-l10n`** after editing `lib/l10n/app_en.arb` / `app_de.arb`. `app_en.arb` is
  the template; every key added there must also be added to `app_de.arb`.

**`SECURITY.md` states facts, not intentions**, and a change can make one of them false
without touching it: that exactly one host is contacted (`api.transitous.org`), that the
Android build asks for one permission (`INTERNET`), that there is no telemetry of any kind,
and the list of foreign files the app parses. A second host — a map's tile server is the
obvious one — a new permission, an analytics or crash-reporting dependency, or another
format read from outside all turn a sentence there into a false claim about what the app
does with someone's data. Correct it in the same commit; a security policy that has drifted
is worse than none, because people rely on it.

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
- **A trip is a trip, however long it lasts.** A walk, a commute, and a fortnight in
  Rome are the same row with different dates — a one-day trip is simply one whose start
  and end are the same day, so nothing declares "scale" and the timeline drops its day
  headers whenever it draws a single day (derived from the dates, not a flag). The one
  thing dates cannot say is whether a plan is meant to be *used again*, and that is the
  whole of `TripKind`: `trip` or `routine`.
- **Tags are the only axis the overview is organized by** (`Tags` / `TripTags`, modeled
  on `People` / `TripParticipants`). The app does not decide that a bike ride is a lesser
  kind of trip than a holiday — that judgment is the user's, so "walks", "commute",
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
  crowding they were introduced for. Its **checklists** travel for the same reason and by the
  same rule as every other copy: the list is what to take *every* time (badge, laptop, season
  ticket), so it is a template like the legs are, and it arrives **unticked**
  (`ChecklistDao.copyChecklist`) — packing is something an occurrence does, as paying is. `Trips.fromRoutineId` records where a trip came from,
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
  **Each day of the replacement is one bundle**, the same rule the import follows: a run of two
  or more legs arriving where there was no group is *given* one (a lone leg the timetable now
  routes with a change has a ticket to hang somewhere, and the journey sheet reads a group),
  while a replacement that crosses a midnight the old run did not keeps the surviving group for
  its first day and leaves the far side of the night out of it — a group may not straddle two
  days, which `GroupDao.groupItems` refuses to build in the first place, and a single leg over
  there is left loose exactly as an imported overnight journey leaves one. A leg written onto a
  day outside the trip's own range widens it (`TripDao.widenToCover`, called by the import too):
  the timeline draws such a day regardless — its days are the union of the range and the
  entries — but the overview card, the calendar, and the header all read the *range*, so the trip
  would go on calling itself a day shorter than it is. Nothing to widen on a routine (ordinals,
  not dates) or on a trip with no dates at all, where an absent range is a deliberate "not
  decided yet" rather than a range to be guessed from a timetable.
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
- **A journey is looked up again from the sheet that reads it**, one run at a time
  (`JourneyDetailsSheet`, on the group's label or a lone imported leg). The trip-wide lookup
  above happens once, in the seconds after a routine is stamped out; every way of not
  finishing it — the switch left off, no signal on the platform, "keep the plan" tapped by
  mistake, nothing running at that hour — used to leave the plan un-refreshable for good,
  since a copied leg carries no `sourceTripId` and nothing else asked the timetable again.
  The button opens the **ordinary search sheet**, pre-filled from the run
  (`ConnectionSearchSheet.replacing`, seeded by `PlannedJourney.fromPlace`/`toPlace` — which
  keep the exact `queryId` the run was found by rather than re-deriving one from the
  coordinates), and taking a result there goes through the same `replaceJourney`, so the
  group, the ticket, and the slot behave identically. The form and not a single silent request,
  because the question is rarely quite the old one: the 07:32 was canceled, the afternoon
  will do instead, today there is a bike to carry — so the day, the time, arrive-by, the vias,
  and the search options are all still the user's, and a list of departures is what a
  traveler picks from. Per journey rather than per trip, because that is the unit the
  question arises in, and on any trip, not only one stamped out of a routine — a **routine**
  included, where the search is made on a real date and the answer laid back onto the plan day
  (`replaceJourney`'s `rebaseFrom`/`rebaseTo`, the same trade `intoRoutine` makes for an import,
  leaving the run's `sourceTripId` and live times behind since a template must not look
  refreshable). A template is as worth re-routing as an outing: a line withdrawn or a 07:32
  retired changes every morning from now on, and the alternative was deleting the leg and
  importing a new one.
- **Being addressable is not the same as being worth asking.** `plannedJourneys` now applies
  two conditions rather than one: `canLookUp` (can the query be issued at all) *and*
  `carriesService` (is this a journey a timetable answers for). A run made only of street
  legs — walking, cycling, driving — is one the router can only hand back unchanged, since it
  recomputes the same path over the same pavement. Running the two together meant that
  pointing at both ends of a campus walk on the map, for the map's own sake, quietly enlisted
  that walk in the unattended lookup, and a routine then asked about it every morning it was
  stamped out. The set is `streetTransportModeIds`, resolved from the **table** and not from
  the enum (a mode is a row the user manages), and defined as exactly the built-ins
  `builtinTransportModeFor` produces from `TransitMode.walk`/`bike`/`car` — the router's own
  answer to "is this a service", rather than a list chosen by taste. A renamed built-in still
  counts, by its `builtinKey`; a mode the user invented, or a leg with no mode at all, does
  **not** count as a street leg, because only what is positively known to be one may cost a
  run its lookup. What is given up is stated plainly: the routine will not discover by itself
  that a bus now beats the walk. `plannedJourneyOf` is untouched, so that question is still
  one tap away from the journey sheet or the item form — the capability moves to where a
  human is watching, which is the split those two functions already exist to draw.
- **A run with no addressable ends is a question for the form, not a dead end.** What the
  routine flow may not do — invent an endpoint for a query nobody is watching — the user may
  do deliberately, so a **hand-entered** run is offered the search too: the form shows the
  names the legs carry ("Rahlstedt") as hints on the empty From/To fields, hands each to the
  place picker as its opening query, and keeps *Search* disabled until both are named. The app
  still never turns a name into an address by itself; it just puts the geocoder's answers one
  tap away, and which Rahlstedt it is stays the user's call. Hence two readings of one run:
  `plannedJourneys` (filtered by `canLookUp`) is what the unattended flow may search, while
  `plannedJourneyOf` is the run the user is looking at. The replacement's outer legs then keep
  the ids **this** search used, not the ones the old run carried, since either end may have
  been repicked outright (`replaceJourney`'s `fromPlaceId`/`toPlaceId`, defaulting to the
  journey's own for the routine flow). Nothing is turned away for want of an addressable end;
  `intoRoutine` and `replacing` compose rather than exclude, and the flag has to reach the form
  from wherever it was opened — including the deep-link opener, which is why `_OpenItemOnce`
  carries it too. A leg of a routine dated by a *search* instead of the plan is the 2083 bug
  waiting to happen again.
- **One leg of a run is searched from its own card**, beside its live-times button
  (`JourneySheet.onFindLegConnection`). The label above answers "is there a better way to make
  this journey"; a leg answers the question a journey already under way raises — the train in
  came twenty late and the connection is gone, or the change turns out to be six minutes and
  not sixteen — where what has to move is the *rest* of the journey and not the part already
  traveled. Only that leg's row is replaced: its slot, its group and the run's shared ticket
  survive, and what comes back may itself be several legs, since a missed connection is often a
  different route (`replaceJourneyLegs` widens the day for it). An inner leg carries no
  endpoint id — those live on a run's outer legs — so it goes out on the **coordinates** every
  imported leg keeps. The time it starts from is where the traveler really is:
  `departureSeedMinutes` prefers the **previous leg's actual arrival** when one has been
  recorded (late or early — standing there sooner means an earlier connection is catchable), so
  a delay already entered on the leg before does not have to be typed again. Not across a date
  boundary or an overnight leg, where minutes-since-midnight would seed the wrong day. It seeds
  a form the user reads and can change; nothing here decides anything. Offered only on a run of
  two or more legs, since on one leg it would be the journey's own button twice.
- **A lone leg is looked up from its own sheet**, not the journey sheet: the item form's
  "search online" button, which for a *new* leg adds a run and on an **existing** one replaces
  it (`ItemFormSheet._canReplaceLeg`). That is the entry point a hand-entered leg has, since
  `hasStandaloneJourney` deliberately keeps the journey sheet off a leg the import never
  touched. It is offered only on a leg standing **on its own**: a grouped leg is one leg of a
  run, and a run is replaced whole from the label above it, so replacing one leg of a shared
  ticket from inside an edit form is not a thing the app does.
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
  pure): an `ItemBlock` (a loose item), a `GroupBlock` (a whole run), or a `DecisionBlock` (a
  whole set). A decision draws as
  an `AlternativeCard` — a `PageView` **swiped** between options, which only *browses*;
  choosing is the explicit button, so looking at an option never moves the trip's money. The
  indicator row under it carries every option's price (the comparison a pager otherwise hides).
  Dragging in a day reorders blocks (writing `ItineraryItems.sortOrder` *and*
  `AlternativeSets.sortOrder`); dragging inside a card reorders that option's blocks, and
  dragging inside a run reorders that run's members. An option is built from the same
  `buildItemBlocks` a day's loose entries are, so a run reads and drags the same way in either.
- **A run is one slot, and a slot is not one sort order.** A group of entries sharing a ticket
  is a single thing to the plan, so it is a single block: it drags as one, and no drag can put
  something in the middle of it or pull a leg out — the two acts that cross a boundary stay the
  explicit move/copy. Its members are a `ReorderableListView` of their own inside the band
  (`GroupRunTile`), the same arrangement a decision has: a card that moves as a unit in the day,
  holding a list that reorders within itself. Before this each member was its own slot, so a run
  could be dragged apart, and the halves went on claiming to be one group — each drawing the
  band and printing the shared ticket. The renumbering therefore walks a **running counter**
  rather than writing each block's index (`_onReorder`), since a run of three legs is one block
  holding three ordinary items; and reordering *within* a run hands the run's own sort orders
  back out in the new order, so rearranging it can never walk it out of its place in the day.
  `buildItemBlocks` collects a run by `groupId` rather than by adjacency: nothing can split one
  any more, but a database written before this could hold one that a drag had split, and closing
  the gap is better than drawing it as two.
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
  dimmed member-by-member (`isHeldItem`), landing via
  `GroupDao.moveGroup` (members travel together, still grouped, the shared cost riding along
  since it hangs off the surviving group) / `copyGroup` (a fresh bundle, no costs). The copy
  fields live once, in `copyItemPlan` (`data/database/item_copy.dart`), shared by every
  duplicate so a new column reaches them all at once.
- **What is done to a whole run is done on the run's label** — the ⋮ menu on the group band
  (`_GroupMenu` in `widgets/timeline_tile.dart`): *Rename group*, *Move group to…*,
  *Copy group to…*, *Ungroup*, *Delete group*. The unit an act applies to is the unit it is
  offered on, the way a decision's acts sit on the decision card; a member's edit form is where
  that *entry* is changed, and it cannot name the run standing above it. So all five live here
  **only**, and the grouping section of a member's sheet keeps just what is about that entry's
  own membership — group with next, remove from group. The name and the dissolving were the last
  two to move: both act on the run, yet were reached through whichever member you happened to
  open, which is an accident deciding where an act is performed from. Delete could not have
  lived there in any case, since it deletes the entry the form is editing. Ungrouping sits
  directly above deleting because it is the harmless half of the same question, and the delete
  dialog says as much in words — a way out named in a warning has to be within reach of the door
  it warns about, not two levels down in a member's form. Delete is also the act that had no path
  at all: deleting a run entry by entry dissolves the group only once one member is left, and
  `_dissolveIfDegenerate` then *rescues* the shared ticket onto that survivor, so a journey
  removed leg by leg left its fare behind on the last leg standing. `GroupDao.deleteGroup` is
  therefore the mirror image of `dissolveGroup`: the entries go, and with them the money —
  each member's own costs by cascade, the shared one with the group — since a ticket is not
  still paid for once every leg it covered is gone. Destructive, so it asks first, and the
  question says that ungrouping is the way to keep the entries.
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
  (marked with a `NowBadge`, a red rail node, and a tinted tile) or *the line goes here* (a
  `NowLine` between two blocks, after the last block that is behind us). The same rule runs a
  second time *inside* a decision that is under way (`nowMarkerForItems` over its chosen
  option): a decision spans its option whole, so when now falls between two of that option's
  entries the day draws no line — the boundary is inside the card, and so is the line.
  Untimed entries stay
  *ahead* of the line unless something timed after them is already past — we cannot know when
  they happen, and claiming they are done is the guess that would make the mark lie. An
  **overnight** entry's end is minutes into the *next* day, so `itemSpan` carries it past
  midnight (`+ kMinutesPerDay`) rather than letting `end < start` collapse the span to a
  moment: without that, a night train reads as finished the minute it departs, and the
  traveller sitting on it is told the journey is behind them. A decision
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
  `widgets/item_times.dart` (colored spans) and the home widget (see below). An actual time
  outranks its planned one in `now_marker.dart`, though: "you are here" is a claim about the
  day as it is going.
- **The router is somebody else's donated server, and its usage policy is part of the
  feature.** Transitous asks each request to carry a `User-Agent` naming the application,
  the client's **version**, and a way of contact; all three live in `core/app_info.dart`
  (`buildUserAgent`, no Flutter import — the smoke tool is plain Dart), fed the real version
  by `appVersionProvider`, which `main` resolves from `PackageInfo` and overrides into the
  scope beside the database path. A browser drops that header (`User-Agent` is forbidden
  there), which the policy answers with the `Referer` — so any public web deployment must
  carry contact information on the page itself; no Dart change can supply it. It also asks
  that the data sources be **linked**, not merely credited: `core/widgets/attribution.dart`
  holds both links, under the search where the data is used and in settings, where they
  outlive the sheet — an imported connection stays in the trip, the PDF, and the `.ics` long
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
- **An end addressed by a coordinate comes back unnamed and unzoned, and both
  silences have to be filled before anything reads the answer.** A stop answers
  as `Hamburg-Rahlstedt` / `Europe/Berlin`; a coordinate — which is what a picked
  address, a point tapped on the map and an imported leg's own ends all travel as
  (`TransportPlace.queryId`) — answers as `{"name": "START"}` with no `stopId`
  and **no `tz` at all**, since the router knows a point on the street network and
  nothing else about it. Left alone each silence became a false statement rather
  than a missing one: `START`/`END` were written into the timeline as the
  stations' names, and the absent zone was read as UTC, which showed *and stored*
  a Hamburg walk two hours early — a wrong time that looks like a time, with
  nothing about it saying it was guessed. `domain/journey_ends.dart` (pure) fills
  both, keyed on the missing `stopId` rather than on the placeholder name, which
  is a label and could change: the run's **outer** ends take the names the search
  was *issued* with (the place the user picked, or what the run being re-routed
  already calls its ends — the middle are changes the router named itself, and
  the query has no name for them anyway), and an unzoned end takes the **nearest**
  zone in the journey, carried forward from the last end that had one else back
  from the next. What the service itself said always stands. It is applied at the
  two places an answer arrives — `JourneyResultsController._fetch`, so paging
  windows are merged already resolved, and `searchPlannedJourney` — so the result
  rows, the preview, the journey sheet and the import all read one resolved
  answer instead of each repairing it. When *nothing* in the journey is zoned —
  a walk between two coordinates, which is exactly the short hop this arises on —
  `localParts` falls back to the **device's** zone: a guess too, but the one that
  is right for a hop, and wrong only for a traveller who has not yet changed
  their clock, where UTC was wrong for everybody outside it.
- **A connection is planned where the button that searched for it plans everything else.**
  The search is reached from the item form, which is reached from a day's *Add transport* or
  from one **option's**, so the option rides along — `ItemFormSheet` → `showConnectionSearchSheet`
  → `importJourney` → `insertJourney(alternativeId:)`. Without it the run was written loose on
  the day *behind* the decision, which is not merely the wrong slot: an option's entries count
  toward the trip only while it is chosen, so a connection searched into an option nobody picks
  was quietly charging the trip for it. Inside an option the legs take **one** sequence of sort
  orders rather than one per day, because a branch item's date does not place it in a day (it
  follows its decision, see `buildDayBlocks`) — an overnight run stays one ordered run in the
  option. Only an *added* run is told where it goes: replacing one keeps the place the old legs
  held, in an option or on the day, which is why the two are separate cases of the destination
  type below rather than parameters that could be passed together.
- **Where a found connection goes is a type, and one of its cases is "nowhere".**
  `presentation/journey_destination.dart` holds a sealed `JourneyDestination`: `AddToDay`
  (a day, or one option of a decision on it), `ReplaceRun` (the run whose legs make way for
  it), both under a `TripJourneyDestination` carrying the trip, the day and `intoRoutine` —
  and `JourneyLookup`, which names **no trip at all**. The search form is the same question
  in every case; only what becomes of the answer differs, so `ConnectionSearchSheet` takes
  one `destination` and switches on it. That is what makes the impossible combinations
  unsayable — a run cannot both be added to an option and replace an existing one — where
  before the rule was an `assert` that only fired at runtime, and the destination-less case
  could not be expressed at all.
- **A connection is worth looking up with no plan behind it.** "When is the next train?" is
  asked before there is a trip to hang the answer on, and often when there never will be
  one, so the overview's app bar opens the ordinary search sheet on a `JourneyLookup`: same
  form, same results, same preview. Having no day of its own it opens on **today**, which is
  what a question asked from the overview is nearly always about. Nothing is stored: not the
  query, and not the journey — a lookup that remembered yesterday's from/to would be
  claiming to ask about a journey nobody asked about, which is the same reason
  `TripQuery.text` is the one facet the overview does not persist.
- **What a lookup found is filed by naming a trip, and the trip is named *after* the
  journey.** The preview's button reads *Save to trip…* and opens `showTripPicker`
  (`features/trips/widgets/trip_picker.dart`, shared with the checklist's move/copy) — the
  ellipsis being the promise that a question follows, since nothing is written until a trip
  has been named. This is deliberately **not** a fourth `JourneyDestination`: that type
  answers "where does a result go?" at the moment the sheet *opens*, and here the answer does
  not exist yet. No day is asked for either — the connection was searched on a real date and
  its legs carry it, so the day it belongs on is the day it runs on, and a trip whose range
  falls short is widened to cover it exactly as an import from inside the trip is
  (`TripDao.widenToCover`). Routines are not offered: a real-dated journey laid onto a
  dateless plan needs a *plan day*, which a flat list of trips cannot ask for. With **no**
  trip in the database there is no button at all rather than one leading to an empty picker —
  the same rule that governs the preview's confirm button generally
  (`showJourneyPreviewSheet`'s `confirmable`): a button that wrote nothing would be worse
  than none. The trip list is therefore `ref.watch`ed in `build` — the answer is needed a
  build before the tap, and reading an autoDispose provider from a callback is the trap
  `TransportSearchController._modes` documents. Saving leaves the search **standing**, unlike
  every trip-bound import, which closes onto a timeline that has just changed underneath it:
  here the screen behind is as it was, and the return journey is the next thing anyone asks.
  *New trip from this connection* is deliberately not built yet.
- **An imported leg keeps the stops it calls at**, encoded in `ItineraryItems.stopovers` by
  `data/database/stopovers.dart` (a JSON list of name + departure minutes + a day offset for
  a night train's small hours). A column, not a table: they belong to exactly one leg, are
  written once by the import and read only when that leg is looked at, so they ride in the
  row they describe and are there offline. Departure only, plus how late the service leaves
  it — or that it **skips** it, which is the one thing a stop list must not get wrong: a
  partially canceled train goes on reporting the planned departure for the stops it is
  dropping, so reading that as a time tells a traveler their station is served, punctually,
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
  the *catalog of built-ins* (EUR/USD/GBP/CHF) the DB is seeded with, in enum order, so a
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
  `tables.dart`) is only the *catalog of built-ins* the DB is seeded with — each value's
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
  beneficiary names; one flagged `isMe`), `TripParticipants`, and `CostBeneficiaries`
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
  split, the expense `count`, and the categories, folding it instead into
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
  participants, and actual times have no mapping (costs ride along as description text, readable
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
  ("5 days · 18 entries") and a section this trip has nothing for is grayed out rather than
  offered as a switch that yields no pages. `summarizePdfSections` counts through the same
  helpers the builder lays out with (`countedBundleCosts`, `bundleItemIsLive`,
  `printableChecklists`), so the picker's numbers cannot drift from the document's contents.
  A section unavailable on this trip keeps its stored setting for the next one.

- **The map draws the plan, and the ground it draws on is swappable.** `features/map/` holds
  the pure `map_features.dart` (items → pins and lines, testable without a tile server),
  `basemap.dart`, and the screen. It reads the trip through the providers the timeline
  already uses and shows only **live** entries, the same rule the PDF and `.ics` follow, so
  an option nobody chose is never on the map. Two rules decide what appears: a leg is drawn
  only when **both** ends carry coordinates — one end alone would be a point, and on a map a
  point is a place — and **nothing connects one place to the next**, because the plan says a
  museum follows a hotel, not that anyone walked between them in a straight line. Long legs
  are interpolated along a **great circle** (a straight line in Web Mercator is not the route
  anything takes) and split where they cross the **antimeridian**, since a Tokyo-to-Los
  Angeles flight is one journey but cannot be one polyline. "You are here" is
  `now_marker.dart` again, asked about today's entries and used only for its *happening*
  answer — a map has slots but no gaps between them to draw a line in — and never on a
  routine, which has no today. **A marker answers when tapped**
  (`map_item_sheet.dart`): a map can only say *where*, while the name, the times, how late
  the leg ran and the note someone left on it all live in the row it was drawn from — a pin
  with no way to ask about it is a dot on a picture. The sheet is a *reading*, not a second
  editor: times come from the same `ItemTimes` the timeline uses, so a delay reads
  identically in both, and the one button hands the job to the form that already owns it.
  Lines and markers take the **trip's own accent**
  (`Trips.colorValue`), the color its card, header, calendar bar and PDF already use, not a
  color from the theme, which says nothing about *which* trip is on screen — and that is the
  rule the all-trips map inherits, so every line there identifies itself. Each line carries a
  casing (`borderStrokeWidth`) in the surface color: a user-chosen accent will land on tiles
  it disappears against otherwise, which is why paper maps do the same.
- **A position is pointed at, never derived.** `map_picker_screen.dart` opens the map on a
  full-screen route — a sheet answers a vertical drag by closing, which is the same gesture
  as panning. A **tap** drops the marker, the readout says where it landed, and *Use this
  point* stays disabled until there is one, so the screen can never return a position nobody
  chose; an edit opens holding the position it is editing. (A fixed crosshair with the map
  moving under it was tried first — a fingertip does cover the point it is placing — but
  tapping won on being the more obvious of the two: the mark appears where you pointed.) The
  marker is drawn ink-on-halo in **map** colours, not theme colours: raster tiles are pale in
  both themes and full of thin red lines, so a mark tinted by the theme is a road.
- **The search can be pointed at the map too.** The place picker in `connection_search_sheet.dart`
  offers *Choose on map* above the geocoder's answers, for an address it does not know, a
  trailhead with no name, or simply "from here". What comes back is a `TransportPlace` of
  kind `place` — which is what makes `queryId` send `lat,lon`, since there is no id to send
  and a coordinate is what the router wants for a door anyway — named by its own numbers,
  because asking the geocoder what is there would put a name on a choice the user did not
  make. Not offered for a **via** stop: only stop ids are allowed there, so a coordinate
  would be a choice that could only fail, which is the same reason that list is filtered to
  stations.
- **The picker writes coordinates and nothing else.** Not `fromPlaceId`/`toPlaceId`: those
  mean "the id the search was issued against", and a tap on a map is not a search. The
  coordinate fallback in `planned_journey.dart` then addresses the end anyway, which is what
  makes a hand-entered leg `canLookUp`-able once both its ends are placed — but no longer
  *searchable* by itself if it is a walk, since that silent side effect turned out to be the
  bug (see the street-mode rule below). The one
  write in the other direction is a **clearing**: moving (or removing) an end drops *that
  end's* id, because the id no longer describes where the end is — and it would win over the
  coordinates, sending a re-search off from the old station. `sourceTripId` stays: it names
  the service, not the end. Reverse geocoding is deliberately absent — the app never turns a
  name into a position or a position into a name; which Rahlstedt was meant is the user's
  answer. A position is therefore its own field in the item sheet, beside the name and
  clearable on its own, and the two are kept as a **pair**: a latitude without a longitude
  is not half a place, so the form normalises the fragment away rather than writing it back.
- **Where the device is, is a measurement; everything else on the map is a
  statement.** `features/map/location/device_location.dart` holds the sensor's
  answer and nothing else does: a fix lives in `deviceLocationProvider`'s state,
  is never written to a row, never rides in a `.tpt` bundle or an export, and is
  never sent anywhere — the tile server is still addressed by grid square, so
  centering on yourself asks for exactly the tiles panning there by hand would.
  It is the app's **first and only runtime permission**, requested on the press
  of the locate button and at no other moment, and released again by
  `autoDispose` when the last map watching it goes away — which is why the map
  must not start it for you: a screen that switched a receiver on because it was
  opened would be asking for something nobody requested. Declining, location
  switched off device-wide, and no receiver at all are three *answers*
  (`LocationProblem`), each with its own sentence and, for the two with a system
  screen behind them, a button that opens it. The one press does the whole job:
  permission, receiver, and **one** centering — `listenForFirstFix` reads "first"
  off the null-to-fix transition, which is exactly why switching the mark off
  clears the fix, and every reading after that moves the mark and not the camera,
  since a map panned ahead to see what is coming must stay where it was put.
  The mark is drawn in a **blue of its own** (`device_location_overlay.dart`),
  not the trip's accent and not the reserved red: it is not part of the plan, and
  the two "you are here"s must not be mistakable — `now_marker.dart` answers
  where the *plan* has got to, this one where the *device* is. Its accuracy is
  drawn as a circle to scale rather than dropped, because a 300 m fix drawn as a
  bare dot is a false statement in the most convincing form available. The picker
  offers the same reading as something to **take** rather than to watch, and it
  is still a pointing act — but only the reading the press was waiting for is
  taken, and a map tap made while waiting wins, or a choice made at a doorway
  would follow its owner down the street.
- **The overview draws the same trips three ways, and which one is a setting.**
  `TripView` (list / calendar / map) lives in `tripViewProvider`, persisted by index and
  append-only like every other stored enum here — the list/calendar switch used to be a
  `bool` in the screen's `State`, which sat oddly beside the rule that *how the overview is
  read* is remembered. It matters more with three: the map fetches tiles, so being dropped
  onto it unasked spends somebody's data. One control, a **menu and not a cycle** — the icon
  shows the view that is on screen, and a cycle past three states makes the map a stop on
  the way somewhere else.
- **The all-trips map is handed its trips, so the filter is inherited rather than rebuilt.**
  `AllTripsMap` draws exactly the list `applyTripQuery` left visible, which is why "only my
  walks, this year" needs no second filter UI; routines are excluded because that function
  already excludes them. Each trip keeps its **own accent**, the color its card is drawn in,
  which is what makes a tangle of lines readable. The camera re-frames when the *selection*
  changes but not when the stream merely ticks: tapping a tag chip is an explicit act with
  an expectation attached, while a rebuild is not. Its entries come from
  `ItineraryDao.watchPositionedItems` — the one query here that is not about a single trip,
  with the live rule expressed in **SQL** (the precedent is `CostDao._countsTowardTotals`)
  and no trip filter at all, since a family keyed by a list compares by identity and would
  rebuild every frame. **A tap answers with every trip under it, not the topmost**, because
  overlap is this map's normal state: a commute is drawn once per day it was made, so twenty
  lines lie exactly on each other, and at any zoom showing a country neighboring routes
  share their stretch of highway. Picking the last-drawn line would be a coin toss the user
  cannot see and cannot re-roll — the trip they meant may be unreachable at that spot. So
  `hitValues` is folded to one entry per trip, in the **overview's** order rather than the
  drawing order (the map is a view of that list, and a stable order is one you can learn);
  one trip opens its card as before, several are listed to choose from. `kLineHitbox` widens
  the hit test past the 3px stroke for the same reason — what "on this line" means has to be
  a fingertip, and a shared stretch that reads as one line should be one tap.
- **A track is a line with a provenance, not "the GPX file".** `Tracks` (v29) holds the
  line an entry *actually* followed — packed by `track_points.dart` into the encoded-polyline
  format every mapping tool reads, so a dense recording costs a fraction of its point count
  and can leave the app without a decoder being written first. A recorded walk, an imported
  route and a path a router computes later are the same row wearing different `TrackSource`
  values, which is why the enum names all three though only the first can be made today: a
  table that could not say "this one was actually walked" would have to be migrated to say
  it. Elevation, timestamps and the file's markup are dropped on the way in (`parseGpx`),
  each for a stated reason — the app has no reading for a profile, and the file remains where
  those live. `<trkseg>`s are **not** joined: a break is where the recording stopped, so they
  arrive as separate rows under one name, which is the same rule the map already follows
  between two places. A `<wpt>` is ignored outright — a waypoint is a place, and inventing a
  dozen untimed entries from a route file is an import of a different kind.
- **One recording is divided among the entries it covered.** A file is made in one go and
  the plan is not, so `splitTrack` / `splitTracks` (pure, `track_split.dart`) cut the line
  where one entry handed over to the next, and `trackImportPlan` reads a selected run:
  **only legs** get a stretch (a place is a point with no straight line to replace), and a
  **positioned place between two legs supplies their handover**, which is exactly what one
  is. It works the other way too: a place *without* a position is **filled in** from the
  handover its neighbours get, or from the recording's own end when it stands at the front
  or back of the run — all three readings of one spot then agree, which they did not when a
  place was left out of the writing. Two properties outrank the exact cut, because they are what a later edit would break:
  **every stretch gets points** — an entry left empty would draw its chord again the moment
  somebody gave it coordinates, weeks later — and **neighbours share their handover point**,
  so the pieces still read as one line. Handovers are located **in order**, each searched
  only in what is left after the one before it; that is what makes a there-and-back route
  work, where "nearest to this coordinate" is ambiguous and "nearest after the last
  handover" is not, and it is what keeps a handover *moved after the fact* between its
  neighbours, since a stretch cannot run backwards. `snapToTrack` answers a tap under the
  same rule, so the preview and the result cannot disagree. A `<trkseg>` gap survives the
  division: an entry spanning a pause keeps two lines rather than one drawn across ground
  nobody covered. There is **no rule for a handover nobody placed**, because there is no way
  to leave one unplaced.
- **The import asks rather than guesses, and shows the division while it is being decided.**
  `TrackImportScreen` draws the recording, colours it per entry, and asks for each handover
  nobody could supply — one tap, snapped onto the line, and **every** one of them: there is
  deliberately no way to skip. That is the app's own rule (*a position is pointed at, never
  derived*) applied to a cut, and an estimated cut is invisible, which is what makes it the
  kind of guess that turns into a wrong answer months later. Insisting also means nothing
  downstream needs a rule for dividing a line nobody has said anything about, and no entry
  can come out of an import half-placed — the failure that made the rule necessary. A
  handover already placed is not final: a further tap moves the nearest one, which is the
  screen's only interaction — an earlier "pick it up, then put it down" step was a state
  nobody could see, competing with the map for the same tap. The **outer** ends
  need no asking: the recording's first point is where the first leg started
  (`trackImportEnds`), which is also what fills in a single hand-entered leg's coordinates.
  An end the user already gave is never overwritten — their statement, with the file as a
  witness. Writing coordinates and writing the pieces is **one transaction**
  (`TrackDao.importTrackAcross`), and a placed end drops its `fromPlaceId`/`toPlaceId` by
  the rule that governs moving one. One flow, two doors — the trip's ⋮ menu (nothing ticked)
  and a leg's form (that leg ticked) — because a recording rarely stops at one entry, and
  the unit an act applies to is the unit it is offered on.
- **A recording covers one path through the plan, because a decision is a fork.** The
  entry picker is handed `buildTrackEntryPath` (`features/map/track_entry_path.dart`,
  pure) rather than `itemsFor` as it comes, for two reasons that turn out to be one. The
  visible one: listing every option at once printed the same station two and three times
  with nothing to tell the copies apart. The silent one: a branch item's `sortOrder` counts
  *within its branch* and shares no ordering space with the day's loose entries — exactly
  what `itemsInDayOrder` warns about — so an option's first entry jumped ahead of the loose
  ones it comes after, and since `splitTrack` divides the line **in the order the entries
  are handed over**, the cuts landed in the wrong places and said so only weeks later on
  the map. The path therefore reads in timeline order and each fork contributes **one**
  option. Which one is a switch on the decision's own row, and it is a choice *about this
  import*: it defaults to the option the trip follows, never settles the decision (the same
  rule that makes swiping an `AlternativeCard` browse rather than choose), and says
  `trackOptionNotChosen` out loud when it points at a road not taken — attaching a scouted
  walk to the option you are still weighing is worth doing, and not worth doing unnoticed.
  Switching carries the run's ends across by identity, so a fork the run merely passes
  *through* keeps the run and swaps its middle, while switching away from an entry that
  *is* an end clears the run: there is no honest place to put an end that has left the
  path. The door has a say too — `pathThrough` opens the picker on the option the import
  was started from, or a leg reached through its own option's form would be missing from
  the list it opened for. A group is still listed leg by leg here, unlike in the timeline
  where it is one slot: the recording is divided per leg, so each one needs its own tick.
- **A track hangs off an item and travels with every copy of it.** `copyItemTracks` is
  called from `duplicateItem`, `copyGroup`, `duplicateAlternative`, `materializeRoutine` and
  the reversed routine, plus the bundle import — deliberately **not** from `copyItemPlan`,
  which builds a companion out of columns and cannot reach a second table. That is exactly
  where this rule rots if nobody writes it down. The reversed routine passes `reversed: true`:
  a path from A to B *is* the path from B to A, unlike the times and stops beside it, which
  that copy drops rather than reverse into a plausible-looking fiction. It is **not** called
  from `replaceJourneyLegs`: there the legs are being swapped for a *different* journey the
  timetable just returned, and carrying the old line onto it would draw the old route under
  the new one and claim it was followed.
- **A connection brings the route it takes, and says so by being dashed.** The search asks
  the router for `legGeometry` (`detailedLegs=true` on `/plan` **only**), and the import
  writes each leg's polyline as a `TrackSource.routed` track — so a train draws along its
  line instead of as a chord across the country. The live refresh keeps `detailedLegs=false`
  and that is the point of sending it per call rather than as a constant: it is the button
  pressed again and again on a platform, it costs 8 KB → 62 KB, and a delay does not move
  the rails. (The search costs 57 KB → 103 KB, paid once per search, by the only request
  whose answer is ever written into a plan.) The shape is **plan, not provenance** — it says
  where the line goes, not which dated run went along it — so it travels into a routine
  beside the coordinates and the stops, while `sourceTripId` is dropped there. Two traps
  guarded rather than assumed: the router encodes at **1e-6** and the column stores 1e-5, so
  `decodeTrackPoints` takes a precision and `_legShape` refuses any other one outright — a
  line read at the wrong precision lands ten times away, which looks like data instead of
  looking wrong; and a shape that will not decode costs its own leg a line and nothing else,
  since the rest of the journey is perfectly good. **A replacement is a routed
  connection too**: `replaceJourneyLegs` writes the new run's shapes exactly as
  the import does, which is why the repository owns that step for both
  (`_writeRoutedShapes`) and why the DAO returns its ids in *leg* order. Leaving
  it out meant a journey fell back to chords between its stops the moment it was
  looked up again — most visibly in a **routine**, where re-routing is the
  ordinary act and adding a run the rare one. Not to be confused with
  `copyItemTracks`, still deliberately absent here: that would carry the *old*
  run's line onto the new one and claim a route was followed that was not, while
  this writes the route the router has just returned for these very legs. Deliberately **not** an opt-in on the
  search form: the switch would have to be set before the user knows whether they will
  import this connection, it would guard the cheap call while the repeated one stays off
  anyway, and one screen of map tiles already costs several times more without being asked.
- **What was followed supersedes what was proposed.** A leg carrying both a recording and a
  routed shape draws the recording, solid; a routed one alone draws dashed
  (`MapPath.dashed`). Both stay stored and the entry's own form lists both — only the map
  picks, because a second line beside the first says nothing a reader wants. The dash is the
  honest part: a map can only draw a line, and whether that line is a record or a proposal
  is exactly the difference a reader needs.
- **A color is a property of the entry, not of the line it happens to be drawn as.**
  `ItineraryItems.colorValue` (nullable, v30) colors an entry on the map — a leg's line or a
  place's pin — and null means the trip's accent, which is what every row written before it
  means and what the great majority go on meaning. Deliberately **not** on `Tracks`: a line
  has to be colorable before there is a track to hang the color on (the straight segment is
  the ordinary case), and an entry that later gains a recording would otherwise lose the
  color it was given. Nothing outside the map reads it — the timeline, the totals and the
  PDF are untouched — so it is the one property whose choice is offered *on* the map, in
  `MapItemSheet`, which is otherwise a reading and not an editor: a color is chosen against
  the picture it lands in, and picking it anywhere else means guessing which line was hard to
  follow. The same `ItemColorField` sits in the item form, and the sheet writes through
  `setItemColor` (a targeted update, since it holds a snapshot of the row from when the
  marker was tapped) while the form saves it with everything else. It is a choice about the
  entry, so it travels: `copyItemPlan`, the `.tpt` bundle (no format-version bump, by the
  rule stated for coordinates), and `replaceJourneyLegs`, which carries the color the old run
  wore throughout — a commute drawn green would otherwise revert every morning the timetable
  is asked again, and the slot is what the color belongs to, exactly as the group and its
  ticket are kept. **Happening still outranks it**: red is the app's one reserved color, and
  a user's choice must not hide where they are. The **all-trips map** ignores it and keeps
  every line in its trip's accent — there the color answers "which trip is that line", which
  is the whole reason that map is readable.
- **A leg with a track draws the track instead of its straight segment**
  (`tripMapFeatures`'s `tracks:`). The chord between the ends and the path between them are
  two answers to the same question, and drawing both puts a line across the bay beside the
  line around it. The points are decoded once in `tripTracksProvider` / `allTracksProvider`
  rather than in `build` — unpacking is the only expensive thing a track does, and doing it
  per camera tick is the shape of the pinch freeze this map has already been through. A row
  whose string does not decode is **dropped rather than thrown on**: it may have come from a
  shared bundle, and one unreadable line must not blank the map for a whole trip.
- **The bundle carries tracks and stays lossless**, as `BundleTrack` on the item, with the
  points as the packed string rather than a JSON array of coordinates — the string is the
  storage format on both sides, so a round trip through pairs of doubles would quadruple the
  file and round every point a second time. `TrackSource` travels by **name**: an index is a
  promise about the order of a Dart declaration. No format-version bump, by the rule already
  stated for coordinates — a version marks a shape an importer must *branch* on, and an older
  app ignoring `tracks` imports exactly the trip it would have imported anyway. The bundle is
  **not** gzipped, unlike the earlier plan: the packed encoding already answers the size
  question that plan raised, and compressing the container would break every older app's
  reading of *every* bundle for a further third.
- **Where you have been is an aggregate, so it lives with the aggregates.** The countries a
  trip touched are a third tab of `TripStatsScreen`, not a layer on the all-trips map: the
  map answers "where did I go" and this answers "how much have I seen", and the two sit on
  opposite sides of the filter split — the map draws what `applyTripQuery` left visible,
  while the statistics read the whole record, which is why an answer here must not move when
  a tag chip is tapped. It is a `FlutterMap` with **no tiles at all**, only a `PolygonLayer`
  over `assets/geo/countries.json`, so it costs nobody's donated server, works offline, and
  worked on the web from its first day. A street map under it would answer a question nobody
  asked and make the fills harder to read.
- **A country is counted from where an entry *stands*, never from the line between two.**
  `visitedPoints` yields a place's own position and **both ends** of a leg, and nothing in
  between: a flight from Hamburg to Rome passes over Austria without anybody setting foot in
  it, and a chord on a map is not a claim about the ground beneath it. A point in no country
  is left uncounted rather than given to the nearest one — the outlines are generalized, so a
  coastal position can fall just offshore, and a wrong country is a claim while a missing one
  is only a gap. A single trip reads through `liveItems`, since an option nobody chose took
  nobody anywhere.
- **The outlines are Natural Earth at 1:50m, packed with the track codec.** Rings are
  encoded polylines at three decimals (~110 m) and simplified with a Douglas-Peucker
  tolerance **scaled to each ring's own extent** (`min(0.02, extent / 60)`), which is what
  turns 3.0 MB of GeoJSON into a 243 KB asset without deleting the micro-states: a fixed
  tolerance generous enough for Russia's coastline collapses San Marino to a triangle and
  Monaco to nothing. The codec was already there and tested, and every mapping tool reads the
  format. **Holes are kept**, so Lesotho is Lesotho and not South Africa; that is the one
  thing a naive "outer ring only" conversion gets wrong, and there is a test standing on
  Maseru to say so. Regions are `REGION_UN`, except that the Americas are split by
  `CONTINENT` (the UN's single "Americas" is not how anybody reads a list of continents), and
  the names come from the source's own `NAME_EN`/`NAME_DE` rather than from a list this
  project would have to maintain. `tool/build_country_outlines.dart` is the conversion, kept
  in the repo and writing through `encodeTrackPoints` — the same codec the app reads it with,
  so the two halves cannot drift, and rebuilding the asset is not an exercise in guessing what
  was done to it the first time.
- **An area is drawn; a state is counted.** The set holds the source's 242 areas, since a
  world map with holes where the dependencies are is a worse map — but what a tally means by
  "country" is the **200 sovereign states** (`ADMIN == SOVEREIGNT` in the source, which is
  where the number comes from), so every area carries the `stateCode` it counts toward and
  `sovereign` says whether it *is* that state. A week in Greenland is a week in a country and
  counts for Denmark. The area's own id is the three-letter administrative code, because the
  alpha-2 is *not* unique: Australia, its Indian Ocean Territories and Ashmore and Cartier all
  answer `AU`, and keying the map by that silently merged three shapes into one.
- **What counts as a state is a list, not a rule.** `kCountedStates` in the builder is the 193
  **UN members plus the two observer states**, Vatican City and Palestine. Natural Earth's own
  test — an area whose administration is its own — was tried first and does not survive
  contact: it makes states of Kosovo, Taiwan, Northern Cyprus, Somaliland and Western Sahara
  while filing **Palestine under Israel**, which is the same question answered the other way
  round, and it counts **Antarctica**, which no state governs. Those five, Antarctica, and
  Siachen Glacier are therefore drawn, tickable, and counted for **no** state: attributing
  them to Serbia, China, Cyprus, Somalia or Morocco would be a claim this app has no business
  making, and the alternative to a claim is a gap — the same answer `visitedAreaCodes` already
  gives for a point in the sea. The list is the thing to change if the world changes; the
  builder **refuses to write the asset** unless every code in it has exactly one outline, so
  the denominator cannot drift silently in either direction. A dependency never counts as a
  state even when it shares its state's alpha-2, or Australia would be in the tally three
  times.
- **The two sets are kept apart, because filling by state would lie about the picture.**
  `visitedWorld` returns `areas` (what the map fills) beside `states` (what the list counts):
  a visit fills the ground it happened on and credits the state, while a **mark** fills that
  state's own ground and not the dependencies scattered under its flag — a tick says "I have
  been to Denmark", which is not a claim about Greenland, and in Mercator Greenland is a
  quarter of the picture. So the two can disagree by design: stand in Nuuk and Greenland is
  shaded while Denmark is not, and Denmark is nonetheless ticked in the list.
- **The unvisited world is drawn as land, not as an outline.** A hairline of border color on
  a dark sea is a country nobody can make out at world scale, and the shape of the continents
  is what the eye reads before it reads anything else — so every area is filled, grey against
  the sea, and the trip's accent then reads as a fill *on* the land rather than as the only
  thing on the map. Both greys come from the scheme (`surfaceContainerHigh` on
  `surfaceContainerLowest`), so the picture inverts correctly in a light theme instead of
  being a dark map with a white sea.
- **A generalized outline is off the ground it stands for, and below a certain size that is
  the whole country.** At 1:50m the micro-states are present and San Marino, Liechtenstein,
  Andorra, Singapore, Malta and the Maldives are all detected from real coordinates — but
  **Monaco and the Vatican are not**: their outlines sit one to two kilometres off, so St
  Peter's Square reads as `IT` and a point in Monaco reads as sea. Measured, written down in
  `assets/geo/countries-ATTRIBUTION.txt` and standing in a test, rather than left to be
  discovered by whoever goes there. The answer is not a finer asset — it is that a country
  can be ticked by hand.
- **A country ticked by hand counts exactly like one a trip stood in.** `VisitedCountries`
  (v31, keyed by code) records the marks; `markedCountriesProvider` streams them and
  `allVisitedCountriesProvider` merges them with the derived set — for the **all-trips**
  reading only, since a mark is a statement about a life and not about one journey, and a
  single trip's tab would be claiming the trip went there. The map is never told which is
  which: a life has journeys in it that were never planned here, and drawing them differently
  would make the app's own record the standard. The *list* does distinguish them, because
  only one of the two is the user's to undo — a trip-derived visit is ticked and **greyed
  out**, which says it by itself; there is no line of text under it, and none above the list
  either, because a control whose state is legible does not need a caption. What is
  deliberately not built is a date, a note, or a level ("lived in", "passed through"): the
  question here is how much of the world, and the record of *when* is the trip.
- **A country is also ticked by tapping it on the map**, which is the only way a *territory*
  can be ticked at all: the list is of states, so Greenland has no row of its own — and it is
  right there on the map. So a mark is stored under `CountryOutline.markKey`: a state's own
  code, a territory's area code, one key per thing that can be pointed at. The two cannot
  collide, and a state's key is the same whether the tick came from the list or from the map.
  Tapping something a *trip* put there does nothing, by the rule above. Its corollary is that
  unticking a state in the list clears `markKeysFor` — the state's own mark **and its
  territories'** — since a mark on Greenland is what was making Denmark read as visited, and
  leaving it standing would put the tick straight back on the next rebuild. `hitValue` is the
  area code and the hit is resolved innermost-first, so a tap on Lesotho means Lesotho.
- **The list is what the map cannot say, so it sits under it and is never scrolled to.**
  `regionTallies` (pure) counts visited-of-total per region and the map is capped at **half
  the screen** — the map answers *how much*, the list answers *which*, and a list you have to
  scroll to discover is one nobody finds. Regions are ordered by size and never reorder as
  you travel: a list whose rows move when you visit a country is one you cannot learn. The
  map's zoom is fixed at the bottom by the width (`minZoom = log2(width / 256)`), which is
  exactly where flutter_map stops drawing the next copy of the world beside this one; where
  the height cap bites, the map gives up **width** and sits centered rather than cropping the
  poles off a full-width band.
- **A basemap is a sealed type with a list behind it, switched and never mixed.** Stacking
  raster under vector would show a seam, disagree about zoom depth, and keep fetching tiles
  hidden under an opaque layer — traffic taken from a donated server for pixels nobody sees.
  Each entry carries its own **attribution** (a condition of use, so it travels with the
  source rather than living on the screen) and an `OfflineDownload` flag: the OpenStreetMap
  tile policy permits interactive viewing and forbids downloading regions ahead of time, so
  a future download feature must **ask the source** instead of applying to whichever one is
  selected. The `User-Agent` goes out as a real header via `NetworkTileProvider`, not through
  `userAgentPackageName`, whose generic format the policy names as a reason for blocking;
  caching stays on flutter_map's default, which honors the server's own headers and is the
  conforming caching the policy requires. `appVersionProvider` now has two callers, not one.

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
- Bump `AppDatabase.schemaVersion` (currently 30) and add an `onUpgrade` branch for **any**
  table/column change — real user databases are migrated in place, not recreated.

### Android home-screen widget

`lib/features/home_widget/` pushes a fully pre-formatted, already-localized `WidgetPayload`
to the native Kotlin `PappusWidgetProvider` (`android/app/src/main/kotlin/.../`) as
flat key/value pairs via `home_widget`. `HomeWidgetSync` (wrapping the app in `app.dart`)
watches trips/itinerary and re-pushes on change; widget taps deep-link via
`pappus://trip?id=N`. `pickFeaturedTrip` decides which trip to show (ongoing → next
upcoming → most recent past). Widget code is Android-only and no-ops elsewhere.

A row's time (`widgetTime`) is the one place the payload is not plain text: it carries the
same planned-time-plus-miss line as the timeline, and a `RemoteViews` text can only be
colored in part through HTML, so the `(+15)` is wrapped in a `<font color>` that
`TodayItemsRemoteViewsService` parses back into spans with `Html.fromHtml`. The colors are
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
