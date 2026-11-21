# Route planner

Read this for the tour planner: the routing engine, the tour model, and how a planned tour
becomes itinerary entries. The connection search is a separate feature
([`transport-search.md`](transport-search.md)); the lines a tour draws are ordinary tracks
([`tracks.md`](tracks.md)).

**Status: a first planner screen exists, reached from *Plan route* under a day.** The app
therefore contacts `brouter.de`, and `overpass-api.de` for ski sections, which
`SECURITY.md` says. **The operator has not been asked
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
  weeks, which `SECURITY.md` has to say. One of two test requests on 2026-11-16 timed out.
  The server is therefore a **setting** (`routingServerProvider`, Settings → Route
  planner), an answer to both: a self-hosted server sends nothing to brouter.de. Stored in
  the preferences like the map style, never in the database or a `.tpt`. An address
  without a path gets `/brouter`, where a bare BRouter server answers; any other path is
  kept for a server behind a proxy. The planner names BRouter beside the map's own
  sources, and so do the settings' data sources, with OpenStreetMap, whose data the
  routes are computed on.
- **The web build sends no `User-Agent` to the router**
  (`BrouterRouteEngine.sendUserAgent`). brouter.de answers with
  `Access-Control-Allow-Origin: *`, but its answer to a preflight allows no headers
  (checked 2026-11-18), and setting `User-Agent` makes Firefox send one, so every request
  would fail there. The rule the tiles follow (`basemapTileHeaders`); the `Referer` names
  the page instead.
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
  its repository, not checked against the server's data). So the app routes them itself
  (*Ski runs*, below).
- **A refusal is told apart by its status**: none is unreachable, 400 is "no way between
  these points" with the server's words kept, 429, 502, 503 and 504 say the server is busy
  (try again later), anything else is failed. Only one 400 text
  ("datafile … not found") was observed; the others are assumed to be 400 too.

## Ski runs

- **Pistes and lifts are routed on the device, over data from Overpass.** `SkiMode` is a
  section mode of its own, beside `RoutedMode`, because no `RouteProfile` server answers
  it. `SkiRouter` (`application/ski_router.dart`) is its interface; `OverpassSkiRouter`
  (`data/ski/`) loads an area's pistes, lifts and lift stations with one Overpass query
  (`skiNetworkQuery`, `out body geom`: node ids say where ways meet, coordinates come in
  the same answer) and routes with Dijkstra over `SkiGraph`. Only the area goes to the
  server, never the points.
- **An area is loaded when a ski run needs it, never ahead.** The run's points plus
  `kSkiNeededMargin` (1 km) must lie inside a loaded area; if none holds them, the points
  plus `kSkiLoadMargin` (3 km), rounded out to hundredths of a degree, are loaded, so the
  next point a few pistes on needs no second request. A run whose box, rounded as it
  would be loaded (which adds up to a kilometer), is wider than `kMaxSkiAreaMeters`
  (30 km) is refused as `tooLarge`; nearer the limit the margin shrinks to fit. Naming a
  waypoint splits such a run into runs loaded each on its own. Areas stay in memory for
  the session and, where there is a cache directory (`core/cache_files.dart`, shared with
  the run shapes), on disk for 30
  days under `<box>_<yyyymmdd>`; the system may clear that directory, which costs one
  request. *Reload pistes and lifts* on a ski section forgets them all. Parsing and
  building the graph run in `compute`: a large area is megabytes of JSON.
- **Overpass is a donated server too**: guidance of about 10,000 queries and 1 GB a day
  for all of an app's users. No retry by itself; the busy failure tells the user to try
  later. On 2026-11-21 four of nine requests came back 502 ("at capacity") or timed
  out, so this is a real path, not a corner case. A 200 with a `remark` containing
  `error` is a query cut short with partial data and is treated as busy, never routed
  over. The server is a setting (`overpassServerProvider`, Settings → Route planner, an
  address without a path gets `/api/interpreter`). It answers `Access-Control-Allow-Origin:
  *`, and the query is a form field, so a browser sends it without a preflight; the web
  build sends no `User-Agent`, as for BRouter.
