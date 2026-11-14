# Tracks

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the `Tracks` table, the polyline codec, GPX import and splitting, routed shapes, line display.

- **A track is a line with a provenance, not "the GPX file".** `Tracks` (v29) holds the
  line an entry *actually* followed — packed by `track_points.dart` into the encoded-polyline
  format every mapping tool reads, so a dense recording costs a fraction of its point count
  and can leave the app without a decoder being written first. A recorded walk, an imported
  route and a path a router computes later are the same row wearing different `TrackSource`
  values, which is why the enum names all three though only the first can be made today: a
  table that could not say "this one was actually walked" would have to be migrated to say
  it. Elevation and the file's markup are dropped on the way in (`parseGpx`), each for a
  stated reason — the app has no reading for a profile, and the file remains where those
  live. Timestamps are *read* but never stored: the import uses them once (below) and they
  leave with the file. `<trkseg>`s are **not** joined: a break is where the recording stopped, so they
  arrive as separate rows under one name, which is the same rule the map already follows
  between two places. A `<wpt>` is ignored outright — a waypoint is a place, and inventing a
  dozen untimed entries from a route file is an import of a different kind.
- **The codec does its arithmetic with `*` and `~/`, never with shifts and masks**, and that
  is a platform fact rather than a style: on the web an `int` is a JavaScript number and the
  bitwise operators truncate to **32 bits, unsigned**, so `~n` answers `2^32 - n - 1` where
  the VM answers `-n - 1`. The encoder survived that (its zig-zag only ever hands `~` a
  negative number, and small positives come back unharmed); the decoder did not, turning a
  step of −22402 into 4294944894 — so the **first move south or west** threw a line out of
  the world. Every recorded track and, since the country outlines are packed with this same
  codec, the whole world map. The multiply-and-divide form is exact on both platforms, the
  values staying far inside the 2^53 a double holds whole. What makes this worth writing
  down is that nothing here could see it: `flutter test` runs on the VM, so the existing
  tests — Google's worked example among them, negative coordinates and all — passed
  throughout, and the web is the one target CI does not build. It was found by compiling the
  codec with `dart compile js` and running it under `node`, which is also how to check it
  again.
- **Several rows on one entry are the ordinary case, so the form lists them rather than
  counting them.** A leg carries more than one line routinely — the `<trkseg>` split above,
  a second import onto the same leg, a connection's computed route left standing beside a
  recording — and `TrackField` used to fold all of that into "3 lines" over a single
  *Remove* that took every one of them. So it is a list now, one row per row of the table,
  each carrying its own delete, which is the rule the group band already follows: the unit
  an act applies to is the unit it is offered on. *Remove all* survives only from two lines
  up, where it says something the row's own button cannot.
  What a row shows is what actually tells two of them apart: the name the **file** gave it
  (still never invented — the table's rule stands, and a nameless line simply has no name in
  its row), where it came from, and **how far it runs** (`TrackSummary` / `summarizeTracks`,
  pure, over `lineLength`). The length and not the point count, which is the number the
  table already refuses to print: how finely a recorder sampled invites tuning something
  that has no dial, while a length describes the line. Decoding happens in
  `itemTrackSummariesProvider` and not in `build`, for the reason `tripTracksProvider`
  exists — a form rebuilds on every keystroke. A row whose points will not decode, or that
  holds fewer than two of them, is listed with **no** length rather than dropped as the map
  drops it: the map's reader wants nothing drawn for it, and this reader wants the one thing
  that makes the row worth having — a way to delete exactly it.
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
  handover already placed is not final, and the screen has **one rule**: a tap places the
  *selected* handover. The selection is a numbered chip in the panel, matched by a larger
  numbered mark on the map, and it moves on to the next open handover after each tap — so
  the first pass is one tap each — and stays put once none is open, so a second tap refines
  the one just placed. It used to be two rules: the open handover took every tap, and only a
  finished division let a tap move the *nearest* one, so a handover placed badly could not be
  corrected before all the others were placed, and then the nearest could be its neighbour.
  The selection lives in the panel and never on the map, because an earlier "pick the mark
  up, then put it down" step was a state nobody could see, competing with the map for the
  same tap. Snapping still keeps a handover between the nearest *placed* ones on either
  side, since with the selection free the one next to it may be open. Those bounds are
  **indices into the recording, never coordinates looked up again**: a handover read off
  an entry's position lies *beside* the line, so `indexOf` found nothing, the bound came
  out as -1, and every tap snapped to the recording's first point. The screen therefore
  holds each handover as a cut index (`trackCutIndices`, resolved once, so moving one never
  moves another), divides by those (`splitTracksAt`) for both the preview and the write,
  and draws the mark on the line where it cuts. The coordinate is kept beside it only as
  what gets written onto an entry that had none. The **outer** ends
  need no asking: the recording's first point is where the first leg started
  (`trackImportEnds`), which is also what fills in a single hand-entered leg's coordinates.
  An end the user already gave is never overwritten — their statement, with the file as a
  witness. Writing coordinates and writing the pieces is **one transaction**
  (`TrackDao.importTrackAcross`), and a placed end drops its `fromPlaceId`/`toPlaceId` by
  the rule that governs moving one. One flow, two doors — the trip's ⋮ menu (nothing ticked)
  and a leg's form (that leg ticked) — because a recording rarely stops at one entry, and
  the unit an act applies to is the unit it is offered on.
