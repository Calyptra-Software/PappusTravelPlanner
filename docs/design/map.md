# Map, positions, device location and recording

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the trip map, the all-trips map, the point picker, device location, the position feed, track recording, basemaps.

## The trip map and the picker

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
- **The trip map is framed once more when its late streams answer, and never after.** The
  entries are open before the map is (the trip screen beneath holds them), while
  `tripTracksProvider`, `tripPhotoMarkersProvider` and the decisions open with it, so
  `initialCameraFit` saw the ends of a round walk and not the walk, and no photograph at all.
  `_MapView.complete` says when all three have answered, and `didUpdateWidget` fits
  `allPoints` then — unless a pointer has touched the screen since it opened (`_handsOn`, a
  `Listener` over the whole stack, buttons included): the late fit is the opening view
  arriving whole, and after somebody has moved the camera it would be pulling it back. A
  rebuild is not an act, so later edits never re-frame — the rule the all-trips map follows.
- **A position is pointed at, never derived.** `map_picker_screen.dart` opens the map on a
  full-screen route — a sheet answers a vertical drag by closing, which is the same gesture
  as panning. A **tap** drops the marker, the readout says where it landed, and *Use this
  point* stays disabled until there is one, so the screen can never return a position nobody
  chose; an edit opens holding the position it is editing. (A fixed crosshair with the map
  moving under it was tried first — a fingertip does cover the point it is placing — but
  tapping won on being the more obvious of the two: the mark appears where you pointed.) The
  marker is drawn ink-on-halo in **map** colours, not theme colours: raster tiles are pale in
  both themes and full of thin red lines, so a mark tinted by the theme is a road. That rule
  covers **every** mark on this map, the trip's other positions included: they are context, so
  they are quieter — a grey *dot* rather than a red pin, since a pin claims the point under
  its tip and exactly one thing here is being chosen — but opaque and ringed in white all the
  same. They were a 50%-alpha `onSurfaceVariant`, which is *dark* in a light theme and *light*
  in a dark one; blended onto ordinary land the dark theme's came out at a contrast ratio of
  1.21, which is not a faint mark but no mark at all, so the layer read as broken on whichever
  theme the user happened to be running. Quiet is a matter of size and colour, never of alpha
  over something you do not control.
- **The search can be pointed at the map too.** The place picker in `connection_search_sheet.dart`
  offers *Choose on map* above the geocoder's answers, for an address it does not know, a
  trailhead with no name, or simply "from here". What comes back is a `TransportPlace` of
  kind `place` — which is what makes `queryId` send `lat,lon`, since there is no id to send
  and a coordinate is what the router wants for a door anyway — named by its own numbers,
  because asking the geocoder what is there would put a name on a choice the user did not
  make. Not offered for a **via** stop: only stop ids are allowed there, so a coordinate
  would be a choice that could only fail, which is the same reason that list is filtered to
  stations. It opens where the search is *happening*, not on the whole globe: the trip's own
  positions, read the way the item form's position fields read them (`itemPositions`, the one
  definition of which points an entry carries), plus whatever ends the form has already been
  given — which say it more precisely, the two ends of a journey generally being a short way
  apart, and which are the only answer a `JourneyLookup` has, having no trip. `ref.read` of an
  autoDispose provider, on the same guarantee the item form relies on: the trip screen this
  sheet was opened over is watching those entries. Where nothing is — and nothing can be, for
  a lookup with neither end named — the list is empty, which is a wider map and not a wrong
  one. The geocoder is deliberately *not* biased by any of it: a name is looked up the same
  way wherever the trip is.
