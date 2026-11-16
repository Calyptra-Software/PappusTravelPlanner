# Route planner

Read this for the tour planner: the routing engine, the tour model, and how a planned tour
becomes itinerary entries. The connection search is a separate feature
([`transport-search.md`](transport-search.md)); the lines a tour draws are ordinary tracks
([`tracks.md`](tracks.md)).

**Status: a first planner screen exists, reached from *Plan route* under a day.** The app
therefore contacts `brouter.de`, which `SECURITY.md` says. **The operator has not been asked
yet** (next section): that has to happen before a release carrying this.

## The engine

- **The router is an interface, and BRouter is behind it.** `RouteEngine`
  (`application/route_engine.dart`) answers one question, the way through a list of
  waypoints for a `RouteProfile`, for the reason `TransportSearch` is an interface. BRouter
  was chosen over Valhalla because it answers with a height for every point of the line
  (Valhalla samples heights at an interval of their own), has profiles for hiking with a
  SAC limit, gravel and mountain bike, and exists as an offline engine reading the same
  data, which is where offline routing would come from. Valhalla on the FOSSGIS server is
  the fallback and fits behind the same interface.
- **The public BRouter server publishes no usage policy for third-party apps.** It must be
  asked for before a release that calls it (contact: the Google group
  `osm-android-bikerouting`). It logs the address and the requested coordinates for two
  weeks, which `SECURITY.md` has to say. One of two test requests on 2026-11-16 timed out,
  so the base URL should become a setting, with self-hosting as the answer to both.
- **It is somebody else's server, so the connection search's rules apply**: the
  `User-Agent` from `buildUserAgent`, `retry: noAutomaticRetry` on every provider that
  calls it, and a request per waypoint *set*, never while one is dragged. One request
  covers a whole run (below) rather than each section.
- **A profile is not a transport mode.** `RouteProfile` is the question put to the router
  (road bike, gravel, mountain bike); several land on one built-in `TransportMode`, which
  is what the leg is filed under. Hiking is `foot`: the stock foot profile already prefers
  paths, and the itinerary files a hike under walking. Stored by name, so the enum's order
  is free.
- **No public engine routes pistes and lifts.** BRouter's tag table has no `aerialway` key
  and its import keeps only ways with a highway, railway, waterway or route tag (read from
  its repository, not checked against the server's data). Until the app routes those
  itself, such a section is a `StraightMode` line drawn by hand.
- **A refusal is told apart by its status**: none is unreachable, 400 is "no way between
  these points" with the server's words kept, anything else is failed. Only one 400 text
  ("datafile … not found") was observed; the others are assumed to be 400 too.

## The tour

- **A tour is waypoints and one mode per section, and the change of mode is pointed at.**
  `Tour` (`domain/tour.dart`) holds no rule for where to leave the car: that waypoint is
  set by the user, by the app's rule that a position is never derived.
- **A leg is a run, not a section.** `tourRuns` joins consecutive sections traveled the
  same way; a run ends where the mode changes or at a waypoint that is named or marked as
  a place, since a leg carries names only at its ends. Waypoints inside a run only shape
  the line.
- **A waypoint marked as a place becomes an entry of its own** between the leg that
  reaches it and the one that leaves it (`tourEntries`). A name alone does not: a car park
  names the ends of two legs without being a stop in the plan.
- **A total is given only when every leg has a figure** (`tourTotals`). A duration that
  left out the hand-drawn descent would read as the whole tour's.

## Into the itinerary

- **A tour is written through `TripRepository.insertJourney`**, as a connection is:
  `tourToItems` (`data/tour_mapper.dart`) builds the rows and packs each line at the
  router's precision, so the lines arrive as `TrackSource.routed` tracks and are drawn
  dashed. The day's entries are bundled into one group by that call.
- **Times run on from a start time and stop where nothing is known**: behind a leg
  without a duration, and at midnight. A leg reaching past midnight keeps its arrival in
  `endDayOffset`; entries after it stay untimed and on the tour's day.
- **A hand-drawn line is stored as `routed`**, there being no source for "drawn": it is a
  proposal and not a record, which is what the dash says. A straight line of two points is
  not stored at all, since the leg's chord is the same line.
- **A routed line is stored with its heights** (`Tracks.elevations`, see `tracks.md`),
  and its climb is counted from them by `climbOf`, not read from the router's own
  "filtered ascend". The stored line is counted again wherever it is shown, and the
  planner must not show another figure for the same line. The threshold (8 m) puts the
  one recorded route at 122 m up and 796 m down against the router's 123 and 799; it was
  checked on that route only.

## Opening a saved tour again

- **Every entry of a saved tour says what it was made from** (`ItineraryItems.routePlan`,
  v43, `data/database/route_plan.dart`): one tour id shared by the legs and the places,
  and on a leg its waypoints, its way of travel and the router's duration and length. A
  JSON column for the reason the stopovers are one. The id is the moment the tour was
  first saved and is kept when it is saved again.
- **A tour id alone is not a tour**, since a copy of an entry carries it too.
  `tourItemsAround` takes the entries with the opened entry's id that are on its day, in
  its group and option, and **connected**: each leg starts where the one before ended.
  So a duplicated leg opens as a tour of its own, and a leg moved to another day leaves
  the tour in two. That is the stretch the planner could have written in one go.
- **Opening asks the router nothing.** `savedTourOf` reads each leg's routed track back
  as the answer for its run (`SavedTour.paths`), with the heights the track holds and the
  duration and length the plan kept. Only a leg whose line was removed since is asked
  about. `tourPlannerProvider` is a family keyed by the saved tour, so the controller's
  first state is the tour and no frame shows an empty planner.
- **Saving replaces the entries, as a connection searched again replaces its legs**
  (`replaceJourneyLegs`): the slot, the group and the color are kept and a cost or a file
  on a replaced entry is rescued. A note, actual times or a recording on a replaced entry
  goes with it, as it does there. Every entry is replaced, changed or not; keeping the
  rows of legs the edit did not touch is not built.
- **A profile this version does not know cannot be opened** (`savedTourOf` answers null),
  rather than opened with a section it would save back as something else. The form then
  stays as it is.
- **The door is the entry's form** (*Edit route*, on a leg or a place with a readable
  plan), which closes first as it does for a search: the entry it was editing is about to
  be replaced. The plan itself rides through an ordinary edit of the form untouched.