- **A recording's timestamps are a measurement, so they fill what is empty and ask about the
  rest** (`features/map/track_times.dart`, pure). They are read for two things and nothing
  else. *Which days* it was made on: a recording sharing no day with the ticked entries
  (`recordingOnOtherDays`, the days an overnight entry covers included) is said to be one
  under the map — a warning and not a refusal, since attaching last week's scouting walk to
  tomorrow is reasonable on purpose. And *when each leg actually ran*: `legInstants` reads a
  leg's departure where the recording last stood within `kStationaryRadiusMeters` of the
  stretch's start and its arrival where it first came within it of the stretch's end, so ten
  minutes on a platform belong to neither leg — a heuristic, named as one, because a
  handover is one point of the line and a change is not one moment. What the user had already
  entered, by hand or from the live data, is a statement the file is a witness against and
  does not overrule by default: such a row is listed with the old value beside it and arrives
  **unticked**, while an empty field arrives ticked, and one within
  `kSameTimeToleranceMinutes` is not asked about at all. Live data being a prognosis when it
  was read before the train arrived is the case the opt-in exists for. **Planned** times are
  never written — a recording measures what happened.
  Three rules keep this honest. **The zone is shown, not assumed**: the file stores UTC and
  the app stores wall-clock time with no zone, so the screen reads the file at an offset the
  user sees and can change on the times sheet, starting from the device's own at the moment
  of the recording — right for an import made where the trip happened, wrong by exactly the
  difference for one made at home afterwards. Proper zones are a separate piece of work;
  when entries carry one, it should become this default. **A time is written only where it
  reads back as the moment it was measured** (`actualTimeProposals`): the column holds a time
  of day and `entry_times.dart` finds its day, so a recording from another day, or one more
  than twelve hours from the plan, would land as a plausible time on the wrong day — those
  are left out rather than written, as is one that would put an end before an actual start
  already entered. **A routine takes none**, enforced in `TrackDao.importTrackAcross` and
  not only by the screen: a delay measured on one Tuesday is not part of a plan. Times are
  offered only once every handover is placed, since a leg's are read at its cuts; and a line
  is timed **all or nothing** (`GpxTrack.times`) — one point without a time, a time with no
  zone, or times running backwards leave it untimed, and a `<rte>` is never timed, since a
  time on a route is a schedule somebody computed. **A place takes the times of the handover
  it stands at**, the rule that already gives it that handover's position: arrived with the
  leg before, left with the leg after — the same two numbers, nothing measured anew. Several
  places at one handover cannot be told apart by a line, so the first takes the arrival and
  the last the departure; one before the first leg takes only when it was left, since a
  recording starting there says nothing about when anybody got there, and one after the last
  leg only when it was reached. A visit spent walking about reads short, as the legs either
  side of it read long — the division gave that walking to them, and the times follow it.
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
  the router for `legGeometry` (`detailedLegs=true` on `/plan`, and on `/trip` only when a
  run is asked to be shown, see `transport-search.md`), and the import
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
- **What was followed supersedes what was proposed — by default, which the user may
  overrule.** A leg carrying both a recording and a routed shape draws the recording, solid;
  a routed one alone draws dashed (`MapPath.dashed`). Both stay stored and the entry's own
  form lists both. The dash is the honest part: a map can only draw a line, and whether that
  line is a record or a proposal is exactly the difference a reader needs.
  What the default cannot know is that a recording is wrong *here*: a tunnel takes the fix,
  the trace jumps the block, and the computed route is the better drawing of that stretch.
  Hence `TrackDisplay` (v36) — `auto` / `shown` / `hidden` on the row, three states in one
  column, the arrangement the cover photo makes with two. Deleting the recording to get at
  the route would throw away **what actually happened**, which is the one thing that table
  exists to hold; hiding it keeps the row, and the copies and the bundle keep it too. `shown`
  is the other direction, and it is why this is not a `hidden` bool: a trace broken in two by
  that tunnel *plus* the route bridging it is one picture of one journey, and no rule can
  derive that. The decision lives once, in the pure `drawnTrackIds` — hidden never, shown
  always, and the rest by the old rule, counting a forced-`shown` recording as a recording —
  read by `tripMapFeatures` **and** by `summarizeTracks`, so a list saying a line is drawn
  cannot disagree with the map about the same picture. An entry whose lines are *all* hidden
  falls back to the **chord**, as an entry with no lines does: a leg vanishing because of a
  decision about how to draw it would be the bigger surprise. The control is an eye on each
  row of the form's list *and* of `MapItemSheet` — the second property on that sheet that is
  about the picture rather than the plan, there for the reason the color is: you notice you
  are looking at the wrong line while looking at it. Removing stays out of the sheet, being
  an act on the record rather than on the drawing. There is no way back to `auto` and none is
  wanted: deriving is never named, exactly as the cover star never names it. Being a
  statement about the line, it travels — `copyItemTracks` (a hidden trace would otherwise
  come back every morning a routine is stamped out) and the `.tpt`, written only when it says
  something and read as `auto` when absent, so no format version moves.
