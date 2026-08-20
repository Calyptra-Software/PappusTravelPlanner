# Changelog

Notable changes per release. Dates are release dates; the git tags carry the
exact commits.

## Unreleased

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