- **And it can be pointed at the device, which is the commonest endpoint there is.**
  *Use my position* sits above *Choose on map* in the same picker, for either end and by the
  same rule as the map (not for a **via** stop). It answers with the same
  `_coordinatePlace` — kind `place`, `lat,lon` as the `queryId`, **named by its own
  numbers**: a reading is not called "my position" however well that reads in the field,
  because the name is what an imported leg carries afterwards, and "my position" stops being
  true the moment its owner walks away from it while the numbers go on saying where the
  journey started. It is still a *pointing* act — the press states the position, and only
  the reading that press was waiting for is taken, the same trade the map picker's own
  locate button makes; the receiver goes on reading and the endpoint does not go on moving.
  The route to it was three acts and a wait (*Choose on map*, the locate button, a tap on
  the mark) for the question a phone is holding the answer to.
  What it must **not** do is start a receiver because a picker was opened: this sheet is not
  a map and has nothing to draw a position on. So it holds the provider with
  `ref.listenManual` **on the press** rather than watching it in `build` — the subscription
  is what keeps an `autoDispose` provider, and so the receiver, alive for exactly as long as
  the press is waiting, and closing it releases both. Nothing here calls `stop()` either:
  that writes the remembered switch, which is the user's standing answer for their *maps*,
  and a search asking where it starts must not switch the mark off everywhere else. The
  press also **beats the resume** that the provider's own `build` schedules when that switch
  is on (`_resume` yields to a session already running or already answered), since the press
  is the half that may bring up the dialog and a resume replacing it would withdraw the
  question just asked. Where a map *behind* the sheet has the receiver running already, its
  reading is taken as it stands rather than restarting the session and blanking its mark.
  The four refusals read identically wherever they are said, from the one
  `locationProblemText` — but they are not *shown* the same way, and that split is the
  general fact rather than a detail of this feature: **a snackbar raised from inside a modal
  sheet is drawn by the scaffold behind that sheet**, since a sheet is a route in the overlay
  and hosts no `Scaffold` of its own, so the message lands underneath the thing the user is
  looking at. The search therefore says it in an `_ErrorRow` beside the geocoder's own
  failure — the better vessel here in any case: it sits next to the control that raised it,
  carries the way out to the system screen without competing with the sheet for the bottom of
  the display, and stays put while an unfamiliar sentence is read, where a snackbar is gone in
  four seconds. A map keeps `showLocationProblem`, having nothing above it to hide one. Note
  that `find.text` finds a message either way, so a test that only asks *whether* it was said
  passes while nothing is visible; ask where it is (`find.descendant(of: BottomSheet)`).
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
  `autoDispose` when the last map watching it goes away. What that press *said*
  is remembered, though (`map_show_my_location` in the preferences), and a map
  opened afterwards puts the mark back on by itself. The rule was that no screen
  may ask for something nobody requested — not that the user must request it
  again on every screen, which somebody moving between a timeline and its map
  does a dozen times an hour, each time waiting out a fresh fix. A **resume** is
  therefore the quiet half of a press and differs in exactly three ways, which
  are together what makes it something a screen may do: it never brings up the
  permission dialog (a grant already given is used, a missing one simply ends
  it), it reports nothing when it comes to nothing — a snackbar on every map
  opened with location switched off is the sort of help that gets a feature
  switched back off — and it moves no camera. Declining, location
  switched off device-wide, and no receiver at all are three *answers*
  (`LocationProblem`), each with its own sentence and, for the two with a system
  screen behind them, a button that opens it. The one press does the whole job:
  permission, receiver, and **one** centering — `listenForFirstFix` reads "first"
  off the null-to-fix transition, which is exactly why switching the mark off
  clears the fix, and it ignores a session it did not start (`startedByHand`),
  since a screen that has just framed itself on a trip must not be pulled off it
  by a reading nobody asked for. Every reading after that moves the mark and not
  the camera, since a map panned ahead to see what is coming must stay where it
  was put — so a press while the mark is **already on** means *center on me
  again*, which is the press the remembered switch made worth having, where a
  plain toggle would have answered "off" and charged two presses for getting back
  what was already there. Switching off moves to the **long** press
  (`MapRoundButton.onLongPress`, which puts the tooltip up by hand because
  `IconButton`'s own would win the gesture arena against it): the receiver stops
  with the map either way, so off is for saying *not again* rather than for
  saving a battery today.
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
- **The position comes from one stream, so nothing opens its own.** `geolocator` hands
  the stream it opened first to every later caller, *with the settings it was opened with*,
  until its last listener goes — so a second `getPositionStream` with other settings does
  not fail, it silently answers with the first. `PositionFeed`
  (`features/map/location/position_feed.dart`, `positionFeedProvider`) is therefore the
  only caller: the map's mark and the track recorder each listen there with a
  `PositionDemand`, and the feed holds one platform subscription opened for the most
  demanding reader present, closing and reopening it when that changes. A recording
  started under a mark the remembered switch put back on would otherwise have run on the
  mark's settings. Opening is synchronous when nothing has to be closed first, so a
  reading delivered in the same breath as a listen is not lost; only a change of settings
  waits for the close. The permission check is shared the same way
  (`checkLocationAccess`). `TrackRecorderController` (`track_recorder.dart`) is the other
  reader: **not** `autoDispose`, since leaving a map is the ordinary thing to do while
  recording, and watching `repositoryProvider`, so switching the database rebuilds it and
  the recording left running in the old file is found there as one nobody stopped. What it
  keeps is written fix by fix (`Recordings`), unlike the mark's fix, which is still never
  stored. **On Android a recording runs in `geolocator`'s foreground service**
  (`positionSettingsFor` returns `AndroidSettings` with a `ForegroundNotificationConfig` for
  `PositionDemand.recording` only), since without one the system stops delivering positions
  the moment the app leaves the screen. It is started from the foreground, on the press,
  which is why no `ACCESS_BACKGROUND_LOCATION` is needed and none is declared, and it ends
  with the recording's last listener: `StreamHandlerImpl` stops the service when the stream
  is cancelled. The notification's texts are localized by the recorder (`RecordingNotice`,
  through `appLocaleFor`, which the home widget shares) because the feed has no widget to
  ask; its small icon, `res/drawable/ic_stat_recording.xml`, is looked up **by name** on the
  native side, so `res/raw/keep.xml` keeps it from the release build's resource shrinker,
  which cannot see a name that lives in Dart. No wake lock (`WAKE_LOCK` stays removed): a
  fix carries the time it was taken, so one delivered late still lands where it belongs —
  and none were seen to be dropped: a walk recorded on an Android 15 phone with the screen
  off came out without a gap or a straight cut across a bend. **The notification is meant to be seen**, which upstream's is not: its channel
  is created with `IMPORTANCE_NONE` (as of 5.2.1), which leaves a recording running with
  nothing in the drawer to say so or to tap back into the app by. The copy creates it
  `IMPORTANCE_LOW` (silent, but listed), and the recorder asks for `POST_NOTIFICATIONS` on
  the record press (`notification_permission.dart`, `NotificationPermission.kt`), after the
  location and on a start only. Its answer is **not read**: the service posts its
  notification with or without the grant, and without it Android 13 and later merely list
  the service in the quick settings' task manager instead of the drawer, so a refusal
  costs the notice its place and never the recording. A channel's importance cannot be
  raised once created, so a phone that ran a build of this branch before the change keeps
  the silent channel until the app is reinstalled. One more fact about the vendored
  service worth knowing before relying on it: the service is **bound** to the plugin (`GeolocatorPlugin.bindForegroundService`),
  not started, so it ends when the Flutter engine detaches — swiping the app out of the
  recents ends a recording, which the database then holds as one nobody stopped and the
  next launch offers to continue. Read off the Java first, and seen so on the same phone.
