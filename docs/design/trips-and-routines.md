# Trips, tags, queries and routines

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the overview, its filters and counts, the statistics filter, routines and materializing them, and duplicating or moving a trip.

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
- **The count above the overview says what matches, and says it always.** `QueryResultLine`
  (`features/trips/widgets/`) sits under the tag bar on both lists and reads "12 of 40
  trips", also as "40 of 40" when nothing is narrowed: the two readings share one shape, the
  total is worth having on its own, and a line that appeared with the first tapped chip would
  shove the list down under the finger. It counts **matches**, not what is on screen — above
  the calendar a month shows only some of them, and the map cannot draw a trip without
  positions — hence "of" and never "shown". The denominator is `applyTripQuery` with an empty
  query rather than `trips.length`, because `tripListProvider` holds the routines too. Its
  *Clear* clears the filter facets only, the scope of the sheet's own button, and appears only
  while one is active: the search text belongs to the app bar's close button. With filters
  remembered across launches, this line is the plainest statement that the list is not
  everything.
- **The all-trips statistics have a filter, and it is theirs.** `statsTripQueryProvider`
  (`features/trips/application/stats_trips_provider.dart`) is a `TripQuery` read through the
  same `applyTripQuery`, and `statsTripsProvider` is the one answer to "which trips count"
  that the expenses, transport and countries tabs all read — they once each walked the trip
  list, and only the expenses skipped routines. It is **not** the overview's query: the rule
  that a statistic must not move because a chip was tapped elsewhere still stands, and what
  it forbids is narrowing *unnoticed* — so the filter is set on the statistics screen, and
  the `QueryResultLine` above the tabs says how many trips are counted. It is **not
  remembered** either (`autoDispose`, no preferences): the overview's filter is a way of
  reading a list used daily, a statistic is one question, and a subset left standing from
  last time reads as the whole record. The sheet is the overview's `TripFilterSheet` with
  `showSort: false`. A trip counts whole or not at all, by the overview's overlap rule — a
  cost carries no date of its own, so dividing a New Year trip's spending between the two
  years would be invented. Participants select *trips*, not *people's* spending: the per-person
  figures still show everyone on those trips. Hand marks join the countries only while the
  reading is unfiltered (`canMarkCountriesProvider`) — a filtered set asks about journeys, and
  a mark is not about one — and cannot be made there, or a tick would vanish as it was made.
  The tag and participant maps are watched only while a facet needs them, so the unfiltered
  screen opens no stream it has no use for.
- **The routine list is read the same way, by a query of its own.** `RoutineQuery` /
  `applyRoutineQuery` (`features/trips/routine_filter.dart`, pure) and the persisted
  `routineQueryProvider` are the overview's pattern applied to the other half of the same
  table: text, tags and participants any-of, sort — everything but the text remembered,
  under **separate** preference keys, since narrowing the templates is not a statement
  about the trips. Deliberately *not* a widened `TripQuery`: a routine has no dates and is
  never stamped out of a routine, so statuses, the date range and `routineIds` could only be
  dead controls on it, and `TripSort`'s date and expense orders would be ordering templates
  by nothing (a routine's costs are prices that count toward no total). What the two lists
  genuinely share is shared as code — `tripMatchesText` is the one definition of which
  words a row is looked for by, so the two searches cannot drift apart in the fields they
  read — and each function drops what the other one lists (`applyTripQuery` drops routines,
  `applyRoutineQuery` drops trips) rather than trusting whichever query fed it. The tag bar
  sits above both lists for the same reason it sits above the first: a routine's tags are
  what its trips are stamped out wearing, so the filing that files the trips files the
  templates. The participant filter's candidates come from the **routines**, not from every
  trip — offering somebody who has only ever been on a holiday is offering a filter that can
  only empty the list.
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
- **A whole plan is copied in one place** (`TripPlanDao.copyPlan`): participants, tags,
  decisions with their choice, groups (cloned), entries via `copyItemPlan` and their lines
  via `copyItemTracks`, and checklists via `copyChecklist`. `materializeRoutine` and
  `duplicateTrip` both call it and add only their own rules around it (the routine's fare
  and paperwork for the one, nothing for the other), so a new part of the plan reaches both.
- **A duplicated trip moves by distance, not by rank.** `duplicateTrip` shifts every day by
  `daysBetween(old start, new start)`, the old start being the trip's own or, without dates,
  its first entry's (`planRange`). A trip's dates are real, so a free day in the middle or
  at the end is part of the plan and stays; reading ranks, as a routine must, would close it
  up. The copy takes the **plan, not the money**: a trip's costs record payments for that
  trip, and its files are its bookings and photographs, so neither travels. Nor do the
  actual times, the delays at the stops, or `sourceTripId` (`dropLiveTimes`): they describe
  how the original days went. Nor `fromRoutineId`, which says the *routine* produced a trip.
  The journeys arrive as a plan, and the same `lookUpTripConnections` round a routine gets
  makes them real for the new dates.
- **A trip is moved from its form, not from a menu.** Changing the start date is where
  moving a trip is looked for, so saving a new start (`entryShiftDays`: only the start
  counts, and only between two dates) asks `showMoveEntriesDialog` whether the entries come
  along. It is a question because a new start means either "the trip moved" or "the dates
  were wrong", and only the user knows which; *Dates only* answers the second. It is asked
  on **saving**, not on picking, so picking twice or cancelling the form asks nothing, and
  only when there are entries (`moveFacts`). `TripPlanDao.moveTrip` writes the row and moves
  the entries, decisions and collapsed days in one transaction, by `addDays`. In place, the
  trip keeps its money, ticks and files; what it drops is the record of the old days, as a
  duplicate does: `sourceTripId` (a live refresh would read the old run onto the new day),
  actual times and stop delays. The dialog says so when actual times exist, since that is
  the one loss. The lookup runs on the detail screen after the form has closed (the form
  pops `true`), because the round needs a screen that stays.
- **The form writes `copyWith` of the row it loaded**, never a fresh `Trip`: a fresh one
  silently reset every column the form does not show, and `fromRoutineId` was lost on each
  edit of a trip made from a routine.
