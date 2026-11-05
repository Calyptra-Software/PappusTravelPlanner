# Visited countries

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the countries tab, the outline asset and its builder, hand marks.

- **Where you have been is an aggregate, so it lives with the aggregates.** The countries a
  trip touched are a third tab of `TripStatsScreen`, not a layer on the all-trips map: the
  map answers "where did I go" and this answers "how much have I seen", and the two sit on
  opposite sides of the filter split — the map draws what `applyTripQuery` left visible,
  while the statistics read through a filter of their own (`statsTripQueryProvider`, below),
  which is why an answer here must not move when a tag chip on the overview is tapped. It is a `FlutterMap` with **no tiles at all**, only a `PolygonLayer`
  over `assets/geo/countries.json`, so it costs nobody's donated server, works offline, and
  worked on the web from its first day. A street map under it would answer a question nobody
  asked and make the fills harder to read.
- **A country is counted from where an entry *stands*, never from the line between two.**
  `visitedPoints` yields a place's own position and **both ends** of a leg, and nothing in
  between: a flight from Hamburg to Rome passes over Austria without anybody setting foot in
  it, and a chord on a map is not a claim about the ground beneath it. A single trip reads
  through `liveItems`, since an option nobody chose took nobody anywhere. Each end counts **on
  its own**, so `watchPositionedItems` — the all-trips reading — hands over a leg with only
  one end placed, which the all-trips map then simply does not draw (`tripMapFeatures` draws
  no line without both ends, and a trip left with nothing to draw is dropped before the
  camera is framed). It used to require both ends, a rule borrowed from the map, so the same
  trip could count a country on its own tab and not in the total.
- **A point off every outline goes to the nearest one only when it is close and clearly
  nearer** (`kOffshoreReachKm`, 3 km; `kOffshoreMargin`, twice as near as the runner-up). The
  rule used to be "never", on the grounds that a wrong country is a claim and a missing one
  only a gap — and that holds where the answer is genuinely open. But a generalized coast
  runs *inland* of the real one wherever the real one is intricate, which is exactly where
  ports and their stations are, so the gap was not a rare edge case: measured on the
  **unsimplified** 1:50m source, Copenhagen's central station lay 0.3 km out to sea,
  Stockholm's 0.9 km, Venice's 2.7 km, and so did Istanbul, Lisbon, Split and Dubrovnik. The
  move to 1:10m brought most of them ashore but not all — Copenhagen's station is still 140 m
  out in the source, Dubrovnik's old town 0.36 km off the asset — so a finer source narrows
  the gap and does not close it. The reach was set at 1:50m and kept, since open water is
  further out than that from anything. The margin is what keeps the old reason standing
  where it applies: the narrows between Helsingør and Helsingborg are 2.1 km from Denmark
  and 2.9 km from Sweden, nearer neither by enough, and count for neither. A point *inside*
  an outline is never moved — land borders are shared edges with no gap, so a border town
  already lies in one of its countries, and second-guessing that would trade a gap for a
  claim.