- **A recording is made, held and filed from the trip's map, and the recorder's state is the
  only answer to "is there one".** `TrackRecorderController.build` looks for an unfiled row
  (`unfiledRecordings`) and takes it up **held** — `interrupted` when it has no stop, since
  that is what the app being closed under it leaves — and every press awaits that look, so a
  start cannot begin a second recording beside one about to be found. The button
  (`MapRecordButton`, under the locate button) and the band (`RecordingBand`) both read that
  state, never the table: a second source would disagree for the length of a database round
  trip after every discard, which is a band flashing back up with "0 m" on it. One press has
  four meanings, defined once in `recordAction` so the labelled button an empty map offers
  cannot drift from the round one: start, stop (or withdraw a start still at its dialog),
  continue a held one, and — while another trip holds the one slot — name that trip, because
  a second recording would be filed into the wrong trip by whoever forgot the first. A
  recording whose trip was deleted (`setNull`) is offered on every trip — which needs the
  recorder to **watch its own row** while it holds one (`_follow`): the delete nulls the
  column behind its back, and a state still naming the deleted trip kept the recording off
  every map until the next launch, with the button quoting a trip that had no title left. Filing is the
  ordinary track import (`fileRecording`, sharing `_divideAcross` with the GPX door) with
  `source: recorded`, the zone the recording **noted at its start** rather than the device's
  now, and no name, since inventing "Recording of 1 May" would be a label nobody gave it; the
  row is thrown away only once the lines are written. The live line is drawn in the device
  mark's blue (`kLocationBlue`), being the device's own — not the trip's accent, which would
  claim a place in the plan before anyone has said which, and not the reserved red. A trip
  with no positions still gets a map once a recording has a point, since that is then the
  thing to draw. **The band is passed as `bottomNavigationBar` only while it shows
  something**: any bottom bar at all, even an empty one, makes the scaffold take the system
  inset out of the body, and the map's attribution sinks under the navigation bar — a test
  in `trip_map_screen_test.dart` caught it.

