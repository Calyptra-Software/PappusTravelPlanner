# Connection search (Transitous)

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for anything that searches, imports, re-routes or refreshes a connection.

## Importing, re-routing and looking up journeys

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
  The corollary is that a routine's own costs count toward **no** total: the all-trips
  statistics read their trips from `statsTripsProvider`, which drops routines, or the same
  fare would be charged both to the plan and to every trip made from it — and the same leg
  counted twice in the transport tab, and its positions in the countries tab. All three tabs
  read that one provider because they once each walked the trip list themselves, and only
  the expenses remembered to skip the templates. Groups and decisions are cloned into fresh ones. Participants travel,
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
  plan first (offline-safe, instant, correct on its own), then `TripConnectionsController`
  (driven by `lookUpTripConnections`) looks each `PlannedJourney` up for the day it now sits
  on and offers the result in the ordinary `journey_sheet.dart`.
  Accepting it swaps the legs via `RoutineDao.replaceJourneyLegs`, which **keeps the group**
  so the shared ticket hanging off it survives — and rescues a cost sitting on a *leg* onto
  the group (or the replacement's first leg) rather than letting the cascade take it, since a
  single-leg commute has no group to hang its fare on — and puts the replacement back in the *slot*
  the old run occupied rather than on the end of the day — appending once put a stop added
  after the journey in front of it. A day the old run did not occupy but the replacement
  **continues** onto (a connection that now crosses midnight) takes those legs at its top,
  under the overnight leg the timeline draws there; appending them put the walk off a night
  train after the next day's connections. A replacement wholly on a later day continues
  nothing there and is appended. A wider replacement pushes what followed it down,
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
  "no signal". Each offer has a **third answer**, *Adjust search…*
  (`showConnectionOfferSheet`), opening the ordinary search form on that run as a `ReplaceRun`,
  and a journey with nothing found is said so **at that journey**, in a dialog with the same
  door, rather than counted into a snack bar after the round: the connection found is often
  the one before the train wanted, and "keep the plan" is then no better an answer than "use
  this", since the copied legs carry no live times either way. The form is opened over the
  routine list or the overview, where nothing watches the new trip's entries, so *Choose on
  map* frames itself on the form's own ends only. **A failure is named by what the router
  said** (`TransportSearchException.failure`, from the `error` text in its body): no answer,
  a date outside its timetable window (a 400 — the window starts about a month back, and a day
  just inside it answers 200 with nothing at all), an end it does not know (a 404), or
  anything else. They all used to read "couldn't reach the service", which sent somebody
  looking for a signal over a date picked a month back. Words not recognized fall back to
  "answered with an error", still true of them; only the first and the last end the round,
  the last because asking a struggling donated server again is the wrong reflex. A run whose id has been lost — a leading walk deleted, an end leg replaced — falls
  back to the **coordinates** the leg still carries, since the router takes a coordinate
  anywhere it takes a stop id; the id is preferred only because it starts on the platform
  rather than outside the station. Without that fallback the ids' living on the outer legs
  alone meant any edit to an end silently and permanently un-offered the journey. A leg
  with neither ids nor coordinates (hand-entered) is simply copied as a plan: there is
  nothing to re-issue a query with, and guessing one from a station's name would be a
  different journey wearing the same label.
- **A journey is looked up again from the screen that reads it**, one run at a time
  (`JourneyScreen`, on the group's label or a lone imported leg). The trip-wide lookup
  above happens once, in the seconds after a routine is stamped out (or a trip is
  duplicated, or moved with its start date); every way of not
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
- **A run the router could not reproduce is not offered either** (`routerCanReplace`, the
  third condition in `plannedJourneys`). Taking an offer replaces the whole run, first end to
  last, so a run holding a leg the router never returns would lose it: a train grouped with a
  ski descent came back as a train and a bus, and a flight would become a train. The set is
  `unroutedTransportModeIds`: ski, flight and taxi, the built-ins `builtinTransportModeFor`
  never produces (a lift imports with no mode). Resolved from the table by `builtinKey`, like
  the street set. A null mode, `other` and a custom mode do not hold a run back, by the same
  "only what is positively known" rule. `plannedJourneyOf` again stays open, so such a run can
  still be looked up deliberately from its sheet.
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
  a delay already entered on the leg before does not have to be typed again. The arrival is
  dated on the earlier leg's own minute line (`entry_times.dart`) and seeds only a leg leaving
  on that same day, so an overnight leg seeds the morning it lands on and a 23:58 arrival is
  never read as the small hours of the wrong day. It seeds
  a form the user reads and can change; nothing here decides anything. Offered only on a run of
  two or more legs, since on one leg it would be the journey's own button twice.
- **The rest of a run is replanned from the change it went wrong at** (*Replan from here*
  on the journey sheet's `ChangeRow`, `JourneySheet.onReplanFrom`). A missed connection
  asks about everything after the change, and neither of the other two buttons answers
  that: the leg's own search keeps every later leg standing whether it still fits or not,
  and the journey's searches again from a station already left. The unit is offered where
  it begins, which is why the button sits on the change and not on a leg.
  `journeyAfter` hands over every leg after the arriving one, the walk to the next platform
  included (it is part of the change), as a `PlannedJourney` under the run's group, so the
  swap goes through the same `replaceJourney` and keeps the ticket and the slot. Its start
  is the change's coordinates, its end the run's own id. The time is the **arrival**
  (`arrivalSeedMinutes`): the actual one when recorded, else the planned one, and never the
  departure just missed, since searching from that offers the gone train again. The leg's
  own button stays beside it; "only this leg" is still a question, just a rarer one.
- **A lone leg is looked up from its own sheet**, not the journey sheet: the item form's
  "search online" button, which for a *new* leg adds a run and on an **existing** one replaces
  it (`ItemFormSheet._canReplaceLeg`). That is the entry point a hand-entered leg has, since
  `hasStandaloneJourney` deliberately keeps the journey sheet off a leg the import never
  touched. It is offered only on a leg standing **on its own**: a grouped leg is one leg of a
  run, and a run is replaced whole from the label above it, so replacing one leg of a shared
  ticket from inside an edit form is not a thing the app does.
  Either way the search opens on **what the form holds now**, saved or not (`SearchSeed.ofLeg`,
  `presentation/search_seed.dart`): typing the stations and then asking for a timetable is the
  ordinary way in, and a new leg used to hand over nothing at all. An end with a position, or
  with an id that still describes it (`_fromPlaceId`, the save's own rule), is filled in; one
  with only a name becomes the hint the hand-entered run already gets, so the geocoder's
  answers are a tap away and the station is still the user's pick. The seed is a separate
  argument from the `JourneyDestination` and not a field of it: one says what the question
  starts as, the other what becomes of the answer, and a `ReplaceRun` opened from the journey
  sheet still seeds itself from its stored run (`SearchSeed.ofJourney`).

## The router, journey views and destinations

- **The router is somebody else's donated server, and its usage policy is part of the
  feature.** Transitous asks each request to carry a `User-Agent` naming the application,
  the client's **version**, and a way of contact; all three live in `core/app_info.dart`
  (`buildUserAgent`, no Flutter import — the smoke tool is plain Dart), fed the real version
  by `appVersionProvider`, which `main` resolves from `PackageInfo` and overrides into the
  scope beside the database path. A browser may not deliver that header — Chrome drops it,
  Firefox sends it — which the policy answers with the `Referer`, so any public web
  deployment must carry contact information on the page itself; no Dart change can supply
  it. Where Firefox does send it, the request becomes a CORS **preflight**, which Transitous
  allows for any header and `tile.openstreetmap.org` refuses for all but
  `X-Requested-With`; so the map's tiles go out **without** one on the web
  (`basemapTileHeaders`), or every tile fails and the map stays grey. It also asks
  that the data sources be **linked**, not merely credited: `core/widgets/attribution.dart`
  holds both links, under the search where the data is used and in settings, where they
  outlive the sheet — an imported connection stays in the trip, the PDF, and the `.ics` long
  after the search that found it. The rest of the policy is why the client looks the way it
  does: `detailedLegs=false` except where a route is to be drawn (a search, and a run asked
  to be shown), a debounced and cached geocode, journeys only on an explicit
  button, live refresh one leg at a time and never on a timer. That includes **Riverpod's own retry**:
  version 3 retries a failing provider ten times over about 38 s by default, loading all the
  while, so every provider that asks the router carries `retry: noAutomaticRetry`
  (`transport_search_providers.dart`) — measured, a refused search sent eleven requests and
  showed a spinner for half a minute in front of an answer given in 0.15 s. A new provider
  that talks to the network needs the same line. `staging.api.transitous.org`
  and the `*.motis-project.*` hosts are off limits outright. Being an open-source,
  non-commercial app is a *condition* of using the API, not a coincidence.
- **A journey is read the same way before and after it is imported.** A connection found by
  the search and a run of legs the trip already holds are both mapped onto one
  `JourneyView` (`features/transport_search/journey_view.dart`, pure — plus the DB-side
  adapter in `data/journey_view_items.dart`), which the pure `journey_preview.dart` folds
  into `LegRow`/`ChangeRow` and one `presentation/journey_sheet.dart` draws (its
  `JourneyHeader` and `JourneyRows`, inside the preview sheet before the import and inside
  the journey screen after it). So the walking
  transfer the router puts between two trains reads as *the change* on both sides of the
  import, where the timeline can only show it as another leg. The arithmetic that survives
  the fan-in is `ViewPoint.absolute`, a monotone minute count each adapter defines in its own
  terms — UTC minutes from the router, wall-clock minutes from the trip, which has no
  timezones to be exact with. The sheet's unit is the **group**: importing bundles each day's
  legs into one, so a group already *is* a journey and the button sits on the run's label
  (`TimelineTile.onShowJourney`); an imported leg standing alone carries its own. Each leg
  card hosts the leg's own `LiveRefreshButton` — still one tap, one leg.
- **A journey the trip holds is read on a screen, with a map; one about to be imported, in a
  sheet.** `JourneyScreen` (`/trip/:id/journey?group=…` or `?item=…`, opened by
  `openJourney`) puts the journey's map behind a panel (`DraggableScrollableSheet`) holding
  the same header and rows the preview sheet shows. A route and not a sheet for the reason
  the point picker is one (`map.md`): a sheet answers a vertical drag by closing, which is
  the gesture that pans a map. The preview stays a sheet, since it sits over the search it
  came from and has no run or positions worth a map yet. The map draws the legs through
  `tripMapFeatures`, so a leg there follows every rule it follows on the trip's map (routed
  shape dashed, recording solid, its color, red while under way via the shared
  `happeningItemIdAt`), and adds what only a journey has (`journey_map_features.dart`): a
  dot per stop with a position (an end hollow and larger, a station where one leg ends and
  the next starts drawn once), and, for a leg whose run has been asked for, that run in the
  point picker's quiet grey (next note but one). The camera frames the journey and not the
  run, which can reach across the country. The panel opens at 45 % and stops short of the
  top, so there is always map to drag it back by, and the attribution follows the panel's
  edge rather than sitting under it, since crediting the tiles is a condition of using
  them; the map itself is not rebuilt as the panel moves. The title is the group's label, read from
  `groupsProvider` rather than passed in, so a deep link carries nothing but ids. The map
  does not answer taps yet: what a tap could say about a leg is in the panel.
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
  A coordinate end brings a third thing, a **walk to nowhere**: the router always walks from
  the point to the nearest stop and from the last stop to the point, and when the point *is*
  the stop (one leg of an imported run searched again from the coordinates it carries) that
  walk is `distance: 0.0` and still a minute long. `resolvedOptionEnds` drops such a leg at
  either outer end, own-steam with its open end within `kStandingWalkMeters` of the stop,
  and dates the option by the legs left. Only there: a walk between two stops on one spot
  is a change the router means.
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
  journey all the same. Since v42 each stop also keeps its position, its IANA zone and its
  planned dwell (`Stopover.lat`/`lon`/`timeZone`/`dwellMinutes`, additive keys an older app
  ignores): the trip stores no zones anywhere else, and an estimate of where a vehicle is
  *now* needs both an instant and a place per stop. A refresh fills them into stops imported
  before (`Stopover.filledFrom`).
- **The rest of the vehicle's run is kept beside the leg, in a column of its own**
  (`ItineraryItems.runStops`, `RunStops` in `stopovers.dart`): the stops before boarding and
  after getting off, listed above and below the leg's ends in the journey view while the run
  is shown (below). Not
  more entries in `stopovers`, which an app that predates it would read as stops *between*
  the ends, routing the traveler through stations behind them; a column it does not know it
  never reads, so the `.tpt` field needs no format version. **Null means never asked**, and
  `{"before":[],"after":[]}` is the answer that the leg is the whole run: the two are offered
  different things. Days count from the leg's `date` like a
  stopover's, so a night train boarded after midnight has stops at `-1`; the terminus, which
  has no departure, is timed by its arrival. `/plan` does not return the run, `/trip` does
  (whole run, every stop with `lat`/`lon`/`tz` and both times, measured 2026-11-14), so it is
  written by the **live-times refresh**, which already asks `/trip` and used to throw the
  rest away (`runStopsAround`), and by *Show the whole route* (below). **Not at import**: a
  journey of five services would be five requests nobody asked for. Like the refresh, it
  asks by `sourceTripId`, and so depends on
  the leg being found again once that id has expired (next note). A run that cannot be
  lined up with the leg (an end not found, or the ends in the wrong order) is not stored
  rather than split at a guess. Copies take it with the plan, live figures stripped
  (`runStopsWithoutLive`); a routine's reversed way back drops it with the stops.
- **The run around a leg is shown on request, along the route it takes, and put away
  again.** *Show the whole route* on a leg card (`RunButton`, state in `JourneyScreen`) lists
  the run's stops in the panel and draws the run on the map; the same button, now *Hide the
  whole route*, puts both away. It is offered whether or not the run was loaded before, and
  the screen opens with every run put away, because a journey's own route is often what
  somebody wants to look at, and a run drawn for good once loaded would make that
  impossible. On the map the run follows **the route the vehicle takes, never straight lines
  from stop to stop**: a chord across country is a route nobody travels, so a run whose route
  is not to hand draws its stops and no line, and says so under the button. The route comes
  from `/trip` with `detailedLegs=true` (`tripRun`), which gives the whole run as one
  polyline at 1e-6 (62.8 KB, 11,403 points for an ICE from Rostock to München, measured
  2026-11-14), cut where the leg boards and gets off (`splitRunShape`, the alighting point
  looked for only after the boarding one). It is **not written to the database**, at about
  45 KB a leg, but kept in `RunShapeCache`: memory for the session and, off the web, one file
  per trip id in `<cache>/run_shapes/`, which the system may empty and which drops a run
  `kRunShapeKeepDays` after its last travel day. **Nothing is asked without the tap, and the
  tap asks only for what is missing** (`showRun`): stops stored and route kept, no request;
  otherwise one `/trip` with the geometry, whose stops are written again where they differ
  (the actual times it also carries are not: asking for the run is not asking to overwrite a
  time someone typed in). An expired trip id is found again as the refresh finds it (next
  note), since this too was asked for. When the request fails, stored stops are shown
  without a route; with nothing stored, the failure is said under the button, in the panel
  where it was asked. After a run is shown the map frames it once, since most of it lies
  outside what the screen opened on; putting it away leaves the camera where it is.
- **A stored trip id expires, so a leg is found again on its station's departure board.**
  The router reissues its trip ids with every feed it loads (runs imported 8 and 27 days
  earlier were both gone, measured 2026-08-23), so `/trip` answers 404 for a leg imported a
  feed ago although its train runs as planned; for a trip planned weeks ahead that was every
  leg, live times included. On that 404, and only then, `_tripStopsOf` reads the board at the
  leg's boarding position (`GET /api/v6/stoptimes` with `center` and a 50 m `radius`, which
  the router requires with a `center`; `exactRadius=false` adds what it counts as the same
  station) for a short window around the planned departure, and takes the one departure
  carrying the leg's title **and** leaving at its planned minute on its day
  (`relocatedTripId`). The title compares because `/stoptimes` labels a service exactly as
  `/plan` does (`displayName`: `ICE 585`, `RB31 (81617)`, verified live 2026-11-14). The new
  id is written back (`setSourceTripId`) and asked once more, so the next tap goes straight
  there. A board, not a `/plan` search: the usage policy names `/plan` as the expensive call,
  a coordinate search picks up spurious walks, and only a journey's outer legs keep a stop id
  at all. **No match, or two, and nothing is guessed**: the 404 reaches the caller and reads
  "no longer in the current timetable", since another train's delays shown as this one's are
  worse than none. That also covers a title edited by hand and a train retimed by a minute.
  The window is placed in the zone of the stop nearest the boarding station
  (`relocationWindowStart`), else the device's, which is right for a leg refreshed on the day
  from where it leaves; a zone guessed an hour wrong misses and is reported the same way.