- **The outlines are Natural Earth 5.1.2 at 1:10m, packed with the track codec.** Rings are
  encoded polylines at three decimals (~110 m) and simplified with a Douglas-Peucker
  tolerance **scaled to each ring's own extent** (`min(0.005, extent / 60)`), which is what
  turns 13 MB of GeoJSON into a 1.0 MB asset (294k of 548k points) without deleting the
  micro-states: a fixed tolerance generous enough for Russia's coastline collapses San Marino
  to a triangle and Monaco to nothing. The set was 1:50m at 0.02° (243 KB) until a coast
  zoomed in on read as a run of straight cuts — and lowering the tolerance alone changed
  nothing visible, which is the lesson worth keeping: 1:50m's own edges are **8 km** long at
  the median, so the cuts were the source's, and only a finer source (1.7 km at 1:10m) could
  remove them. What it costs, measured on the desktop VM: parsing goes from 8 to 38 ms (once
  per launch, `countryOutlinesProvider` keeps it), and looking up 2000 inland positions from
  76 to 180 ms. The codec was already there and tested, and every mapping tool reads the format.
  **Holes are kept**, so Lesotho is Lesotho and not South Africa; that is the one
  thing a naive "outer ring only" conversion gets wrong, and there is a test standing on
  Maseru to say so. Regions are `REGION_UN`, except that the Americas are split by
  `CONTINENT` (the UN's single "Americas" is not how anybody reads a list of continents), and
  the names come from the source's own `NAME_EN`/`NAME_DE` rather than from a list this
  project would have to maintain — bar the one it gets wrong (`_nameFixes`: the Spratly
  Islands are called "Wake Island" there). `tool/build_country_outlines.dart` is the conversion, kept
  in the repo and writing through `encodeTrackPoints` — the same codec the app reads it with,
  so the two halves cannot drift, and rebuilding the asset is not an exercise in guessing what
  was done to it the first time.
- **An area is drawn; a state is counted.** The set holds the source's 258 areas, since a
  world map with holes where the dependencies are is a worse map — but what a tally means by
  "country" is the **195 states** of `kCountedStates` (below), so every area carries the
  `stateCode` it counts toward and
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
  times; nor does a **lease** (Baikonur answers `KZ`, and counts for Kazakhstan the way a
  dependency counts for its state). Brazilian Island answers `BR` and is claimed by Uruguay
  too, but the source calls it *indeterminate*, as it does Palestine, so the type cannot tell
  them apart and it is named in `_notStates` instead — counted for nobody.
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
  the whole country.** The micro-states are present and San Marino, Liechtenstein, Andorra,
  Singapore, Malta, the Maldives and — since 1:10m — Monaco are detected from real
  coordinates, but **the Vatican is not**: its outline stops short of St Peter's Square,
  which reads as `IT` (inside an outline, so never moved). Measured, written down in
  `assets/geo/countries-ATTRIBUTION.txt` and standing in a test, rather than left to be
  discovered by whoever goes there. The answer is not an ever finer asset — it is that a
  country can be ticked by hand.
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
- **Two rings in the world need special handling, and both are Antarctica's.** Its outline
  runs to **-89.999°**, which Mercator sends two and a third worlds below the bottom of the
  map, and it **steps 360°** along the pole to close the continent — the one ring in the set
  that crosses the antimeridian, since the source splits every other country there. Left
  alone, flutter_map's `projectList` unwrapped that step (it moves a point a whole world
  sideways when the step from the one before is wider than half of one), drew the returning
  coastline in the next world along, and filled the self-crossing path that made: the Southern
  Ocean came out as land and the continent as sea. The builder therefore **clamps** latitudes
  to `kMercatorLimit` and **rotates** a seam-crossing ring so the crossing falls between its
  last point and its first, where the painter draws it as the closing edge — which is exactly
  the edge along the bottom of the map the continent needs. Both are asserted in
  `visited_countries_test.dart`, since neither is visible until somebody pans south. The cost
  is stated: a position below 85° now falls outside its outline, which costs nothing — that
  ground counts for no state anyway, and no other outline comes within four degrees of the
  limit.
- **The list is what the map cannot say, so it sits under it and is never scrolled to.**
  `regionTallies` (pure) counts visited-of-total per region and the map is capped at **half
  the screen** — the map answers *how much*, the list answers *which*, and a list you have to
  scroll to discover is one nobody finds. Regions are ordered by size and never reorder as
  you travel: a list whose rows move when you visit a country is one you cannot learn. The
  map's zoom is fixed at the bottom by the width (`minZoom = log2(width / 256)`), which is
  exactly where flutter_map stops drawing the next copy of the world beside this one; where
  the height cap bites, the map gives up **width** and sits centered rather than cropping the
  poles off a full-width band. At the top it stops at `kCountryMapMaxZoom` — two steps past
  what a world view needs, since Liechtenstein and Monaco are a few pixels across at any zoom
  showing a continent and a country nobody can see is one nobody can tap, and no further,
  because the rings are stored to three decimals and simplified on top of that: past there the
  map would be promising a coastline it does not have. The map is also one tap from the
  **whole screen** — a full-screen route, for the reason `pickPointOnMap` is one: a map is
  dragged, and a sheet, a scroll or a growing box all answer a vertical drag as well. Once
  the map filled the viewport there would be nothing left to drag the list back with, since
  the map swallows the gesture; and growing it inside the tab leaves the app bar and the tab
  bar standing on exactly the height the map wants. The camera travels in both directions
  (`_CameraHandover`, mutable and passed by reference rather than returned by
  `Navigator.pop`, since the route can also be left by the back button and the back gesture,
  which carry no result) and is clamped on the way in: a wider map needs *more* zoom to fill
  itself with one world, so the floor the handed-over camera has to clear is the one this
  map computed for itself. The fullscreen map watches the providers itself rather than being
  handed the tab's snapshot — a country ticked there has to fill there, not on the way
  back — and the marking rule is the same function on both (`_markOnTap`).