## The overview's map

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
- **The same overlap buries the pins, so they are gathered rather than hit-tested.** A line
  under another can still be reached by widening the hitbox; a pin under another cannot be
  reached at all, since a marker wins the hit test against everything beneath it — twenty
  identical commutes put twenty marks on one platform and nineteen of them are taps nobody
  can aim. `clusterPins` (`features/map/pin_clusters.dart`) is therefore `clusterPhotos`
  applied to the pins: the greedy, order-dependent rule now lives once in `map_clusters.dart`
  and both call it, since *which* marks fall together is one question and two answers to it
  would drift. Measured in **screen pixels** through the camera's own projection, so a
  cluster comes apart as you zoom in — which is why the pins are a layer of their own
  (`_PinMarkers` reads `MapCamera.of(context)`, the arrangement `_PhotoMarkers` already has)
  rather than markers among the rest, which would then rebuild on every pan. It applies to
  **both** maps, since the pile-up is not peculiar to the all-trips one: a hotel returned to
  every evening and a station passed through twice put two pins on one spot, and at a zoom
  showing the country a city's worth of entries is one blob. `PinCluster<T>` is generic in
  what a place *belongs to* for exactly that reason — the trip map gathers `MapPin`s and
  answers with the entry (`_showPins`, one opens directly and several name themselves,
  through the same `_showChoice` sheet the lines use), the all-trips map gathers `TripPin`s
  and answers with the trip. A gathered mark sits on the **representative's own position**
  and keeps the order it was handed, so its face and its list are stable as the camera moves.
  Its color is `gatheredPinColor`: the one every place under it would have worn, else
  `kMixedPinColor`. **Agreement, not identity** — two trips that happen to share an accent,
  or two entries given the same color, keep it, because drawing it says nothing about them
  that was not already true; the neutral is only for a mark that would otherwise have to
  *pick* one of several, which on either map is a false statement about the rest. Being
  **under way still outranks it**, exactly as it outranks an entry's own color: a mark that
  gathered the entry you are in the middle of must not be the thing that hides the reserved
  red. The badge is `MapPlacePin`'s `count`, the same `_CountBadge` the photo marker draws —
  and it makes room for itself *inside* the marker's box (`pinBoxFor`, symmetric in width and
  taller only upwards), because `MarkerLayer` lays its children out in a `Stack` that clips,
  and because the tip is the pin's whole claim and a badge may not move it.

## Basemaps

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
- **The style is one choice per device, and the camera does not know about it.**
  `basemapProvider` stores the entry's id in the preferences, so it travels in neither the
  database nor a `.tpt`, and a server beyond OpenStreetMap's hears from the app only after
  someone picked its style. `maxZoom` is the same on every entry, because a camera that had
  to back off when the style changes is a camera moved by something other than the user;
  what differs is `maxNativeZoom`, past which the last real level is enlarged. It is
  **measured**, since few sources state it, and getting it wrong is visible: past 17
  OpenTopoMap serves one identical placeholder, past 18 OpenSnowMap a picture reading "No
  tile here", past 18 Humanitarian a 404. Each `TileLayer` is keyed by source because
  `didUpdateWidget` reloads on a new URL but not on a new `maxNativeZoom`.
- **An overlay is not a second ground, and it is not part of a style.** "Switched, never
  mixed" is about two opaque layers, so a transparent `MapOverlay` does not break it: nothing
  is fetched to be hidden. A ski style was tried first, OpenSnowMap's pistes bundled over
  OpenTopoMap, and it could not offer them on another ground; OpenRailwayMap and OpenSeaMap's
  seamarks exist only as overlays. So overlays are a list of their own, switched on
  independently (`mapOverlaysProvider`) and drawn in list order, whichever was switched on
  first. Each
  costs a further server's requests for every view, for as long as it stays on, so the
  layers button is tinted while one is on, and `minZoom` keeps it from being fetched where
  it would be a tangle. OpenSnowMap's own grounds (`base_snow_map`, `pistes-relief`)
  redirected our requests to an access-denied image, and its terms forbid bulk download
  without addressing live use by an app, so the operator's view is still to be asked; for
  OpenSeaMap's tiles no usage policy could be found at all. The `©` lives in each
  `MapAttribution` label, not in the bar, because SRTM is credited rather than claimed;
  `combinedAttributions` lists each source once.
- **A 429 means stop.** OpenRailwayMap's terms ask a client to stop on one rather than risk a
  longer block, and flutter_map, though it does not retry a 429, goes on asking for every new
  tile. `tile_client.dart` therefore leaves a host alone for the `Retry-After` it gave, or for
  a quarter of an hour, and answers for it meanwhile. It sits under every tile layer, since
  no server's 429 means anything else. One shared client rather than flutter_map's per-layer
  default, because a pause kept per layer would end with the next rebuild.
- **"Raster tiles are pale" holds less well than it did.** The rule above that marks use map
  colors and carry a ring was written for one pale ground. OpenTopoMap is browner and the
  pistes are blue, red and black, which is the reserved red and close to `kLocationBlue`;
  pins and lines stayed legible on them on a phone. A satellite or dark style would break the
  premise outright, and needs that checked before it is added.