- **What the graph takes from OSM** (`SkiGraph.build`):
  - A downhill piste (`piste:type=downhill`) is drawn downhill and skied that way;
    `oneway=no` makes it both ways, `-1` turns it. A connection (`piste:type=connection`)
    likewise. Pistes drawn as areas (`area=yes`) are left out.
  - A lift is ridden from each stop to every stop above it: its two ends always, and a
    station node (`aerialway=station`) on it unless `aerialway:access` forbids getting on
    (`exit`) or off (`entry`) there, or both (`no`). A gondola or cable car also goes
    down unless `oneway=yes`, a chairlift only with `oneway=no`, a drag lift never.
    Garmisch-Classic shows why the ends always count: some lifts have no station nodes at
    all, others have them a node short of the end.
  - The lifts ridden are `kRiddenAerialways`; `mixed_lift` is filed as a gondola,
    everything dragged or conveyed as a drag lift. Zip lines and goods lifts are left out.
  - The map data often stops a piste a few meters short of its lift (13 of 21 lifts in
    Garmisch share a node with a piste at the bottom), so each end of a piste and each
    lift stop gets a **walk** to the nearest node of every other way within
    `kMaxWalkMeters` (150 m). Farther, the router finds no way rather than send somebody
    across a slope it knows nothing about.
- **What it weighs.** Minutes, estimated: 18 km/h down a piste, 11 km/h on a connection,
  3 km/h on foot, a lift's `aerialway:duration` (minutes, `mm:ss` or `hh:mm:ss`) or a
  typical speed for its kind, plus `kBoardingTime` (2 min) per ride. A walk weighs three
  times its minutes, so it is used only where skiing or a lift would not do. A ride
  **down** weighs three times too: from the Osterfelderkopf to the Kreuzeckbahn the
  fastest way rides the Alpspitzbahn down, and a skier came to ski. A waypoint is taken
  to mean every node within `kSnapRadiusMeters` (100 m), weighed by the walk there, or the
  nearest within 500 m; the next section starts from the node the last one reached.
- **The grade is the tour's, not a section's.** `SkiMode.maxDifficulty` (the OSM grade,
  `PisteDifficulty`) is set under the chips and applies to every ski section
  (`setSkiDifficulty`): it is one skier's ability, and a grade that changed only the next
  section would look as if it changed nothing. The default takes every piste up to
  `expert` but no `freeride` route. A piste without a grade is taken.
- **A ski run is a leg per ride and per descent.** The router's path carries
  `PathSegment`s: consecutive descents are one, each ride is one, and a walk shorter than
  `kFoldWalkMeters` (200 m) or a descent shorter than `kFoldDescentMeters` (50 m) is
  folded into the descent (else the ride) beside it, so no one gets a leg for the thirty
  meters to the lift. A ride that takes in such a piece keeps its name and stations.
  `tourEntries` lays each segment out as a `TourLeg` with a `TourLegPart`: a lift leg is
  filed under its lift mode and titled with the lift's name, a descent under ski and
  titled with its pistes' names. Where two legs meet, the point is the user's waypoint if
  the path passes one there, else one the router chose (`TourWaypoint.byRouter`), named
  after its station when the data names one. All of a ski day's legs land in one group,
  saved expanded like every group; folding it is the user's choice.