- **The reversed routine turns the plan round with the line** (`reversedRoutePlan`), so
  the way back can be opened too.

## The screen

- **A tap sets the next waypoint, and the mode chosen before the tap is the one that
  section takes** (`presentation/route_planner_screen.dart`). The chips therefore choose
  for the *next* section and change nothing already planned, which is what puts the change
  from the car to the trail at a point somebody set. A full-screen route, not a sheet, for
  the point picker's reason.
- **`TourPlannerController` asks for a run once.** Answers are kept by what was asked (the
  profile and the waypoints, `runKey`), so taking a point back and setting it again, or
  naming a point at a run's end, asks nothing twice. A refusal is kept as well and asked
  again only on *Retry*: the planner never repeats a request by itself.
- **A run still unanswered is a thin dotted chord**, not the dashed line of a route, so
  what is drawn never claims a way the router has not given. *Add to day* is disabled
  until every routed run has its answer.
- **A waypoint is moved by a tap, not by a drag.** *Move point* in the waypoint's sheet
  makes the next tap on the map (or on a line) put that waypoint there. A drag would pass
  through a hundred positions the router must not be asked about, and a marker's drag
  competes with the map's pan. The state is said in the panel for as long as it lasts,
  with *Cancel* beside it and the mode chips at rest, since a tap now means one thing.
- **A tap on a line opens the section it landed in**, not the run: `locateOnRun`
  (`tour_geometry.dart`) finds the section by where the run's shaping waypoints lie along
  the line, searched in order, and by the nearest *segment* rather than the nearest
  vertex, which on a long straight section would name its neighbor. The sheet changes
  that section's mode or sets a point into it, snapped onto the line. The line's
  `GestureDetector` takes the tap, so the map's own `onTap` does not also add a waypoint
  (a test holds this, for a line and for a waypoint).
- **A point set into an answered line keeps the answer** (`insertWaypoint`): the way
  through a point on it is the way already given, so the cache is told so and the router
  is not asked for a line it has just returned. Moving or naming the point asks as usual.
- **The order of the waypoints is changed in a list, and a waypoint keeps the mode it
  is reached by** (`Tour.reordered`). Modes belong to sections, and a section does not
  survive its ends being pulled apart, so something has to say which mode goes where:
  the summit walked up to is still walked up to wherever it comes. The first waypoint,
  reached by nothing, carries the mode it is left by; whichever waypoint ends up first
  has its own set aside. The list (`_PointsSheet`) watches the tour, so a drop is the
  change and the router is asked about the runs the new order made. The marks on the map
  are **numbered** for this: most waypoints have no name, and a row saying only a
  coordinate could not be found on the map. Each row carries its own bin; there is no
  "remove last point" button, which acted on a point the user had not pointed at.
- **The panel keeps its height whatever it says.** It sits under the map in a `Column`,
  so a panel growing by a line resizes the map and shifts it under a finger on its way
  to it. The status line has a minimum height and the hint line is always there.
- **The duration wears a clock and is written "1 h 35 min"** (`formatStayDuration`), not
  the compact "1h 35m" used elsewhere: beside two figures in meters it read as a third
  distance.
- **The elevation profile is a sheet, opened from the panel**, not a strip in it: the
  panel keeps its height. `tourProfile` lays the legs' profiles end to end and leaves a
  **gap** as long as a leg that has no heights (a line drawn by hand), since a profile
  closed up over it would show a tour shorter than it is. The chart runs from the lowest
  point to the highest, with both written beside it and the length under it.
- **The tour lives with the screen** (`autoDispose`): one not added to a day is not kept.
- **Ski is a straight line under its own chip**, filed under the ski mode; *Straight line*
  is the same with no mode.

## Not built yet

- The door from a decision's option, from a routine's own screen and from the overview
  (a tour planned before there is a trip). Only a day's add row opens the planner.
- Centering on the device and taking its position as a waypoint.
- The base URL as a setting, and a link crediting BRouter beside the map's attribution.
- Whether `brouter.de` sends the CORS header the web build needs (unverified).
- Heights on an imported GPX file and on a recording (`tracks.md`), and a walking-time
  model with the user's own pace in place of the router's duration.
- *Edit route* from the group's label and from the map, beside the entry's form.
- Timetabled sections inside a tour, through the connection search.
- Pistes and lifts, including a short walk between the end of a piste and a lift.
- A run made by the planner must be kept out of the unattended connection lookup
  (`plannedJourneys`), or a hike grouped with a train is replaced by the router's walk.
