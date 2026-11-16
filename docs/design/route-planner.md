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
- **The tour lives with the screen** (`autoDispose`): one not added to a day is not kept.
- **Ski is a straight line under its own chip**, filed under the ski mode; *Straight line*
  is the same with no mode.

## Not built yet

- The door from a decision's option, from a routine's own screen and from the overview
  (a tour planned before there is a trip). Only a day's add row opens the planner.
- Changing the mode of a section already set, moving a waypoint, inserting one into a
  line, and centering on the device.
- The base URL as a setting, and a link crediting BRouter beside the map's attribution.
- Whether `brouter.de` sends the CORS header the web build needs (unverified).
- Heights: the parser reads them, nothing stores them. That needs a column on `Tracks`
  and overturns the "elevation is dropped" rule in `tracks.md`.
- Reopening a saved tour for editing, which needs the waypoints and profile kept on the
  leg (a JSON column like `stopovers`).
- Timetabled sections inside a tour, through the connection search.
- Pistes and lifts, including a short walk between the end of a piste and a lift.
- A run made by the planner must be kept out of the unattended connection lookup
  (`plannedJourneys`), or a hike grouped with a train is replaced by the router's walk.