- **The chord is a line too, and the user may put it away.** `ItineraryItems.chordDisplay`
  (v39) gives the straight segment between a leg's ends the same three `TrackDisplay` states,
  decided once in the pure `chordDrawn`: `auto` draws it while no stored line is drawn (the
  rule above, unchanged), `hidden` never, `shown` beside whatever else is. The case it exists
  for is a leg whose ends are there **as a reference** — to frame the picker, to search a
  connection from, to count a country — and whose chord would cut across the picture saying
  nothing. Hiding it keeps the coordinates; only the line goes. That does not contradict the
  fallback above: what that rule forbids is a leg vanishing because of a decision about
  *another* line, and here the user is saying so about this very one. On the entry and not
  on `Tracks`, since the chord is not a row there — the reason the color is on the entry.
  It appears as a `ChordRow` under the stored lines wherever both ends are placed, drawn or
  not (a row that appeared only while its line was drawn could not put it back), with the
  eye and no remove, since the ends are edited as positions. In the item form the row
  reads the form's *current* ends, so it follows an end picked before saving, and its eye
  writes at once like a stored line's (`setChordDisplay`, targeted) while the form also
  holds the value so its full-row save cannot put back the one it opened with. A tap on
  the chord marks that row in `MapItemSheet` (`highlightChord`, since it has no track id).
  It travels with `copyItemPlan` and in the `.tpt` (by name, only when not `auto`, no version
  bump); it does **not** travel through `replaceJourneyLegs`, whose legs have new ends and
  usually their own routed shapes. The all-trips map honors it through `tripMapFeatures`.
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
- **A drawn line is one stored line, so it can be pointed at.** `tripMapFeatures` emits one
  `MapPath` per track rather than one per entry, each carrying the `trackId` it was drawn
  from (null for the straight segment between the ends, which is a drawing of the plan and
  not a row anybody can point at) — the pieces were already drawn separately, since a
  recording that stopped and started again has to keep its gap, so this costs nothing and
  buys the finer answer. `dashed` moves with it, from the entry to the line making the claim;
  the drawing is unchanged, because a set holding both kinds never reaches the map (the
  recorded ones supersede). What one path per line would otherwise break is the **mode
  badge**: `badged` marks exactly one path of an entry — the one holding its longest piece,
  which is where `MapPath.anchor` already put the icon — so a walk recorded in four segments
  still wears one icon, in the place it wore it before — and the marker layer draws a badge
  for that path **only**, since a marker wins the hit test against the line beneath it, so an
  icon on every path would take the taps of every line it sits on.
  The trip map then hit-tests its lines the way the all-trips map does (`hitNotifier`,
  `kLineHitbox` — "on this line" has to be a fingertip), and `pathsUnderTap` folds the hits
  to **one per entry, in draw order**: overlap is normal here too — a walk out and back lies
  on itself, neighbouring legs share a road at any zoom showing a city — and picking the
  last-drawn line would be the coin toss that map already refuses. Two entries are listed to
  choose from; two lines of *one* entry are one answer, because the sheet that opens lists
  that entry's lines anyway. Which is the other half of the tap: `MapItemSheet` takes a
  `highlightTrackId` and marks the row the finger landed on, since a map cannot say which
  line is which — every line of an entry is the same color by design. The **badge** marks no
  line: it is the entry's mark and not a line's, so a leg's lines listed unmarked is what
  "you tapped the icon" looks like. The rows are the item form's own `TrackRow`, so the words
  that tell two lines apart cannot come out differently in the two places; the sheet passes
  no `onRemove`, because it is a reading and removing is an act, which lives in the form its
  button opens.
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
