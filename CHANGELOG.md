# Changelog

Notable changes per release. Dates are release dates; the git tags carry the
exact commits.

## Unreleased

- **The countries map opens on the whole screen.** A button on the map puts it
  there with the list out of the way; the same button, the back button and the
  back gesture all bring the list back. The camera travels in both directions,
  so a region you zoomed in on fullscreen is where the small map is looking when
  you return.

## 1.9.0 — 2026-08-23

- **Photos and files on a plan.** A photograph or a document can hang on a single
  entry, on a group, or on the whole trip — the same three things a cost hangs
  on. They live **in** the database, not beside it, so a copy of that one file is
  still a copy of everything, and a `.tpt` bundle carries the bytes and stays
  lossless.
- **Which of the two a file becomes is the door it came through**, never the
  decoder: *Add photo* bounds and re-encodes the picture with a thumbnail beside
  it, *Add file* keeps the bytes exactly as they arrived, up to 20 MB — so a
  ticket sent as a `.png` can be filed under documents and handed on unchanged.
- A photo keeps the **position** the camera recorded, lifted into a field of its
  own and clearable there, and loses the rest of its EXIF to the re-encoding. A
  document is not re-encoded and so keeps its metadata; `SECURITY.md` says both.
- An entry counts its **photos and its documents apart**, because they are two
  acts: the first opens that entry's pictures as a gallery, the second lists its
  files. A trip's own photographs are a gallery too, reached from a band of
  thumbnails on the trip screen that folds away and stays folded.
- **One amber star does the cover.** Star a picture in the gallery and the trip's
  overview card shows it; unstar it and the card shows none. Until then the card
  shows the first photograph in gallery order, with the star filled on it.
- **Photographs are on the map** where they carry a position, drawn as their
  thumbnail in the color of the entry they hang on; those that would hide each
  other are gathered under one thumbnail with a count and come apart as you zoom
  in.
- The PDF gains a **Photos** section, off until you tick it, with the size beside
  the count. **Settings → Database** says what the file weighs and how much of it
  the attachments account for, and space freed by a deletion comes back on its
  own.

## 1.8.0 — 2026-08-21

- **Which countries you have been to**, as a third tab of the statistics: the
  world drawn from bundled outlines with the ones you have stood in filled in,
  and underneath a list by continent with how many of each you have been to, as
  a share and a worldwide total — out of the 195 states of the United Nations,
  with a dependency counting for the state it belongs to. It is counted from
  where an entry stands and never from the line between two, so a flight does
  not claim the countries it passes over. The map draws no tiles at all, so it
  needs no connection — the outlines are Natural Earth, public domain, credited
  on the license page.
- The countries map zooms **two steps further in**, which is what it takes to see
  Liechtenstein or Monaco, and Antarctica is drawn the right way round — the sea
  south of 60° was filled in and the continent left empty.
- A country can also be **ticked by hand** — in the list, or by tapping it on the
  map, which is the only way to tick a territory like Greenland — for somewhere
  you went before the app knew about it; it counts and draws exactly like one
  worked out from a trip. Which is also the answer to the very small countries:
  Monaco and the Vatican sit too far from their own generalized outlines to be
  recognized from a position.
- **Everything done to a group is now done on the group.** Its name and
  *Ungroup* move from the edit form of whichever member you happened to open to
  the ⋮ menu on the run's own label, beside moving, copying and deleting it.
  Ungrouping sits right above deleting, where the warning that ungrouping is the
  way to keep the entries can be acted on. A member's form keeps what is about
  that entry: group with next, remove from group.
- **The map can show where you are.** A locate button on a trip's map, on the
  all-trips map, and in the map picker — where it also takes that reading as the
  point being picked. One press asks for the permission, starts the receiver and
  centers the map once; after that the mark moves and the camera does not, so a
  map panned ahead stays where it was put. The reading is drawn with its accuracy
  as a circle around it, in a blue of its own so it cannot be mistaken for the
  plan's own "you are here".
- The position is **never stored and never sent** — not to a row, not into a
  `.tpt` bundle or any export, and not to the tile server, which is addressed by
  grid square exactly as before. It is the app's first runtime permission, asked
  for on the button press and at no other moment, and the receiver is released
  when the map is left. Nothing runs in the background.
- **A GPX import covers one path through the plan.** The entry picker lists a
  day as the timeline reads it, and each decision contributes a single option,
  switched on the decision's own row — which never settles it, and says so when
  it points at a road not taken. Listing every option at once printed the same
  station two and three times, and divided the recording at the wrong places.

## 1.7.0 — 2026-08-18

- **One recording is divided among the entries it covered.** A GPX file is made
  in one go and a plan is not, so an import cuts the line where one entry handed
  over to the next. Only legs get a stretch, a place between two legs supplies
  their handover — and a place with no position is filled in from it. Every
  handover nobody could supply is asked for, one tap on the line, with the
  division drawn while it is being decided.
- **An entry carries its own color on the map** (schema v30): a leg's line or a
  place's pin, chosen against the picture it lands in. Null still means the
  trip's accent. It travels with a copy, in a `.tpt` bundle, and through a
  re-route — but "under way" still outranks it, since red must not be hidden.
- **An end the router was given as a coordinate is named and dated.** A picked
  address, a point tapped on the map or an imported leg's own ends come back as
  `START`/`END` with no timezone at all. Those were being read as statements: the
  placeholder went into the timeline as the station's name, and the missing zone
  as UTC, which showed *and stored* a Hamburg walk two hours early.
- **The timetable is asked only about runs it can answer for.** Placing both ends
  of a campus walk on the map used to enlist it in a routine's unattended lookup,
  which asked about it every morning. A run of nothing but street legs is left
  alone; asking is still one tap away where a human is watching.
- **A re-routed connection draws along its line too**, not as chords between its
  stops — which is most visible in a routine, where re-routing is the ordinary
  act and adding a run the rare one.

## 1.6.0 — 2026-08-16

The map.

- **A map of a trip** — places as pins, transport legs as lines, in the trip's
  own accent colour, with the entry that is under way marked as the timeline
  marks it. Tapping a marker opens what the row says: name, times, delays, note,
  coordinates.
- **A map of every trip**, as a third way to read the overview beside the list
  and the calendar. It inherits the filter, so "only my walks" needs no second
  filter UI. A tap where routes overlap lists all the trips under it.
- **Places carry coordinates** (schema v28), picked by tapping the map. The
  connection search can be pointed at the map too, for an address the geocoder
  does not know.
- **GPX import** (schema v29): the line an entry actually followed is drawn
  instead of the straight one between its ends. It travels with every copy of
  the entry, and rides along in a `.tpt` bundle.
- **An imported connection brings its route**, so a train draws along its line
  rather than across the country. Those are dashed — computed, not recorded —
  and a GPX you import yourself takes precedence.
- A night train no longer reads as finished the minute it departs.

## 1.5.0 — 2026-08-09

Renamed to **Pappus Travel Planner**, with new icons and a new repository home.
Added a code of conduct, a security policy, and the `docs/` pages. A connection
can be looked up with no trip behind it.

## 1.4.0 — 2026-08-06

A journey's replacement is bundled per day, the trip's dates widen to cover what
was written, and checklists come along. A routine's journeys and legs can be
re-routed. A run drags as one block of its day.

## 1.3.0 — 2026-08-05

A whole group can be moved and deleted from its own label. A hand-entered run
can be looked up in the timetable.

## 1.2.0 — 2026-08-04

A journey can be looked up again from the sheet that reads it. An imported leg
keeps its stopovers and endpoint ids when edited. Added the about page.

## 1.1.0 — 2026-08-03

First tagged release.