- **It is read back from its legs.** Each leg's `RoutePlan` keeps the grade (`ski`), what
  the leg is (`part`: `descent`, `walk` or the lift's mode) and which of its points the
  router chose (`router`). `savedTourOf` leaves those points out, so the legs join into
  one run again, and rebuilds the run's path and segments from the legs' lines (a leg of
  two points stores none: its ends are its line), titles and stations. A leg is kept on
  saving again while its run runs between the same two waypoints and it is the same ride
  or descent at the same place in it (`TourLegPart.index`, part and title). An older app
  reads `ski` as no profile it knows and declines to open the tour, as for any profile it
  does not know.
- **Ski tour is the hand-drawn ski line.** Off the pistes nothing is routed, so *Ski
  tour* is the `StraightMode` ski line the planner had before, under its own chip.

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
- **A hand-drawn line is stored as `TrackSource.drawn`** (appended to the enum, and by
  name in a `.tpt`, which an older app reads as an import). It was stored as `routed`
  at first, which made the entry's row say "computed route" and the GPX `<src>routed`
  about a line nobody computed. It is a proposal like a routed one
  (`TrackSourceKind.isProposal`): drawn dashed, put away by a recording, and replaced when
  the tour is saved again. A straight line of two points is not stored at all, since the
  leg's chord is the same line.
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
- **Saving keeps the entries that stayed the same entry** (`RoutineDao.rewriteRoute`,
  `keptEntryIds`), rather than replacing them as a connection searched again does. That
  rule fits a connection, whose notes are composed from its platforms and go with the
  train; on a route the notes, actual times, photos and recordings are the user's own,
  and an edit that rewrote every entry took them all. Identity is the **waypoint's key**
  (`TourWaypoint.key`, its index in the tour as saved, kept through moves, renames and
  reorders): a place is the same while its waypoint stands, a leg while it runs between
  the same two keys, and a leg split at a point inside it (a key between its ends, or a
  point set since) keeps its row for the first half. Nothing is matched by position or
  order alone, which would hand one entry's notes to another. A kept row is **updated**
  with the plan's columns only; its planned times are rewritten only when the tour has a
  start time, and only its *routed* line is replaced, a recording on it staying. A row no
  entry keeps is deleted with the rescue `replaceJourneyLegs` gives (costs and files to
  the group). The slot, the group and the option are kept. Places are paired with their
  waypoints by order (the k-th place entry with the k-th place mark), both having been
  written from one walk along the tour.
- **The planner shows the names the entries carry now**: a leg's ends and a place's
  title renamed in the entry's form since are read back from the rows, not from the plan,
  so saving does not put the old names back.
- **A profile this version does not know cannot be opened** (`savedTourOf` answers null),
  rather than opened with a section it would save back as something else. The button then
  says so in a snack bar (`routeEditUnavailable`) instead of doing nothing.
- **The door is the run's label, beside *Show journey*** (`GroupRunTile.onEditRoute`),
  and the leg itself for a planned leg standing alone (`TimelineTile.onEditRoute`), the
  way an imported leg carries its own journey button. A route is the whole run, so it is
  offered on the unit it applies to and not inside one member's form, where it first was:
  saving there replaced the very entry the form was editing. `isPlannedLeg` decides, and a
  place of a tour opens nothing of its own. The plan rides through an ordinary edit of the
  entry's form untouched.
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
- **The elevation profile lies over the bottom of the map, switched on from the panel**,
  not in a sheet, whose scrim would hide the map it is read against, and not in the
  panel, which keeps its height. The map keeps its size too. `tourProfile` lays the legs'
  profiles end to end and leaves a **gap** as long as a leg that has no heights (a line
  drawn by hand), since a profile closed up over it would show a tour shorter than it is.
  The chart runs from the lowest point to the highest, with both written beside it and
  the length under it.
- **The profile is read point by point**: a pointer hovering over it, or a finger drawn
  across it, puts a line at that distance with the distance and height written under the
  chart, and a dark dot on the map where that point is (`LaidProfile.at`, interpolated
  between two points of the line, which lie a few meters apart). Letting go or leaving
  the chart takes both away. In a gap the line shows the distance only and the map shows
  nothing, there being no height there. The chart takes the drag, so the map does not
  pan under it. The dot is a `ValueNotifier` of its own and the profile is worked out
  once per planner state: a cursor moving redraws one marker, and the chart keeps its
  cursor only while it is handed the same profile.
- **The locate button sets a point where the device is**, the point picker's rule: a
  pointing act, taking only the reading the press waited for, and a tap on the map while
  it waits answers the question instead. It sets the next point, or puts the point being
  moved there, and centers the map. The blue mark is drawn under the tour's own marks.
- **An option of a decision has its own *Plan route***, and a new route planned from it
  is saved into that option (`insertJourney`'s `alternativeId`); its start time is
  picked from the option's own last time. A route opened again keeps the place it has.
- **The tour lives with the screen** (`autoDispose`): one not added to a day is not kept.
- **Ski is routed, *Ski tour* is a straight line** filed under the ski mode;
  *Straight line* is the same with no mode. The *Pistes:* line takes the place of the
  straight-line hint while *Ski* is selected, at the same height.

## Not built yet

- The door from the overview, for a route planned before there is a trip: where it is
  saved (a trip picked as for a connection, or a new routine) is still to decide.
- A walking-time model with the user's own pace in place of the router's duration.
- *Edit route* from the map.
- Timetabled sections inside a tour, through the connection search.
- Heights for ski runs: Overpass data has none. The source is still to decide (no
  dependency on Amazon's terrain tiles).
- Piste names from route relations (`route=piste`): a piste named only on its relation is
  an unnamed descent. Pistes drawn as areas are not routed over.
- A run made by the planner must be kept out of the unattended connection lookup
  (`plannedJourneys`), or a hike grouped with a train is replaced by the router's walk.
